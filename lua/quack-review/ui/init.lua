local layout = require("quack-review.ui.layout")
local summary = require("quack-review.ui.summary")
local diff = require("quack-review.ui.diff")
local actions = require("quack-review.ui.actions")
local comment = require("quack-review.ui.comment")
local state = require("quack-review.state")

local M = {}

--- Refresh all UI panels based on current state.
function M.refresh()
    if not layout.is_open() then return end
    if not state.is_active() then return end

    -- Schedule to avoid issues when called from within autocmds
    vim.schedule(function()
        if not layout.is_open() or not state.is_active() then return end
        summary.render()
        diff.render()
        actions.render()
    end)
end

--- Set up keybindings on all review buffers.
local function setup_keymaps()
    local bufs = layout.get_bufs()
    local all_bufs = { bufs.summary, bufs.diff, bufs.actions }

    for _, bufnr in ipairs(all_bufs) do
        if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
            goto continue
        end

        local map = function(key, fn, desc)
            vim.keymap.set("n", key, fn, { buffer = bufnr, nowait = true, silent = true, desc = desc })
        end

        -- Navigation
        map("n", function()
            if state.next_hunk() then
                layout.focus_diff()
            end
        end, "Next hunk")

        map("p", function()
            if state.prev_hunk() then
                layout.focus_diff()
            end
        end, "Previous hunk")

        map("]f", function()
            if state.next_file() then
                layout.focus_diff()
            end
        end, "Next file")

        map("[f", function()
            if state.prev_file() then
                layout.focus_diff()
            end
        end, "Previous file")

        map("]u", function()
            if state.next_unresolved() then
                layout.focus_diff()
            end
        end, "Next unresolved hunk")

        map("[u", function()
            if state.prev_unresolved() then
                layout.focus_diff()
            end
        end, "Previous unresolved hunk")

        -- Actions
        map("a", function()
            state.accept()
            if not state.next_unresolved() then end
            layout.focus_diff()
        end, "Accept hunk")

        map("r", function()
            state.reject()
            if not state.next_unresolved() then end
            layout.focus_diff()
        end, "Reject hunk")

        map("c", function()
            comment.open()
        end, "Comment on hunk")

        map("x", function()
            state.reset()
        end, "Reset hunk to pending")

        -- Apply / Revert
        map("A", function()
            local apply = require("quack-review.apply")
            -- Show preview first
            local preview = apply.preview()
            local preview_text = table.concat(preview, "\n")
            vim.ui.select({ "Apply", "Cancel" }, {
                prompt = preview_text .. "\n\nProceed?",
            }, function(choice)
                if choice == "Apply" then
                    apply.apply()
                end
            end)
        end, "Apply review (revert rejected)")

        map("R", function()
            local apply = require("quack-review.apply")
            vim.ui.select({ "Revert rejected only", "Revert rejected + commented", "Cancel" }, {
                prompt = "What to revert?",
            }, function(choice)
                if choice == "Revert rejected only" then
                    apply.revert_rejected()
                elseif choice == "Revert rejected + commented" then
                    apply.revert_rejected()
                    apply.revert_commented()
                end
            end)
        end, "Revert rejected hunks")

        -- Export
        map("S", function()
            require("quack-review.export").export_all()
        end, "Export feedback")

        -- Quit
        map("q", function()
            M.close()
            require("quack-review").stop()
        end, "Quit review")

        ::continue::
    end
end

--- Open the review UI.
function M.open()
    layout.open()
    setup_keymaps()

    -- Hook state changes to refresh UI
    state.on_change(M.refresh)

    -- Initial render
    M.refresh()
end

--- Close the review UI.
function M.close()
    state.on_change(nil)
    layout.close()
end

--- Check if UI is open.
function M.is_open()
    return layout.is_open()
end

return M
