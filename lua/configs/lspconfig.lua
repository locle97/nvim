require("nvchad.configs.lspconfig").defaults()

local servers = { "html", "cssls", "ts_ls", "omnisharp", "jsonls" }
vim.lsp.enable(servers)

local lspconfig = require('lspconfig')
