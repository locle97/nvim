local float = require("quarker.ui.float")
local context = require("quarker.context")
local M = {}

-- Show context in editable float buffer
function M.show_context()
    local quarker = require("quarker")
    local scope_name = quarker.get_active_scope_name()
    local filepath = context.get_context_path()

    local title = string.format(" Context: %s ", scope_name)

    -- Create floating window
    local bufnr, winid = float.create_float_win({
        width_ratio = 0.7,
        height_ratio = 0.8,
        title = title,
        win_type = "context",
    })

    -- Load content
    local content = context.get_content()
    local lines = {}
    if content ~= "" then
        for line in content:gmatch("([^\n]*)\n?") do
            table.insert(lines, line)
        end
        -- Remove trailing empty line from split
        if #lines > 0 and lines[#lines] == "" then
            table.remove(lines)
        end
    end

    -- Set buffer content
    vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(bufnr, "modified", false)

    -- Set filetype for syntax highlighting
    vim.api.nvim_buf_set_option(bufnr, "filetype", "markdown")

    -- Make buffer writable
    vim.api.nvim_buf_set_option(bufnr, "buftype", "acwrite")
    vim.api.nvim_buf_set_name(bufnr, "quarker://context/" .. scope_name)

    -- Save on write
    vim.api.nvim_create_autocmd("BufWriteCmd", {
        buffer = bufnr,
        callback = function()
            local buf_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
            local new_content = table.concat(buf_lines, "\n")
            context.set_content(new_content)
            vim.api.nvim_buf_set_option(bufnr, "modified", false)
            vim.notify("Context saved", vim.log.levels.INFO)
        end,
    })

    -- Close with q or Esc
    local function close_window()
        -- Check if modified
        if vim.api.nvim_buf_get_option(bufnr, "modified") then
            local choice = vim.fn.confirm("Save changes?", "&Yes\n&No\n&Cancel", 1)
            if choice == 1 then
                vim.cmd("write")
            elseif choice == 3 then
                return
            end
        end
        float.close_float_win(winid)
    end

    float.set_float_keymaps(bufnr, {
        { mode = "n", key = "q", callback = close_window, desc = "Close" },
        { mode = "n", key = "<Esc>", callback = close_window, desc = "Close" },
    })
end

return M
