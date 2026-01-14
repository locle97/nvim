local M = {}

local ui = require("quackpane.ui")
local git = require("quackpane.git")

-- State
local state = {
  current_mode = "marks", -- "marks" or "git"
  bufnr = nil,
  winid = nil,
  current_files = {}, -- Cache of current file list
}

-- Get files for the current mode
local function get_files_for_mode()
  if state.current_mode == "marks" then
    -- Get marks from Quarker
    local ok, quarker = pcall(require, "quarker")
    if ok then
      local marks = quarker.get_marks()
      -- Quarker marks already have the right format: {path, full_path, name}
      return marks or {}
    else
      vim.notify("Quarker not available", vim.log.levels.WARN)
      return {}
    end
  elseif state.current_mode == "git" then
    -- Get git changed files
    return git.get_changed_files()
  end

  return {}
end

-- Refresh the pane with current mode's files
local function refresh_pane()
  if not M.is_open() then
    return
  end

  state.current_files = get_files_for_mode()
  ui.render(state.bufnr, state.current_files, state.current_mode)
end

-- Open file at cursor
local function open_file()
  local file = ui.get_file_at_cursor(state.current_files)
  if file and file.full_path then
    -- Go back to previous window
    vim.cmd("wincmd p")
    -- Open the file
    vim.cmd("edit " .. vim.fn.fnameescape(file.full_path))
  end
end

-- Cycle to next mode
local function cycle_mode_forward()
  if state.current_mode == "marks" then
    M.switch_mode("git")
  else
    M.switch_mode("marks")
  end
end

-- Cycle to previous mode
local function cycle_mode_backward()
  if state.current_mode == "git" then
    M.switch_mode("marks")
  else
    M.switch_mode("git")
  end
end

-- Check if pane is open
function M.is_open()
  return state.winid ~= nil and vim.api.nvim_win_is_valid(state.winid)
end

-- Open the pane
function M.open(mode)
  if M.is_open() then
    -- Already open, just switch to the window
    vim.api.nvim_set_current_win(state.winid)
    return
  end

  -- Set mode if provided
  if mode then
    state.current_mode = mode
  end

  -- Create window and buffer
  state.bufnr, state.winid = ui.create_window()

  -- Setup keymaps with callbacks
  ui.setup_keymaps(state.bufnr, {
    open_file = open_file,
    cycle_mode_forward = cycle_mode_forward,
    cycle_mode_backward = cycle_mode_backward,
    refresh = function()
      M.refresh()
    end,
    close = function()
      M.close()
    end,
  })

  -- Setup autocmd to clean up state when buffer is closed
  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = state.bufnr,
    callback = function()
      state.bufnr = nil
      state.winid = nil
      state.current_files = {}
    end,
    once = true,
  })

  -- Render initial content
  refresh_pane()
end

-- Close the pane
function M.close()
  if M.is_open() then
    vim.api.nvim_win_close(state.winid, true)
    state.bufnr = nil
    state.winid = nil
    state.current_files = {}
  end
end

-- Toggle the pane
function M.toggle()
  if M.is_open() then
    M.close()
  else
    M.open()
  end
end

-- Switch to a specific mode
function M.switch_mode(mode)
  if mode ~= "marks" and mode ~= "git" then
    vim.notify("Invalid mode: " .. mode .. ". Use 'marks' or 'git'.", vim.log.levels.ERROR)
    return
  end

  state.current_mode = mode
  refresh_pane()
end

-- Refresh current mode
function M.refresh()
  refresh_pane()
end

return M
