local M = {}

local NS = vim.api.nvim_create_namespace("quack_review")

-- Layout state
local layout = {
    tab = nil,           -- tab page number
    prev_tab = nil,      -- tab to return to on close
    bufs = {             -- buffer numbers
        summary = nil,
        diff = nil,
        actions = nil,
    },
    wins = {             -- window IDs
        summary = nil,
        diff = nil,
        actions = nil,
    },
}

-- Layout dimensions
local SUMMARY_HEIGHT = 10
local ACTIONS_WIDTH = 30

--- Create a scratch buffer with standard options.
local function create_buf(name)
    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].swapfile = false
    vim.bo[buf].buflisted = false
    vim.api.nvim_buf_set_name(buf, "quack-review://" .. name)
    return buf
end

--- Set standard window options for review panels.
local function set_win_opts(win)
    vim.wo[win].number = false
    vim.wo[win].relativenumber = false
    vim.wo[win].signcolumn = "no"
    vim.wo[win].foldcolumn = "0"
    vim.wo[win].wrap = false
    vim.wo[win].spell = false
    vim.wo[win].cursorline = false
    vim.wo[win].winfixheight = true
    vim.wo[win].winfixwidth = true
end

--- Open the 3-panel review layout in a new tab.
--- Layout:
---   ┌──────────────────────────────────────────┐
---   │ SUMMARY (fixed height)                    │
---   ├────────────────────────────┬──────────────┤
---   │ DIFF (main area)           │ ACTIONS      │
---   │                            │ (fixed width) │
---   └────────────────────────────┴──────────────┘
function M.open()
    if M.is_open() then
        return
    end

    layout.prev_tab = vim.api.nvim_get_current_tabpage()

    -- Create buffers
    layout.bufs.summary = create_buf("summary")
    layout.bufs.diff = create_buf("diff")
    layout.bufs.actions = create_buf("actions")

    -- Create new tab - starts with one window
    -- Use keepjumps to prevent polluting the jumplist
    vim.cmd("keepjumps tabnew")
    layout.tab = vim.api.nvim_get_current_tabpage()

    -- The initial window becomes the diff window
    layout.wins.diff = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(layout.wins.diff, layout.bufs.diff)

    -- Split above for summary
    vim.cmd("aboveleft split")
    layout.wins.summary = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(layout.wins.summary, layout.bufs.summary)
    vim.api.nvim_win_set_height(layout.wins.summary, SUMMARY_HEIGHT)

    -- Go back to diff window, split right for actions
    vim.api.nvim_set_current_win(layout.wins.diff)
    vim.cmd("belowright vsplit")
    layout.wins.actions = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(layout.wins.actions, layout.bufs.actions)
    vim.api.nvim_win_set_width(layout.wins.actions, ACTIONS_WIDTH)

    -- Apply window options to all panels
    for _, win in pairs(layout.wins) do
        set_win_opts(win)
    end

    -- Diff panel gets special treatment
    vim.wo[layout.wins.diff].cursorline = true
    vim.wo[layout.wins.diff].signcolumn = "yes"

    -- Focus the diff window
    vim.api.nvim_set_current_win(layout.wins.diff)

    -- Set filetype for diff syntax highlighting
    vim.bo[layout.bufs.diff].filetype = "diff"

    -- Set up autocmd to detect when the tab is closed externally
    local augroup = vim.api.nvim_create_augroup("QuackReviewLayout", { clear = true })

    vim.api.nvim_create_autocmd("TabClosed", {
        group = augroup,
        callback = function()
            -- Check if our tab still exists
            if layout.tab and not vim.tbl_contains(vim.api.nvim_list_tabpages(), layout.tab) then
                layout.tab = nil
                layout.wins = { summary = nil, diff = nil, actions = nil }
                layout.bufs = { summary = nil, diff = nil, actions = nil }
                -- Also stop the review session if tab was closed externally
                local state_ok, st = pcall(require, "quack-review.state")
                if state_ok and st.is_active() then
                    st.stop()
                end
            end
        end,
    })

    -- Prevent accidental window splits inside the review tab
    vim.api.nvim_create_autocmd("WinNew", {
        group = augroup,
        callback = function()
            -- Only act if we're in the review tab
            if layout.tab and vim.api.nvim_get_current_tabpage() == layout.tab then
                -- Allow floating windows (for comment input, vim.ui.select, etc.)
                local win = vim.api.nvim_get_current_win()
                local config = vim.api.nvim_win_get_config(win)
                if config.relative == "" then
                    -- Non-floating window created in our tab — could break layout
                    -- Close it and notify
                    local known = { layout.wins.summary, layout.wins.diff, layout.wins.actions }
                    if not vim.tbl_contains(known, win) then
                        vim.schedule(function()
                            if vim.api.nvim_win_is_valid(win) then
                                pcall(vim.api.nvim_win_close, win, true)
                            end
                        end)
                    end
                end
            end
        end,
    })
end

--- Close the review layout and return to previous tab.
function M.close()
    if not M.is_open() then
        return
    end

    -- Close the tab (this wipes all windows in it)
    local tab = layout.tab
    if tab and vim.tbl_contains(vim.api.nvim_list_tabpages(), tab) then
        -- Switch to the tab first, then close it
        vim.api.nvim_set_current_tabpage(tab)
        vim.cmd("tabclose")
    end

    -- Return to previous tab
    if layout.prev_tab and vim.tbl_contains(vim.api.nvim_list_tabpages(), layout.prev_tab) then
        vim.api.nvim_set_current_tabpage(layout.prev_tab)
    end

    -- Clean up autocmds
    pcall(vim.api.nvim_del_augroup_by_name, "QuackReviewLayout")

    layout.tab = nil
    layout.prev_tab = nil
    layout.wins = { summary = nil, diff = nil, actions = nil }
    layout.bufs = { summary = nil, diff = nil, actions = nil }
end

--- Check if the review layout is open.
function M.is_open()
    return layout.tab ~= nil
        and vim.tbl_contains(vim.api.nvim_list_tabpages(), layout.tab)
end

--- Get buffer numbers.
function M.get_bufs()
    return layout.bufs
end

--- Get window IDs.
function M.get_wins()
    return layout.wins
end

--- Get the namespace ID for highlights.
function M.namespace()
    return NS
end

--- Write lines to a buffer (handles modifiable toggle).
function M.set_lines(bufnr, lines)
    if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
        return
    end
    vim.bo[bufnr].modifiable = true
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    vim.bo[bufnr].modifiable = false
end

--- Add highlight to a buffer line.
function M.add_hl(bufnr, hl_group, line, col_start, col_end)
    if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
        return
    end
    vim.api.nvim_buf_add_highlight(bufnr, NS, hl_group, line, col_start, col_end)
end

--- Clear all highlights from a buffer.
function M.clear_hl(bufnr)
    if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
        return
    end
    vim.api.nvim_buf_clear_namespace(bufnr, NS, 0, -1)
end

--- Focus the diff window.
function M.focus_diff()
    if layout.wins.diff and vim.api.nvim_win_is_valid(layout.wins.diff) then
        vim.api.nvim_set_current_win(layout.wins.diff)
    end
end

return M
