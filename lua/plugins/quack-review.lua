return {
    {
        dir = vim.fn.stdpath("config") .. "/lua/quack-review",
        name = "quack-review",
        cmd = "QuackReview",
        keys = {
            { "<leader>qr", "<cmd>QuackReview start<CR>", desc = "QuackReview: start (unstaged)" },
            { "<leader>qR", "<cmd>QuackReview start head<CR>", desc = "QuackReview: start (all uncommitted)" },
        },
        config = function()
            require("quack-review")
        end,
    },
}
