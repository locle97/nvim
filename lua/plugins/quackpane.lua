return {
  dir = vim.fn.stdpath("config") .. "/lua/quackpane",
  name = "quackpane",
  dependencies = {
    "nvim-tree/nvim-web-devicons",
    {
      dir = vim.fn.stdpath("config") .. "/lua/quarker",
      name = "quarker",
    },
  },
  keys = {
    {
      "<leader>qp",
      function()
        require("quackpane").toggle()
      end,
      desc = "Quackpane: Toggle pane",
    },
    {
      "<leader>qm",
      function()
        require("quackpane").open("marks")
      end,
      desc = "Quackpane: Open marks mode",
    },
    {
      "<leader>qg",
      function()
        require("quackpane").open("git")
      end,
      desc = "Quackpane: Open git mode",
    },
  },
  config = function()
    -- Register user commands
    vim.api.nvim_create_user_command("Quackpane", function(opts)
      local mode = opts.args
      if mode == "" then
        mode = "marks"
      end

      if mode ~= "marks" and mode ~= "git" then
        vim.notify("Usage: :Quackpane [marks|git]", vim.log.levels.ERROR)
        return
      end

      require("quackpane").open(mode)
    end, {
      nargs = "?",
      complete = function()
        return { "marks", "git" }
      end,
      desc = "Open Quackpane in specified mode (default: marks)",
    })

    vim.api.nvim_create_user_command("QuackpaneToggle", function()
      require("quackpane").toggle()
    end, { desc = "Toggle Quackpane" })

    vim.api.nvim_create_user_command("QuackpaneMarks", function()
      require("quackpane").open("marks")
    end, { desc = "Open Quackpane in marks mode" })

    vim.api.nvim_create_user_command("QuackpaneGit", function()
      require("quackpane").open("git")
    end, { desc = "Open Quackpane in git mode" })

    vim.api.nvim_create_user_command("QuackpaneRefresh", function()
      require("quackpane").refresh()
    end, { desc = "Refresh Quackpane" })
  end,
}
