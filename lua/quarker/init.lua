local M = {}

-- Storage for marked files per scope
local marks = {}

-- Get data directory for storing marks
local function get_data_dir()
    local data_dir = vim.fn.stdpath("data") .. "/quarker"
    vim.fn.mkdir(data_dir, "p")
    return data_dir
end

-- Get marks file path for a scope
local function get_marks_file(scope)
    local data_dir = get_data_dir()
    local scope_hash = vim.fn.sha256(scope)
    return data_dir .. "/" .. scope_hash .. ".json"
end

-- Save marks for a scope to disk
local function save_marks(scope)
    local scope_marks = marks[scope]
    if not scope_marks then
        return
    end
    
    local marks_file = get_marks_file(scope)
    local data = {
        scope = scope,
        marks = scope_marks,
        timestamp = os.time()
    }
    
    local success, encoded = pcall(vim.json.encode, data)
    if not success then
        vim.notify("Failed to encode marks data", vim.log.levels.ERROR)
        return
    end
    
    local file = io.open(marks_file, "w")
    if file then
        file:write(encoded)
        file:close()
    else
        vim.notify("Failed to save marks to " .. marks_file, vim.log.levels.ERROR)
    end
end

-- Load marks for a scope from disk
local function load_marks(scope)
    local marks_file = get_marks_file(scope)
    
    if vim.fn.filereadable(marks_file) == 0 then
        return {}
    end
    
    local file = io.open(marks_file, "r")
    if not file then
        return {}
    end
    
    local content = file:read("*all")
    file:close()
    
    if not content or content == "" then
        return {}
    end
    
    local success, data = pcall(vim.json.decode, content)
    if not success or not data or not data.marks then
        vim.notify("Failed to decode marks file: " .. marks_file, vim.log.levels.WARN)
        return {}
    end
    
    return data.marks
end

-- Get the scope (git root or CWD)
local function get_scope()
    local git_root = vim.fn.systemlist("git rev-parse --show-toplevel")[1]
    if vim.v.shell_error == 0 and git_root and git_root ~= "" then
        return git_root
    end
    return vim.fn.getcwd()
end

-- Get the current scope's marks
local function get_marks()
    local scope = get_scope()
    if not marks[scope] then
        marks[scope] = load_marks(scope)
    end
    return marks[scope]
end

-- Get relative path from scope
local function get_relative_path(filepath, scope)
    if filepath:sub(1, #scope) == scope then
        local relative = filepath:sub(#scope + 1)
        if relative:sub(1, 1) == "/" then
            relative = relative:sub(2)
        end
        return relative
    end
    return filepath
end

-- Mark current file
function M.mark()
    local filepath = vim.fn.expand("%:p")
    if filepath == "" then
        vim.notify("No file to mark", vim.log.levels.WARN)
        return
    end

    local scope = get_scope()
    local relative_path = get_relative_path(filepath, scope)
    local scope_marks = get_marks()

    -- Check if already marked
    for i, mark in ipairs(scope_marks) do
        if mark.path == relative_path then
            vim.notify(string.format("File already marked at position %d", i), vim.log.levels.INFO)
            return
        end
    end

    -- Add new mark
    table.insert(scope_marks, {
        path = relative_path,
        full_path = filepath,
        name = vim.fn.fnamemodify(filepath, ":t")
    })

    vim.notify(string.format("Marked file at position %d: %s", #scope_marks, relative_path), vim.log.levels.INFO)
    save_marks(scope)
end

-- Unmark current file
function M.unmark()
    local filepath = vim.fn.expand("%:p")
    if filepath == "" then
        vim.notify("No file to unmark", vim.log.levels.WARN)
        return
    end

    local scope = get_scope()
    local relative_path = get_relative_path(filepath, scope)
    local scope_marks = get_marks()

    for i, mark in ipairs(scope_marks) do
        if mark.path == relative_path then
            table.remove(scope_marks, i)
            vim.notify(string.format("Unmarked file: %s", relative_path), vim.log.levels.INFO)
            save_marks(scope)
            return
        end
    end

    vim.notify("File is not marked", vim.log.levels.WARN)
end

-- Navigate to marked file by index
function M.navigate(index)
    local scope_marks = get_marks()

    if index < 1 or index > #scope_marks then
        vim.notify(string.format("Invalid index %d. Available marks: 1-%d", index, #scope_marks), vim.log.levels.WARN)
        return
    end

    local mark = scope_marks[index]
    local scope = get_scope()
    local full_path = scope .. "/" .. mark.path

    -- Check if file exists
    if vim.fn.filereadable(full_path) == 1 then
        vim.cmd("edit " .. vim.fn.fnameescape(full_path))
    else
        vim.notify(string.format("File not found: %s", full_path), vim.log.levels.ERROR)
    end
end

-- Get all marks for current scope
function M.get_marks()
    return get_marks()
end

-- Get current scope
function M.get_scope()
    return get_scope()
end

-- Remove mark by index
function M.remove_mark(index)
    local scope_marks = get_marks()

    if index < 1 or index > #scope_marks then
        vim.notify(string.format("Invalid index %d", index), vim.log.levels.WARN)
        return false
    end

    local removed = table.remove(scope_marks, index)
    vim.notify(string.format("Removed mark: %s", removed.path), vim.log.levels.INFO)
    save_marks(get_scope())
    return true
end

-- Toggle mark for current file
function M.toggle()
    local filepath = vim.fn.expand("%:p")
    if filepath == "" then
        vim.notify("No file to toggle mark", vim.log.levels.WARN)
        return
    end
    
    local scope = get_scope()
    local relative_path = get_relative_path(filepath, scope)
    local scope_marks = get_marks()
    
    -- Check if already marked
    for i, mark in ipairs(scope_marks) do
        if mark.path == relative_path then
            -- Unmark if already marked
            table.remove(scope_marks, i)
            vim.notify(string.format("Unmarked file: %s", relative_path), vim.log.levels.INFO)
            save_marks(scope)
            return
        end
    end
    
    -- Mark if not already marked
    table.insert(scope_marks, {
        path = relative_path,
        full_path = filepath,
        name = vim.fn.fnamemodify(filepath, ":t")
    })
    
    vim.notify(string.format("Marked file at position %d: %s", #scope_marks, relative_path), vim.log.levels.INFO)
    save_marks(scope)
end

-- Clear all marks for current scope
function M.clear_marks()
    local scope = get_scope()
    marks[scope] = {}
    save_marks(scope)
    vim.notify("Cleared all marks for current scope", vim.log.levels.INFO)
end

return M
