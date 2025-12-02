local float = require("quarker.ui.float")
local M = {}

-- Get the number of marks in a scope
-- @param base_scope string Base scope path
-- @param scope_name string Scope name
-- @return number Number of marks in the scope
local function get_marks_count(base_scope, scope_name)
    local marks_file = vim.fn.stdpath("data") .. "/quarker/" .. vim.fn.sha256(base_scope) .. "/" .. scope_name .. ".json"

    if vim.fn.filereadable(marks_file) == 1 then
        local file = io.open(marks_file, "r")
        if file then
            local content = file:read("*all")
            file:close()
            local success, data = pcall(vim.json.decode, content)
            if success and data and data.marks then
                return #data.marks
            end
        end
    end

    return 0
end

-- Render scopes to buffer
-- @param bufnr number Buffer number
-- @param scopes table Array of scope names
-- @param active_scope string Active scope name
-- @param base_scope string Base scope path
-- @return number Line number of active scope
local function render_scopes(bufnr, scopes, active_scope, base_scope)
    local lines = {}
    local highlights = {}
    local active_line = 1

    for i, scope_name in ipairs(scopes) do
        local count = get_marks_count(base_scope, scope_name)
        local is_active = (scope_name == active_scope)
        local marker = is_active and " [active]" or ""
        local line = string.format("%s (%d marks)%s", scope_name, count, marker)
        table.insert(lines, line)

        -- Highlight active scope
        if is_active then
            active_line = i
            table.insert(highlights, {
                line = i,
                col_start = 0,
                col_end = -1,
                hl_group = "String",
            })
        end
    end

    -- Create help bar with keybindings
    local help_bar = "<CR>:switch  n:new  r:rename  dd:delete  1-9:jump  q:quit"

    float.render_lines(bufnr, lines, highlights, { help_bar = help_bar })
    return active_line
end

-- Main function to show scopes in floating buffer
function M.show_scopes()
    local quarker = require("quarker")
    local scopes, active_scope = quarker.list_scopes()

    if #scopes == 0 then
        vim.notify("No scopes found", vim.log.levels.INFO)
        return
    end

    local base_scope = quarker.get_scope()
    local title = " Quarker Scopes "

    -- Create floating window
    local bufnr, winid = float.create_float_win({
        width_ratio = 0.5,
        height_ratio = 0.6,
        title = title,
        win_type = "scopes",
    })

    -- Render scopes and get active line
    local active_line = render_scopes(bufnr, scopes, active_scope, base_scope)

    -- Set cursor to active scope
    vim.api.nvim_win_set_cursor(winid, { active_line, 0 })

    -- Setup keymaps
    local function switch_scope()
        local line = vim.api.nvim_win_get_cursor(winid)[1]
        local scope_name = scopes[line]
        float.close_float_win(winid)
        quarker.switch_scope(scope_name)
    end

    local function close_window()
        float.close_float_win(winid)
    end

    local function create_scope()
        float.close_float_win(winid)
        vim.ui.input({ prompt = "New scope name: " }, function(name)
            if name and name ~= "" then
                if quarker.create_scope(name) then
                    -- Re-open to show new scope
                    M.show_scopes()
                end
            end
        end)
    end

    local function rename_scope()
        local line = vim.api.nvim_win_get_cursor(winid)[1]
        local old_name = scopes[line]

        if old_name == "default" then
            vim.notify("Cannot rename the default scope", vim.log.levels.ERROR)
            return
        end

        float.close_float_win(winid)
        vim.ui.input({ prompt = string.format("Rename '%s' to: ", old_name) }, function(new_name)
            if new_name and new_name ~= "" then
                if quarker.rename_scope(old_name, new_name) then
                    -- Re-open to show renamed scope
                    M.show_scopes()
                end
            end
        end)
    end

    local function delete_scope()
        local line = vim.api.nvim_win_get_cursor(winid)[1]
        local scope_name = scopes[line]

        if scope_name == "default" then
            vim.notify("Cannot delete the default scope", vim.log.levels.ERROR)
            return
        end

        local choice = vim.fn.confirm(
            string.format("Delete scope '%s'?", scope_name),
            "&Yes\n&No",
            2
        )

        if choice == 1 then
            float.close_float_win(winid)
            quarker.delete_scope(scope_name)
        end
    end

    -- Quick switch functions for number keys
    local function make_switch_handler(index)
        return function()
            if index <= #scopes then
                local scope_name = scopes[index]
                float.close_float_win(winid)
                quarker.switch_scope(scope_name)
            else
                vim.notify(string.format("Scope %d does not exist", index), vim.log.levels.WARN)
            end
        end
    end

    local keymaps = {
        { mode = "n", key = "<CR>", callback = switch_scope, desc = "Switch to scope" },
        { mode = "n", key = "q", callback = close_window, desc = "Close window" },
        { mode = "n", key = "<Esc>", callback = close_window, desc = "Close window" },
        { mode = "n", key = "n", callback = create_scope, desc = "Create new scope" },
        { mode = "n", key = "r", callback = rename_scope, desc = "Rename scope" },
        { mode = "n", key = "dd", callback = delete_scope, desc = "Delete scope" },
    }

    -- Add number keys 1-9 for quick switch
    for i = 1, 9 do
        table.insert(keymaps, {
            mode = "n",
            key = tostring(i),
            callback = make_switch_handler(i),
            desc = string.format("Switch to scope %d", i)
        })
    end

    float.set_float_keymaps(bufnr, keymaps)
end

return M
