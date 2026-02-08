local parser = require("quack-review.parser")
local state = require("quack-review.state")
local ui = require("quack-review.ui")
local export = require("quack-review.export")
local apply = require("quack-review.apply")

local M = {}

--- Start a review session.
--- @param opts table|nil Options: { source = "unstaged"|"staged"|"head"|"HEAD~1"|... }
function M.start(opts)
    opts = opts or {}

    if state.is_active() then
        vim.notify("quack-review: Review session already active. Use :QuackReview stop first.", vim.log.levels.WARN)
        return
    end

    local source = opts.source
    local diff_text = parser.get_diff(source)

    if diff_text == "" then
        vim.notify("quack-review: No diff found.", vim.log.levels.INFO)
        return
    end

    local parsed = parser.parse(diff_text)

    if parsed.total_hunks == 0 then
        vim.notify("quack-review: No hunks to review.", vim.log.levels.INFO)
        return
    end

    local flat_hunks = parser.flatten_hunks(parsed)
    state.start(parsed, flat_hunks, source)

    vim.notify(
        string.format(
            "quack-review: Started review — %d files, %d hunks, +%d -%d",
            parsed.total_files,
            parsed.total_hunks,
            parsed.total_added,
            parsed.total_removed
        ),
        vim.log.levels.INFO
    )

    -- Open the review UI
    ui.open()
end

--- Stop the current review session.
function M.stop()
    if not state.is_active() then
        vim.notify("quack-review: No active review session.", vim.log.levels.WARN)
        return
    end

    local counts = state.counts()

    -- Close UI first
    if ui.is_open() then
        ui.close()
    end

    state.stop()

    vim.notify(
        string.format(
            "quack-review: Session ended — accepted: %d, rejected: %d, commented: %d",
            counts.accepted,
            counts.rejected,
            counts.commented
        ),
        vim.log.levels.INFO
    )
end

--- Get review status for statusline integration.
function M.statusline()
    if not state.is_active() then
        return ""
    end

    local counts = state.counts()
    local idx = state.current_index()
    local total = state.total_hunks()
    local hunk = state.current_hunk()
    local file = hunk and vim.fn.fnamemodify(hunk.file, ":t") or "?"

    return string.format(
        " 󰈈 %s [%d/%d] ✔%d ✘%d 💬%d",
        file, idx, total,
        counts.accepted, counts.rejected, counts.commented
    )
end

--- Export review feedback (JSON + markdown + clipboard).
function M.export()
    export.export_all()
end

--- Apply review decisions (revert rejected/commented hunks).
function M.apply_review(opts)
    apply.apply(opts)
end

--- Debug: print parsed diff summary.
function M.debug(source)
    local diff_text = parser.get_diff(source)
    if diff_text == "" then
        vim.notify("quack-review: No diff found.", vim.log.levels.INFO)
        return
    end

    local parsed = parser.parse(diff_text)
    local lines = {
        "quack-review: Diff Summary",
        string.format("  Files: %d", parsed.total_files),
        string.format("  Hunks: %d", parsed.total_hunks),
        string.format("  Added: +%d", parsed.total_added),
        string.format("  Removed: -%d", parsed.total_removed),
        "",
    }

    for _, file in ipairs(parsed.files) do
        table.insert(lines, string.format("  %s (%d hunks, +%d -%d)%s",
            file.path, file.total_hunks, file.added, file.removed,
            file.is_binary and " [binary]" or ""
        ))
        for _, hunk in ipairs(file.hunks) do
            table.insert(lines, string.format("    Hunk %d: %s (%d lines, +%d -%d)",
                hunk.index, hunk.header:sub(1, 40), #hunk.lines, hunk.added, hunk.removed
            ))
        end
    end

    print(table.concat(lines, "\n"))
end

-- ==========================================================================
-- User Command
-- ==========================================================================

function M.setup_commands()
    vim.api.nvim_create_user_command("QuackReview", function(opts)
        local args = vim.split(opts.args, "%s+")
        local subcmd = args[1] or ""

        if subcmd == "" or subcmd == "start" then
            local source = args[2]
            M.start({ source = source })

        elseif subcmd == "stop" then
            M.stop()

        elseif subcmd == "status" then
            if not state.is_active() then
                vim.notify("quack-review: No active session.", vim.log.levels.INFO)
                return
            end
            local counts = state.counts()
            local idx = state.current_index()
            local total = state.total_hunks()
            print(string.format(
                "quack-review: Hunk %d/%d — pending: %d, accepted: %d, rejected: %d, commented: %d",
                idx, total, counts.pending, counts.accepted, counts.rejected, counts.commented
            ))

        elseif subcmd == "export" then
            M.export()

        elseif subcmd == "apply" then
            M.apply_review()

        elseif subcmd == "preview" then
            local preview = apply.preview()
            print(table.concat(preview, "\n"))

        elseif subcmd == "debug" then
            local source = args[2]
            M.debug(source)

        else
            vim.notify(
                "quack-review: Unknown command '" .. subcmd .. "'\n"
                .. "Available: start [source], stop, status, export, apply, preview, debug [source]",
                vim.log.levels.ERROR
            )
        end
    end, {
        nargs = "*",
        complete = function(ArgLead, CmdLine)
            local args = vim.split(CmdLine, "%s+")
            if #args == 2 then
                local subcmds = { "start", "stop", "status", "export", "apply", "preview", "debug" }
                return vim.tbl_filter(function(cmd)
                    return cmd:find(ArgLead, 1, true) == 1
                end, subcmds)
            end
            if #args == 3 and (args[2] == "start" or args[2] == "debug") then
                local sources = { "unstaged", "staged", "head", "HEAD~1", "HEAD~2", "HEAD~3" }
                return vim.tbl_filter(function(s)
                    return s:find(ArgLead, 1, true) == 1
                end, sources)
            end
            return {}
        end,
        desc = "quack-review: Agent diff review mode",
    })
end

-- Re-exports for direct access
M.parser = parser
M.state = state
M.applier = apply

-- Auto-setup commands on load
M.setup_commands()

return M
