local state = require("quack-review.state")

local M = {}

--- Open a floating multi-line comment input for the current hunk.
--- On confirm, calls state.comment() and triggers refresh.
function M.open()
    local hunk = state.current_hunk()
    if not hunk then
        vim.notify("quack-review: No hunk selected.", vim.log.levels.WARN)
        return
    end

    local existing = state.get_feedback(hunk.global_index)

    -- Create buffer for the input
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.bo[bufnr].buftype = "acwrite"
    vim.bo[bufnr].bufhidden = "wipe"
    vim.bo[bufnr].swapfile = false
    vim.bo[bufnr].filetype = "markdown"

    -- Pre-fill with existing feedback or placeholder
    local initial_lines
    if existing and existing ~= "" then
        initial_lines = vim.split(existing, "\n")
    else
        initial_lines = { "" }
    end
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, initial_lines)

    -- Window dimensions
    local width = math.floor(vim.o.columns * 0.5)
    local height = math.max(8, math.floor(vim.o.lines * 0.2))

    local win = vim.api.nvim_open_win(bufnr, true, {
        relative = "editor",
        row = math.floor((vim.o.lines - height) / 2),
        col = math.floor((vim.o.columns - width) / 2),
        width = width,
        height = height,
        style = "minimal",
        border = "rounded",
        title = string.format(" 💬 Comment — %s hunk %d ", vim.fn.fnamemodify(hunk.file, ":t"), hunk.index),
        title_pos = "center",
        footer = " <C-s> save  │  <Esc> cancel ",
        footer_pos = "center",
    })

    vim.wo[win].wrap = true
    vim.wo[win].cursorline = true

    -- Start in insert mode if empty
    if not existing or existing == "" then
        vim.cmd("startinsert")
    end

    -- Save: confirm comment
    local function save_comment()
        local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
        local text = vim.trim(table.concat(lines, "\n"))
        if text ~= "" then
            state.comment(text)
            vim.notify("quack-review: Comment saved.", vim.log.levels.INFO)
        end
        if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_close(win, true)
        end
    end

    -- Cancel: close without saving
    local function cancel()
        if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_close(win, true)
        end
    end

    -- Keymaps for the comment buffer
    local opts = { buffer = bufnr, nowait = true, silent = true }

    -- Normal mode: Ctrl-S to save, Esc/q to cancel
    vim.keymap.set("n", "<C-s>", save_comment, opts)
    vim.keymap.set("n", "<Esc>", cancel, opts)
    vim.keymap.set("n", "q", cancel, opts)

    -- Insert mode: Ctrl-S to save
    vim.keymap.set("i", "<C-s>", function()
        vim.cmd("stopinsert")
        save_comment()
    end, opts)

    -- Handle BufWriteCmd for :w
    vim.api.nvim_create_autocmd("BufWriteCmd", {
        buffer = bufnr,
        once = true,
        callback = function()
            save_comment()
        end,
    })
end

return M
