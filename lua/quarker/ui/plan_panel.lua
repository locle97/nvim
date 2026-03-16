-- lua/quarker/ui/plan_panel.lua
-- Right-side vertical split panel showing a raw task_plan.md with
-- valid file-path highlights and hotkey navigation.

local M = {}

local state = {
    panel_win   = nil,   -- window id
    panel_buf   = nil,   -- buffer id
    orig_win    = nil,   -- window to return focus to
    source_file = nil,   -- absolute path to task_plan.md
    line_map    = {},    -- line_nr (1-indexed) → { files = [abs_path, ...] }
}

local NS = vim.api.nvim_create_namespace("quarker_plan_panel")

--- Define (or refresh) the path highlight group: Special fg + bold + underline.
local function setup_highlights()
    local special = vim.api.nvim_get_hl(0, { name = "Special", link = false })
    vim.api.nvim_set_hl(0, "QuarkerPlanPath", vim.tbl_extend("force", special, {
        bold      = true,
        underline = true,
    }))
end

-- Tracks which file was last opened per line (for Tab cycling)
local tab_state = { line = nil, idx = 1 }

--- Resolve a relative token to an absolute readable path, or nil.
local function resolve_file(token)
    local root = vim.fn.systemlist("git rev-parse --show-toplevel 2>/dev/null")[1]
    if not root or root == "" or root:match("^fatal") then
        root = vim.fn.getcwd()
    end
    local src_dir = vim.fn.fnamemodify(state.source_file or "", ":h")
    for _, base in ipairs({ root, src_dir }) do
        local p = base .. "/" .. token
        if vim.fn.filereadable(p) == 1 then return p end
    end
    if vim.fn.filereadable(token) == 1 then return token end
    return nil
end

--- Read source_file, find valid path tokens per line, build highlights + line_map.
local function build_render()
    local raw = vim.fn.readfile(state.source_file)
    if not raw then return {}, {}, {} end

    local highlights = {}
    local line_map   = {}

    for i, line in ipairs(raw) do
        local files = {}
        local pos   = 1
        while true do
            local s, e, token = line:find("`([^`]+)`", pos)
            if not s then break end
            -- Only consider tokens that look like file paths
            if token:match("[./]") then
                local resolved = resolve_file(token)
                if resolved then
                    table.insert(files, resolved)
                    -- Highlight the backtick-quoted span (col is 0-indexed, e is inclusive 1-indexed)
                    table.insert(highlights, {
                        line      = i,
                        col_start = s - 1,
                        col_end   = e,
                        hl_group  = "QuarkerPlanPath",
                    })
                end
            end
            pos = e + 1
        end
        if #files > 0 then
            line_map[i] = { files = files }
        end
    end

    return raw, highlights, line_map
end

--- Render the raw plan file into the panel buffer.
local function render()
    local bufnr = state.panel_buf
    if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then return end

    local lines, highlights, line_map = build_render()
    state.line_map = line_map

    vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(bufnr, "modifiable", false)

    vim.api.nvim_buf_clear_namespace(bufnr, NS, 0, -1)
    for _, hl in ipairs(highlights) do
        vim.api.nvim_buf_add_highlight(bufnr, NS, hl.hl_group, hl.line - 1, hl.col_start, hl.col_end)
    end
end

-- ── Navigation helpers ────────────────────────────────────────────────────────

--- Open an absolute path in orig_win, keep panel focused.
local function open_file_in_orig(abs_path)
    if not (state.orig_win and vim.api.nvim_win_is_valid(state.orig_win)) then
        vim.notify("[quarker] Original window is gone", vim.log.levels.WARN)
        return
    end
    vim.api.nvim_set_current_win(state.orig_win)
    vim.cmd("edit " .. vim.fn.fnameescape(abs_path))
    if state.panel_win and vim.api.nvim_win_is_valid(state.panel_win) then
        vim.api.nvim_set_current_win(state.panel_win)
    end
end

--- <CR> / gf variant: open first valid file on current line.
local function nav_open_first()
    local ln    = vim.api.nvim_win_get_cursor(state.panel_win)[1]
    local entry = state.line_map[ln]
    if not entry then
        vim.notify("[quarker] No valid file path on this line", vim.log.levels.INFO)
        return
    end
    tab_state.line = ln
    tab_state.idx  = 1
    open_file_in_orig(entry.files[1])
end

