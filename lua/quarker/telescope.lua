local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local quarker = require("quarker")

-- Get filetype icon with color
local function get_filetype_icon(filename)
    local ok, devicons = pcall(require, "nvim-web-devicons")
    if ok then
        local icon, hl_group = devicons.get_icon(filename, vim.fn.fnamemodify(filename, ":e"), { default = true })
        return icon or "", hl_group
    end
    return "", nil
end

local M = {}

-- Custom actions for the telescope picker
local function delete_mark(prompt_bufnr)
    local selection = action_state.get_selected_entry()
    if selection then
        local index = selection.index
        if quarker.remove_mark(index) then
            -- Refresh the picker
            actions.close(prompt_bufnr)
            M.toggle_quarker()
        end
    end
end

local function navigate_to_mark(prompt_bufnr)
    local selection = action_state.get_selected_entry()
    if selection then
        actions.close(prompt_bufnr)
        quarker.navigate(selection.index)
    end
end

local function move_mark_up(prompt_bufnr)
    local selection = action_state.get_selected_entry()
    if selection then
        local index = selection.index
        if quarker.move_mark_up(index) then
            -- Refresh the picker
            actions.close(prompt_bufnr)
            M.toggle_quarker()
        end
    end
end

local function move_mark_down(prompt_bufnr)
    local selection = action_state.get_selected_entry()
    if selection then
        local index = selection.index
        if quarker.move_mark_down(index) then
            -- Refresh the picker
            actions.close(prompt_bufnr)
            M.toggle_quarker()
        end
    end
end

-- Main telescope picker for quarker
function M.toggle_quarker()
    local marks = quarker.get_marks()
    local scope = quarker.get_scope()

    if #marks == 0 then
        vim.notify("No marks found in current scope", vim.log.levels.INFO)
        return
    end

    -- Get current buffer path for default selection
    local current_buf_path = vim.api.nvim_buf_get_name(0)
    local current_buf_path_resolved = vim.fn.resolve(current_buf_path)
    local default_selection = 1 -- Default to first entry

    -- Prepare entries for telescope
    local entries = {}
    for i, mark in ipairs(marks) do
        -- Check if this mark matches current buffer (try both original and resolved paths)
        local mark_path_resolved = vim.fn.resolve(mark.path)
        if mark.path == current_buf_path or mark_path_resolved == current_buf_path_resolved then
            default_selection = i
        end

        table.insert(entries, {
            value = mark,
            display = function(entry)
                local hl = {}
                local filetype_icon, icon_hl = get_filetype_icon(entry.filename)
                local display_str = string.format("[%d] %s %s %s", entry.index, filetype_icon, entry.filename, entry.path)

                local index_part = string.format("[%d] ", entry.index)
                local icon_part = filetype_icon .. " "
                local filename_start = string.len(index_part .. icon_part)
                local filename_end = filename_start + string.len(entry.filename)
                local path_start = filename_end + 1

                -- Highlight icon with its color
                if icon_hl and filetype_icon ~= "" then
                    table.insert(hl, { { string.len(index_part), string.len(index_part) + string.len(filetype_icon) }, icon_hl })
                end

                -- Highlight path in comment color
                table.insert(hl, { { path_start, string.len(display_str) }, "Comment" })

                return display_str, hl
            end,
            ordinal = string.format("[%d] %s", i, mark.name),
            index = i,
            path = mark.path,
            filename = mark.name
        })
    end

    pickers.new({}, {
        prompt_title = string.format("Quarker Marks (%s)", vim.fn.fnamemodify(scope, ":t")),
        finder = finders.new_table {
            results = entries,
            entry_maker = function(entry)
                return entry
            end
        },
        sorter = conf.generic_sorter({}),
        previewer = conf.file_previewer({}),
        default_selection_index = default_selection,
        attach_mappings = function(prompt_bufnr, map)
            -- Default action: navigate to file
            actions.select_default:replace(navigate_to_mark)

            -- Custom mappings
            map("i", "<C-d>", delete_mark)
            map("n", "dd", delete_mark)
            map("i", "<CR>", navigate_to_mark)
            map("n", "<CR>", navigate_to_mark)
            map("i", "<C-k>", move_mark_up)
            map("n", "<C-k>", move_mark_up)
            map("i", "<C-j>", move_mark_down)
            map("n", "<C-j>", move_mark_down)

            return true
        end,
    }):find()
end

return M
