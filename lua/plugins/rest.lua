return {
    "rest-nvim/rest.nvim",
    event = "VeryLazy",
    dependencies = {
        "nvim-treesitter/nvim-treesitter",
        opts = function(_, opts)
            opts.ensure_installed = opts.ensure_installed or {}
            table.insert(opts.ensure_installed, "http")
        end,
    },
    config = function()
        vim.keymap.set("n", "<leader>rr", "<cmd>Rest run<CR>", { desc = "Run rest command" })
        vim.keymap.set("n", "<leader>re", function ()
            require("telescope").extensions.rest.select_env()
        end, { desc = "Run telescope to select environment" })
        vim.api.nvim_create_autocmd("FileType", {
            pattern = { "json" },
            callback = function()
                vim.api.nvim_set_option_value("formatprg", "jq", { scope = 'local' })
            end,
        })
    end
}
