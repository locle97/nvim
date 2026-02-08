local M = {}

-- Hunk status constants
M.STATUS = {
    PENDING = "pending",
    ACCEPTED = "accepted",
    REJECTED = "rejected",
    COMMENTED = "commented",
}

-- Review session state
local session = {
    active = false,
    parsed = nil,          -- result of parser.parse()
    hunks = {},            -- flat list of all hunks (from parser.flatten_hunks)
    current_index = 0,     -- current hunk index (1-based) in flat list
    statuses = {},         -- hunk global_index -> status string
    feedback = {},         -- hunk global_index -> feedback string
    diff_source = nil,     -- what diff source was used
    on_change = nil,       -- callback when state changes (for UI refresh)
}

--- Start a new review session.
--- @param parsed table Parsed diff data from parser.parse()
--- @param flat_hunks table Flat hunk list from parser.flatten_hunks()
--- @param diff_source string|nil The diff source used
function M.start(parsed, flat_hunks, diff_source)
    session.active = true
    session.parsed = parsed
    session.hunks = flat_hunks
    session.current_index = #flat_hunks > 0 and 1 or 0
    session.statuses = {}
    session.feedback = {}
    session.diff_source = diff_source

    -- Initialize all hunks as pending
    for _, hunk in ipairs(flat_hunks) do
        session.statuses[hunk.global_index] = M.STATUS.PENDING
    end
end

--- End the current review session.
function M.stop()
    session.active = false
    session.parsed = nil
    session.hunks = {}
    session.current_index = 0
    session.statuses = {}
    session.feedback = {}
    session.diff_source = nil
    session.on_change = nil
end

--- Check if a review session is active.
function M.is_active()
    return session.active
end

--- Set callback for state changes.
function M.on_change(fn)
    session.on_change = fn
end

--- Notify state change.
local function notify_change()
    if session.on_change then
        session.on_change()
    end
end

-- ==========================================================================
-- Navigation
-- ==========================================================================

--- Get current hunk index (1-based).
function M.current_index()
    return session.current_index
end

--- Get total number of hunks.
function M.total_hunks()
    return #session.hunks
end

--- Get the current hunk data.
--- @return table|nil The hunk table or nil if no session
function M.current_hunk()
    if not session.active or session.current_index < 1 then
        return nil
    end
    return session.hunks[session.current_index]
end

--- Navigate to next hunk. Returns true if moved.
function M.next_hunk()
    if not session.active then return false end
    if session.current_index < #session.hunks then
        session.current_index = session.current_index + 1
        notify_change()
        return true
    end
    return false
end

--- Navigate to previous hunk. Returns true if moved.
function M.prev_hunk()
    if not session.active then return false end
    if session.current_index > 1 then
        session.current_index = session.current_index - 1
        notify_change()
        return true
    end
    return false
end

--- Navigate to a specific hunk by global index. Returns true if moved.
function M.goto_hunk(global_index)
    if not session.active then return false end
    for i, hunk in ipairs(session.hunks) do
        if hunk.global_index == global_index then
            session.current_index = i
            notify_change()
            return true
        end
    end
    return false
end

--- Jump to the next file's first hunk. Returns true if moved.
function M.next_file()
    if not session.active then return false end
    local current = session.hunks[session.current_index]
    if not current then return false end

    for i = session.current_index + 1, #session.hunks do
        if session.hunks[i].file ~= current.file then
            session.current_index = i
            notify_change()
            return true
        end
    end
    return false
end

--- Jump to the previous file's first hunk. Returns true if moved.
function M.prev_file()
    if not session.active then return false end
    local current = session.hunks[session.current_index]
    if not current then return false end

    -- Find the start of current file
    local current_file_start = session.current_index
    while current_file_start > 1 and session.hunks[current_file_start - 1].file == current.file do
        current_file_start = current_file_start - 1
    end

    -- If we're not at the start of current file, go there
    if current_file_start < session.current_index then
        session.current_index = current_file_start
        notify_change()
        return true
    end

    -- Otherwise find the previous file's first hunk
    if current_file_start <= 1 then return false end

    local prev_file = session.hunks[current_file_start - 1].file
    local prev_file_start = current_file_start - 1
    while prev_file_start > 1 and session.hunks[prev_file_start - 1].file == prev_file do
        prev_file_start = prev_file_start - 1
    end

    session.current_index = prev_file_start
    notify_change()
    return true
end

