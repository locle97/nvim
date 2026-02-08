local state = require("quack-review.state")
local layout = require("quack-review.ui.layout")

local M = {}

local function render_diff_fallback(bufnr, wins, hunk)
    local status = state.get_status(hunk.global_index)
    local feedback = state.get_feedback(hunk.global_index)
    local idx = state.current_index()
    local total = state.total_hunks()

    local lines = {}

    local header = string.format(
        " %s  │  Hunk %d/%d  │  %s",
        hunk.file,
        idx,
        total,
        status
    )
    table.insert(lines, header)
    table.insert(lines, string.rep("─", math.max(#header, 60)))
    table.insert(lines, "")
    table.insert(lines, hunk.header)
    table.insert(lines, "")

    for _, line in ipairs(hunk.lines) do
        table.insert(lines, line)
    end

    if feedback then
        table.insert(lines, "")
        table.insert(lines, string.rep("─", 40))
        table.insert(lines, " 💬 Feedback:")
        for _, fline in ipairs(vim.split(feedback, "\n")) do
            table.insert(lines, "    " .. fline)
        end
    end

    layout.set_lines(bufnr, lines)
    layout.clear_hl(bufnr)

    for i, line in ipairs(lines) do
        local li = i - 1
        if i == 1 then
            layout.add_hl(bufnr, "Title", li, 0, -1)
        elseif line:match("^@@") then
            layout.add_hl(bufnr, "Function", li, 0, -1)
        elseif line:sub(1, 1) == "+" then
            layout.add_hl(bufnr, "DiffAdd", li, 0, -1)
        elseif line:sub(1, 1) == "-" then
            layout.add_hl(bufnr, "DiffDelete", li, 0, -1)
        elseif line:match("^ 💬") then
            layout.add_hl(bufnr, "DiagnosticInfo", li, 0, -1)
        elseif line:match("^─") then
            layout.add_hl(bufnr, "Comment", li, 0, -1)
        end
    end

    if wins.diff and vim.api.nvim_win_is_valid(wins.diff) then
        vim.api.nvim_win_set_cursor(wins.diff, { 1, 0 })
    end
end

local function highlight_hunk(bufnr, hunk)
    layout.clear_hl(bufnr)

    local line_count = vim.api.nvim_buf_line_count(bufnr)
    if line_count == 0 then
        return
    end

    local new_lnum = hunk.new_start
    local removed = 0

    for _, line in ipairs(hunk.lines) do
        local prefix = line:sub(1, 1)
        if prefix == "+" then
            if new_lnum >= 1 and new_lnum <= line_count then
                layout.add_hl(bufnr, "DiffAdd", new_lnum - 1, 0, -1)
            end
            new_lnum = new_lnum + 1
        elseif prefix == " " then
            if new_lnum >= 1 and new_lnum <= line_count then
                layout.add_hl(bufnr, "DiffChange", new_lnum - 1, 0, -1)
            end
            new_lnum = new_lnum + 1
        elseif prefix == "-" then
            removed = removed + 1
        end
    end

    if removed > 0 then
        local anchor = math.min(math.max(hunk.new_start, 1), line_count)
        vim.api.nvim_buf_set_extmark(bufnr, layout.namespace(), anchor - 1, 0, {
            virt_text = { { "-" .. removed .. " removed", "DiffDelete" } },
            virt_text_pos = "eol",
        })
    end
end

local function set_file_view(bufnr, file_path)
    local ok, file_lines = pcall(vim.fn.readfile, file_path)
    if not ok then
        return false
    end

    vim.bo[bufnr].modifiable = true
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, file_lines)
    vim.bo[bufnr].modifiable = false

    local ft = vim.filetype.match({ filename = file_path })
    if ft and ft ~= "" then
        vim.bo[bufnr].filetype = ft
        pcall(vim.treesitter.start, bufnr, ft)
    else
        vim.bo[bufnr].filetype = ""
    end

    return true
end

--- Render the diff panel for the current hunk.
function M.render()
    local bufs = layout.get_bufs()
    local wins = layout.get_wins()
    local bufnr = bufs.diff
    if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then return end

    local hunk = state.current_hunk()
    if not hunk then
        layout.set_lines(bufnr, { "", "  No hunks to display." })
        return
    end

    local file_path = hunk.file
    local readable = vim.fn.filereadable(file_path) == 1
    if not readable then
        render_diff_fallback(bufnr, wins, hunk)
        return
    end

    if not set_file_view(bufnr, file_path) then
        render_diff_fallback(bufnr, wins, hunk)
        return
    end

    pcall(vim.fn.sign_unplace, "quack_review", { buffer = bufnr })

    local status = state.get_status(hunk.global_index)
    local idx = state.current_index()
    local total = state.total_hunks()

    if wins.diff and vim.api.nvim_win_is_valid(wins.diff) then
        vim.wo[wins.diff].winbar = string.format(" %s  │  Hunk %d/%d  │  %s", hunk.file, idx, total, status)
    end

    highlight_hunk(bufnr, hunk)

    if wins.diff and vim.api.nvim_win_is_valid(wins.diff) then
        local line_count = vim.api.nvim_buf_line_count(bufnr)
        local target = math.min(math.max(hunk.new_start, 1), math.max(line_count, 1))
        vim.api.nvim_win_set_cursor(wins.diff, { target, 0 })
    end
end

return M
