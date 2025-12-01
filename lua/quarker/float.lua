local quarker = require("quarker")

local M = {}

-- State management
local state = {
    buf = nil,
    win = nil,
    marks = {},
    selected_index = 1,
    scope = nil
}

-- Get filetype icon with color
local function get_filetype_icon(filename)
    local ok, devicons = pcall(require, "nvim-web-devicons")
    if ok then
        local icon, hl_group = devicons.get_icon(filename, vim.fn.fnamemodify(filename, ":e"), { default = true })
        return icon or "", hl_group
    end
    return "", nil
end

-- Create or get buffer
local function create_buffer()
    if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
        return state.buf
    end

    local buf = vim.api.nvim_create_buf(false, true) -- no listed, scratch
    vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
    vim.api.nvim_buf_set_option(buf, 'filetype', 'quarker')
    vim.api.nvim_buf_set_option(buf, 'modifiable', false)

    state.buf = buf
    return buf
end

-- Calculate window dimensions and position
local function get_window_config()
    local width = math.floor(vim.o.columns * 0.6)
    local height = math.floor(vim.o.lines * 0.6)

    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)

    return {
        relative = 'editor',
        width = width,
        height = height,
        row = row,
        col = col,
        style = 'minimal',
        border = 'rounded',
        title = string.format(" Quarker Marks (%s) ", vim.fn.fnamemodify(state.scope or "", ":t")),
        title_pos = 'center'
    }
end

-- Create or open float window
local function create_window()
    if state.win and vim.api.nvim_win_is_valid(state.win) then
        -- Just update config if window exists
        vim.api.nvim_win_set_config(state.win, get_window_config())
        return state.win
    end

    local buf = create_buffer()
    local win = vim.api.nvim_open_win(buf, true, get_window_config())

    -- Window options
    vim.api.nvim_win_set_option(win, 'cursorline', true)
    vim.api.nvim_win_set_option(win, 'number', false)
    vim.api.nvim_win_set_option(win, 'relativenumber', false)
    vim.api.nvim_win_set_option(win, 'wrap', false)

    state.win = win
    return win
end

-- Close the float window
local function close_window()
    if state.win and vim.api.nvim_win_is_valid(state.win) then
        vim.api.nvim_win_close(state.win, true)
    end
    state.win = nil
end

