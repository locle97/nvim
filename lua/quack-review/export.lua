local state = require("quack-review.state")

local M = {}

--- Get the data directory for quack-review outputs.
local function get_data_dir()
    local dir = vim.fn.stdpath("data") .. "/quack-review"
    vim.fn.mkdir(dir, "p")
    return dir
end

--- Export structured JSON feedback for agent consumption.
--- @return string|nil filepath The path to the written file, or nil on failure
function M.export_json()
    if not state.is_active() then
        vim.notify("quack-review: No active review session.", vim.log.levels.WARN)
        return nil
    end

    local feedback = state.build_feedback()
    local ok, json = pcall(vim.json.encode, feedback)
    if not ok then
        vim.notify("quack-review: Failed to encode feedback.", vim.log.levels.ERROR)
        return nil
    end

    local filepath = get_data_dir() .. "/feedback.json"
    local file = io.open(filepath, "w")
    if file then
        file:write(json)
        file:close()
    else
        vim.notify("quack-review: Failed to write " .. filepath, vim.log.levels.ERROR)
        return nil
    end

    -- Also copy to clipboard
    vim.fn.setreg("+", json)

    return filepath
end

--- Export a human-readable markdown summary of the review.
--- @return string|nil filepath
function M.export_markdown()
    if not state.is_active() then
        return nil
    end

    local parsed = state.get_parsed()
    local counts = state.counts()
    local hunks = state.get_hunks()
    local source = state.get_diff_source() or "unstaged"

    local lines = {
        "# Quack Review Summary",
        "",
        string.format("**Source:** `%s`", source),
        string.format("**Files:** %d | **Hunks:** %d | **+%d** **-%d**",
            parsed.total_files, parsed.total_hunks, parsed.total_added, parsed.total_removed),
        "",
        string.format("| Status | Count |"),
        string.format("|--------|-------|"),
        string.format("| Accepted | %d |", counts.accepted),
        string.format("| Rejected | %d |", counts.rejected),
        string.format("| Commented | %d |", counts.commented),
        string.format("| Pending | %d |", counts.pending),
        "",
    }

    -- Rejected hunks
    local rejected = state.hunks_by_status(state.STATUS.REJECTED)
    if #rejected > 0 then
        table.insert(lines, "## Rejected Hunks")
        table.insert(lines, "")
        for _, hunk in ipairs(rejected) do
            table.insert(lines, string.format("- `%s` hunk %d (lines %d-%d)",
                hunk.file, hunk.index, hunk.new_start, hunk.new_start + hunk.new_count))
        end
        table.insert(lines, "")
    end

    -- Commented hunks with feedback
    local commented = state.hunks_by_status(state.STATUS.COMMENTED)
    if #commented > 0 then
        table.insert(lines, "## Feedback")
        table.insert(lines, "")
        for _, hunk in ipairs(commented) do
            local fb = state.get_feedback(hunk.global_index) or ""
            table.insert(lines, string.format("### `%s` hunk %d", hunk.file, hunk.index))
            table.insert(lines, "")
            table.insert(lines, "```diff")
            for _, dline in ipairs(hunk.lines) do
                table.insert(lines, dline)
            end
            table.insert(lines, "```")
            table.insert(lines, "")
            table.insert(lines, "**Feedback:** " .. fb)
            table.insert(lines, "")
        end
    end

    local filepath = get_data_dir() .. "/review-summary.md"
    local file = io.open(filepath, "w")
    if file then
        file:write(table.concat(lines, "\n"))
        file:close()
    else
        vim.notify("quack-review: Failed to write " .. filepath, vim.log.levels.ERROR)
        return nil
    end

    return filepath
end

--- Full export: JSON + markdown + clipboard.
--- @return table { json_path, md_path }
function M.export_all()
    local json_path = M.export_json()
    local md_path = M.export_markdown()

    local msgs = {}
    if json_path then table.insert(msgs, "JSON: " .. json_path) end
    if md_path then table.insert(msgs, "Markdown: " .. md_path) end

    if #msgs > 0 then
        vim.notify(
            "quack-review: Exported feedback\n  " .. table.concat(msgs, "\n  ")
                .. "\n  (JSON also copied to clipboard)",
            vim.log.levels.INFO
        )
    end

    return { json = json_path, md = md_path }
end

return M
