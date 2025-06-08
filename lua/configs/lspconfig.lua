require("nvchad.configs.lspconfig").defaults()

local servers = { "html", "cssls", "omnisharp", "jsonls", "vue_ls" }

vim.lsp.config('vue_ls', {
    filetypes = { 'typescript', 'javascript', 'javascriptreact', 'typescriptreact', 'vue' },
    init_options = {
        vue = {
            hybridMode = false,
        },
    },
})

vim.lsp.enable(servers)
