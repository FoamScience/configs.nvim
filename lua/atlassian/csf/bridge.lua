-- ADF ↔ CSF bidirectional conversion bridge
-- Converts between Jira's Atlassian Document Format and Confluence Storage Format
local M = {}

-- =============================================================================
-- ADF → CSF
-- =============================================================================

---@param marks table[]|nil ADF text marks
---@param text string Inner text
---@return string CSF-wrapped text
local function apply_marks(marks, text)
    if not marks then return text end
    -- Apply marks inside-out
    for i = #marks, 1, -1 do
        local mark = marks[i]
        if mark.type == "strong" then
            text = "<strong>" .. text .. "</strong>"
        elseif mark.type == "em" then
            text = "<em>" .. text .. "</em>"
        elseif mark.type == "code" then
            text = "<code>" .. text .. "</code>"
        elseif mark.type == "strike" then
            text = "<s>" .. text .. "</s>"
        elseif mark.type == "underline" then
            text = "<u>" .. text .. "</u>"
        elseif mark.type == "link" then
            local href = mark.attrs and mark.attrs.href or ""
            text = '<a href="' .. href .. '">' .. text .. '</a>'
        elseif mark.type == "subsup" then
            local sub_type = mark.attrs and mark.attrs.type or "sub"
            text = "<" .. sub_type .. ">" .. text .. "</" .. sub_type .. ">"
        end
    end
    return text
end

