-- lua/quarker/plan.lua
-- Plan discovery + parser for quarker task plan checklist panel

local M = {}

--- Find the git root or fall back to cwd
---@return string
local function get_root()
  local git_root = vim.fn.systemlist("git rev-parse --show-toplevel 2>/dev/null")[1]
  if git_root and git_root ~= "" and not git_root:match("^fatal") then
    return git_root
  end
  return vim.fn.getcwd()
end

--- Extract file paths from backtick-quoted tokens in item text
--- Matches `path/to/file.lua` patterns
---@param text string
---@return string[]
local function extract_files(text)
  local files = {}
  for token in text:gmatch("`([^`]+)`") do
    -- Keep tokens that look like file paths: contain . or /
    if token:match("[./]") and not token:match("^%s*$") then
      table.insert(files, token)
    end
  end
  return files
end

--- Parse a single task_plan.md file into structured data
---@param filepath string  Absolute path to task_plan.md
---@return table|nil  plan_data or nil on error
function M.parse_plan(filepath)
  local lines = vim.fn.readfile(filepath)
  if not lines or #lines == 0 then
    return nil
  end

  local plan = {
    title       = "",
    goal        = "",
    status      = "",
    phases      = {},
    source_file = filepath,
  }

  local i = 1
  local in_goal = false
  local goal_lines = {}
  local current_phase = nil

  while i <= #lines do
    local line = lines[i]

    -- Title: # Task Plan: Name
    local title = line:match("^# Task Plan: (.+)$")
    if title then
      plan.title = vim.trim(title)
      in_goal = false
      i = i + 1
      goto continue
    end

    -- Status: ## Status: value
    local status = line:match("^## Status: (.+)$")
    if status then
      plan.status = vim.trim(status)
      in_goal = false
      i = i + 1
      goto continue
    end

    -- ## Goal section start
    if line:match("^## Goal$") then
      in_goal = true
      i = i + 1
      goto continue
    end

    -- Any other ## header ends the goal section
    if line:match("^## ") then
      if in_goal then
        plan.goal = vim.trim(table.concat(goal_lines, "\n"))
        in_goal = false
        goal_lines = {}
      end
      -- Don't skip — let phase parsing handle ### headers below
    end

    -- Collect goal lines
    if in_goal then
      table.insert(goal_lines, line)
      i = i + 1
      goto continue
    end

    -- Phase header: ### Phase N: Name [status]
    local phase_name, phase_status = line:match("^### Phase %d+: (.+) %[(.-)%]$")
    if phase_name then
      current_phase = {
        name    = vim.trim(phase_name),
        status  = vim.trim(phase_status),
        line_nr = i,
        items   = {},
      }
      table.insert(plan.phases, current_phase)
      i = i + 1
      goto continue
    end

    -- Checklist item: - [x] or - [ ]
    if current_phase then
      local checked_char, item_text = line:match("^%s*%- %[([x ])%] (.+)$")
      if checked_char then
        local item = {
          checked = (checked_char == "x"),
          text    = vim.trim(item_text),
          files   = extract_files(item_text),
          line_nr = i,
        }
        table.insert(current_phase.items, item)
        i = i + 1
        goto continue
      end
    end

    i = i + 1
    ::continue::
  end

  -- Finalize goal if file ended while in goal section
  if in_goal and #goal_lines > 0 then
    plan.goal = vim.trim(table.concat(goal_lines, "\n"))
  end

  return plan
end

--- Discover all task_plan.md files under the given root
---@param root string|nil  Directory to search from (defaults to git root / cwd)
---@return string[]  List of absolute paths to task_plan.md files
function M.discover_plans(root)
  root = root or get_root()

  local results = {}
  local patterns = {
    root .. "/plans/*/task_plan.md",
    root .. "/plans/task_plan.md",
  }

  for _, pattern in ipairs(patterns) do
    local matches = vim.fn.glob(pattern, false, true)
    for _, path in ipairs(matches) do
      -- Deduplicate
      local seen = false
      for _, existing in ipairs(results) do
        if existing == path then
          seen = true
          break
        end
      end
      if not seen then
        table.insert(results, path)
      end
    end
  end

  return results
end

--- Convenience: discover + parse all plans under root
---@param root string|nil
---@return table[]  List of parsed plan_data tables
function M.load_all_plans(root)
  local paths = M.discover_plans(root)
  local plans = {}
  for _, path in ipairs(paths) do
    local plan = M.parse_plan(path)
    if plan then
      table.insert(plans, plan)
    end
  end
  return plans
end

return M
