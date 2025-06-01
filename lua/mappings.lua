require "nvchad.mappings"

-- add yours here

local map = vim.keymap.set

map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")

map("n", "<leader>h", "yiw:%s/<C-r>\"//gI<Left><Left><Left>", { desc = "Replace current word" })
map("v", "<leader>h", "y:%s/<C-r>\"//gI<Left><Left><Left>",
    { noremap = true, silent = false, desc = "Replace current selected text" })

map("i", "<C-b>", "<ESC>^i", { desc = "move beginning of line" })
map("i", "<C-e>", "<End>", { desc = "move end of line" })
map("i", "<C-h>", "<Left>", { desc = "move left" })
map("i", "<C-l>", "<Right>", { desc = "move right" })
map("i", "<C-j>", "<Down>", { desc = "move down" })
map("i", "<C-k>", "<Up>", { desc = "move up" })

map("n", "<C-h>", "<C-w>h", { desc = "switch window left" })
map("n", "<C-l>", "<C-w>l", { desc = "switch window right" })
map("n", "<C-j>", "<C-w>j", { desc = "switch window down" })
map("n", "<C-k>", "<C-w>k", { desc = "switch window up" })

map("n", "<Esc>", "<cmd>noh<CR>", { desc = "General Clear highlights" })

-- map("n", "<C-s>", "<cmd>w<CR>", { desc = "General Save file" })
map("n", "<C-c>", "<cmd>%y+<CR>", { desc = "General Copy whole file" })

map("x", "p", "\"_dP", { desc = "In visual mode, when pasting, no copy deleted words" })
map("n", "J", "mzJ`z", { desc = "No jumping to end of line when J" })

-- Mapping to move selected block up and down
map("x", "J", ":m '>+1<CR>gv=gv", { desc = "Move the whole selected block down" })
map("x", "K", ":m '<-2<CR>gv=gv", { desc = "Move the whole selected block up" })

-- Center search results
map("n", "n", "nzzzv", { desc = "Jump to next search centralize screen" })
map("n", "N", "Nzzzv", { desc = "Jump to next search centralize screen" })

map("n", "<leader>fm", function()
    require("conform").format { lsp_fallback = true }
end, { desc = "General Format file" })

-- global lsp mappings
map("n", "<leader>ds", vim.diagnostic.setloclist, { desc = "LSP Diagnostic loclist" })

-- tabufline
map("n", "<leader>bb", "<cmd>Telescope buffers<CR>", { desc = "Show buffers" })
map("n", "<leader>bo", function() require('utils').remove_other_buffers() end, { desc = "Delete other buffers" })
map("n", "<tab>", "<cmd>bnext<CR>", { desc = "buffer goto next" })
map("n", "<S-tab>", "<cmd>bprevious<CR>", { desc = "buffer goto prev" })
map("n", "<leader>x", "<cmd>bdelete<CR>", { desc = "buffer close" })

-- Comment
map("n", "<leader>/", "gcc", { desc = "Toggle Comment", remap = true })
map("v", "<leader>/", "gc", { desc = "Toggle comment", remap = true })

-- nvimtree
map("n", "<leader>e", "<cmd>NvimTreeToggle<CR>", { desc = "nvimtree toggle window" })
-- map("n", "<leader>e", function() require("nvim-tree.api").tree.toggle({ current_window = true }) end,
--     { desc = "Open nvim tree in current window" })
-- map("n", "<leader>e", "<cmd>Explore<CR>", { desc = "nvimtree focus window" })

-- telescope
map("n", "<leader>fw", "<cmd>Telescope live_grep<CR>", { desc = "telescope live grep" })
map("n", "<leader>fb", "<cmd>Telescope buffers<CR>", { desc = "telescope find buffers" })
map("n", "<leader>fh", "<cmd>Telescope help_tags<CR>", { desc = "telescope help page" })
map("n", "<leader>ma", "<cmd>Telescope marks<CR>", { desc = "telescope find marks" })
map("n", "<leader>fo", "<cmd>Telescope oldfiles<CR>", { desc = "telescope find oldfiles" })
map("n", "<leader>fz", "<cmd>Telescope current_buffer_fuzzy_find<CR>", { desc = "telescope find in current buffer" })
map("n", "<leader>cm", "<cmd>Telescope git_commits<CR>", { desc = "telescope git commits" })
map("n", "<leader>gs", "<cmd>Telescope git_status<CR>", { desc = "telescope git status" })
map("n", "<leader>pt", "<cmd>Telescope terms<CR>", { desc = "telescope pick hidden term" })
map("n", "<leader>th", "<cmd>Telescope themes<CR>", { desc = "telescope nvchad themes" })
map("n", "<C-p>", "<cmd> Telescope find_files <CR>", { desc = "telescope find files" })
map("n", "<leader>ff", "<cmd>Telescope find_files<cr>", { desc = "telescope find files" })
map(
    "n",
    "<leader>fa",
    "<cmd>Telescope find_files follow=true no_ignore=true hidden=true<CR>",
    { desc = "telescope find all files" }
)
map("n", "<leader>fp", "<cmd> Telescope projects <CR>", { desc = "Project" })

