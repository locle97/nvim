local M = {}

-- Setup highlight groups
local function setup_highlights()
  vim.api.nvim_set_hl(0, "QuackpaneHeader", { link = "Title" })
  vim.api.nvim_set_hl(0, "QuackpaneSeparator", { link = "Comment" })
  vim.api.nvim_set_hl(0, "QuackpaneGitModified", { link = "DiffChange" })
  vim.api.nvim_set_hl(0, "QuackpaneGitStaged", { link = "DiffAdd" })
  vim.api.nvim_set_hl(0, "QuackpaneGitUntracked", { link = "DiffText" })
  vim.api.nvim_set_hl(0, "QuackpanePath", { link = "Comment" })
end

-- Create the sidebar window and buffer
function M.create_window()
  -- Create buffer
  local bufnr = vim.api.nvim_create_buf(false, true)

  -- Set buffer options
  vim.api.nvim_buf_set_option(bufnr, "buftype", "nofile")
  vim.api.nvim_buf_set_option(bufnr, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(bufnr, "swapfile", false)
  vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
  vim.api.nvim_buf_set_option(bufnr, "filetype", "quackpane")

  -- Calculate window width (30 characters)
  local width = 50

  -- Create window on the right side
  vim.cmd("vsplit")
  local winid = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(winid, bufnr)

  -- Move window to the right
  vim.cmd("wincmd L")

  -- Set width after moving to prevent it from being reset
  vim.api.nvim_win_set_width(winid, width)

  -- Set window options
  vim.api.nvim_win_set_option(winid, "number", true)
  vim.api.nvim_win_set_option(winid, "relativenumber", false)
  vim.api.nvim_win_set_option(winid, "cursorline", true)
  vim.api.nvim_win_set_option(winid, "wrap", false)
  vim.api.nvim_win_set_option(winid, "signcolumn", "no")

  -- Setup highlights
  setup_highlights()

  return bufnr, winid
end

-- Get file icon using nvim-web-devicons
local function get_file_icon(filename)
  local ok, devicons = pcall(require, "nvim-web-devicons")
  if ok then
    local icon, hl = devicons.get_icon(filename, nil, { default = true })
    return icon or " ", hl
  end
  return " ", nil
end

-- Render file list in the buffer
function M.render(bufnr, files, mode)
  -- Make buffer modifiable
  vim.api.nvim_buf_set_option(bufnr, "modifiable", true)

  local lines = {}
  local highlights = {}

  -- Header line
  local mode_name = mode == "marks" and "Marks" or "Git"
  local count = #files
  local header = string.format("[Mode: %s] (%d files)", mode_name, count)
  table.insert(lines, header)
  table.insert(highlights, { line = 0, col = 0, end_col = #header, hl_group = "QuackpaneHeader" })

  -- Separator
  local separator = string.rep("─", 40)
  table.insert(lines, separator)
  table.insert(highlights, { line = 1, col = 0, end_col = #separator, hl_group = "QuackpaneSeparator" })

  -- File entries
  if count == 0 then
    local msg = mode == "marks" and "No marked files" or "No git changes"
    table.insert(lines, msg)
  else
    for i, file in ipairs(files) do
      local line = ""
      local col_offset = 0

      -- For marks mode, show mark index
      if mode == "marks" then
        local mark_idx = string.format("[%d] ", i)
        line = mark_idx
        col_offset = #mark_idx
      end

      -- For git mode, show status indicator
      if mode == "git" and file.status then
        local status = file.status .. " "
        line = line .. status

        -- Highlight status indicator
        local status_hl = "QuackpaneGitModified"
        if file.status == "A" then
          status_hl = "QuackpaneGitStaged"
        elseif file.status == "?" then
          status_hl = "QuackpaneGitUntracked"
        end

        table.insert(highlights, {
          line = #lines,
          col = col_offset,
          end_col = col_offset + #status,
          hl_group = status_hl,
        })

        col_offset = col_offset + #status
      end

      -- Get file icon
      local icon, icon_hl = get_file_icon(file.name)
      line = line .. icon .. " "

      -- Highlight icon
      if icon_hl then
        table.insert(highlights, {
          line = #lines,
          col = col_offset,
          end_col = col_offset + #icon,
          hl_group = icon_hl,
        })
      end

      col_offset = col_offset + #icon + 1

      -- Add filename (main text)
      local filename = file.name or file.path
      line = line .. filename

      -- Add relative path in gray (if different from filename)
      if file.path and file.path ~= filename then
        local path_text = " " .. file.path
        line = line .. path_text

        -- Highlight path in gray
        table.insert(highlights, {
          line = #lines,
          col = col_offset + #filename,
          end_col = col_offset + #filename + #path_text,
          hl_group = "QuackpanePath",
        })
      end

      table.insert(lines, line)
    end
  end

  -- Set buffer content
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

  -- Apply highlights
  local ns_id = vim.api.nvim_create_namespace("quackpane")
  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)

  for _, hl in ipairs(highlights) do
    vim.api.nvim_buf_add_highlight(bufnr, ns_id, hl.hl_group, hl.line, hl.col, hl.end_col)
  end

  -- Make buffer readonly
  vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
end

-- Get file object at current cursor position
function M.get_file_at_cursor(files)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = cursor[1]

  -- Account for header (2 lines)
  local file_index = line - 2

  if file_index >= 1 and file_index <= #files then
    return files[file_index]
  end

  return nil
end

-- Setup buffer-local keymaps
function M.setup_keymaps(bufnr, callbacks)
  local opts = { buffer = bufnr, noremap = true, silent = true }

  -- Open file at cursor
  vim.keymap.set("n", "<CR>", callbacks.open_file, opts)

  -- Switch modes
  vim.keymap.set("n", "<Tab>", callbacks.cycle_mode_forward, opts)
  vim.keymap.set("n", "<S-Tab>", callbacks.cycle_mode_backward, opts)

  -- Refresh
  vim.keymap.set("n", "r", callbacks.refresh, opts)

  -- Close pane
  vim.keymap.set("n", "q", callbacks.close, opts)
  vim.keymap.set("n", "<Esc>", callbacks.close, opts)
end

return M
