local M = {}

-- Configuration with defaults
local config = {
    mark_icon = "⭐",
    mark_hl_group = "String",
    score_offset = 10000,
    enabled = true,
}

-- Setup function for user configuration
function M.setup(opts)
    config = vim.tbl_deep_extend("force", config, opts or {})
end

-- Build mark lookup table for O(1) access
-- Returns lookup table and mark count
local function build_mark_lookup()
    local quarker = require('quarker')
    local marks = quarker.get_marks()
    local lookup = {}
    local mark_count = #marks

    for i, mark in ipairs(marks) do
        -- Store both relative and absolute paths for lookup
        -- to handle different path formats from Telescope
        lookup[mark.path] = i          -- relative path
        lookup[mark.full_path] = i     -- absolute path
    end

    return lookup, mark_count
end

-- Create custom sorter that prioritizes marked files
function M.create_quarker_sorter(opts)
    opts = opts or {}
    local conf = require('telescope.config').values
    local base_sorter = conf.file_sorter(opts)

    -- Cache marks once when sorter is created
    local mark_lookup, mark_count = build_mark_lookup()

    -- Wrap the scoring function
    local original_scoring = base_sorter.scoring_function

    base_sorter.scoring_function = function(self, prompt, line, entry)
        -- Check if file is marked
        local mark_index = mark_lookup[line]

        if mark_index then
            -- Negative score ensures marked files sort first
            -- Lower index = better score (appears earlier)
            -- Example: mark 1 gets -10009, mark 2 gets -10008, etc.
            return -(config.score_offset + (mark_count - mark_index))
        end

        -- Use original scoring for unmarked files
        return original_scoring(self, prompt, line, entry)
    end

    return base_sorter
end

-- Create custom entry maker that adds visual indicators to marked files
function M.create_quarker_entry_maker(opts)
    opts = opts or {}
    local make_entry = require('telescope.make_entry')
    local base_entry_maker = make_entry.gen_from_file(opts)

    -- Cache marks once when entry maker is created
    local mark_lookup = build_mark_lookup()

    return function(line)
        local entry = base_entry_maker(line)
        if not entry then return nil end

        -- Check if marked (check both the line and the entry path)
        entry.is_marked = mark_lookup[line] ~= nil or mark_lookup[entry.path] ~= nil

        -- Wrap display function to add icon
        local original_display = entry.display
        entry.display = function(e)
            local display_str, highlights = original_display(e)

            if e.is_marked then
                -- Prepend icon
                display_str = config.mark_icon .. " " .. display_str

                -- Adjust highlight positions for icon offset
                if highlights then
                    local icon_len = #config.mark_icon + 1
                    for _, hl in ipairs(highlights) do
                        if type(hl[1]) == "table" and #hl[1] >= 2 then
                            hl[1][1] = hl[1][1] + icon_len  -- start position
                            hl[1][2] = hl[1][2] + icon_len  -- end position
                        end
                    end
                end
            end

            return display_str, highlights
        end

        return entry
    end
end

-- Enhanced find_files that integrates Quarker marks
function M.find_files(opts)
    opts = opts or {}

    -- Only inject custom components if integration is enabled
    if config.enabled then
        opts.sorter = M.create_quarker_sorter(opts)
        opts.entry_maker = M.create_quarker_entry_maker(opts)
    end

    -- Call original find_files
    require('telescope.builtin').find_files(opts)
end

return M