---@param node table ADF node
---@return string CSF string
local function adf_node_to_csf(node)
    if not node then return "" end

    local t = node.type

    if t == "text" then
        local text = node.text or ""
        return apply_marks(node.marks, text)

    elseif t == "hardBreak" then
        return "<br />"

    elseif t == "paragraph" then
        local inner = {}
        for _, child in ipairs(node.content or {}) do
            table.insert(inner, adf_node_to_csf(child))
        end
        return "<p>" .. table.concat(inner) .. "</p>"

    elseif t == "heading" then
        local level = node.attrs and node.attrs.level or 1
        local inner = {}
        for _, child in ipairs(node.content or {}) do
            table.insert(inner, adf_node_to_csf(child))
        end
        return "<h" .. level .. ">" .. table.concat(inner) .. "</h" .. level .. ">"

    elseif t == "bulletList" then
        local items = {}
        for _, child in ipairs(node.content or {}) do
            table.insert(items, adf_node_to_csf(child))
        end
        return "<ul>" .. table.concat(items) .. "</ul>"

    elseif t == "orderedList" then
        local items = {}
        for _, child in ipairs(node.content or {}) do
            table.insert(items, adf_node_to_csf(child))
        end
        return "<ol>" .. table.concat(items) .. "</ol>"

    elseif t == "listItem" then
        local inner = {}
        for _, child in ipairs(node.content or {}) do
            table.insert(inner, adf_node_to_csf(child))
        end
        return "<li>" .. table.concat(inner) .. "</li>"

    elseif t == "codeBlock" then
        local lang = node.attrs and node.attrs.language or ""
        local inner = {}
        for _, child in ipairs(node.content or {}) do
            table.insert(inner, child.text or "")
        end
        local code = table.concat(inner)
        -- Roundtrip: codeBlock with language "math" → mathblock macro
        if lang == "math" then
            return '<ac:structured-macro ac:name="mathblock">'
                .. '<ac:plain-text-body><![CDATA[' .. code .. ']]></ac:plain-text-body>'
                .. '</ac:structured-macro>'
        end
        return '<ac:structured-macro ac:name="code">'
            .. '<ac:parameter ac:name="language">' .. lang .. '</ac:parameter>'
            .. '<ac:plain-text-body><![CDATA[' .. code .. ']]></ac:plain-text-body>'
            .. '</ac:structured-macro>'

    elseif t == "blockquote" then
        local inner = {}
        for _, child in ipairs(node.content or {}) do
            table.insert(inner, adf_node_to_csf(child))
        end
        return "<blockquote>" .. table.concat(inner) .. "</blockquote>"

    elseif t == "rule" then
        return "<hr />"

    elseif t == "panel" then
        local panel_type = node.attrs and node.attrs.panelType or "info"
        local inner = {}
        for _, child in ipairs(node.content or {}) do
            table.insert(inner, adf_node_to_csf(child))
        end
        return '<ac:structured-macro ac:name="' .. panel_type .. '">'
            .. '<ac:rich-text-body>' .. table.concat(inner) .. '</ac:rich-text-body>'
            .. '</ac:structured-macro>'

    elseif t == "table" then
        local rows = {}
        for _, child in ipairs(node.content or {}) do
            table.insert(rows, adf_node_to_csf(child))
        end
        return "<table><tbody>" .. table.concat(rows) .. "</tbody></table>"

    elseif t == "tableRow" then
        local cells = {}
        for _, child in ipairs(node.content or {}) do
            table.insert(cells, adf_node_to_csf(child))
        end
        return "<tr>" .. table.concat(cells) .. "</tr>"

    elseif t == "tableHeader" then
        local inner = {}
        for _, child in ipairs(node.content or {}) do
            table.insert(inner, adf_node_to_csf(child))
        end
        return "<th>" .. table.concat(inner) .. "</th>"

    elseif t == "tableCell" then
        local inner = {}
        for _, child in ipairs(node.content or {}) do
            table.insert(inner, adf_node_to_csf(child))
        end
        return "<td>" .. table.concat(inner) .. "</td>"

    elseif t == "mediaSingle" then
        local inner = {}
        for _, child in ipairs(node.content or {}) do
            table.insert(inner, adf_node_to_csf(child))
        end
        return table.concat(inner)

    elseif t == "media" then
        local media_type = node.attrs and node.attrs.type or "file"
        if media_type == "external" then
            local url = node.attrs and node.attrs.url or ""
            return '<ac:image><ri:url ri:value="' .. url .. '" /></ac:image>'
        else
            local filename = node.attrs and node.attrs.alt or node.attrs and node.attrs.id or ""
            return '<ac:image><ri:attachment ri:filename="' .. filename .. '" /></ac:image>'
        end

    elseif t == "taskList" then
        local items = {}
        for _, child in ipairs(node.content or {}) do
            table.insert(items, adf_node_to_csf(child))
        end
        return "<ac:task-list>" .. table.concat(items) .. "</ac:task-list>"

    elseif t == "taskItem" then
        local state = node.attrs and node.attrs.state or "TODO"
        local status = state == "DONE" and "complete" or "incomplete"
        local inner = {}
        for _, child in ipairs(node.content or {}) do
            table.insert(inner, adf_node_to_csf(child))
        end
        return "<ac:task>"
            .. "<ac:task-status>" .. status .. "</ac:task-status>"
            .. "<ac:task-body>" .. table.concat(inner) .. "</ac:task-body>"
            .. "</ac:task>"

    elseif t == "mention" then
        local account_id = node.attrs and node.attrs.id or ""
        local display = node.attrs and node.attrs.text or ""
        return '<ac:link><ri:user ri:account-id="' .. account_id .. '" />'
            .. '<ac:link-body>' .. display .. '</ac:link-body></ac:link>'

    elseif t == "bodiedExtension" then
        local ext_key = node.attrs and node.attrs.extensionKey or ""
        -- Math macros
        if ext_key == "mathblock" or ext_key:match("math") then
            local inner = {}
            for _, child in ipairs(node.content or {}) do
                for _, sub in ipairs(child.content or {}) do
                    if sub.text then table.insert(inner, sub.text) end
                end
            end
            return '<ac:structured-macro ac:name="' .. ext_key .. '">'
                .. '<ac:plain-text-body><![CDATA[' .. table.concat(inner) .. ']]></ac:plain-text-body>'
                .. '</ac:structured-macro>'
        end
        -- Generic bodied extension
        local inner = {}
        for _, child in ipairs(node.content or {}) do
            table.insert(inner, adf_node_to_csf(child))
        end
        return '<ac:structured-macro ac:name="' .. ext_key .. '">'
            .. '<ac:rich-text-body>' .. table.concat(inner) .. '</ac:rich-text-body>'
            .. '</ac:structured-macro>'

    elseif t == "extension" then
        local ext_key = node.attrs and node.attrs.extensionKey or ""
        -- Inline math
        if ext_key == "mathinline" or ext_key:match("math") then
            local body = ""
            if node.attrs and node.attrs.parameters and node.attrs.parameters.body then
                body = node.attrs.parameters.body
            end
            return '<ac:structured-macro ac:name="' .. ext_key .. '">'
                .. '<ac:parameter ac:name="body">' .. body .. '</ac:parameter>'
                .. '</ac:structured-macro>'
        end
        return '<ac:structured-macro ac:name="' .. ext_key .. '" />'

    elseif t == "doc" then
        local parts = {}
        for _, child in ipairs(node.content or {}) do
            table.insert(parts, adf_node_to_csf(child))
        end
        return table.concat(parts)
    end

    -- Fallback: process children
    if node.content then
        local parts = {}
        for _, child in ipairs(node.content) do
            table.insert(parts, adf_node_to_csf(child))
        end
        return table.concat(parts)
    end

    return ""
