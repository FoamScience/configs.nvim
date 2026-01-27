local M = {}

local atlassian_format = require("atlassian.format")

---@class ConfluenceSpace
---@field id string Space ID
---@field key string Space key
---@field name string Space name
---@field type string Space type (global, personal)
---@field status string Space status
---@field description string|nil Space description
---@field homepage_id string|nil Homepage ID
---@field web_url string Web URL

---@class ConfluencePage
---@field id string Page ID
---@field title string Page title
---@field space_id string|nil Space ID
---@field space_key string|nil Space key
---@field parent_id string|nil Parent page ID
---@field status string Page status
---@field version number Version number
---@field body string|nil Page body (storage format)
---@field created string Created timestamp
---@field updated string Updated timestamp
---@field created_by string|nil Creator display name
---@field updated_by string|nil Last updater display name
---@field web_url string Web URL

-- Helper to check if value is a valid table (not nil/vim.NIL)
local function is_table(value)
    return type(value) == "table"
end

---@param raw table
---@return ConfluenceSpace
function M.parse_space(raw)
    local desc = nil
    if is_table(raw.description) and is_table(raw.description.plain) then
        desc = raw.description.plain.value
    end

    return {
        id = raw.id or "",
        key = raw.key or "",
        name = raw.name or "",
        type = raw.type or "global",
        status = raw.status or "current",
        description = desc,
        homepage_id = raw.homepageId or nil,
        web_url = is_table(raw._links) and raw._links.webui or "",
    }
end

---@param raw table
---@return ConfluencePage
function M.parse_page(raw)
    local body = nil
    if is_table(raw.body) then
        if is_table(raw.body.storage) then
            body = raw.body.storage.value
        elseif is_table(raw.body.atlas_doc_format) then
            body = raw.body.atlas_doc_format.value
        end
    end

    local version_num = 1
    local updated = ""
    local author_id = nil
    if is_table(raw.version) then
        version_num = raw.version.number or 1
        updated = raw.version.createdAt or ""
        author_id = raw.version.authorId
    end

    return {
        id = raw.id or "",
        title = raw.title or "",
        space_id = raw.spaceId or nil,
        space_key = nil,
        parent_id = raw.parentId or nil,
        status = raw.status or "current",
        version = version_num,
        body = body,
        created = raw.createdAt or "",
        updated = updated,
        created_by = author_id,
        updated_by = author_id,
        web_url = is_table(raw._links) and raw._links.webui or "",
    }
end

---@param raw table
---@return ConfluencePage
function M.parse_page_v1(raw)
    local body = nil
    if is_table(raw.body) then
        if is_table(raw.body.storage) then
            body = raw.body.storage.value
        elseif is_table(raw.body.view) then
            body = raw.body.view.value
        end
    end

    local version_num = 1
    local updated = ""
    local updated_by = nil
    if is_table(raw.version) then
        version_num = raw.version.number or 1
        updated = raw.version.when or ""
        if is_table(raw.version.by) then
            updated_by = raw.version.by.displayName
        end
    end

    local created = ""
    local created_by = nil
    if is_table(raw.history) then
        created = raw.history.createdDate or ""
        if is_table(raw.history.createdBy) then
            created_by = raw.history.createdBy.displayName
        end
    end

    return {
        id = raw.id or "",
        title = raw.title or "",
        space_id = nil,
        space_key = is_table(raw.space) and raw.space.key or nil,
        parent_id = nil,
        status = raw.status or "current",
        version = version_num,
        body = body,
        created = created,
        updated = updated,
        created_by = created_by,
        updated_by = updated_by,
        web_url = is_table(raw._links) and raw._links.webui or "",
    }
end

-- Delegate to shared format module
M.format_timestamp = atlassian_format.format_timestamp
M.format_relative_time = atlassian_format.format_relative_time

