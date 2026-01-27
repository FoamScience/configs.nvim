local M = {}

---@param iso_timestamp string ISO 8601 timestamp (e.g., "2024-01-15T10:30:00.000+0000")
---@return string Formatted date/time
function M.format_timestamp(iso_timestamp)
    if not iso_timestamp or iso_timestamp == "" then
        return "N/A"
    end

    local year, month, day, hour, min, sec = iso_timestamp:match("(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")

    if not year then
        return iso_timestamp
    end

    local months = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }
    local month_name = months[tonumber(month)] or month

    return string.format("%s %d, %s %s:%s", month_name, tonumber(day), year, hour, min)
end

---@param iso_timestamp string ISO 8601 timestamp
---@return string Relative time (e.g., "2 hours ago", "3 days ago")
function M.format_relative_time(iso_timestamp)
    if not iso_timestamp or iso_timestamp == "" then
        return "N/A"
    end

    local year, month, day, hour, min, sec = iso_timestamp:match("(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")

    if not year then
        return iso_timestamp
    end

    local ts = os.time({
        year = tonumber(year),
        month = tonumber(month),
        day = tonumber(day),
        hour = tonumber(hour),
        min = tonumber(min),
        sec = tonumber(sec) or 0,
    })

    local now = os.time()
    local diff = now - ts

    if diff < 0 then
        return M.format_timestamp(iso_timestamp)
    elseif diff < 60 then
        return "just now"
    elseif diff < 3600 then
        local mins = math.floor(diff / 60)
        return mins == 1 and "1 minute ago" or (mins .. " minutes ago")
    elseif diff < 86400 then
        local hours = math.floor(diff / 3600)
        return hours == 1 and "1 hour ago" or (hours .. " hours ago")
    elseif diff < 604800 then
        local days = math.floor(diff / 86400)
        return days == 1 and "1 day ago" or (days .. " days ago")
    elseif diff < 2592000 then
        local weeks = math.floor(diff / 604800)
        return weeks == 1 and "1 week ago" or (weeks .. " weeks ago")
    else
        return M.format_timestamp(iso_timestamp)
    end
end

---@param bytes number
---@return string
function M.format_file_size(bytes)
    if bytes < 1024 then
        return bytes .. " B"
    elseif bytes < 1024 * 1024 then
        return string.format("%.1f KB", bytes / 1024)
    elseif bytes < 1024 * 1024 * 1024 then
        return string.format("%.1f MB", bytes / (1024 * 1024))
    else
        return string.format("%.1f GB", bytes / (1024 * 1024 * 1024))
    end
end

---@param duedate string|nil Due date in YYYY-MM-DD format
---@return string Formatted due date
function M.format_duedate(duedate)
    if not duedate or duedate == "" then
        return "No due date"
    end

    local year, month, day = duedate:match("(%d+)-(%d+)-(%d+)")
    if not year then
        return duedate
    end

    local months = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }
    local month_name = months[tonumber(month)] or month

    return string.format("%s %d, %s", month_name, tonumber(day), year)
end

---@param duedate string|nil Due date in YYYY-MM-DD format
---@return string Relative due date (e.g., "in 3 days", "overdue by 2 days")
function M.format_duedate_relative(duedate)
    if not duedate or duedate == "" then
        return ""
    end

    local year, month, day = duedate:match("(%d+)-(%d+)-(%d+)")
    if not year then
        return ""
    end

    local due_ts = os.time({
        year = tonumber(year),
        month = tonumber(month),
        day = tonumber(day),
        hour = 23,
        min = 59,
        sec = 59,
    })

    local now = os.time()
    local diff = due_ts - now
    local days = math.floor(diff / 86400)

    if days < -1 then
        return "overdue by " .. math.abs(days) .. " days"
    elseif days == -1 then
        return "overdue by 1 day"
    elseif days == 0 then
        return "due today"
    elseif days == 1 then
        return "due tomorrow"
    elseif days <= 7 then
        return "in " .. days .. " days"
    elseif days <= 14 then
        return "in " .. math.floor(days / 7) .. " week" .. (days >= 14 and "s" or "")
    else
        return "in " .. math.floor(days / 7) .. " weeks"
    end
end

---@param duedate string|nil Due date in YYYY-MM-DD format
---@return string "overdue" | "today" | "soon" | "future" | "none"
function M.get_duedate_status(duedate)
    if not duedate or duedate == "" then
        return "none"
    end

    local year, month, day = duedate:match("(%d+)-(%d+)-(%d+)")
    if not year then
        return "none"
    end

    local due_ts = os.time({
        year = tonumber(year),
        month = tonumber(month),
        day = tonumber(day),
        hour = 23,
        min = 59,
        sec = 59,
    })

    local now = os.time()
    local diff = due_ts - now
    local days = math.floor(diff / 86400)

    if days < 0 then
        return "overdue"
    elseif days == 0 then
        return "today"
    elseif days <= 3 then
        return "soon"
    else
        return "future"
    end
end

return M
