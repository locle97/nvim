local state = require("quack-review.state")
local layout = require("quack-review.ui.layout")

local M = {}

-- Status icons
local STATUS_ICONS = {
    pending   = "?",
    accepted  = "✔",
    rejected  = "✘",
    commented = "💬",
}

-- Highlight groups for statuses
local STATUS_HL = {
    pending   = "DiagnosticWarn",
    accepted  = "DiagnosticOk",
    rejected  = "DiagnosticError",
    commented = "DiagnosticInfo",
}

--- Compute per-file status summary.
local function file_status_summary(file)
    local counts = { pending = 0, accepted = 0, rejected = 0, commented = 0 }
    for _, hunk in ipairs(file.hunks) do
        local s = state.get_status(hunk.global_index)
        counts[s] = (counts[s] or 0) + 1
    end
    return counts
end

--- Render the summary panel.
function M.render()
    local bufs = layout.get_bufs()
    local bufnr = bufs.summary
    if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then return end

    local parsed = state.get_parsed()
    if not parsed then return end

    local counts = state.counts()
    local idx = state.current_index()
    local total = state.total_hunks()
    local current_hunk = state.current_hunk()
    local source = state.get_diff_source() or "unstaged"

    local lines = {}
    local highlights = {}

    -- Header
    table.insert(lines, "  QUACK REVIEW                                    " .. source)
    table.insert(highlights, { line = #lines - 1, col_start = 2, col_end = 14, hl = "Title" })

    -- Stats bar
    local stats = string.format(
        "  Files: %d  │  Hunks: %d/%d  │  +%d  -%d  │  ✔ %d  ✘ %d  💬 %d  ? %d",
        parsed.total_files, idx, total,
        parsed.total_added, parsed.total_removed,
        counts.accepted, counts.rejected, counts.commented, counts.pending
    )
    table.insert(lines, stats)
    table.insert(lines, "")

    -- Separator
    table.insert(lines, "  " .. string.rep("─", 60))
    table.insert(lines, "")

    -- File list
    for _, file in ipairs(parsed.files) do
        local fc = file_status_summary(file)
        local is_current = current_hunk and current_hunk.file == file.path

        -- Build status indicator string
        local status_parts = {}
        if fc.accepted > 0 then table.insert(status_parts, "✔" .. fc.accepted) end
        if fc.rejected > 0 then table.insert(status_parts, "✘" .. fc.rejected) end
        if fc.commented > 0 then table.insert(status_parts, "💬" .. fc.commented) end
        if fc.pending > 0 then table.insert(status_parts, "?" .. fc.pending) end
        local status_str = table.concat(status_parts, " ")

        local prefix = is_current and "  ▶ " or "    "
        local line = string.format(
            "%s%-40s (%d hunks)  %s",
            prefix,
            file.path,
            file.total_hunks,
            status_str
        )
        table.insert(lines, line)

        -- Highlight current file
        local line_idx = #lines - 1
        if is_current then
            table.insert(highlights, { line = line_idx, col_start = 0, col_end = #line, hl = "CursorLine" })
        end

        -- Highlight the status parts
        if fc.accepted > 0 then
            table.insert(highlights, { line = line_idx, col_start = 0, col_end = 0, hl = "DiagnosticOk" })
        end
    end

    layout.set_lines(bufnr, lines)

    -- Apply highlights
    layout.clear_hl(bufnr)
    for _, hl in ipairs(highlights) do
        layout.add_hl(bufnr, hl.hl, hl.line, hl.col_start, hl.col_end)
    end
end

return M