---@param html string Storage format HTML
---@return string Markdown
function M.storage_to_markdown(html)
    if not html or html == "" then
        return ""
    end

    local md = html

    -- Handle code blocks first (preserve content)
    md = md:gsub('<ac:structured%-macro[^>]*ac:name="code"[^>]*>(.-)</ac:structured%-macro>', function(content)
        local lang = content:match('ac:parameter[^>]*ac:name="language"[^>]*>([^<]*)</ac:parameter>') or ""
        local code = content:match('<ac:plain%-text%-body><!%[CDATA%[(.-)%]%]></ac:plain%-text%-body>') or ""
        return "\n```" .. lang .. "\n" .. code .. "\n```\n"
    end)

    -- Handle info/note/warning panels
    md = md:gsub('<ac:structured%-macro[^>]*ac:name="(%w+)"[^>]*>(.-)</ac:structured%-macro>',
        function(macro_type, content)
            local body = content:match('<ac:rich%-text%-body>(.-)</ac:rich%-text%-body>') or ""
            if macro_type == "info" or macro_type == "note" or macro_type == "warning" or macro_type == "tip" then
                return "\n> **" .. macro_type:upper() .. ":** " .. body .. "\n"
            end
            return body
        end)

    -- User mentions: <ac:link><ri:user ri:account-id="..."/><ac:link-body>Name</ac:link-body></ac:link>
    md = md:gsub(
    '<ac:link>%s*<ri:user[^>]*ri:account%-id="([^"]*)"[^/]*/>[^<]*<ac:link%-body>([^<]*)</ac:link%-body>%s*</ac:link>',
        '@[%2](confluence-user:%1)')
    -- User mentions without link body
    md = md:gsub('<ac:link>%s*<ri:user[^>]*ri:account%-id="([^"]*)"[^/]*/>[^<]*</ac:link>', '@[user](confluence-user:%1)')
    -- Simpler mention format
    md = md:gsub('<ri:user[^>]*ri:account%-id="([^"]*)"[^/]*/>', '@[user](confluence-user:%1)')

    -- Headers
    md = md:gsub("<h1[^>]*>(.-)</h1>", "# %1\n")
    md = md:gsub("<h2[^>]*>(.-)</h2>", "## %1\n")
    md = md:gsub("<h3[^>]*>(.-)</h3>", "### %1\n")
    md = md:gsub("<h4[^>]*>(.-)</h4>", "#### %1\n")
    md = md:gsub("<h5[^>]*>(.-)</h5>", "##### %1\n")
    md = md:gsub("<h6[^>]*>(.-)</h6>", "###### %1\n")

    -- Paragraphs
    md = md:gsub("<p[^>]*>(.-)</p>", "%1\n\n")

    -- Line breaks
    md = md:gsub("<br%s*/?>", "\n")

    -- Bold/Strong
    md = md:gsub("<strong>(.-)</strong>", "**%1**")
    md = md:gsub("<b>(.-)</b>", "**%1**")

    -- Italic/Emphasis
    md = md:gsub("<em>(.-)</em>", "*%1*")
    md = md:gsub("<i>(.-)</i>", "*%1*")

    -- Underline (no markdown equivalent, use emphasis)
    md = md:gsub("<u>(.-)</u>", "_%1_")

    -- Strikethrough
    md = md:gsub("<s>(.-)</s>", "~~%1~~")
    md = md:gsub("<del>(.-)</del>", "~~%1~~")

    -- Links
    md = md:gsub('<a[^>]*href="([^"]*)"[^>]*>(.-)</a>', "[%2](%1)")

    -- Confluence internal links
    md = md:gsub('<ac:link[^>]*><ri:page[^>]*ri:content%-title="([^"]*)"[^/]*/></ac:link>', "[[%1]]")
    md = md:gsub(
    '<ac:link[^>]*><ri:page[^>]*ri:content%-title="([^"]*)"[^>]*/><ac:plain%-text%-link%-body><!%[CDATA%[([^%]]*)%]%]></ac:plain%-text%-link%-body></ac:link>',
        "[%2]([[%1]])")

    -- Inline code
    md = md:gsub("<code>(.-)</code>", "`%1`")

    -- Lists
    md = md:gsub("<ul[^>]*>", "\n")
    md = md:gsub("</ul>", "\n")
    md = md:gsub("<ol[^>]*>", "\n")
    md = md:gsub("</ol>", "\n")
    md = md:gsub("<li[^>]*>(.-)</li>", "- %1\n")

    -- Task lists (Confluence checkboxes)
    md = md:gsub('<ac:task%-status>complete</ac:task%-status>', "[x]")
    md = md:gsub('<ac:task%-status>incomplete</ac:task%-status>', "[ ]")
    md = md:gsub('<ac:task[^>]*>(.-)</ac:task>', "- %1\n")

    -- Blockquotes
    md = md:gsub("<blockquote[^>]*>(.-)</blockquote>", "> %1\n")

    -- Horizontal rules
    md = md:gsub("<hr[^>]*>", "\n---\n")

    -- Tables (basic conversion)
    md = md:gsub("<table[^>]*>", "\n")
    md = md:gsub("</table>", "\n")
    md = md:gsub("<tbody[^>]*>", "")
    md = md:gsub("</tbody>", "")
    md = md:gsub("<thead[^>]*>", "")
    md = md:gsub("</thead>", "")
    md = md:gsub("<tr[^>]*>", "|")
    md = md:gsub("</tr>", "\n")
    md = md:gsub("<th[^>]*>(.-)</th>", " %1 |")
    md = md:gsub("<td[^>]*>(.-)</td>", " %1 |")

    -- Clean up remaining HTML tags
    md = md:gsub("<[^>]+>", "")

    -- Clean up HTML entities
    md = md:gsub("&nbsp;", " ")
    md = md:gsub("&amp;", "&")
    md = md:gsub("&lt;", "<")
    md = md:gsub("&gt;", ">")
    md = md:gsub("&quot;", '"')
    md = md:gsub("&#(%d+);", function(n)
        return string.char(tonumber(n))
    end)

    -- Clean up excessive whitespace
    md = md:gsub("\n\n\n+", "\n\n")
    md = md:gsub("^%s+", "")
    md = md:gsub("%s+$", "")

    return md
