local M = {}

local config = require("jira-interface.config")

---@class JiraAttachment
---@field id string Attachment ID
---@field filename string File name
---@field size number File size in bytes
---@field mimeType string MIME type
---@field url string Download URL
---@field created string Created timestamp

---@class JiraIssue
---@field key string Issue key (e.g., "PROJ-123")
---@field id string Issue ID
---@field summary string Issue summary/title
---@field description string|nil Issue description
---@field acceptance_criteria string|nil Acceptance criteria (custom field)
---@field status string Current status
---@field type string Issue type
---@field level number Hierarchy level (1-4)
---@field project string Project key
---@field assignee string|nil Assignee display name
---@field parent string|nil Parent issue key
---@field children string[] Child issue keys
---@field attachments JiraAttachment[] Attachments
---@field comment_count number Number of comments
---@field web_url string URL to view issue in browser
---@field duedate string|nil Due date (YYYY-MM-DD)
---@field created string Created timestamp
---@field updated string Updated timestamp

---@class JiraTransition
---@field id string Transition ID
---@field name string Transition name
---@field to string Target status

-- Status display configuration
M.status_icons = {
    ["To Do"] = { icon = "", hl = "Comment" },
    ["In Progress"] = { icon = "", hl = "Function" },
    ["In Review"] = { icon = "", hl = "Type" },
    ["Blocked"] = { icon = "", hl = "Error" },
    ["Done"] = { icon = "", hl = "String" },
}

-- Valid status transitions
M.transitions = {
    ["To Do"] = { "In Progress" },
    ["In Progress"] = { "In Review", "Blocked" },
    ["In Review"] = { "Done", "In Progress", "Blocked" },
    ["Blocked"] = { "In Progress" },
    ["Done"] = {},
}

---@param type_name string
---@return number
function M.get_level(type_name)
    local opts = config.options
    for _, t in ipairs(opts.types.lvl1 or {}) do
        if t:lower() == type_name:lower() then
            return 1
        end
    end
    for _, t in ipairs(opts.types.lvl2 or {}) do
        if t:lower() == type_name:lower() then
            return 2
        end
    end
    for _, t in ipairs(opts.types.lvl3 or {}) do
        if t:lower() == type_name:lower() then
            return 3
        end
    end
    for _, t in ipairs(opts.types.lvl4 or {}) do
        if t:lower() == type_name:lower() then
            return 4
        end
    end
    return 0
end

---@param level number
---@return string[]
function M.get_types_for_level(level)
    local opts = config.options
    if level == 1 then
        return opts.types.lvl1 or {}
    elseif level == 2 then
        return opts.types.lvl2 or {}
    elseif level == 3 then
        return opts.types.lvl3 or {}
    elseif level == 4 then
        return opts.types.lvl4 or {}
    end
    return {}
end

---@param status string
---@return string[], string[]
function M.get_valid_transitions(status)
    return M.transitions[status] or {}
end

---@param status string
---@return { icon: string, hl: string }
function M.get_status_display(status)
    return M.status_icons[status] or { icon = "?", hl = "Normal" }
end

-- Helper to safely check if value is a valid table (not nil/vim.NIL)
---@param value any
---@return boolean
local function is_table(value)
    return type(value) == "table"
end

---@param raw table Raw Jira API response
---@return JiraIssue
function M.parse_issue(raw)
    local fields = raw.fields or {}
    local issue_type = is_table(fields.issuetype) and fields.issuetype.name or "Unknown"
    local key = raw.key or ""

    -- Extract comment count
    local comment_count = 0
    if is_table(fields.comment) then
        comment_count = fields.comment.total or 0
    end

    -- Build web URL
    local base_url = config.options.auth.url or ""
    if not base_url:match("^https?://") then
        base_url = "https://" .. base_url
    end
    base_url = base_url:gsub("/$", "")
    local web_url = base_url .. "/browse/" .. key

    return {
        key = key,
        id = raw.id or "",
        summary = fields.summary or "",
        description = M.parse_description(fields.description),
        acceptance_criteria = M.parse_acceptance_criteria(fields),
        status = is_table(fields.status) and fields.status.name or "Unknown",
        type = issue_type,
        level = M.get_level(issue_type),
        project = is_table(fields.project) and fields.project.key or "",
        assignee = is_table(fields.assignee) and fields.assignee.displayName or nil,
        parent = is_table(fields.parent) and fields.parent.key or nil,
        children = {},
        attachments = M.parse_attachments(fields.attachment),
        comment_count = comment_count,
        web_url = web_url,
        duedate = type(fields.duedate) == "string" and fields.duedate or nil,
        created = fields.created or "",
        updated = fields.updated or "",
    }
end

---@param attachments any
---@return JiraAttachment[]
function M.parse_attachments(attachments)
    local result = {}
    if not is_table(attachments) then
        return result
    end

    for _, att in ipairs(attachments) do
        if is_table(att) then
            table.insert(result, {
                id = att.id or "",
                filename = att.filename or "unknown",
                size = att.size or 0,
                mimeType = att.mimeType or "",
                url = att.content or "",
                created = att.created or "",
            })
        end
    end

    return result
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

---@param description any
---@return string|nil
function M.parse_description(description)
    if type(description) == "string" then
        return description
    end
    -- Handle Atlassian Document Format (ADF)
    if type(description) == "table" and description.content then
        return M.adf_to_text(description)
    end
    return nil
end

