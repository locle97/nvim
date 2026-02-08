local state = require("quack-review.state")

local M = {}

--- Build a valid unified diff patch for a set of hunks, grouped by file.
--- The patch includes proper file headers so `git apply` can process it.
--- @param hunks table List of hunk objects (must have .file, .header, .lines)
--- @param parsed table The full parsed diff data (for file header info)
--- @return string The patch text
local function build_patch(hunks, parsed)
    if #hunks == 0 then
        return ""
    end

    -- Group hunks by file, preserving order
    local file_hunks = {}
    local file_order = {}
    for _, hunk in ipairs(hunks) do
        if not file_hunks[hunk.file] then
            file_hunks[hunk.file] = {}
            table.insert(file_order, hunk.file)
        end
        table.insert(file_hunks[hunk.file], hunk)
    end

    local patch_lines = {}

    for _, filepath in ipairs(file_order) do
        -- File header
        table.insert(patch_lines, "diff --git a/" .. filepath .. " b/" .. filepath)
        table.insert(patch_lines, "--- a/" .. filepath)
        table.insert(patch_lines, "+++ b/" .. filepath)

        -- Hunks for this file
        for _, hunk in ipairs(file_hunks[filepath]) do
            table.insert(patch_lines, hunk.header)
            for _, line in ipairs(hunk.lines) do
                table.insert(patch_lines, line)
            end
        end
    end

    -- Ensure trailing newline
    table.insert(patch_lines, "")
    return table.concat(patch_lines, "\n")
end

--- Apply a patch using git apply.
--- @param patch string The patch text
--- @param reverse boolean Whether to apply in reverse
--- @return boolean success
--- @return string|nil error message
local function git_apply(patch, reverse)
    if patch == "" then
        return true, nil
    end

    -- Write patch to temp file
    local tmpfile = vim.fn.tempname() .. ".patch"
    local f = io.open(tmpfile, "w")
    if not f then
        return false, "Failed to create temp patch file"
    end
    f:write(patch)
    f:close()

    local cmd = "git apply --unidiff-zero"
    if reverse then
        cmd = cmd .. " --reverse"
    end
    cmd = cmd .. " " .. vim.fn.shellescape(tmpfile)

    local result = vim.fn.system(cmd)
    local success = vim.v.shell_error == 0

    -- Cleanup
    os.remove(tmpfile)

    if not success then
        return false, vim.trim(result)
    end
    return true, nil
end

--- Revert rejected hunks from the working tree.
--- This applies the rejected hunks in reverse, effectively undoing them.
--- @return boolean success
--- @return string|nil error message
function M.revert_rejected()
    if not state.is_active() then
        return false, "No active review session"
    end

    local rejected = state.hunks_by_status(state.STATUS.REJECTED)
    if #rejected == 0 then
        vim.notify("quack-review: No rejected hunks to revert.", vim.log.levels.INFO)
        return true, nil
    end

    local parsed = state.get_parsed()
    local patch = build_patch(rejected, parsed)

    local ok, err = git_apply(patch, true)
    if ok then
        vim.notify(
            string.format("quack-review: Reverted %d rejected hunk(s).", #rejected),
            vim.log.levels.INFO
        )
    else
        vim.notify(
            "quack-review: Failed to revert rejected hunks: " .. (err or "unknown error"),
            vim.log.levels.ERROR
        )
    end
    return ok, err
end

--- Revert commented hunks (hunks with feedback, treated as "needs revision").
--- @return boolean success
--- @return string|nil error message
function M.revert_commented()
    if not state.is_active() then
        return false, "No active review session"
    end

    local commented = state.hunks_by_status(state.STATUS.COMMENTED)
    if #commented == 0 then
        vim.notify("quack-review: No commented hunks to revert.", vim.log.levels.INFO)
        return true, nil
    end

    local parsed = state.get_parsed()
    local patch = build_patch(commented, parsed)

    local ok, err = git_apply(patch, true)
    if ok then
        vim.notify(
            string.format("quack-review: Reverted %d commented hunk(s).", #commented),
            vim.log.levels.INFO
        )
    else
        vim.notify(
            "quack-review: Failed to revert commented hunks: " .. (err or "unknown error"),
            vim.log.levels.ERROR
        )
    end
    return ok, err
end

--- Apply the review decisions:
---   - Accepted hunks: kept as-is (no action needed)
---   - Rejected hunks: reverted
---   - Commented hunks: reverted (agent should regenerate)
---   - Pending hunks: left as-is (user hasn't decided)
--- @param opts table|nil Options: { revert_commented = true|false }
--- @return boolean success
function M.apply(opts)
    opts = opts or {}
    local revert_commented = opts.revert_commented ~= false -- default true

    if not state.is_active() then
        vim.notify("quack-review: No active review session.", vim.log.levels.WARN)
        return false
    end

    local counts = state.counts()

    if counts.pending > 0 then
        vim.notify(
            string.format("quack-review: %d hunk(s) still pending. Resolve all hunks first.", counts.pending),
            vim.log.levels.WARN
        )
        return false
    end

    local results = {}

    -- Revert rejected hunks
    if counts.rejected > 0 then
        local ok, err = M.revert_rejected()
        table.insert(results, { action = "revert rejected", ok = ok, err = err, count = counts.rejected })
    end

    -- Revert commented hunks
    if revert_commented and counts.commented > 0 then
        local ok, err = M.revert_commented()
        table.insert(results, { action = "revert commented", ok = ok, err = err, count = counts.commented })
    end

    -- Summary
    local all_ok = true
    for _, r in ipairs(results) do
        if not r.ok then all_ok = false end
    end

    if all_ok then
        vim.notify(
            string.format(
                "quack-review: Applied — kept %d accepted, reverted %d rejected%s.",
                counts.accepted,
                counts.rejected,
                revert_commented and counts.commented > 0
                    and string.format(", reverted %d commented", counts.commented)
                    or ""
            ),
            vim.log.levels.INFO
        )
    else
        vim.notify("quack-review: Some operations failed. Check messages above.", vim.log.levels.ERROR)
    end

    return all_ok
end

--- Preview what will happen when applying (dry run).
--- @return table Summary of actions
function M.preview()
    if not state.is_active() then
        return {}
    end

    local counts = state.counts()
    local lines = {
        "quack-review: Apply Preview",
        "",
        string.format("  ✔ Keep (accepted):     %d hunks — no changes to working tree", counts.accepted),
        string.format("  ✘ Revert (rejected):   %d hunks — will undo these changes", counts.rejected),
        string.format("  💬 Revert (commented):  %d hunks — will undo for regeneration", counts.commented),
        string.format("  ? Pending:             %d hunks — must be resolved first", counts.pending),
    }

    if counts.pending > 0 then
        table.insert(lines, "")
        table.insert(lines, "  ⚠ Cannot apply: resolve all pending hunks first.")
    end

    return lines
end

--- Expose build_patch for testing.
M._build_patch = build_patch

return M