end

---@param markdown string
---@return string Storage format HTML
function M.markdown_to_storage(markdown)
    if not markdown or markdown == "" then
        return ""
    end

    local html = markdown
    local lines = vim.split(html, "\n")
    local result = {}
    local in_code_block = false
    local code_lang = ""
    local code_lines = {}
    local in_list = false
    local list_type = nil

    for _, line in ipairs(lines) do
        -- Code blocks
        if line:match("^```") then
            if in_code_block then
                local code = table.concat(code_lines, "\n")
                table.insert(result, string.format(
                    '<ac:structured-macro ac:name="code"><ac:parameter ac:name="language">%s</ac:parameter><ac:plain-text-body><![CDATA[%s]]></ac:plain-text-body></ac:structured-macro>',
                    code_lang, code
                ))
                in_code_block = false
                code_lines = {}
            else
                in_code_block = true
                code_lang = line:match("^```(%w*)") or ""
            end
        elseif in_code_block then
            table.insert(code_lines, line)
            -- Headers
        elseif line:match("^######%s") then
            table.insert(result, "<h6>" .. line:gsub("^######%s+", "") .. "</h6>")
        elseif line:match("^#####%s") then
            table.insert(result, "<h5>" .. line:gsub("^#####%s+", "") .. "</h5>")
        elseif line:match("^####%s") then
            table.insert(result, "<h4>" .. line:gsub("^####%s+", "") .. "</h4>")
        elseif line:match("^###%s") then
            table.insert(result, "<h3>" .. line:gsub("^###%s+", "") .. "</h3>")
        elseif line:match("^##%s") then
            table.insert(result, "<h2>" .. line:gsub("^##%s+", "") .. "</h2>")
        elseif line:match("^#%s") then
            table.insert(result, "<h1>" .. line:gsub("^#%s+", "") .. "</h1>")
            -- Horizontal rule
        elseif line:match("^%-%-%-+$") or line:match("^%*%*%*+$") then
            if in_list then
                table.insert(result, list_type == "ul" and "</ul>" or "</ol>")
                in_list = false
            end
            table.insert(result, "<hr />")
            -- Lists
        elseif line:match("^%s*[%-*]%s+%[[ x]%]") then
            local checked = line:match("%[x%]") and "complete" or "incomplete"
            local text = line:gsub("^%s*[%-*]%s+%[[ x]%]%s*", "")
            table.insert(result, string.format(
                '<ac:task><ac:task-status>%s</ac:task-status><ac:task-body>%s</ac:task-body></ac:task>',
                checked, M.inline_markdown_to_html(text)
            ))
        elseif line:match("^%s*[%-*]%s") then
            if not in_list or list_type ~= "ul" then
                if in_list then
                    table.insert(result, list_type == "ul" and "</ul>" or "</ol>")
                end
                table.insert(result, "<ul>")
                in_list = true
                list_type = "ul"
            end
            local text = line:gsub("^%s*[%-*]%s+", "")
            table.insert(result, "<li>" .. M.inline_markdown_to_html(text) .. "</li>")
        elseif line:match("^%s*%d+%.%s") then
            if not in_list or list_type ~= "ol" then
                if in_list then
                    table.insert(result, list_type == "ul" and "</ul>" or "</ol>")
                end
                table.insert(result, "<ol>")
                in_list = true
                list_type = "ol"
            end
            local text = line:gsub("^%s*%d+%.%s+", "")
            table.insert(result, "<li>" .. M.inline_markdown_to_html(text) .. "</li>")
            -- Blockquotes
        elseif line:match("^>%s") then
            if in_list then
                table.insert(result, list_type == "ul" and "</ul>" or "</ol>")
                in_list = false
            end
            local text = line:gsub("^>%s*", "")
            table.insert(result, "<blockquote><p>" .. M.inline_markdown_to_html(text) .. "</p></blockquote>")
            -- Empty line
        elseif line:match("^%s*$") then
            if in_list then
                table.insert(result, list_type == "ul" and "</ul>" or "</ol>")
                in_list = false
            end
            -- Regular paragraph
        else
            if in_list then
                table.insert(result, list_type == "ul" and "</ul>" or "</ol>")
                in_list = false
            end
            if vim.trim(line) ~= "" then
                table.insert(result, "<p>" .. M.inline_markdown_to_html(line) .. "</p>")
            end
        end
    end

    if in_list then
        table.insert(result, list_type == "ul" and "</ul>" or "</ol>")
    end

    return table.concat(result, "")
