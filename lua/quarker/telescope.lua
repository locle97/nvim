local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local quarker = require("quarker")

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

-- Main telescope picker for quarker
function M.toggle_quarker()
    local marks = quarker.get_marks()
    local scope = quarker.get_scope()

    if #marks == 0 then
        vim.notify("No marks found in current scope", vim.log.levels.INFO)
        return
    end

    -- Prepare entries for telescope
    local entries = {}
    for i, mark in ipairs(marks) do
        table.insert(entries, {
            value = mark,
            display = function(entry)
                local hl = {}
                local display_str = string.format("[%d] %s %s", entry.index, entry.filename, entry.path)
                local filename_start = string.len(string.format("[%d] ", entry.index))
                local filename_end = filename_start + string.len(entry.filename)

                -- Highlight path in comment color
                table.insert(hl, { { filename_end, string.len(display_str) }, "Comment" })

                return display_str, hl
            end,
            ordinal = mark.path,
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
        attach_mappings = function(prompt_bufnr, map)
            -- Default action: navigate to file
            actions.select_default:replace(navigate_to_mark)

            -- Custom mappings
            map("i", "<C-d>", delete_mark)
            map("n", "dd", delete_mark)
            map("i", "<CR>", navigate_to_mark)
            map("n", "<CR>", navigate_to_mark)

            return true
        end,
    }):find()
end

return M
