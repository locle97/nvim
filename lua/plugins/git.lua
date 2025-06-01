return {
    {
        "kdheepak/lazygit.nvim",
        lazy = false,
        config = function()
            vim.g.lazygit_floating_window_scaling_factor = 1
        end
    },
    {
        "lewis6991/gitsigns.nvim",
        event = "User FilePost",
        opts = function()
            return require "nvchad.configs.gitsigns"
        end,
    },
    {
        "sindrets/diffview.nvim",
        event = "VeryLazy",
        config = function()
            require("diffview").setup({
                enhanced_diff_hl = true,
                file_panel = {
                    listing_style = "list"
                },
                keymaps = {
                    file_panel = {
                        {
                            "n", "q", ":DiffviewClose<CR>", {desc = "Close panel"}
                        },
                        {
                            "n", "c",
                            function()
                                vim.ui.input({ prompt = "Commit message: " }, function(msg)
                                    if not msg then return end
                                    local results = vim.system({ "git", "commit", "-m", msg }, { text = true }):wait()

                                    if results.code ~= 0 then
                                        vim.notify(
                                            "Commit failed with the message: \n"
                                            .. vim.trim(results.stdout .. "\n" .. results.stderr),
                                            vim.log.levels.ERROR,
                                            { title = "Commit" }
                                        )
                                    else
                                        vim.notify(results.stdout, vim.log.levels.INFO, { title = "Commit" })
                                    end
                                end)
                            end,
                        },
                    },
                }
            })
        end
    }
}
