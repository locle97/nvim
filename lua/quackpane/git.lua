local M = {}

-- Check if current directory is inside a git repository
local function is_git_repo()
  local result = vim.fn.systemlist("git rev-parse --is-inside-work-tree 2>/dev/null")
  return vim.v.shell_error == 0 and result[1] == "true"
end

-- Get the git repository root directory
local function get_git_root()
  local result = vim.fn.systemlist("git rev-parse --show-toplevel 2>/dev/null")
  if vim.v.shell_error == 0 and #result > 0 then
    return result[1]
  end
  return nil
end

-- Get modified files (working tree changes)
local function get_modified_files()
  local result = vim.fn.systemlist("git diff --name-only 2>/dev/null")
  if vim.v.shell_error == 0 then
    return result
  end
  return {}
end

-- Get staged files (index changes)
local function get_staged_files()
  local result = vim.fn.systemlist("git diff --cached --name-only 2>/dev/null")
  if vim.v.shell_error == 0 then
    return result
  end
  return {}
end

-- Get untracked files
local function get_untracked_files()
  local result = vim.fn.systemlist("git ls-files --others --exclude-standard 2>/dev/null")
  if vim.v.shell_error == 0 then
    return result
  end
  return {}
end

-- Deduplicate and sort file list
local function deduplicate(files)
  local seen = {}
  local result = {}

  for _, file in ipairs(files) do
    if not seen[file] and file ~= "" then
      seen[file] = true
      table.insert(result, file)
    end
  end

  table.sort(result)
  return result
end

-- Get git status for a file (M, A, ?)
local function get_file_status(file, modified_set, staged_set, untracked_set)
  if untracked_set[file] then
    return "?"
  elseif staged_set[file] then
    return "A"
  elseif modified_set[file] then
    return "M"
  end
  return " "
end

-- Main function: Get all changed files in git repository
-- Returns array of file objects: { path, full_path, name, status }
function M.get_changed_files()
  -- Check if we're in a git repository
  if not is_git_repo() then
    return {}
  end

  -- Get git root
  local git_root = get_git_root()
  if not git_root then
    return {}
  end

  -- Collect all changed files
  local modified = get_modified_files()
  local staged = get_staged_files()
  local untracked = get_untracked_files()

  -- Create sets for status lookup
  local modified_set = {}
  for _, file in ipairs(modified) do
    modified_set[file] = true
  end

  local staged_set = {}
  for _, file in ipairs(staged) do
    staged_set[file] = true
  end

  local untracked_set = {}
  for _, file in ipairs(untracked) do
    untracked_set[file] = true
  end

  -- Combine and deduplicate
  local all_files = {}
  vim.list_extend(all_files, modified)
  vim.list_extend(all_files, staged)
  vim.list_extend(all_files, untracked)

  all_files = deduplicate(all_files)

  -- Format as objects compatible with Quarker format
  local result = {}
  for _, file in ipairs(all_files) do
    local full_path = git_root .. "/" .. file
    local name = vim.fn.fnamemodify(file, ":t")
    local status = get_file_status(file, modified_set, staged_set, untracked_set)

    table.insert(result, {
      path = file,
      full_path = full_path,
      name = name,
      status = status,
    })
  end

  return result
end

return M
