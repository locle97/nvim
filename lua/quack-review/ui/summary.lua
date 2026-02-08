local state = require("quack-review.state")
local layout = require("quack-review.ui.layout")

local M = {}

local function build_tree(files)
    local root = { name = "", children = {}, files = {} }
    for _, file in ipairs(files) do
        local parts = vim.split(file.path, "/", { plain = true })
        local node = root
        for i = 1, #parts - 1 do
            local part = parts[i]
            if not node.children[part] then
                node.children[part] = { name = part, children = {}, files = {} }
            end
            node = node.children[part]
        end
        table.insert(node.files, { name = parts[#parts], file = file })
    end
    return root
end

local function collect_entries(node)
    local entries = {}
    for _, child in pairs(node.children) do
        table.insert(entries, { type = "dir", name = child.name, node = child })
    end
    for _, file in ipairs(node.files) do
        table.insert(entries, { type = "file", name = file.name, file = file.file })
    end
    table.sort(entries, function(a, b)
        if a.type ~= b.type then
            return a.type == "dir"
        end
        return a.name < b.name
    end)
    return entries
end

local function render_tree(node, prefix, lines, highlights, current_path)
    local entries = collect_entries(node)
    for i, entry in ipairs(entries) do
        local is_last = i == #entries
        local branch = is_last and "└── " or "├── "
        local next_prefix = prefix .. (is_last and "    " or "│   ")

        if entry.type == "dir" then
            local line = "  " .. prefix .. branch .. entry.name .. "/"
            table.insert(lines, line)
            render_tree(entry.node, next_prefix, lines, highlights, current_path)
        else
            local label = entry.name
            if entry.file.is_new then
                label = label .. " [new]"
            end
            local is_current = entry.file.path == current_path
            local indicator = is_current and "▶ " or "  "
            local line = indicator .. "  " .. prefix .. branch .. label
            table.insert(lines, line)
            if is_current then
                table.insert(highlights, { line = #lines - 1, col_start = 0, col_end = #line, hl = "CursorLine" })
            end
        end
    end
end

--- Render the summary panel.
function M.render()
    local bufs = layout.get_bufs()
    local bufnr = bufs.summary
    if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then return end

    local parsed = state.get_parsed()
    if not parsed then return end

    local current_hunk = state.current_hunk()
    local source = state.get_diff_source() or "unstaged"

    local lines = {}
    local highlights = {}

    table.insert(lines, "  QUACK REVIEW  " .. source)
    table.insert(highlights, { line = #lines - 1, col_start = 2, col_end = 14, hl = "Title" })
    table.insert(lines, string.format("  Files: %d  Hunks: %d", parsed.total_files, parsed.total_hunks))
    table.insert(lines, "")

    if #parsed.files == 0 then
        table.insert(lines, "  No files to display.")
    else
        local tree = build_tree(parsed.files)
        render_tree(tree, "", lines, highlights, current_hunk and current_hunk.file or nil)
    end

    layout.set_lines(bufnr, lines)

    layout.clear_hl(bufnr)
    for _, hl in ipairs(highlights) do
        layout.add_hl(bufnr, hl.hl, hl.line, hl.col_start, hl.col_end)
    end
end

return M
