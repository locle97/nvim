vim.api.nvim_create_autocmd("VimEnter", {
  callback = function(data)
    -- buffer is a directory
    local directory = vim.fn.isdirectory(data.file) == 1

    if directory then
      vim.cmd.cd(data.file)
      require("nvim-tree.api").tree.open()
    elseif data.file == "" then
      require("nvim-tree.api").tree.open()
    end
  end
})

