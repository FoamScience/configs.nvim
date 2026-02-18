-- CSF (Confluence Storage Format) core utilities
-- Central module for metadata handling and section extraction
local M = {}

---@class CsfMetadata
---@field type string "confluence" or "jira"
---@field id? string Page ID or "NEW"
---@field version? number Page version
---@field key? string Jira issue key
---@field project? string Jira project key
---@field issue_type? string Jira issue type
---@field space_id? string Confluence space ID
---@field parent_id? string Confluence parent page ID

---@param line string First line of buffer (metadata comment)
---@return CsfMetadata|nil
function M.parse_metadata(line)
    if not line or not line:match("^<!%-%- csf:") then
        return nil
    end

    local meta = {}
    meta.type = line:match("type=(%w+)")
    meta.id = line:match("id=([%w%-]+)")
    meta.version = tonumber(line:match("version=(%d+)"))
    meta.key = line:match("key=([%w%-]+)")
    meta.project = line:match("project=([%w%-]+)")
    meta.issue_type = line:match("issue_type=([%w%-]+)")
    meta.space_id = line:match("space_id=([%w%-]+)")
    meta.parent_id = line:match("parent_id=([%w%-]+)")

    if not meta.type then
        return nil
    end

    return meta
end

---@param meta CsfMetadata
---@return string
function M.generate_metadata(meta)
    local parts = { "<!-- csf:" }

    table.insert(parts, " type=" .. (meta.type or "confluence"))

    if meta.id then
        table.insert(parts, " id=" .. meta.id)
    end
    if meta.version then
        table.insert(parts, " version=" .. meta.version)
    end
    if meta.key then
        table.insert(parts, " key=" .. meta.key)
    end
    if meta.project then
        table.insert(parts, " project=" .. meta.project)
    end
    if meta.issue_type then
        table.insert(parts, " issue_type=" .. meta.issue_type)
    end
    if meta.space_id then
        table.insert(parts, " space_id=" .. meta.space_id)
    end
    if meta.parent_id then
        table.insert(parts, " parent_id=" .. meta.parent_id)
    end

    table.insert(parts, " -->")
    return table.concat(parts)
end

---@param lines string[] Buffer lines
---@return string|nil title, string[] remaining_lines
function M.extract_title(lines)
    local title = nil
    local remaining = {}
    local found_title = false

    for _, line in ipairs(lines) do
        local trimmed = vim.trim(line)
        if not found_title and trimmed:match("^<h1>(.+)</h1>$") then
            title = trimmed:match("^<h1>(.+)</h1>$")
            found_title = true
        elseif not found_title and trimmed:match("^<h1>(.+)</h1>") then
            title = trimmed:match("^<h1>(.+)</h1>")
            found_title = true
        else
            table.insert(remaining, line)
        end
    end

    return title, remaining
end

---@param lines string[] Buffer lines (without metadata line)
---@param section_names string[] Section names to extract (lowercase)
---@return table<string, string> sections keyed by lowercase section name
function M.extract_sections(lines, section_names)
    local result = {}
    local current_section = nil
    local section_lines = {}

    -- Build a lookup set for quick checking
    local section_set = {}
    for _, name in ipairs(section_names) do
        section_set[name:lower()] = true
    end

    local function save_section()
        if current_section and #section_lines > 0 then
            -- Remove leading/trailing empty lines
            while section_lines[1] and section_lines[1]:match("^%s*$") do
                table.remove(section_lines, 1)
            end
            while section_lines[#section_lines] and section_lines[#section_lines]:match("^%s*$") do
                table.remove(section_lines)
            end
            result[current_section] = table.concat(section_lines, "\n")
        end
        section_lines = {}
    end

    for _, line in ipairs(lines) do
        local trimmed = vim.trim(line)
        -- Match <h2>Section Name</h2>
        local section_text = trimmed:match("^<h2>(.+)</h2>$") or trimmed:match("^<h2>(.+)</h2>")
        if section_text then
            save_section()
            local normalized = section_text:lower():gsub("%s+", "_")
            if section_set[normalized] then
                current_section = normalized
            else
                current_section = nil
            end
        elseif trimmed:match("^<hr%s*/>") then
            save_section()
            current_section = nil
        elseif current_section then
            table.insert(section_lines, line)
        end
    end

    save_section()
    return result
end

--- Block-level tags that should start on their own line
local block_tags = {
    h1 = true, h2 = true, h3 = true, h4 = true, h5 = true, h6 = true,
    p = true, ul = true, ol = true, li = true,
    table = true, tr = true, td = true, th = true, thead = true, tbody = true,
    blockquote = true, div = true, pre = true, hr = true, br = true,
}

---@param text string Raw CSF/storage format string
---@return string Formatted with block-level tags on their own lines
function M.format(text)
    if not text or text == "" then return text end

    -- Insert \n before block-level opening tags not already at line start
    local result = text:gsub("([^\n])(<([%w]+)[%s>/])", function(before, tag, name)
        if block_tags[name] then
            return before .. "\n" .. tag
        end
        return before .. tag
    end)

    -- ac: namespace block tags
    -- Note: ac:task-id, ac:task-status, ac:task-body stay inline with <ac:task>
    -- so the whole task renders as one line: ☐ task text
    for _, pat in ipairs({
        "ac:structured%-macro",
        "ac:rich%-text%-body",
        "ac:plain%-text%-body",
        "ac:task%-list",
        "ac:task>",
    }) do
        result = result:gsub("([^\n])(<" .. pat .. ")", "%1\n%2")
    end

    -- Keep container tags and their first child <p> on the same line.
    -- Without this, <li><p>text</p></li> splits the bullet from its content.
    local containers = {
        { open = "li", close = "li" },
        { open = "td", close = "td" },
        { open = "th", close = "th" },
        { open = "blockquote", close = "blockquote" },
        { open = "ac:task%-body", close = "ac:task%-body" },
    }
    for _, c in ipairs(containers) do
        result = result:gsub("(<" .. c.open .. "[^>]*>)\n(<p[> ])", "%1%2")
        result = result:gsub("(</p>)\n(</" .. c.close .. ">)", "%1%2")
    end

    return result
end

---@param text string Raw CSF/storage format string
---@return string[] Lines ready for nvim_buf_set_lines
function M.format_lines(text)
    return vim.split(M.format(text), "\n")
end

return M