-- toggleable
map({ "n", "t" }, "<A-v>", function()
    require("nvchad.term").toggle { pos = "vsp", id = "vtoggleTerm" }
end, { desc = "terminal toggleable vertical term" })

map({ "n", "t" }, "<A-h>", function()
    require("nvchad.term").toggle { pos = "sp", id = "htoggleTerm" }
end, { desc = "terminal toggleable horizontal term" })

map({ "n", "t" }, "<A-i>", function()
    require("nvchad.term").toggle { pos = "float", id = "floatTerm" }
end, { desc = "terminal toggle floating term" })

-- add yours here

-- map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")

-- map({ "n", "i", "v" }, "<C-s>", "<cmd> w <cr>")
-- n, v, i, t = mode names

-- Lspconfig Code action
map("n", "<C-y>", function() vim.lsp.buf.code_action() end, { desc = "lsp code_action", })
map({ "n", "v", "i" }, "<C-.>", function() vim.lsp.buf.code_action() end, { desc = "lsp code_action", })

-- User config
-- LSPConfig
map("n", "gD", function() vim.lsp.buf.declaration() end, { desc = "lsp declaration", noremap = true, silent = true })
map("n", "gd", function() vim.lsp.buf.definition() end, { desc = "lsp definition", noremap = true, silent = true })
map("n", "K", function() vim.lsp.buf.hover() end, { desc = "lsp hover", })
map("n", "gi", function() require("telescope.builtin").lsp_implementations() end,
    { desc = "lsp implementation", noremap = true, silent = true })
map("n", "gr", function() require("telescope.builtin").lsp_references() end,
    { desc = "lsp references", noremap = true, silent = true })
map("n", "go", function() require("telescope.builtin").lsp_document_symbols() end,
    { desc = "lsp document symbols", noremap = true, silent = true })

-- Open code action
map("n", "<C-y>", function() vim.lsp.buf.code_action() end, { desc = "lsp code_action", })
map("v", "<C-y>", function() vim.lsp.buf.code_action() end, { desc = "lsp code_action", })

-- Open Diagnostic of current workspace
map("n", "<leader>f", function() vim.diagnostic.open_float(nil, { border = 'rounded' }) end,
    { desc = "floating diagnostic", })
map("n", "<leader>q", function() require("telescope.builtin").diagnostics({ bufnr = 0 }) end,
    { desc = "Diagnostic setloclist", })
map("n", "<leader>fq", function() require("telescope.builtin").diagnostics() end,
    { desc = "lsp document symbols", noremap = true, silent = true })

-- Lsp rename
map("n", "<F2>", function() vim.lsp.buf.rename() end, { desc = "lsp rename", })

-- Lsp format code
map("n", "<leader>fm", function() vim.lsp.buf.format { async = true } end, { desc = "LSP formatting", })
map("v", "<leader>fm", function() vim.lsp.buf.format { async = true } end, { desc = "lsp formatting", })

-- Git
map("n", "<leader>gl", ":LazyGit<CR>", { desc = "Open LazyGit" })
map("n", "<leader>gd", function()
    local lib = require("diffview.lib")
    local view = lib.get_current_view()
    if view then
        -- Current tabpage is a Diffview; close it
        vim.cmd.DiffviewClose()
    else
        -- No open Diffview exists: open a new one
        vim.cmd.DiffviewOpen()
    end
end, { desc = "Toggle Git differents" })

-- Tmux
-- map("n", "<c-h>", "<cmd>TmuxNavigateLeft<cr>")
-- map("n", "<c-j>", "<cmd>TmuxNavigateDown<cr>")
-- map("n", "<c-k>", "<cmd>TmuxNavigateUp<cr>")
-- map("n", "<c-l>", "<cmd>TmuxNavigateRight<cr>")
-- map("n", "<c-\\>", "<cmd>TmuxNavigatePrevious<cr>")

-- Copilot Chat
map("n", "<leader>cc", function()
    require("CopilotChat").toggle()
end, { desc = "Open Copilot Chat" })
map("x", "<leader>ce", ":CopilotChatExplain<CR>",
    { desc = "Explain the whole selected block" })

-- remapping ; work as :
map("n", ";", ":", { noremap = true, silent = false })

-- End user config
