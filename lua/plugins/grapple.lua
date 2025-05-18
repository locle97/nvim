return {
    "cbochs/grapple.nvim",
    keys = {
        {
            "<leader>mm",
            function()
                require("grapple").tag()
                vim.cmd.mark("a")
            end,
            desc = "Tag a file"
        },
        { "<leader><leader>", "<cmd>Grapple toggle_tags<cr>",     desc = "Toggle tags menu" },

        { "<leader>1",        "<cmd>Grapple select index=1<cr>",  desc = "Select first tag" },
        { "<leader>2",        "<cmd>Grapple select index=2<cr>",  desc = "Select second tag" },
        { "<leader>3",        "<cmd>Grapple select index=3<cr>",  desc = "Select third tag" },
        { "<leader>4",        "<cmd>Grapple select index=4<cr>",  desc = "Select fourth tag" },
        { "<leader>5",        "<cmd>Grapple select index=5<cr>",  desc = "Select fifth tag" },

        { "<c-s-n>",          "<cmd>Grapple cycle_tags next<cr>", desc = "Go to next tag" },
        { "<c-s-p>",          "<cmd>Grapple cycle_tags prev<cr>", desc = "Go to previous tag" },
    },
    opts = {
        scope = "git",
        icons = true, -- setting to "true" requires "nvim-web-devicons"
        status = true,
        name_pos = "start",
        style = "basename"
    }
}
