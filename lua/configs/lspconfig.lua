require("nvchad.configs.lspconfig").defaults()

local servers = { "html", "cssls", "omnisharp", "angularls", "ts_ls" }
vim.lsp.enable(servers)

-- read :h vim.lsp.config for changing options of lsp servers 
