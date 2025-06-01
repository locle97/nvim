return {
    {
        "iamcco/markdown-preview.nvim",
        cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
        build = "cd app && yarn install",
        init = function()
            vim.g.mkdp_filetypes = { "markdown" }
        end,
        config = function()
            vim.g.mkdp_browser = "firefox"
            vim.keymap.set("n",
                "<leader>mp",
                "<cmd>MarkdownPreviewToggle<cr>",
                { desc = "Markdown Preview Toggle" })
        end,
        ft = { "markdown" },
    },
}