-- Render the buffer content
local function render_buffer()
    if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
        return
    end

    local lines = {}
    local highlights = {}

    -- Add header
    table.insert(lines, string.format("Press '?' for help | %d marks", #state.marks))
    table.insert(lines, string.rep("─", vim.api.nvim_win_get_width(state.win) - 2))

    for i, mark in ipairs(state.marks) do
        local icon, hl_group = get_filetype_icon(mark.name)
        local line = string.format(" [%d] %s %s  %s", i, icon, mark.name, mark.path)
        table.insert(lines, line)

        -- Store highlight information
        if hl_group then
            local icon_col = #string.format(" [%d] ", i)
            table.insert(highlights, {
                line = #lines - 1, -- 0-indexed
                col = icon_col,
                length = #icon,
                hl_group = hl_group
            })
        end

        -- Highlight path in comment color
        local path_col = #string.format(" [%d] %s %s  ", i, icon, mark.name)
        table.insert(highlights, {
            line = #lines - 1,
            col = path_col,
            length = #mark.path,
            hl_group = "Comment"
        })
    end

    -- Add footer with help
    table.insert(lines, string.rep("─", vim.api.nvim_win_get_width(state.win) - 2))
    table.insert(lines, "? help | ↑↓/jk navigate | <CR> open | dd delete | <C-k/j> move | <C-x> clear | q quit")

    -- Set buffer content
    vim.api.nvim_buf_set_option(state.buf, 'modifiable', true)
    vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(state.buf, 'modifiable', false)

    -- Apply highlights
    local ns_id = vim.api.nvim_create_namespace('quarker_highlights')
    vim.api.nvim_buf_clear_namespace(state.buf, ns_id, 0, -1)

    for _, hl in ipairs(highlights) do
        vim.api.nvim_buf_add_highlight(
            state.buf,
            ns_id,
            hl.hl_group,
            hl.line,
            hl.col,
            hl.col + hl.length
        )
    end

    -- Set cursor to selected index (add 2 for header lines)
    if state.win and vim.api.nvim_win_is_valid(state.win) then
        vim.api.nvim_win_set_cursor(state.win, {state.selected_index + 2, 0})
    end
end

-- Update selected index based on cursor position
local function update_selected_index()
    if not state.win or not vim.api.nvim_win_is_valid(state.win) then
        return
    end

    local cursor = vim.api.nvim_win_get_cursor(state.win)
    local line = cursor[1]

    -- Account for header (2 lines)
    local index = line - 2

    -- Clamp to valid range
    if index < 1 then
        index = 1
    elseif index > #state.marks then
        index = #state.marks
    end

    state.selected_index = index

    -- Ensure cursor is on a valid mark line
    vim.api.nvim_win_set_cursor(state.win, {index + 2, 0})
end

-- Navigate to selected mark
local function navigate_to_mark()
    update_selected_index()

    if state.selected_index < 1 or state.selected_index > #state.marks then
        return
    end

    close_window()
    quarker.navigate(state.selected_index)
end

-- Delete selected mark
local function delete_mark()
    update_selected_index()

    if quarker.remove_mark(state.selected_index) then
        -- Reload marks and refresh
        state.marks = quarker.get_marks()

        if #state.marks == 0 then
            close_window()
            return
        end

        -- Adjust selected index if needed
        if state.selected_index > #state.marks then
            state.selected_index = #state.marks
        end

        render_buffer()
    end
end

-- Move mark up
local function move_mark_up()
    update_selected_index()

    if quarker.move_mark_up(state.selected_index) then
        state.marks = quarker.get_marks()
        state.selected_index = math.max(1, state.selected_index - 1)
        render_buffer()
    end
end

-- Move mark down
local function move_mark_down()
    update_selected_index()

    if quarker.move_mark_down(state.selected_index) then
        state.marks = quarker.get_marks()
        state.selected_index = math.min(#state.marks, state.selected_index + 1)
        render_buffer()
    end
end

-- Clear all marks
local function clear_all_marks()
    local choice = vim.fn.confirm("Clear all marks for current scope?", "&Yes\n&No", 2)
    if choice == 1 then
        quarker.clear_marks()
        close_window()
    end
end

-- Show help popup
local function show_help()
    local help_lines = {
        "Quarker Help",
        "",
        "Navigation:",
        "  ↑/k          - Move up",
        "  ↓/j          - Move down",
        "  <CR>         - Open selected mark",
        "",
        "Mark Management:",
        "  dd           - Delete selected mark",
        "  <C-k>        - Move mark up",
        "  <C-j>        - Move mark down",
        "  <C-x>        - Clear all marks",
        "",
        "Other:",
        "  q/<Esc>      - Close window",
        "  ?            - Toggle this help",
        "",
        "Press any key to continue..."
    }

    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, help_lines)
    vim.api.nvim_buf_set_option(buf, 'modifiable', false)

    local width = 50
    local height = #help_lines
    local win = vim.api.nvim_open_win(buf, true, {
        relative = 'editor',
        width = width,
        height = height,
        row = math.floor((vim.o.lines - height) / 2),
        col = math.floor((vim.o.columns - width) / 2),
        style = 'minimal',
        border = 'rounded'
    })

    -- Close on any key
    vim.api.nvim_buf_set_keymap(buf, 'n', '<buffer>', '<cmd>close<CR>', {
        noremap = true,
        silent = true
    })

    -- Map common keys to close
    for _, key in ipairs({'<Esc>', 'q', '<CR>', '?'}) do
        vim.api.nvim_buf_set_keymap(buf, 'n', key, '<cmd>close<CR>', {
            noremap = true,
            silent = true
        })
    end
end

-- Setup keybindings for the buffer
local function setup_keymaps()
    local opts = { noremap = true, silent = true, buffer = state.buf }

    -- Navigation
    vim.keymap.set('n', '<CR>', navigate_to_mark, opts)
    vim.keymap.set('n', 'q', close_window, opts)
    vim.keymap.set('n', '<Esc>', close_window, opts)

    -- Mark operations
    vim.keymap.set('n', 'dd', delete_mark, opts)
    vim.keymap.set('n', '<C-k>', move_mark_up, opts)
    vim.keymap.set('n', '<C-j>', move_mark_down, opts)
    vim.keymap.set('n', '<C-x>', clear_all_marks, opts)

    -- Help
    vim.keymap.set('n', '?', show_help, opts)

    -- Update selection on cursor move
    vim.api.nvim_create_autocmd('CursorMoved', {
        buffer = state.buf,
        callback = update_selected_index
    })
end

-- Main function to toggle quarker float
function M.toggle_quarker()
    -- If already open, close it
    if state.win and vim.api.nvim_win_is_valid(state.win) then
        close_window()
        return
    end

    -- Get marks
    state.marks = quarker.get_marks()
    state.scope = quarker.get_scope()

    if #state.marks == 0 then
        vim.notify("No marks found in current scope", vim.log.levels.INFO)
        return
    end

    -- Find current file in marks for default selection
    local current_buf_path = vim.api.nvim_buf_get_name(0)
    state.selected_index = 1

    if current_buf_path ~= "" then
        local current_relative_path = ""
        if current_buf_path:sub(1, #state.scope) == state.scope then
            current_relative_path = current_buf_path:sub(#state.scope + 1)
            if current_relative_path:sub(1, 1) == "/" then
                current_relative_path = current_relative_path:sub(2)
            end
        else
            current_relative_path = current_buf_path
        end

        -- Find matching mark
        for i, mark in ipairs(state.marks) do
            if mark.path == current_relative_path then
                state.selected_index = i
                break
            end
        end
    end

    -- Create window and buffer
    create_window()
    setup_keymaps()
    render_buffer()
end

return M
