-- Internal: Atlassian Document Format (ADF) utilities
-- Used by atlassian.csf.bridge for ADF↔CSF conversion
-- Plain-text ADF helpers used by pickers, notifications, and issue parsing
local M = {}

---@param text string Plain text to convert to ADF
---@return table ADF document
function M.text_to_adf(text)
    local content = {}

    local paragraphs = vim.split(text, "\n\n")

    for _, para in ipairs(paragraphs) do
        if para:match("^%s*[-*]") then
            -- Bullet list
            local items = {}
            for line in para:gmatch("[^\n]+") do
                local item_text = line:gsub("^%s*[-*]%s*", "")
                if item_text ~= "" then
                    table.insert(items, {
                        type = "listItem",
                        content = {
                            {
                                type = "paragraph",
                                content = { { type = "text", text = item_text } },
                            },
                        },
                    })
                end
            end
            if #items > 0 then
                table.insert(content, { type = "bulletList", content = items })
            end
        elseif para:match("^%s*%d+%.") then
            -- Ordered list
            local items = {}
            for line in para:gmatch("[^\n]+") do
                local item_text = line:gsub("^%s*%d+%.%s*", "")
                if item_text ~= "" then
                    table.insert(items, {
                        type = "listItem",
                        content = {
                            {
                                type = "paragraph",
                                content = { { type = "text", text = item_text } },
                            },
                        },
                    })
                end
            end
            if #items > 0 then
                table.insert(content, { type = "orderedList", content = items })
            end
        elseif para:match("^#+%s") then
            -- Heading
            local level, heading_text = para:match("^(#+)%s+(.+)")
            if heading_text then
                table.insert(content, {
                    type = "heading",
                    attrs = { level = math.min(#level, 6) },
                    content = { { type = "text", text = heading_text } },
                })
            end
        elseif vim.trim(para) ~= "" then
            -- Regular paragraph
            table.insert(content, {
                type = "paragraph",
                content = { { type = "text", text = para:gsub("\n", " ") } },
            })
        end
    end

    return {
        type = "doc",
        version = 1,
        content = content,
    }
end

---@param adf table Atlassian Document Format
---@return string Plain text
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
        if node.type == "codeBlock" then
            local texts = {}
            for _, child in ipairs(node.content or {}) do
                local text = process_node(child)
                if text then
                    table.insert(texts, text)
                end
            end
            local lang = node.attrs and node.attrs.language or ""
            return "```" .. lang .. "\n" .. table.concat(texts, "") .. "\n```"
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

---@param node table ADF node
---@return string
function M.process_node(node)
    if not node then
        return ""
    end
    if node.type == "text" then
        return node.text or ""
    end
    if node.type == "paragraph" then
        local texts = {}
        for _, child in ipairs(node.content or {}) do
            local text = M.process_node(child)
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
                local text = M.process_node(child)
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
            local text = M.process_node(child)
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
            local text = M.process_node(child)
            if text ~= "" then
                table.insert(texts, text)
            end
        end
        return table.concat(texts, "\n")
    end
    return ""
end

---@param adf table ADF document
---@param section_name string Heading text to find (case-insensitive)
---@return string|nil Content after the heading until next heading
function M.extract_section(adf, section_name)
    if not adf or not adf.content then
        return nil
    end

    local in_section = false
    local section_content = {}
    local section_lower = section_name:lower()

    for _, node in ipairs(adf.content) do
        if node.type == "heading" then
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
                break
            end
        elseif in_section then
            local text = M.process_node(node)
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

return M
