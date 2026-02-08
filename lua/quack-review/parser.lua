local M = {}

--- Parse a unified diff hunk header line.
--- Example: "@@ -21,7 +21,15 @@ function foo()"
--- Returns old_start, old_count, new_start, new_count, context_text
local function parse_hunk_header(line)
    local old_start, old_count, new_start, new_count, ctx =
        line:match("^@@ %-(%d+),?(%d*) %+(%d+),?(%d*) @@(.*)")
    if not old_start then
        return nil
    end
    return {
        old_start = tonumber(old_start),
        old_count = tonumber(old_count) or 1,
        new_start = tonumber(new_start),
        new_count = tonumber(new_count) or 1,
        context_text = ctx and vim.trim(ctx) or "",
    }
end

--- Parse a file header from unified diff.
--- Example: "diff --git a/src/foo.lua b/src/foo.lua"
--- Returns the file path (from b/ side, which is the "new" file).
local function parse_file_header(line)
    local path = line:match("^diff %-%-git a/.+ b/(.+)$")
    return path
end

--- Detect if a file is binary from diff output.
local function is_binary_notice(line)
    return line:match("^Binary files") ~= nil
end

--- Parse raw unified diff text into structured data.
---
--- Returns:
--- {
---   files = {
---     {
---       path = "relative/path.lua",
---       hunks = {
---         {
---           index = 1,
---           header = "@@ -21,7 +21,15 @@ context",
---           old_start = 21, old_count = 7,
---           new_start = 21, new_count = 15,
---           context_text = "context",
---           lines = { " ctx", "-removed", "+added", ... },
---           added = 2,
---           removed = 1,
---         },
---         ...
---       },
---       total_hunks = 3,
---       added = 10,
---       removed = 5,
---       is_binary = false,
---     },
---     ...
---   },
---   total_files = 5,
---   total_hunks = 12,
---   total_added = 134,
---   total_removed = 22,
--- }
function M.parse(diff_text)
    if not diff_text or diff_text == "" then
        return {
            files = {},
            total_files = 0,
            total_hunks = 0,
            total_added = 0,
            total_removed = 0,
        }
    end

    local lines = vim.split(diff_text, "\n")
    local files = {}
    local current_file = nil
    local current_hunk = nil

    for _, line in ipairs(lines) do
        -- New file header
        local file_path = parse_file_header(line)
        if file_path then
            -- Finalize previous hunk
            if current_hunk and current_file then
                table.insert(current_file.hunks, current_hunk)
            end
            -- Finalize previous file
            if current_file then
                current_file.total_hunks = #current_file.hunks
                table.insert(files, current_file)
            end
            current_file = {
                path = file_path,
                hunks = {},
                total_hunks = 0,
                added = 0,
                removed = 0,
                is_binary = false,
            }
            current_hunk = nil
            goto continue
        end

        -- Binary file notice
        if current_file and is_binary_notice(line) then
            current_file.is_binary = true
            goto continue
        end

        -- Hunk header
        local hunk_info = parse_hunk_header(line)
        if hunk_info and current_file then
            -- Finalize previous hunk
            if current_hunk then
                table.insert(current_file.hunks, current_hunk)
            end
            current_hunk = {
                index = #current_file.hunks + 1,
                header = line,
                old_start = hunk_info.old_start,
                old_count = hunk_info.old_count,
                new_start = hunk_info.new_start,
                new_count = hunk_info.new_count,
                context_text = hunk_info.context_text,
                lines = {},
                added = 0,
                removed = 0,
            }
            goto continue
        end

        -- Diff content lines (context, added, removed)
        if current_hunk then
            if line:sub(1, 1) == "+" then
                table.insert(current_hunk.lines, line)
                current_hunk.added = current_hunk.added + 1
                current_file.added = current_file.added + 1
            elseif line:sub(1, 1) == "-" then
                table.insert(current_hunk.lines, line)
                current_hunk.removed = current_hunk.removed + 1
                current_file.removed = current_file.removed + 1
            elseif line:sub(1, 1) == " " then
                table.insert(current_hunk.lines, line)
            elseif line == "\\ No newline at end of file" then
                table.insert(current_hunk.lines, line)
            end
        end

        ::continue::
    end

    -- Finalize last hunk and file
    if current_hunk and current_file then
        table.insert(current_file.hunks, current_hunk)
    end
    if current_file then
        current_file.total_hunks = #current_file.hunks
        table.insert(files, current_file)
    end

    -- Compute totals
    local total_hunks = 0
    local total_added = 0
    local total_removed = 0
    for _, file in ipairs(files) do
        total_hunks = total_hunks + file.total_hunks
        total_added = total_added + file.added
        total_removed = total_removed + file.removed
    end

    -- Assign global hunk indices
    local global_idx = 0
    for _, file in ipairs(files) do
        for _, hunk in ipairs(file.hunks) do
            global_idx = global_idx + 1
            hunk.global_index = global_idx
            hunk.file = file.path
        end
    end

    return {
        files = files,
        total_files = #files,
        total_hunks = total_hunks,
        total_added = total_added,
        total_removed = total_removed,
    }
end

--- Get diff text from git.
--- @param source string|nil Diff source: nil/"unstaged", "staged", "head", "HEAD~N", or a commit ref
--- @return string Raw diff text
function M.get_diff(source)
    local cmd
    if not source or source == "" or source == "unstaged" then
        cmd = "git diff --unified=3"
    elseif source == "staged" or source == "cached" then
        cmd = "git diff --cached --unified=3"
    elseif source == "head" then
        cmd = "git diff HEAD --unified=3"
    else
        -- Treat as a commit ref (e.g. "HEAD~1", "abc123", "main..feature")
        cmd = "git diff " .. source .. " --unified=3"
    end

    local result = vim.fn.system(cmd)
    if vim.v.shell_error ~= 0 then
        vim.notify("quack-review: git diff failed: " .. (result or ""), vim.log.levels.ERROR)
        return ""
    end
    return result
end

--- Build a flat list of all hunks across all files, each with its file path attached.
--- Useful for linear hunk-by-hunk navigation.
--- @param parsed table The result of M.parse()
--- @return table List of hunks with .file field
function M.flatten_hunks(parsed)
    local flat = {}
    for _, file in ipairs(parsed.files) do
        for _, hunk in ipairs(file.hunks) do
            table.insert(flat, hunk)
        end
    end
    return flat
end

return M
