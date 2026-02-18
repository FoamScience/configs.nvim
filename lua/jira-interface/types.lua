local M = {}

local config = require("jira-interface.config")
local atlassian_adf = require("atlassian.adf")

---@class JiraAttachment
---@field id string Attachment ID
---@field filename string File name
---@field size number File size in bytes
---@field mimeType string MIME type
---@field url string Download URL
---@field created string Created timestamp

---@class JiraComment
---@field id string Comment ID
---@field author_name string Author display name
---@field author_account_id string Author account ID
---@field body table ADF table for comment body
---@field created string Created timestamp
---@field updated string Updated timestamp

---@class JiraIssueLink
---@field id string Link ID
---@field link_type string Link type name (e.g., "Blocks")
---@field direction "inward"|"outward" Direction of the relationship
---@field label string Human-readable relationship text (e.g., "is blocked by")
---@field issue_key string Linked issue key
---@field issue_summary string Linked issue summary
---@field issue_status string Linked issue status

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
---@field comments JiraComment[] Comments
---@field comments_total number Total number of comments
---@field links JiraIssueLink[] Issue links
---@field comment_count number Number of comments (backward compat)
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

    local comments, comments_total = M.parse_comments(fields.comment)
    local links = M.parse_issue_links(fields.issuelinks)

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
        description_raw = fields.description, -- raw ADF table or string, for lossless CSF conversion
        acceptance_criteria = M.parse_acceptance_criteria(fields),
        acceptance_criteria_raw = M.parse_acceptance_criteria_raw(fields), -- raw ADF for AC field
        custom_fields_raw = M.parse_custom_fields_raw(fields), -- raw values for all custom_fields
        status = is_table(fields.status) and fields.status.name or "Unknown",
        type = issue_type,
        level = M.get_level(issue_type),
        project = is_table(fields.project) and fields.project.key or "",
        assignee = is_table(fields.assignee) and fields.assignee.displayName or nil,
        parent = is_table(fields.parent) and fields.parent.key or nil,
        children = {},
        attachments = M.parse_attachments(fields.attachment),
        comments = comments,
        comments_total = comments_total,
        comment_count = comments_total,
        links = links,
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

---@param raw table Raw Jira API comment object
---@return JiraComment
function M.parse_comment(raw)
    local author = is_table(raw.author) and raw.author or {}
    return {
        id = raw.id or "",
        author_name = author.displayName or "Unknown",
        author_account_id = author.accountId or "",
        body = is_table(raw.body) and raw.body or {},
        created = raw.created or "",
        updated = raw.updated or "",
    }
end

---@param comment_field any The fields.comment object from Jira API
---@return JiraComment[], number
function M.parse_comments(comment_field)
    local comments = {}
    local total = 0
    if not is_table(comment_field) then
        return comments, total
    end
    total = comment_field.total or 0
    for _, raw in ipairs(comment_field.comments or {}) do
        if is_table(raw) then
            table.insert(comments, M.parse_comment(raw))
        end
    end
    return comments, total
end

---@param raw table Raw issue link from Jira API
---@return JiraIssueLink
function M.parse_issue_link(raw)
    local link_type = is_table(raw.type) and raw.type or {}
    if is_table(raw.inwardIssue) then
        local issue = raw.inwardIssue
        local status = is_table(issue.fields) and is_table(issue.fields.status) and issue.fields.status.name or "Unknown"
        local summary = is_table(issue.fields) and issue.fields.summary or ""
        return {
            id = raw.id or "",
            link_type = link_type.name or "",
            direction = "inward",
            label = link_type.inward or "",
            issue_key = issue.key or "",
            issue_summary = summary,
            issue_status = status,
        }
    else
        local issue = raw.outwardIssue or {}
        local status = is_table(issue.fields) and is_table(issue.fields.status) and issue.fields.status.name or "Unknown"
        local summary = is_table(issue.fields) and issue.fields.summary or ""
        return {
            id = raw.id or "",
            link_type = link_type.name or "",
            direction = "outward",
            label = link_type.outward or "",
            issue_key = issue.key or "",
            issue_summary = summary,
            issue_status = status,
        }
    end
end

---@param issuelinks any The fields.issuelinks array from Jira API
---@return JiraIssueLink[]
function M.parse_issue_links(issuelinks)
    local result = {}
    if not is_table(issuelinks) then
        return result
    end
    for _, raw in ipairs(issuelinks) do
        if is_table(raw) then
            table.insert(result, M.parse_issue_link(raw))
        end
    end
    return result
end

---@param description any
---@return string|nil
function M.parse_description(description)
    if type(description) == "string" then
        return description
    end
    if type(description) == "table" and description.content then
        return atlassian_adf.adf_to_text(description)
    end
    return nil
end

--- Find a custom_fields entry by heading (case-insensitive)
---@param heading_pattern string
---@return string[] candidate field IDs
local function find_custom_field_candidates(heading_pattern)
    local pattern = heading_pattern:lower()
    for heading, field_ref in pairs(config.options.custom_fields or {}) do
        if heading:lower() == pattern then
            return type(field_ref) == "table" and field_ref or { field_ref }
        end
    end
    return {}
end

--- Look up a value across multiple candidate field IDs
---@param fields table Raw Jira fields
---@param candidates string[]
---@return any|nil
local function find_first_value(fields, candidates)
    for _, cid in ipairs(candidates) do
        local value = fields[cid]
        if value and value ~= vim.NIL then
            if type(value) == "table" then
                if value.content or next(value) then return value end
            elseif value ~= "" then
                return value
            end
        end
    end
    return nil
end

---@param fields table
---@return table|string|nil Raw ADF or string for acceptance criteria
function M.parse_acceptance_criteria_raw(fields)
    local candidates = find_custom_field_candidates("acceptance criteria")
    return find_first_value(fields, candidates)
end

---@param fields table
---@return table<string, any> Map of section heading → raw field value
function M.parse_custom_fields_raw(fields)
    local custom = config.options.custom_fields or {}

    local result = {}
    local resolved_ids = {}
    for heading, field_ref in pairs(custom) do
        -- field_ref is either a string (single ID) or a table (array of candidate IDs)
        local candidates = type(field_ref) == "table" and field_ref or { field_ref }
        local found_id = nil
        local found_value = find_first_value(fields, candidates)
        if found_value then
            -- determine which candidate matched
            for _, cid in ipairs(candidates) do
                local v = fields[cid]
                if v and v ~= vim.NIL then
                    found_id = cid
                    break
                end
            end
        end

        if found_value then
            result[heading] = found_value
            resolved_ids[heading] = found_id
        else
            -- Store first candidate as fallback for writes
            resolved_ids[heading] = candidates[1]
        end
    end
    -- Store which field ID was resolved for each heading (used by edit save)
    result._resolved_ids = resolved_ids
    return result
end

---@param fields table
---@return string|nil
function M.parse_acceptance_criteria(fields)
    local candidates = find_custom_field_candidates("acceptance criteria")
    local value = find_first_value(fields, candidates)
    if value then
        if type(value) == "string" and value ~= "" then
            return value
        elseif type(value) == "table" and value.content then
            return atlassian_adf.adf_to_text(value)
        end
    end

    local description = fields.description
    if type(description) == "table" and description.content then
        local ac = atlassian_adf.extract_section(description, "Acceptance Criteria")
        if ac and ac ~= "" then
            return ac
        end
    end

    return nil
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
