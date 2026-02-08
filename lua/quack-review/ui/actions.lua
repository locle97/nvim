local state = require("quack-review.state")
local layout = require("quack-review.ui.layout")

local M = {}

-- Visual indicators per status
local STATUS_DISPLAY = {
    pending   = { icon = "?", label = "PENDING",   hl = "DiagnosticWarn" },
    accepted  = { icon = "✔", label = "ACCEPTED",  hl = "DiagnosticOk" },
    rejected  = { icon = "✘", label = "REJECTED",  hl = "DiagnosticError" },
    commented = { icon = "💬", label = "COMMENTED", hl = "DiagnosticInfo" },
}

--- Render the actions panel.
function M.render()
    local bufs = layout.get_bufs()
    local bufnr = bufs.actions
    if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then return end

    local hunk = state.current_hunk()
    local counts = state.counts()
    local total = state.total_hunks()
    local idx = state.current_index()

    local lines = {}
    local highlights = {}

    -- Title
    table.insert(lines, "  ACTIONS")
    table.insert(highlights, { line = #lines - 1, hl = "Title" })
    table.insert(lines, "  " .. string.rep("─", 24))
    table.insert(lines, "")

    if hunk then
        local status = state.get_status(hunk.global_index)
        local display = STATUS_DISPLAY[status] or STATUS_DISPLAY.pending
        local filename = vim.fn.fnamemodify(hunk.file, ":t")

        -- Current hunk info
        table.insert(lines, "  File: " .. filename)
        table.insert(lines, "  Path: " .. hunk.file)
        table.insert(lines, string.format("  Hunk: %d / %d", hunk.index,
            (function()
                local parsed = state.get_parsed()
                for _, f in ipairs(parsed.files) do
                    if f.path == hunk.file then return f.total_hunks end
                end
                return "?"
            end)()
        ))
        table.insert(lines, string.format("  Global: %d / %d", idx, total))
        table.insert(lines, string.format("  Lines: +%d -%d", hunk.added, hunk.removed))
        table.insert(lines, "")

        -- Status display
        local status_line = string.format("  Status: %s %s", display.icon, display.label)
        table.insert(lines, status_line)
        table.insert(highlights, { line = #lines - 1, hl = display.hl })

        -- Show feedback preview if commented
        if status == "commented" then
            local fb = state.get_feedback(hunk.global_index)
            if fb then
                table.insert(lines, "")
                table.insert(lines, "  Feedback:")
                local preview = fb:sub(1, 60)
                if #fb > 60 then preview = preview .. "..." end
                table.insert(lines, "  " .. preview)
                table.insert(highlights, { line = #lines - 1, hl = "DiagnosticInfo" })
            end
        end
    else
        table.insert(lines, "  No hunk selected")
    end

    table.insert(lines, "")
    table.insert(lines, "  " .. string.rep("─", 24))
    table.insert(lines, "")

    -- Keybindings reference
    table.insert(lines, "  KEYS")
    table.insert(highlights, { line = #lines - 1, hl = "Title" })
    table.insert(lines, "  " .. string.rep("─", 24))
    table.insert(lines, "")
    table.insert(lines, "  a       Accept hunk")
    table.insert(lines, "  r       Reject hunk")
    table.insert(lines, "  c       Comment (float)")
    table.insert(lines, "  x       Reset to pending")
    table.insert(lines, "")
    table.insert(lines, "  n / p   Next / Prev hunk")
    table.insert(lines, "  ]f / [f Next / Prev file")
    table.insert(lines, "  ]u / [u Next / Prev unresolved")
    table.insert(lines, "")
    table.insert(lines, "  A       Apply (revert rejected)")
    table.insert(lines, "  R       Revert menu")
    table.insert(lines, "  S       Export feedback")
    table.insert(lines, "  q       Quit review")
    table.insert(lines, "")
    table.insert(lines, "  " .. string.rep("─", 24))
    table.insert(lines, "")

    -- Progress summary
    table.insert(lines, "  PROGRESS")
    table.insert(highlights, { line = #lines - 1, hl = "Title" })
    table.insert(lines, "  " .. string.rep("─", 24))
    table.insert(lines, "")

    -- Progress bar
    local resolved = counts.accepted + counts.rejected + counts.commented
    local pct = total > 0 and math.floor((resolved / total) * 100) or 0
    local bar_width = 20
    local filled = math.floor((resolved / math.max(total, 1)) * bar_width)
    local bar = string.rep("█", filled) .. string.rep("░", bar_width - filled)
    table.insert(lines, string.format("  [%s] %d%%", bar, pct))
    table.insert(lines, "")

    table.insert(lines, string.format("  ✔ Accepted:  %d", counts.accepted))
    table.insert(highlights, { line = #lines - 1, hl = "DiagnosticOk" })
    table.insert(lines, string.format("  ✘ Rejected:  %d", counts.rejected))
    table.insert(highlights, { line = #lines - 1, hl = "DiagnosticError" })
    table.insert(lines, string.format("  💬 Commented: %d", counts.commented))
    table.insert(highlights, { line = #lines - 1, hl = "DiagnosticInfo" })
    table.insert(lines, string.format("  ? Pending:   %d", counts.pending))
    table.insert(highlights, { line = #lines - 1, hl = "DiagnosticWarn" })

    layout.set_lines(bufnr, lines)

    -- Apply highlights
    layout.clear_hl(bufnr)
    for _, hl in ipairs(highlights) do
        layout.add_hl(bufnr, hl.hl, hl.line, 0, -1)
    end
end

return M