end

---@param adf_table table ADF document
---@return string CSF string
function M.adf_to_csf(adf_table)
    if not adf_table then return "" end
    if type(adf_table) == "string" then return adf_table end
    return adf_node_to_csf(adf_table)
end

-- =============================================================================
-- CSF → ADF (lightweight recursive descent XML parser)
-- =============================================================================

---@class CsfParserState
---@field pos number Current position in string
---@field src string Source CSF string

---@param src string
---@return CsfParserState
local function new_parser(src)
    return { pos = 1, src = src }
end

---@param state CsfParserState
---@return boolean
local function at_end(state)
    return state.pos > #state.src
end

---@param state CsfParserState
---@param pattern string
---@return string|nil
local function peek(state, pattern)
    return state.src:match("^" .. pattern, state.pos)
end

---@param state CsfParserState
---@param n number
local function advance(state, n)
    state.pos = state.pos + n
end

---@param state CsfParserState
---@return string text
local function read_text(state)
    local text_start = state.pos
    while not at_end(state) and state.src:sub(state.pos, state.pos) ~= "<" do
        state.pos = state.pos + 1
    end
    return state.src:sub(text_start, state.pos - 1)
end

---@param state CsfParserState
---@return string|nil tag_name, table attrs, boolean self_closing
local function read_open_tag(state)
    local tag_match = state.src:match("^<([%w:%-]+)", state.pos)
    if not tag_match then return nil, {}, false end

    -- Find the end of the tag
    local tag_end = state.src:find("[>/]", state.pos + 1 + #tag_match)
    if not tag_end then return nil, {}, false end

    -- Extract attributes
    local tag_str = state.src:sub(state.pos, state.src:find(">", state.pos) or state.pos)
    local attrs = {}
    for attr_name, attr_val in tag_str:gmatch('([%w:%-]+)="([^"]*)"') do
        attrs[attr_name] = attr_val
    end

    -- Find actual > position
    local close_pos = state.src:find(">", state.pos)
    if not close_pos then return nil, {}, false end

    local self_closing = state.src:sub(close_pos - 1, close_pos) == "/>"
    state.pos = close_pos + 1

    return tag_match, attrs, self_closing
end

---@param state CsfParserState
---@param tag_name string
---@return boolean
local function read_close_tag(state, tag_name)
    local pattern = "</" .. tag_name:gsub("([%-:%.])", "%%%1") .. ">"
    local match_start, match_end = state.src:find(pattern, state.pos)
    if match_start == state.pos then
        state.pos = match_end + 1
        return true
    end
    return false
end

---@param state CsfParserState
---@return string
local function read_cdata(state)
    local cdata_start = state.src:find("<!%[CDATA%[", state.pos)
    if cdata_start ~= state.pos then return "" end
    local content_start = cdata_start + 9  -- length of <![CDATA[
    local cdata_end = state.src:find("%]%]>", content_start)
    if not cdata_end then return "" end
    local content = state.src:sub(content_start, cdata_end - 1)
    state.pos = cdata_end + 3  -- length of ]]>
    return content
end

-- Forward declaration
local parse_children

---@param tag string
---@param attrs table
---@param children table[]
---@return table ADF node
local function csf_element_to_adf(tag, attrs, children)
    -- Headings
    local heading_level = tag:match("^h(%d)$")
    if heading_level then
        return {
            type = "heading",
            attrs = { level = tonumber(heading_level) },
            content = children,
        }
    end

    if tag == "p" then
        return { type = "paragraph", content = children }
    end

    if tag == "strong" or tag == "b" then
        -- Inline mark — handled in text processing
        return { _mark = "strong", content = children }
    end

    if tag == "em" or tag == "i" then
        return { _mark = "em", content = children }
    end

    if tag == "code" then
        return { _mark = "code", content = children }
    end

    if tag == "s" or tag == "del" then
        return { _mark = "strike", content = children }
    end

    if tag == "u" then
        return { _mark = "underline", content = children }
    end

    if tag == "a" then
        return { _mark = "link", _href = attrs["href"] or "", content = children }
    end

    if tag == "ul" then
        return { type = "bulletList", content = children }
    end

    if tag == "ol" then
        return { type = "orderedList", content = children }
    end

    if tag == "li" then
        return { type = "listItem", content = children }
    end

    if tag == "blockquote" then
        return { type = "blockquote", content = children }
    end

    if tag == "hr" then
        return { type = "rule" }
    end

    if tag == "br" then
        return { type = "hardBreak" }
    end

    if tag == "table" then
        -- Flatten tbody
        local rows = {}
        for _, child in ipairs(children) do
            if child.type == "_tbody" then
                for _, row in ipairs(child.content or {}) do
                    table.insert(rows, row)
                end
            else
                table.insert(rows, child)
            end
        end
        return { type = "table", content = rows }
    end

    if tag == "tbody" or tag == "thead" then
        return { type = "_tbody", content = children }
    end

    if tag == "tr" then
        return { type = "tableRow", content = children }
    end

    if tag == "th" then
        return { type = "tableHeader", content = children }
    end

    if tag == "td" then
        return { type = "tableCell", content = children }
    end

    -- Confluence structured macros
    if tag == "ac:structured-macro" then
        local macro_name = attrs["ac:name"] or ""

        -- Code block
        if macro_name == "code" then
            local lang = ""
            local code = ""
            for _, child in ipairs(children) do
                if child._param_name == "language" then
                    lang = child._param_value or ""
                elseif child._plain_text_body then
                    code = child._plain_text_body
                end
            end
            return {
                type = "codeBlock",
                attrs = { language = lang },
                content = { { type = "text", text = code } },
            }
        end

        -- Panels
        if macro_name == "info" or macro_name == "note" or macro_name == "warning" or macro_name == "tip" then
            local body_content = {}
            for _, child in ipairs(children) do
                if child._rich_text_body then
                    body_content = child._rich_text_body
                end
            end
            return {
                type = "panel",
                attrs = { panelType = macro_name },
                content = body_content,
            }
        end

        -- Math block macros → codeBlock (Jira doesn't support bodiedExtension
        -- for Confluence marketplace extensions like math)
        if macro_name == "mathblock" or macro_name:match("math") or macro_name:match("latex") then
            local body = ""
            for _, child in ipairs(children) do
                if child._plain_text_body then
                    body = child._plain_text_body
                elseif child._param_name == "body" then
                    body = child._param_value or ""
                end
            end
            -- Inline math → inline code mark
            if macro_name == "mathinline" then
                return { _mark = "code", content = { { type = "text", text = body } } }
            end
            -- Block math → code block
            return {
                type = "codeBlock",
                attrs = { language = "math" },
                content = { { type = "text", text = body } },
            }
        end

        -- Generic macro → panel fallback (Jira doesn't support bodiedExtension
        -- for unknown Confluence extensions)
        local body_content = {}
        for _, child in ipairs(children) do
            if child._rich_text_body then
                body_content = child._rich_text_body
            elseif child._plain_text_body then
                table.insert(body_content, {
                    type = "paragraph",
                    content = { { type = "text", text = child._plain_text_body } },
                })
            end
        end
        if #body_content == 0 then
            body_content = { { type = "paragraph", content = {} } }
        end
        return {
            type = "panel",
            attrs = { panelType = "info" },
            content = body_content,
        }
    end

    -- Confluence parameter
    if tag == "ac:parameter" then
        return {
            _param_name = attrs["ac:name"] or "",
            _param_value = children[1] and children[1].text or "",
        }
    end

    -- Confluence plain text body
    if tag == "ac:plain-text-body" then
        local text = ""
        for _, child in ipairs(children) do
            if child._cdata then
                text = text .. child._cdata
            elseif child.text then
                text = text .. child.text
            end
        end
        return { _plain_text_body = text }
    end

    -- Confluence rich text body
    if tag == "ac:rich-text-body" then
        return { _rich_text_body = children }
    end

    -- Confluence task list
    if tag == "ac:task-list" then
        -- Filter out whitespace text nodes; taskList can only contain taskItem
        local items = {}
        for _, child in ipairs(children) do
            if child.type == "taskItem" then
                table.insert(items, child)
            end
        end
        return {
            type = "taskList",
            attrs = { localId = string.format("%08x-%04x-4%03x-%04x-%04x%08x",
                    math.random(0, 0xFFFFFFFF), math.random(0, 0xFFFF),
                    math.random(0, 0x0FFF), math.random(0x8000, 0xBFFF),
                    math.random(0, 0xFFFF), math.random(0, 0xFFFFFFFF)) },
            content = items,
        }
    end

    if tag == "ac:task" then
        local status = "TODO"
        local body_content = {}
        for _, child in ipairs(children) do
            if child._task_status then
                status = child._task_status == "complete" and "DONE" or "TODO"
            elseif child._task_body then
                body_content = child._task_body
            end
        end
        -- ADF taskItem requires block-level content; wrap inline nodes in a paragraph
        -- Also flatten _mark nodes into proper text nodes with marks arrays
        local wrapped = {}
        local inline_acc = {}
        local function flatten_task_marks(nodes)
            local result = {}
            for _, node in ipairs(nodes) do
                if node._mark then
                    local inner = flatten_task_marks(node.content or {})
                    for _, child in ipairs(inner) do
                        local marks = child.marks or {}
                        local mark = { type = node._mark }
                        if node._href then
                            mark.attrs = { href = node._href }
                        end
                        table.insert(marks, mark)
                        child.marks = marks
                        table.insert(result, child)
                    end
                else
                    table.insert(result, node)
                end
            end
            return result
        end
        body_content = flatten_task_marks(body_content)
        local function flush_inline()
            if #inline_acc > 0 then
                table.insert(wrapped, { type = "paragraph", content = inline_acc })
                inline_acc = {}
            end
        end
        local block = {
            paragraph = true, heading = true, codeBlock = true, blockquote = true,
            bulletList = true, orderedList = true, taskList = true,
            panel = true, ["table"] = true, mediaSingle = true, rule = true,
        }
        for _, node in ipairs(body_content) do
            if block[node.type] then
                flush_inline()
                table.insert(wrapped, node)
            else
                table.insert(inline_acc, node)
            end
        end
        flush_inline()
        return {
            type = "taskItem",
            attrs = {
                state = status,
                localId = string.format("%08x-%04x-4%03x-%04x-%04x%08x",
                    math.random(0, 0xFFFFFFFF), math.random(0, 0xFFFF),
                    math.random(0, 0x0FFF), math.random(0x8000, 0xBFFF),
                    math.random(0, 0xFFFF), math.random(0, 0xFFFFFFFF)),
            },
            content = wrapped,
        }
    end

    if tag == "ac:task-status" then
        local text = children[1] and children[1].text or "incomplete"
        return { _task_status = text }
    end

    if tag == "ac:task-body" then
        return { _task_body = children }
    end

    -- User mentions
    if tag == "ac:link" then
        for _, child in ipairs(children) do
            if child._ri_user then
                local display = ""
                for _, sub in ipairs(children) do
                    if sub._link_body then display = sub._link_body end
                end
                return {
                    type = "mention",
                    attrs = { id = child._ri_user, text = display },
                }
            end
        end
        return { type = "paragraph", content = children }
    end

    if tag == "ri:user" then
        return { _ri_user = attrs["ri:account-id"] or "" }
    end

    if tag == "ac:link-body" then
        local text = children[1] and children[1].text or ""
        return { _link_body = text }
    end

    -- Images
    if tag == "ac:image" then
        for _, child in ipairs(children) do
            if child._ri_url then
                return {
                    type = "mediaSingle",
                    content = {
                        {
                            type = "media",
                            attrs = { type = "external", url = child._ri_url },
                        },
                    },
                }
            elseif child._ri_attachment then
                return {
                    type = "mediaSingle",
                    content = {
                        {
                            type = "media",
                            attrs = { type = "file", alt = child._ri_attachment },
                        },
                    },
                }
            end
        end
        return { type = "mediaSingle", content = {} }
    end

    if tag == "ri:url" then
        return { _ri_url = attrs["ri:value"] or "" }
    end

    if tag == "ri:attachment" then
        return { _ri_attachment = attrs["ri:filename"] or "" }
    end

    -- Fallback
    return { type = "paragraph", content = children }
end

-- Block-level ADF types that cannot be inside paragraphs
local block_types = {
    bodiedExtension = true, extension = true, codeBlock = true,
    panel = true, ["table"] = true, taskList = true,
    bulletList = true, orderedList = true, blockquote = true,
    mediaSingle = true, heading = true, rule = true,
}

--- Split a paragraph containing block-level nodes into separate nodes.
--- Block children are promoted to siblings; surrounding inline content
--- stays in separate paragraphs.
---@param para table ADF paragraph node
---@return table[] List of ADF nodes
local function split_paragraph_blocks(para)
    if para.type ~= "paragraph" then return { para } end

    local content = para.content or {}
    local has_block = false
    for _, child in ipairs(content) do
        if block_types[child.type] then
            has_block = true
            break
        end
    end
    if not has_block then return { para } end

    local result = {}
    local inline_acc = {}

    local function flush_inline()
        local non_empty = {}
        for _, n in ipairs(inline_acc) do
            if n.type ~= "text" or vim.trim(n.text or "") ~= "" then
                table.insert(non_empty, n)
            end
        end
        if #non_empty > 0 then
            table.insert(result, { type = "paragraph", content = non_empty })
        end
        inline_acc = {}
    end

    for _, child in ipairs(content) do
        if block_types[child.type] then
            flush_inline()
            table.insert(result, child)
        else
            table.insert(inline_acc, child)
        end
    end
    flush_inline()

    return result
end

---@param nodes table[] Mixed ADF nodes (some with _mark)
---@return table[] Flattened ADF text nodes with marks applied
local function flatten_marks(nodes)
    local result = {}
    for _, node in ipairs(nodes) do
        if node._mark then
            -- Wrap children's marks
            local inner = flatten_marks(node.content or {})
            for _, child in ipairs(inner) do
                local marks = child.marks or {}
                local mark = { type = node._mark }
                if node._href then
                    mark.attrs = { href = node._href }
                end
                table.insert(marks, mark)
                child.marks = marks
                table.insert(result, child)
            end
        elseif node.type == "text" then
            table.insert(result, node)
        else
            table.insert(result, node)
        end
    end
    return result
end

---@param state CsfParserState
---@return table[] ADF nodes
parse_children = function(state)
    local children = {}

    while not at_end(state) do
        -- Check for CDATA
        if peek(state, "<!%[CDATA%[") then
            local cdata = read_cdata(state)
            table.insert(children, { _cdata = cdata, type = "text", text = cdata })
        -- Check for closing tag
        elseif peek(state, "</") then
            break
        -- Check for comment
        elseif peek(state, "<!%-%-") then
            local comment_end = state.src:find("%-%->", state.pos)
            if comment_end then
                state.pos = comment_end + 3
            else
                break
            end
        -- Check for opening tag
        elseif peek(state, "<") then
            local tag, attrs, self_closing = read_open_tag(state)
            if not tag then break end

            if self_closing then
                local node = csf_element_to_adf(tag, attrs, {})
                table.insert(children, node)
            else
                local inner = parse_children(state)
                read_close_tag(state, tag)

                -- Flatten marks in paragraphs and headings
                local node = csf_element_to_adf(tag, attrs, inner)
                if node.type == "paragraph" or (node.type == "heading") then
                    node.content = flatten_marks(node.content or {})
                end
                -- Split paragraphs containing block-level nodes
                if node.type == "paragraph" then
                    for _, split in ipairs(split_paragraph_blocks(node)) do
                        table.insert(children, split)
                    end
                else
                    table.insert(children, node)
                end
            end
        else
            -- Text content
            local text = read_text(state)
            if text ~= "" then
                table.insert(children, { type = "text", text = text })
            end
        end
    end

    return children
end

---@param csf_string string CSF (XML) content
---@return table ADF document
function M.csf_to_adf(csf_string)
    if not csf_string or csf_string == "" then
        return { type = "doc", version = 1, content = {} }
    end

    local state = new_parser(csf_string)
    local children = parse_children(state)

    -- Filter doc-level content: only block nodes are valid in ADF doc
    local doc_content = {}
    for _, child in ipairs(children) do
        if child.type == "text" then
            -- Wrap non-whitespace text in a paragraph; discard whitespace
            if vim.trim(child.text or "") ~= "" then
                table.insert(doc_content, { type = "paragraph", content = { child } })
            end
        elseif child.type and not child.type:match("^_") then
            table.insert(doc_content, child)
        end
    end

    return {
        type = "doc",
        version = 1,
        content = doc_content,
    }
end

-- =============================================================================
-- ADF sanitization for Jira API writes
-- =============================================================================

--- Sanitize an ADF node tree in-place for Jira API submission.
--- - Downgrades taskList → bulletList, taskItem → listItem (strips localId/state attrs)
--- - Removes empty paragraph nodes (content is nil or {})
--- - Filters non-listItem children from bulletList/orderedList (whitespace text nodes)
--- - Recurses into all content arrays
---@param node table ADF node (or document) to sanitize in-place
local function sanitize_node(node)
    if not node or type(node) ~= "table" then return end

    -- Downgrade task nodes
    if node.type == "taskList" then
        node.type = "bulletList"
        node.attrs = nil
    elseif node.type == "taskItem" then
        node.type = "listItem"
        node.attrs = nil
    end

    -- Recurse into children first
    if node.content then
        for _, child in ipairs(node.content) do
            sanitize_node(child)
        end
    end

    -- Filter invalid children from list nodes (whitespace text nodes left by CSF parser)
    if node.type == "bulletList" or node.type == "orderedList" then
        local filtered = {}
        for _, child in ipairs(node.content or {}) do
            if child.type == "listItem" then
                table.insert(filtered, child)
            end
        end
        node.content = filtered
    end

    -- Remove empty paragraphs and empty mediaSingle from parent content arrays
    if node.content then
        local cleaned = {}
        for _, child in ipairs(node.content) do
            local is_empty = (child.type == "paragraph" or child.type == "mediaSingle")
                and (not child.content or #child.content == 0)
            if not is_empty then
                table.insert(cleaned, child)
            end
        end
        node.content = cleaned
    end

    -- Ensure container nodes that require children have at least one
    if (node.type == "panel" or node.type == "blockquote") and (not node.content or #node.content == 0) then
        node.content = { { type = "paragraph", content = { { type = "text", text = " " } } } }
    end
end

--- Sanitize an ADF document for Jira API submission.
--- Cleans the document in-place: downgrades task lists, removes empty paragraphs,
--- filters invalid list children.
---@param adf table ADF document to sanitize in-place
---@return table The same ADF document (for chaining)
function M.sanitize_for_jira(adf)
    if not adf then return adf end
    sanitize_node(adf)
    return adf
end

return M
