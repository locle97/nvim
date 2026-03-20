local M = {}

-- ============================================================================
-- Configuration
-- ============================================================================

---@type QuarkerSyncConfig
local config = {
    enabled = true,
    targets = {
        claude   = true,   -- write fenced section into CLAUDE.md
        cursor   = true,   -- write .cursor/rules/quarker.mdc (quarker-owned)
        agent_md = false,  -- write fenced section into AGENT.md
    },
    section_header    = "## Quarker Active Scope",
    empty_placeholder = "> No context generated yet. Run `:Quarker ai generate` to build context for this scope.",
}

local MARKER_START      = "<!-- quarker-context:start -->"
local MARKER_END        = "<!-- quarker-context:end -->"
local CURSOR_RULES_FILE = ".cursor/rules/quarker.mdc"

-- ============================================================================
-- Type Hints
-- ============================================================================

---@class QuarkerSyncConfig
---@field enabled       boolean
---@field targets       QuarkerSyncTargets
---@field section_header string
---@field empty_placeholder string|nil

---@class QuarkerSyncTargets
---@field claude   boolean
---@field cursor   boolean
---@field agent_md boolean

---@class QuarkerSyncResult
---@field file    string
---@field action  string  "injected"|"appended"|"created"|"overwritten"|"removed"|"skipped"|"error"
---@field message string

-- ============================================================================
-- Setup
-- ============================================================================

function M.setup(user_config)
    if user_config == nil then return end

    if user_config.enabled ~= nil then config.enabled = user_config.enabled end
    if user_config.section_header ~= nil then config.section_header = user_config.section_header end
    if user_config.empty_placeholder ~= nil then config.empty_placeholder = user_config.empty_placeholder end

    if user_config.targets ~= nil then
        if user_config.targets.claude   ~= nil then config.targets.claude   = user_config.targets.claude   end
        if user_config.targets.cursor   ~= nil then config.targets.cursor   = user_config.targets.cursor   end
        if user_config.targets.agent_md ~= nil then config.targets.agent_md = user_config.targets.agent_md end
    end
end

-- ============================================================================
-- Private Helpers
-- ============================================================================

local function read_file(filepath)
    local file, err = io.open(filepath, "r")
    if not file then
        if err and not err:match("No such file") and not err:match("cannot open") then
            vim.notify(("quarker.sync: cannot read %s: %s"):format(filepath, err), vim.log.levels.WARN)
        end
        return ""
    end
    local content = file:read("*a")
    file:close()
    return content or ""
end

local function write_file(filepath, content)
    local parent = vim.fn.fnamemodify(filepath, ":h")
    if vim.fn.mkdir(parent, "p") == -1 then
        return false
    end
    local file = io.open(filepath, "w")
    if not file then return false end
    file:write(content)
    file:close()
    return true
end

--- Build the text placed BETWEEN the fenced markers.
--- Returns nil when content is empty AND empty_placeholder is nil (caller should skip).
local function build_section_body(scope_name, content)
    local trimmed = content:match("^%s*(.-)%s*$") or ""
    if trimmed == "" then
        if config.empty_placeholder == nil then
            return nil
        end
        content = config.empty_placeholder
    end

    local body = config.section_header .. "\n\n"
        .. "_Active scope: **" .. scope_name .. "**_\n\n"
        .. content

    -- Ensure trailing newline so the END marker lands on its own line
    if body:sub(-1) ~= "\n" then
        body = body .. "\n"
    end

    return body
end

