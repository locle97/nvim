require("nvchad.configs.lspconfig").defaults()

local servers = { "html", "cssls", "angularls", "ts_ls", "roslyn" }
vim.lsp.enable(servers)

local lspconfig = require('lspconfig')

lspconfig.volar.setup {
  filetypes = { 'typescript', 'javascript', 'javascriptreact', 'typescriptreact', 'vue' },
  init_options = {
    vue = {
      hybridMode = false,
    },
  },
}