end

---@param text string
---@return string
function M.inline_markdown_to_html(text)
    -- Escape HTML entities first
    text = text:gsub("&", "&amp;")
    text = text:gsub("<", "&lt;")
    text = text:gsub(">", "&gt;")

    -- Inline code (do first to avoid other transformations inside)
    text = text:gsub("`([^`]+)`", "<code>%1</code>")

    -- Bold (** or __)
    text = text:gsub("%*%*([^*]+)%*%*", "<strong>%1</strong>")
    text = text:gsub("__([^_]+)__", "<strong>%1</strong>")

    -- Italic (* or _)
    text = text:gsub("%*([^*]+)%*", "<em>%1</em>")
    text = text:gsub("_([^_]+)_", "<em>%1</em>")

    -- Strikethrough
    text = text:gsub("~~([^~]+)~~", "<s>%1</s>")

    -- User mentions @[Name](confluence-user:account-id) -> Confluence format
    text = text:gsub("@%[([^%]]+)%]%(confluence%-user:([^%)]+)%)",
        '<ac:link><ri:user ri:account-id="%2"/><ac:link-body>%1</ac:link-body></ac:link>')

    -- Links [text](url) - but not confluence-user: links
    text = text:gsub("%[([^%]]+)%]%(([^%)]+)%)", function(link_text, url)
        -- Skip if it was already processed as a mention (starts with ac:link)
        if url:match("^confluence%-user:") then
            return "@[" .. link_text .. "](confluence-user:" .. url:gsub("^confluence%-user:", "") .. ")"
        end
        return '<a href="' .. url .. '">' .. link_text .. '</a>'
    end)

    return text
end

return M
