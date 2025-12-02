local float = require("quarker.ui.float")
local M = {}

-- Get filetype icon with color
local function get_filetype_icon(filename)
    local ok, devicons = pcall(require, "nvim-web-devicons")
    if ok then
        local icon, hl_group = devicons.get_icon(filename, vim.fn.fnamemodify(filename, ":e"), { default = true })
        return icon or "", hl_group
    end
    return "", nil
end

-- Calculate cursor position based on current file
local function get_cursor_position(marks, scope)
    local current_buf_path = vim.api.nvim_buf_get_name(0)
    if current_buf_path == "" then
        return 1
    end

    -- Normalize scope path (remove trailing slash)
    local normalized_scope = scope:gsub("/$", "")

    -- Convert current buffer to relative path
    local current_relative_path = ""
    if current_buf_path:sub(1, #normalized_scope) == normalized_scope then
        current_relative_path = current_buf_path:sub(#normalized_scope + 1)
        -- Remove leading slash
        if current_relative_path:sub(1, 1) == "/" then
            current_relative_path = current_relative_path:sub(2)
        end
    else
        -- If not in scope, use the full path
        current_relative_path = current_buf_path
    end

    -- Find matching mark
    for i, mark in ipairs(marks) do
        if mark.path == current_relative_path then
            return i
        end
    end

    return 1
end

-- Render marks to buffer
local function render_marks(bufnr, marks)
    local lines = {}
    local highlights = {}

    for i, mark in ipairs(marks) do
        local icon, icon_hl = get_filetype_icon(mark.name)
        local line = string.format("[%d] %s %s %s", i, icon, mark.name, mark.path)
        table.insert(lines, line)

        -- Calculate positions for highlights
        local index_end = string.len(string.format("[%d] ", i))
        local icon_start = index_end
        local icon_end = icon_start + string.len(icon)
        local filename_start = icon_end + 1
        local filename_end = filename_start + string.len(mark.name)
        local path_start = filename_end + 1

        -- Highlight icon with its color
        if icon_hl and icon ~= "" then
            table.insert(highlights, {
                line = i,
                col_start = icon_start,
                col_end = icon_end,
                hl_group = icon_hl,
            })
        end

        -- Highlight path in comment color
        table.insert(highlights, {
            line = i,
            col_start = path_start,
            col_end = -1,
            hl_group = "Comment",
        })
    end

    -- Create help bar with keybindings
    local help_bar = "<CR>:select  dd:delete  <C-k/j>:move  <C-x>:clear  1-9:jump  q:quit"

    float.render_lines(bufnr, lines, highlights, { help_bar = help_bar })
end

-- Main function to show marks in floating buffer
function M.show_marks(force_cursor_line)
    local quarker = require("quarker")
    local marks = quarker.get_marks()

    if #marks == 0 then
        vim.notify("No marks found in current scope", vim.log.levels.INFO)
        return
    end

    -- Get scope info for title
    local scope_name = quarker.get_active_scope_name()
    local scope_path = quarker.get_scope()
    local title = string.format(" Quarker Marks (%s) ", scope_name)

    -- Create floating window
    local bufnr, winid = float.create_float_win({
        width_ratio = 0.6,
        height_ratio = 0.7,
        title = title,
        win_type = "marks",
    })

    -- Render marks
    render_marks(bufnr, marks)

    -- Set cursor position
    local cursor_line = force_cursor_line or get_cursor_position(marks, scope_path)
    vim.api.nvim_win_set_cursor(winid, { cursor_line, 0 })

    -- Setup keymaps
    local function navigate()
        local line = vim.api.nvim_win_get_cursor(winid)[1]
        float.close_float_win(winid)
        quarker.navigate(line)
    end

    local function close_window()
        float.close_float_win(winid)
    end

    local function delete_mark()
        local line = vim.api.nvim_win_get_cursor(winid)[1]
        if quarker.remove_mark(line) then
            -- Check if there are any marks left
            local remaining_marks = quarker.get_marks()
            if #remaining_marks == 0 then
                -- Close window if no marks left
                float.close_float_win(winid)
            else
                -- Refresh the marks buffer, keeping cursor at same position or previous
                local new_cursor = math.min(line, #remaining_marks)
                M.show_marks(new_cursor)
            end
        end
    end

    local function move_mark_up()
        local line = vim.api.nvim_win_get_cursor(winid)[1]
        if line == 1 then
            vim.notify("Already at the top", vim.log.levels.INFO)
            return
        end
        if quarker.move_mark_up(line) then
            -- Refresh and position cursor at new location
            M.show_marks(line - 1)
        end
    end

    local function move_mark_down()
        local line = vim.api.nvim_win_get_cursor(winid)[1]
        if line == #marks then
            vim.notify("Already at the bottom", vim.log.levels.INFO)
            return
        end
        if quarker.move_mark_down(line) then
            -- Refresh and position cursor at new location
            M.show_marks(line + 1)
        end
    end

    local function clear_all_marks()
        local choice = vim.fn.confirm("Clear all marks for current scope?", "&Yes\n&No", 2)
        if choice == 1 then
            quarker.clear_marks()
            float.close_float_win(winid)
        end
    end

    -- Quick jump functions for number keys
    local function make_jump_handler(index)
        return function()
            if index <= #marks then
                float.close_float_win(winid)
                quarker.navigate(index)
            else
                vim.notify(string.format("Mark %d does not exist", index), vim.log.levels.WARN)
            end
        end
    end

    local keymaps = {
        { mode = "n", key = "<CR>", callback = navigate, desc = "Navigate to mark" },
        { mode = "n", key = "q", callback = close_window, desc = "Close window" },
        { mode = "n", key = "<Esc>", callback = close_window, desc = "Close window" },
        { mode = "n", key = "dd", callback = delete_mark, desc = "Delete mark" },
        { mode = "n", key = "<C-k>", callback = move_mark_up, desc = "Move mark up" },
        { mode = "n", key = "<C-j>", callback = move_mark_down, desc = "Move mark down" },
        { mode = "n", key = "<C-x>", callback = clear_all_marks, desc = "Clear all marks" },
    }

    -- Add number keys 1-9 for quick jump
    for i = 1, 9 do
        table.insert(keymaps, {
            mode = "n",
            key = tostring(i),
            callback = make_jump_handler(i),
            desc = string.format("Jump to mark %d", i)
        })
    end

    float.set_float_keymaps(bufnr, keymaps)
end

return M