--- gf: open the file whose backtick token the cursor is sitting on.
--- Falls back to first file on the line.
local function nav_gf()
    local cursor = vim.api.nvim_win_get_cursor(state.panel_win)
    local ln     = cursor[1]
    local col    = cursor[2]  -- 0-indexed
    local line   = vim.api.nvim_buf_get_lines(state.panel_buf, ln - 1, ln, false)[1] or ""

    local pos = 1
    while true do
        local s, e, token = line:find("`([^`]+)`", pos)
        if not s then break end
        if col >= s - 1 and col < e then
            local resolved = resolve_file(token)
            if resolved then
                open_file_in_orig(resolved)
                return
            end
        end
        pos = e + 1
    end

    -- Fallback: first file on this line
    local entry = state.line_map[ln]
    if entry then
        open_file_in_orig(entry.files[1])
    else
        vim.notify("[quarker] No file path under cursor", vim.log.levels.INFO)
    end
end

--- <Tab>: cycle to next file on current line.
local function nav_tab_next()
    local ln    = vim.api.nvim_win_get_cursor(state.panel_win)[1]
    local entry = state.line_map[ln]
    if not entry then return end
    if tab_state.line ~= ln then
        tab_state.line = ln
        tab_state.idx  = 1
    else
        tab_state.idx = (tab_state.idx % #entry.files) + 1
    end
    open_file_in_orig(entry.files[tab_state.idx])
end

--- <S-Tab>: cycle to previous file on current line.
local function nav_tab_prev()
    local ln    = vim.api.nvim_win_get_cursor(state.panel_win)[1]
    local entry = state.line_map[ln]
    if not entry then return end
    if tab_state.line ~= ln then
        tab_state.line = ln
        tab_state.idx  = #entry.files
    else
        tab_state.idx = ((tab_state.idx - 2) % #entry.files) + 1
    end
    open_file_in_orig(entry.files[tab_state.idx])
end

--- ]p / [p: jump between ### section headers.
local function get_header_lines()
    local result = {}
    local total  = vim.api.nvim_buf_line_count(state.panel_buf)
    for ln = 1, total do
        local line = vim.api.nvim_buf_get_lines(state.panel_buf, ln - 1, ln, false)[1] or ""
        if line:match("^#") then
            table.insert(result, ln)
        end
    end
    return result
end

local function jump_next_header()
    local cur     = vim.api.nvim_win_get_cursor(state.panel_win)[1]
    local headers = get_header_lines()
    for _, ln in ipairs(headers) do
        if ln > cur then
            vim.api.nvim_win_set_cursor(state.panel_win, { ln, 0 })
            return
        end
    end
    if #headers > 0 then
        vim.api.nvim_win_set_cursor(state.panel_win, { headers[1], 0 })
    end
end

local function jump_prev_header()
    local cur     = vim.api.nvim_win_get_cursor(state.panel_win)[1]
    local headers = get_header_lines()
    for i = #headers, 1, -1 do
        if headers[i] < cur then
            vim.api.nvim_win_set_cursor(state.panel_win, { headers[i], 0 })
            return
        end
    end
    if #headers > 0 then
        vim.api.nvim_win_set_cursor(state.panel_win, { headers[#headers], 0 })
    end
end

--- <Space>: toggle `- [ ]` ↔ `- [x]` and write change to disk.
local function toggle_checkbox()
    local ln   = vim.api.nvim_win_get_cursor(state.panel_win)[1]
    local line = vim.api.nvim_buf_get_lines(state.panel_buf, ln - 1, ln, false)[1] or ""

    local new_line
    if line:match("^%s*%- %[ %]") then
        new_line = line:gsub("^(%s*%- )%[ %]", "%1[x]", 1)
    elseif line:match("^%s*%- %[x%]") then
        new_line = line:gsub("^(%s*%- )%[x%]", "%1[ ]", 1)
    else
        vim.notify("[quarker] Not a checklist item", vim.log.levels.INFO)
        return
    end

    -- Update buffer in-place (no full re-render needed)
    vim.api.nvim_buf_set_option(state.panel_buf, "modifiable", true)
    vim.api.nvim_buf_set_lines(state.panel_buf, ln - 1, ln, false, { new_line })
    vim.api.nvim_buf_set_option(state.panel_buf, "modifiable", false)

    -- Write to disk
    local file_lines = vim.fn.readfile(state.source_file)
    if file_lines and file_lines[ln] then
        file_lines[ln] = new_line
        vim.fn.writefile(file_lines, state.source_file)
    end
end

--- p: pick a different plan (vim.ui.select; telescope added in Phase 5).
local function pick_plan()
    local plan_mod = require("quarker.plan")
    local paths    = plan_mod.discover_plans()
    if #paths == 0 then
        vim.notify("[quarker] No plans found", vim.log.levels.WARN)
        return
    end
    if #paths == 1 then
        M.open(paths[1])
        return
    end
    vim.ui.select(paths, {
        prompt = "Select plan:",
        format_item = function(p)
            return vim.fn.fnamemodify(p, ":h:t") .. "  (" .. vim.fn.fnamemodify(p, ":~:.") .. ")"
        end,
    }, function(choice)
        if choice then M.open(choice) end
    end)
end

-- ── Keymap setup ──────────────────────────────────────────────────────────────

local function setup_keymaps(bufnr)
    local o = { buffer = bufnr, nowait = true, silent = true }
    local function k(key, fn, desc)
        vim.keymap.set("n", key, fn, vim.tbl_extend("force", o, { desc = desc }))
    end

    k("q",       M.close,          "Close plan panel")
    k("<Esc>",   M.close,          "Close plan panel")
    k("r",       M.reload,         "Reload plan from disk")
    k("<CR>",    nav_open_first,   "Open file on this line")
    k("o",       nav_open_first,   "Open file on this line")
    k("gf",      nav_gf,           "Go to file under cursor")
    k("<Tab>",   nav_tab_next,     "Cycle to next file on line")
    k("<S-Tab>", nav_tab_prev,     "Cycle to prev file on line")
    k("]p",      jump_next_header, "Jump to next section header")
    k("[p",      jump_prev_header, "Jump to prev section header")
    k("<Space>", toggle_checkbox,  "Toggle checkbox + write to disk")
    k("p",       pick_plan,        "Pick a different plan")
end

-- ── Public API ────────────────────────────────────────────────────────────────

--- Open the plan panel for the given task_plan.md path.
---@param source_file string  Absolute path to task_plan.md
function M.open(source_file)
    if M.is_open() then M.close() end

    state.orig_win    = vim.api.nvim_get_current_win()
    state.source_file = source_file

    setup_highlights()

    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(buf, "buftype",   "nofile")
    vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
    vim.api.nvim_buf_set_option(buf, "swapfile",  false)
    vim.api.nvim_buf_set_option(buf, "filetype",  "markdown")

    vim.cmd("botright vsplit")
    local win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win, buf)

    local width = math.max(40, math.min(80, math.floor(vim.o.columns * 0.35)))
    vim.api.nvim_win_set_width(win, width)

    vim.wo[win].winfixwidth    = true
    vim.wo[win].wrap           = false
    vim.wo[win].number         = false
    vim.wo[win].relativenumber = false
    vim.wo[win].cursorline     = true
    vim.wo[win].signcolumn     = "no"

    state.panel_win = win
    state.panel_buf = buf

    render()
    setup_keymaps(buf)

    vim.api.nvim_create_autocmd("BufWipeout", {
        buffer   = buf,
        once     = true,
        callback = function()
            state.panel_buf = nil
            state.panel_win = nil
            state.line_map  = {}
        end,
    })

    vim.api.nvim_set_current_win(state.orig_win)
end

--- Close the plan panel and restore focus.
function M.close()
    if state.panel_win and vim.api.nvim_win_is_valid(state.panel_win) then
        vim.api.nvim_win_close(state.panel_win, true)
    end
    state.panel_win = nil
    state.panel_buf = nil
    state.line_map  = {}
    if state.orig_win and vim.api.nvim_win_is_valid(state.orig_win) then
        vim.api.nvim_set_current_win(state.orig_win)
    end
end

--- Toggle open/closed.
---@param source_file string
function M.toggle(source_file)
    if M.is_open() then M.close() else M.open(source_file) end
end

---@return boolean
function M.is_open()
    return state.panel_win ~= nil and vim.api.nvim_win_is_valid(state.panel_win)
end

--- Re-read task_plan.md from disk and re-render.
function M.reload()
    if not state.source_file then return end
    render()
    vim.notify("[quarker] Plan reloaded", vim.log.levels.INFO)
end

return M
