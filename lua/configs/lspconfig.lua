require("nvchad.configs.lspconfig").defaults()

local servers = { "html", "cssls", "omnisharp", "angularls", "ts_ls" }
vim.lsp.enable(servers)

