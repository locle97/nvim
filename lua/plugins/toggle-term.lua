return {
    "akinsho/toggleterm.nvim",
    lazy = false,
    config = function()
        require("toggleterm").setup {
            open_mapping = [[<c-t>]],
            direction = "float",
            shade_terminals = true,
            shell = "/bin/fish"
        }
    end,
}