---@param adf table Atlassian Document Format
---@return string
function M.adf_to_text(adf)
    local lines = {}

    local function process_node(node)
        if not node then
            return
        end
        if node.type == "text" then
            return node.text or ""
        end
        if node.type == "paragraph" then
            local texts = {}
            for _, child in ipairs(node.content or {}) do
                local text = process_node(child)
                if text then
                    table.insert(texts, text)
                end
            end
            return table.concat(texts, "")
        end
        if node.type == "bulletList" or node.type == "orderedList" then
            local items = {}
            for i, item in ipairs(node.content or {}) do
                local prefix = node.type == "orderedList" and (i .. ". ") or "- "
                for _, child in ipairs(item.content or {}) do
                    local text = process_node(child)
                    if text then
                        table.insert(items, prefix .. text)
                    end
                end
            end
            return table.concat(items, "\n")
        end
        if node.type == "heading" then
            local texts = {}
            for _, child in ipairs(node.content or {}) do
                local text = process_node(child)
                if text then
                    table.insert(texts, text)
                end
            end
            local level = node.attrs and node.attrs.level or 1
            return string.rep("#", level) .. " " .. table.concat(texts, "")
        end
        if node.content then
            local texts = {}
            for _, child in ipairs(node.content) do
                local text = process_node(child)
                if text then
                    table.insert(texts, text)
                end
            end
            return table.concat(texts, "\n")
        end
        return ""
    end

    for _, node in ipairs(adf.content or {}) do
        local text = process_node(node)
        if text and text ~= "" then
            table.insert(lines, text)
        end
    end

    return table.concat(lines, "\n\n")
end

---@param fields table
---@return string|nil
function M.parse_acceptance_criteria(fields)
    -- First try custom field
    local ac_field = config.options.acceptance_criteria_field
    if ac_field and ac_field ~= "" then
        local value = fields[ac_field]
        if value then
            if type(value) == "string" and value ~= "" then
                return value
            elseif type(value) == "table" and value.content then
                return M.adf_to_text(value)
            end
        end
    end

    -- Fallback: look for "Acceptance Criteria" section in description
    local description = fields.description
    if type(description) == "table" and description.content then
        local ac = M.extract_section_from_adf(description, "Acceptance Criteria")
        if ac and ac ~= "" then
            return ac
        end
    end

    return nil
end

---@param adf table ADF document
---@param section_name string Heading text to find (case-insensitive)
---@return string|nil Content after the heading until next heading
function M.extract_section_from_adf(adf, section_name)
    if not adf or not adf.content then
        return nil
    end

    local in_section = false
    local section_content = {}
    local section_lower = section_name:lower()

    for _, node in ipairs(adf.content) do
        if node.type == "heading" then
            -- Check if this heading matches our section
            local heading_text = ""
            if node.content then
                for _, child in ipairs(node.content) do
                    if child.type == "text" and child.text then
                        heading_text = heading_text .. child.text
                    end
                end
            end

            if heading_text:lower():find(section_lower, 1, true) then
                in_section = true
            elseif in_section then
                -- Next heading, stop collecting
                break
            end
        elseif in_section then
            -- Collect content for this section
            local text = M.process_adf_node(node)
            if text and text ~= "" then
                table.insert(section_content, text)
            end
        end
    end

    if #section_content > 0 then
        return table.concat(section_content, "\n\n")
    end

    return nil
end

---@param node table ADF node
---@return string
function M.process_adf_node(node)
    if not node then
        return ""
    end
    if node.type == "text" then
        return node.text or ""
    end
    if node.type == "paragraph" then
        local texts = {}
        for _, child in ipairs(node.content or {}) do
            local text = M.process_adf_node(child)
            if text ~= "" then
                table.insert(texts, text)
            end
        end
        return table.concat(texts, "")
    end
    if node.type == "bulletList" or node.type == "orderedList" then
        local items = {}
        for i, item in ipairs(node.content or {}) do
            local prefix = node.type == "orderedList" and (i .. ". ") or "- "
            for _, child in ipairs(item.content or {}) do
                local text = M.process_adf_node(child)
                if text ~= "" then
                    table.insert(items, prefix .. text)
                end
            end
        end
        return table.concat(items, "\n")
    end
    if node.type == "heading" then
        local texts = {}
        for _, child in ipairs(node.content or {}) do
            local text = M.process_adf_node(child)
            if text ~= "" then
                table.insert(texts, text)
            end
        end
        local level = node.attrs and node.attrs.level or 1
        return string.rep("#", level) .. " " .. table.concat(texts, "")
    end
    if node.content then
        local texts = {}
        for _, child in ipairs(node.content) do
            local text = M.process_adf_node(child)
            if text ~= "" then
                table.insert(texts, text)
            end
        end
        return table.concat(texts, "\n")
    end
    return ""
end

---@param iso_timestamp string ISO 8601 timestamp (e.g., "2024-01-15T10:30:00.000+0000")
---@return string Formatted date/time
function M.format_timestamp(iso_timestamp)
    if not iso_timestamp or iso_timestamp == "" then
        return "N/A"
    end

    -- Parse ISO 8601: 2024-01-15T10:30:00.000+0000 or 2024-01-15T10:30:00.000Z
    local year, month, day, hour, min, sec = iso_timestamp:match("(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")

    if not year then
        return iso_timestamp
    end

    -- Format as "Jan 15, 2024 10:30"
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

    -- Create timestamp
    local ts = os.time({
        year = tonumber(year),
        month = tonumber(month),
        day = tonumber(day),
        hour = tonumber(hour),
        min = tonumber(min),
        sec = tonumber(sec),
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

---@param duedate string|nil Due date in YYYY-MM-DD format
---@return string Formatted due date with status
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

    -- Create timestamp for due date at end of day
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

-- Due date status icons and highlights
M.duedate_display = {
    overdue = { icon = "", hl = "Error" },
    today = { icon = "", hl = "WarningMsg" },
    soon = { icon = "", hl = "Type" },
    future = { icon = "", hl = "Comment" },
    none = { icon = "", hl = "Comment" },
}

return M
