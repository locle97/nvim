M = {}

M.remove_other_buffers = function()
    local current_buf = vim.api.nvim_get_current_buf()
    local bufs = vim.api.nvim_list_bufs()
    for _, buf in ipairs(bufs) do
        if buf ~= current_buf and vim.api.nvim_buf_is_loaded(buf) then
            vim.api.nvim_buf_delete(buf, { force = true })
        end
    end
end

-- Get the scope (git root or CWD)
local function get_scope()
    local git_root = vim.fn.systemlist("git rev-parse --show-toplevel 2>/dev/null")[1]
    if vim.v.shell_error == 0 and git_root and git_root ~= "" then
        return git_root
    else
        return vim.fn.getcwd()
    end
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

-- Copy relative path to clipboard
M.copy_relative_path = function()
    local filepath = vim.fn.expand("%:p")
    if filepath == "" then
        vim.notify("No file to copy path", vim.log.levels.WARN)
        return
    end

    local scope = get_scope()
    local relative_path = get_relative_path(filepath, scope)

    vim.fn.setreg("+", relative_path)
    vim.notify("Copied: " .. relative_path, vim.log.levels.INFO)
end

return M