--- Inject section_content between MARKER_START / MARKER_END inside filepath.
--- If markers are absent, appends the fenced block. Creates the file if missing.
--- Returns: "injected" | "appended" | "created" | "error"
local function inject_fenced_section(filepath, section_content)
    local existing = read_file(filepath)
    existing = existing:gsub("\r\n", "\n"):gsub("\r", "\n")

    local fenced_block = MARKER_START .. "\n" .. section_content .. MARKER_END .. "\n"

    local start_pos = existing:find(MARKER_START, 1, true)
    local end_pos   = existing:find(MARKER_END,   1, true)

    local new_content, action

    if start_pos and end_pos and start_pos < end_pos then
        -- Replace the existing fenced section
        local before    = existing:sub(1, start_pos - 1)
        local after_raw = existing:sub(end_pos + #MARKER_END)
        -- Strip at most one leading newline — fenced_block already ends with \n
        if after_raw:sub(1, 1) == "\n" then
            after_raw = after_raw:sub(2)
        end
        new_content = before .. fenced_block .. after_raw
        action = "injected"
    elseif existing == "" then
        new_content = fenced_block
        action = "created"
    else
        -- Append: ensure file ends with a newline, then add a blank line separator
        if existing:sub(-1) ~= "\n" then
            existing = existing .. "\n"
        end
        new_content = existing .. "\n" .. fenced_block
        action = "appended"
    end

    if write_file(filepath, new_content) then
        return action
    end
    return "error"
end

--- Remove the fenced quarker section (including markers) from filepath.
--- Returns true if markers were found and removed, false otherwise.
local function remove_fenced_section(filepath)
    local existing = read_file(filepath)
    if existing == "" then return false end

    existing = existing:gsub("\r\n", "\n"):gsub("\r", "\n")

    local start_pos = existing:find(MARKER_START, 1, true)
    local end_pos   = existing:find(MARKER_END,   1, true)

    -- Both markers must be present and in the right order
    if not start_pos or not end_pos or start_pos >= end_pos then
        return false
    end

    local before = existing:sub(1, start_pos - 1)
    local after  = existing:sub(end_pos + #MARKER_END)

    before = before:gsub("%s+$", "")  -- trim trailing whitespace/newlines
    after  = after:gsub("^%s+", "")   -- trim leading whitespace/newlines

    local new_content
    if before == "" and after == "" then
        new_content = ""
    elseif before == "" then
        new_content = after .. "\n"
    elseif after == "" then
        new_content = before .. "\n"
    else
        new_content = before .. "\n\n" .. after .. "\n"
    end

    return write_file(filepath, new_content)
end

-- ============================================================================
-- Target Writers
-- ============================================================================

local function sync_claude_md(base_scope, scope_name, content)
    local filepath = base_scope .. "/CLAUDE.md"

    local body = build_section_body(scope_name, content)
    if body == nil then
        return { file = filepath, action = "skipped", message = "No context and no placeholder configured" }
    end

    local action = inject_fenced_section(filepath, body)

    local msgs = {
        injected = "Updated quarker section",
        appended = "Appended quarker section",
        created  = "Created with quarker section",
        error    = "Failed to write CLAUDE.md",
    }
    return { file = filepath, action = action, message = msgs[action] or action }
end

local function sync_cursor_rules(base_scope, scope_name, content)
    local filepath = base_scope .. "/" .. CURSOR_RULES_FILE

    local body = build_section_body(scope_name, content)

    local mdc_content
    if body == nil then
        -- Write minimal frontmatter-only file so Cursor doesn't see stale scope
        mdc_content = table.concat({
            "---",
            "description: Quarker active scope context",
            "alwaysApply: true",
            "---",
            "",
        }, "\n")
    else
        mdc_content = table.concat({
            "---",
            "description: Quarker active scope context",
            "alwaysApply: true",
            "---",
            "",
        }, "\n") .. body
    end

    if write_file(filepath, mdc_content) then
        return { file = filepath, action = "overwritten", message = "Updated cursor rules" }
    end
    return { file = filepath, action = "error", message = "Failed to write " .. CURSOR_RULES_FILE }
end

local function sync_agent_md(base_scope, scope_name, content)
    local filepath = base_scope .. "/AGENT.md"

    local body = build_section_body(scope_name, content)
    if body == nil then
        return { file = filepath, action = "skipped", message = "No context and no placeholder configured" }
    end

    local action = inject_fenced_section(filepath, body)

    local msgs = {
        injected = "Updated quarker section",
        appended = "Appended quarker section",
        created  = "Created with quarker section",
        error    = "Failed to write AGENT.md",
    }
    return { file = filepath, action = action, message = msgs[action] or action }
end

-- ============================================================================
-- Public API
-- ============================================================================

--- Sync the quarker context for (base_scope, scope_name) to all enabled agent files.
---@return QuarkerSyncResult[]
function M.sync(base_scope, scope_name)
    if not config.enabled then return {} end

    -- Read context for the (now active) scope
    local content = require("quarker.context").get_content()

    local results = {}

    if config.targets.claude then
        local ok, result = pcall(sync_claude_md, base_scope, scope_name, content)
        table.insert(results, ok and result or {
            file    = base_scope .. "/CLAUDE.md",
            action  = "error",
            message = tostring(result),
        })
    end

    if config.targets.cursor then
        local ok, result = pcall(sync_cursor_rules, base_scope, scope_name, content)
        table.insert(results, ok and result or {
            file    = base_scope .. "/" .. CURSOR_RULES_FILE,
            action  = "error",
            message = tostring(result),
        })
    end

    if config.targets.agent_md then
        local ok, result = pcall(sync_agent_md, base_scope, scope_name, content)
        table.insert(results, ok and result or {
            file    = base_scope .. "/AGENT.md",
            action  = "error",
            message = tostring(result),
        })
    end

    return results
end

--- Remove all quarker-injected sections from every enabled target file.
---@return QuarkerSyncResult[]
function M.clear(base_scope)
    local results = {}

    if config.targets.claude then
        local filepath = base_scope .. "/CLAUDE.md"
        local ok, removed = pcall(remove_fenced_section, filepath)
        table.insert(results, {
            file    = filepath,
            action  = ok and (removed and "removed" or "skipped") or "error",
            message = ok and (removed and "Removed quarker section" or "No quarker section found")
                          or tostring(removed),
        })
    end

    if config.targets.cursor then
        local filepath = base_scope .. "/" .. CURSOR_RULES_FILE
        if vim.fn.filereadable(filepath) == 1 then
            local deleted = vim.fn.delete(filepath) == 0
            table.insert(results, {
                file    = filepath,
                action  = deleted and "removed" or "error",
                message = deleted and "Deleted quarker.mdc" or "Failed to delete quarker.mdc",
            })
        else
            table.insert(results, { file = filepath, action = "skipped", message = "File does not exist" })
        end
    end

    if config.targets.agent_md then
        local filepath = base_scope .. "/AGENT.md"
        local ok, removed = pcall(remove_fenced_section, filepath)
        table.insert(results, {
            file    = filepath,
            action  = ok and (removed and "removed" or "skipped") or "error",
            message = ok and (removed and "Removed quarker section" or "No quarker section found")
                          or tostring(removed),
        })
    end

    return results
end

--- Return status of which files currently contain quarker context. Does not modify files.
function M.status(base_scope)
    local entries = {}

    if config.targets.claude then
        local filepath = base_scope .. "/CLAUDE.md"
        local content  = read_file(filepath)
        local present  = content:find(MARKER_START, 1, true) ~= nil
        table.insert(entries, { file = filepath, present = present, action = present and "synced" or "not synced" })
    end

    if config.targets.cursor then
        local filepath = base_scope .. "/" .. CURSOR_RULES_FILE
        local present  = vim.fn.filereadable(filepath) == 1
        table.insert(entries, { file = filepath, present = present, action = present and "synced" or "not synced" })
    end

    if config.targets.agent_md then
        local filepath = base_scope .. "/AGENT.md"
        local content  = read_file(filepath)
        local present  = content:find(MARKER_START, 1, true) ~= nil
        table.insert(entries, { file = filepath, present = present, action = present and "synced" or "not synced" })
    end

    return entries
end

return M
