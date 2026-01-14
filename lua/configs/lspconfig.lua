require("nvchad.configs.lspconfig").defaults()

local servers = { "html", "cssls", "omnisharp", "jsonls", "ts_ls", "prettier", "vtsls" }

vim.lsp.config('ts_ls', {
    init_options = {
        plugins = {
            {
                name = "@vue/typescript-plugin",
                location = "/usr/local/lib/node_modules/@vue/language-server/node_modules/@vue/typescript-plugin",
                languages = { "javascript", "typescript", "vue" },
            },
        },
    },
    filetypes = {
        "javascript",
        "typescript",
        "vue",
    },
})

vim.lsp.enable(servers)
