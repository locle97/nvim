local state = require("quack-review.state")
local layout = require("quack-review.ui.layout")

local M = {}

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

    local status = state.get_status(hunk.global_index)
    local feedback = state.get_feedback(hunk.global_index)
    local idx = state.current_index()
    local total = state.total_hunks()

    local lines = {}

    -- Winbar-style header line
    local header = string.format(
        " %s  │  Hunk %d/%d (file %d/%d)  │  %s",
        hunk.file,
        hunk.index,
        -- total hunks in this file
        (function()
            local parsed = state.get_parsed()
            for _, f in ipairs(parsed.files) do
                if f.path == hunk.file then return f.total_hunks end
            end
            return "?"
        end)(),
        idx,
        total,
        status
    )
    table.insert(lines, header)
    table.insert(lines, string.rep("─", math.max(#header, 60)))
    table.insert(lines, "")

    -- Hunk header (@@ line)
    table.insert(lines, hunk.header)
    table.insert(lines, "")

    -- Diff lines
    for _, line in ipairs(hunk.lines) do
        table.insert(lines, line)
    end

    -- Feedback section if commented
    if feedback then
        table.insert(lines, "")
        table.insert(lines, string.rep("─", 40))
        table.insert(lines, " 💬 Feedback:")
        for _, fline in ipairs(vim.split(feedback, "\n")) do
            table.insert(lines, "    " .. fline)
        end
    end

    layout.set_lines(bufnr, lines)

    -- Apply highlights
    layout.clear_hl(bufnr)
    local ns = layout.namespace()

    for i, line in ipairs(lines) do
        local li = i - 1 -- 0-indexed
        if i == 1 then
            -- Header line
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

    -- Place signs in the sign column for the diff lines
    pcall(vim.fn.sign_unplace, "quack_review", { buffer = bufnr })

    -- Define signs if not already defined
    local sign_ok = pcall(vim.fn.sign_getdefined, "quack_add")
    if not sign_ok or #vim.fn.sign_getdefined("quack_add") == 0 then
        vim.fn.sign_define("quack_add", { text = "+", texthl = "DiffAdd" })
        vim.fn.sign_define("quack_del", { text = "-", texthl = "DiffDelete" })
        vim.fn.sign_define("quack_ctx", { text = " ", texthl = "Comment" })
    end

    -- Skip header lines (first 5), then place signs on diff content
    local header_offset = 5 -- header, separator, blank, @@ line, blank
    for i = header_offset + 1, #lines do
        local line = lines[i]
        local sign_name = nil
        if line:sub(1, 1) == "+" then
            sign_name = "quack_add"
        elseif line:sub(1, 1) == "-" then
            sign_name = "quack_del"
        elseif line:sub(1, 1) == " " then
            sign_name = "quack_ctx"
        end
        if sign_name then
            vim.fn.sign_place(0, "quack_review", sign_name, bufnr, { lnum = i })
        end
    end

    -- Scroll to top of diff content
    if wins.diff and vim.api.nvim_win_is_valid(wins.diff) then
        vim.api.nvim_win_set_cursor(wins.diff, { 1, 0 })
    end
end

return M