--- Jump to the next unresolved (pending) hunk. Returns true if moved.
function M.next_unresolved()
    if not session.active then return false end

    for i = session.current_index + 1, #session.hunks do
        local hunk = session.hunks[i]
        if session.statuses[hunk.global_index] == M.STATUS.PENDING then
            session.current_index = i
            notify_change()
            return true
        end
    end
    -- Wrap around from start
    for i = 1, session.current_index - 1 do
        local hunk = session.hunks[i]
        if session.statuses[hunk.global_index] == M.STATUS.PENDING then
            session.current_index = i
            notify_change()
            return true
        end
    end
    return false
end

--- Jump to the previous unresolved (pending) hunk. Returns true if moved.
function M.prev_unresolved()
    if not session.active then return false end

    for i = session.current_index - 1, 1, -1 do
        local hunk = session.hunks[i]
        if session.statuses[hunk.global_index] == M.STATUS.PENDING then
            session.current_index = i
            notify_change()
            return true
        end
    end
    -- Wrap around from end
    for i = #session.hunks, session.current_index + 1, -1 do
        local hunk = session.hunks[i]
        if session.statuses[hunk.global_index] == M.STATUS.PENDING then
            session.current_index = i
            notify_change()
            return true
        end
    end
    return false
end

-- ==========================================================================
-- Actions
-- ==========================================================================

--- Get the status of a hunk by global index.
function M.get_status(global_index)
    return session.statuses[global_index] or M.STATUS.PENDING
end

--- Get the status of the current hunk.
function M.current_status()
    local hunk = M.current_hunk()
    if not hunk then return nil end
    return session.statuses[hunk.global_index]
end

--- Set the status of the current hunk.
local function set_current_status(status)
    local hunk = M.current_hunk()
    if not hunk then return false end
    session.statuses[hunk.global_index] = status
    notify_change()
    return true
end

--- Accept the current hunk.
function M.accept()
    return set_current_status(M.STATUS.ACCEPTED)
end

--- Reject the current hunk.
function M.reject()
    return set_current_status(M.STATUS.REJECTED)
end

--- Comment on the current hunk with feedback text.
function M.comment(feedback_text)
    local hunk = M.current_hunk()
    if not hunk then return false end
    session.statuses[hunk.global_index] = M.STATUS.COMMENTED
    session.feedback[hunk.global_index] = feedback_text
    notify_change()
    return true
end

--- Get feedback for a hunk.
function M.get_feedback(global_index)
    return session.feedback[global_index]
end

--- Reset the current hunk to pending.
function M.reset()
    local hunk = M.current_hunk()
    if not hunk then return false end
    session.statuses[hunk.global_index] = M.STATUS.PENDING
    session.feedback[hunk.global_index] = nil
    notify_change()
    return true
end

-- ==========================================================================
-- Summary / Stats
-- ==========================================================================

--- Get the parsed diff data.
function M.get_parsed()
    return session.parsed
end

--- Get the flat hunk list.
function M.get_hunks()
    return session.hunks
end

--- Get the diff source used.
function M.get_diff_source()
    return session.diff_source
end

--- Count hunks by status.
--- @return table { pending=N, accepted=N, rejected=N, commented=N }
function M.counts()
    local counts = {
        pending = 0,
        accepted = 0,
        rejected = 0,
        commented = 0,
    }
    for _, status in pairs(session.statuses) do
        counts[status] = (counts[status] or 0) + 1
    end
    return counts
end

--- Get all hunks with a specific status.
--- @param status string One of M.STATUS values
--- @return table List of hunks
function M.hunks_by_status(status)
    local result = {}
    for _, hunk in ipairs(session.hunks) do
        if session.statuses[hunk.global_index] == status then
            table.insert(result, hunk)
        end
    end
    return result
end

--- Check if all hunks are resolved (not pending).
function M.all_resolved()
    for _, status in pairs(session.statuses) do
        if status == M.STATUS.PENDING then
            return false
        end
    end
    return true
end

--- Build the structured feedback payload for agent consumption.
--- @return table JSON-serializable payload
function M.build_feedback()
    local accepted = {}
    local rejected = {}
    local comments = {}

    for _, hunk in ipairs(session.hunks) do
        local gid = hunk.global_index
        local status = session.statuses[gid]

        if status == M.STATUS.ACCEPTED then
            table.insert(accepted, hunk.file .. ":" .. hunk.index)
        elseif status == M.STATUS.REJECTED then
            table.insert(rejected, hunk.file .. ":" .. hunk.index)
        elseif status == M.STATUS.COMMENTED then
            table.insert(comments, {
                file = hunk.file,
                hunk = hunk.index,
                diff = table.concat(hunk.lines, "\n"),
                feedback = session.feedback[gid] or "",
            })
        end
    end

    return {
        source = session.diff_source or "unstaged",
        total_hunks = #session.hunks,
        accepted = accepted,
        rejected = rejected,
        comments = comments,
        summary = M.counts(),
    }
end

return M
