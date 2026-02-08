-- CSF input translation: markdown-like keystrokes → CSF tags
-- Attached to FileType csf buffers via autocmd
local M = {}

-- Get math macro names from config (with defaults)
local function get_math_config()
    local conf = { block_macro = "mathblock", inline_macro = "mathinline", inline_param = "body" }
    -- Try Confluence config first, then Jira
    local ok, cc = pcall(require, "confluence-interface.config")
    if ok and cc.options and cc.options.math then
        conf = vim.tbl_extend("force", conf, cc.options.math)
    end
    local ok2, jc = pcall(require, "jira-interface.config")
    if ok2 and jc.options and jc.options.math then
        conf = vim.tbl_extend("force", conf, jc.options.math)
    end
    return conf
end

---@param buf number Buffer handle
function M.setup_buffer(buf)
    local group = vim.api.nvim_create_augroup("csf_input_" .. buf, { clear = true })

    -- Block-level translations: triggered on TextChangedI
    vim.api.nvim_create_autocmd("TextChangedI", {
        group = group,
        buffer = buf,
        callback = function()
            M.check_block_prefix(buf)
        end,
    })

    -- Inline translations: triggered on InsertCharPre for delimiters
    vim.api.nvim_create_autocmd("InsertCharPre", {
        group = group,
        buffer = buf,
        callback = function()
            M.check_inline_delimiter(buf)
        end,
    })

    -- Enter key for list continuation and tag closing
    vim.keymap.set("i", "<CR>", function()
        return M.handle_enter(buf)
    end, { buffer = buf, expr = true, desc = "CSF-aware Enter" })

    -- Section navigation: ]] and [[ to jump between headings
    vim.keymap.set("n", "]]", function()
        M.jump_section(buf, 1)
    end, { buffer = buf, desc = "Next section" })
    vim.keymap.set("n", "[[", function()
        M.jump_section(buf, -1)
    end, { buffer = buf, desc = "Previous section" })
end

---@param buf number
function M.check_block_prefix(buf)
    local cursor = vim.api.nvim_win_get_cursor(0)
    local row = cursor[1]
    local line = vim.api.nvim_buf_get_lines(buf, row - 1, row, false)[1] or ""

    -- Heading: "# " through "###### "
    local hashes, space_after = line:match("^(#+)(%s)$")
    if hashes and space_after and #hashes <= 6 then
        local level = #hashes
        local replacement = "<h" .. level .. "></h" .. level .. ">"
        vim.api.nvim_buf_set_lines(buf, row - 1, row, false, { replacement })
        vim.api.nvim_win_set_cursor(0, { row, 3 + #tostring(level) })
        return
    end

    -- Task: "- [ ] " / "- [x] " / "-[] " / "-[x] "
    local task_char = line:match("^%-%s?%[(.?)%]%s$")
    if task_char ~= nil then
        local status = task_char == "x" and "complete" or "incomplete"
        local task_line = "<ac:task><ac:task-status>" .. status
            .. "</ac:task-status><ac:task-body></ac:task-body></ac:task>"
        local prev = row > 1 and (vim.api.nvim_buf_get_lines(buf, row - 2, row - 1, false)[1] or "") or ""
        if prev:match("<ac:task>") or prev:match("</ac:task%-list>") then
            vim.api.nvim_buf_set_lines(buf, row - 1, row, false, { task_line })
        else
            vim.api.nvim_buf_set_lines(buf, row - 1, row, false, {
                "<ac:task-list>", task_line, "</ac:task-list>",
            })
            row = row + 1
        end
        local body_pos = task_line:find("<ac:task%-body>") + 13
        vim.api.nvim_win_set_cursor(0, { row, body_pos })
        return
    end

    -- Bullet list: "* "
    if line:match("^%*%s$") then
        local li = "<li><p></p></li>"
        local prev = row > 1 and (vim.api.nvim_buf_get_lines(buf, row - 2, row - 1, false)[1] or "") or ""
        if prev:match("<li>") or prev:match("</ul>") then
            -- Extend existing <ul>: if prev line is </ul>, insert before it
            if prev:match("^</ul>$") then
                vim.api.nvim_buf_set_lines(buf, row - 2, row, false, { li, "</ul>" })
            else
                vim.api.nvim_buf_set_lines(buf, row - 1, row, false, { li })
            end
        else
            vim.api.nvim_buf_set_lines(buf, row - 1, row, false, { "<ul>", li, "</ul>" })
            row = row + 1
        end
        vim.api.nvim_win_set_cursor(0, { row, 7 })
        return
    end

    -- Ordered list: "1. "
    if line:match("^%d+%.%s$") then
        local li = "<li><p></p></li>"
        local prev = row > 1 and (vim.api.nvim_buf_get_lines(buf, row - 2, row - 1, false)[1] or "") or ""
        if prev:match("<li>") or prev:match("</ol>") then
            if prev:match("^</ol>$") then
                vim.api.nvim_buf_set_lines(buf, row - 2, row, false, { li, "</ol>" })
            else
                vim.api.nvim_buf_set_lines(buf, row - 1, row, false, { li })
            end
        else
            vim.api.nvim_buf_set_lines(buf, row - 1, row, false, { "<ol>", li, "</ol>" })
            row = row + 1
        end
        vim.api.nvim_win_set_cursor(0, { row, 7 })
        return
    end

    -- Blockquote: "> "
    if line:match("^>%s$") then
        local replacement = "<blockquote><p></p></blockquote>"
        vim.api.nvim_buf_set_lines(buf, row - 1, row, false, { replacement })
        vim.api.nvim_win_set_cursor(0, { row, 15 })
        return
    end

    -- Horizontal rule: "---"
    if line:match("^%-%-%-$") then
        vim.api.nvim_buf_set_lines(buf, row - 1, row, false, { "<hr />" })
        vim.api.nvim_win_set_cursor(0, { row, 6 })
        return
    end

    -- Math block: "$$" at line start
    if line:match("^%$%$$") then
        local math_conf = get_math_config()
        local replacement = '<ac:structured-macro ac:name="' .. math_conf.block_macro .. '">'
            .. '<ac:plain-text-body><![CDATA[]]></ac:plain-text-body>'
            .. '</ac:structured-macro>'
        vim.api.nvim_buf_set_lines(buf, row - 1, row, false, { replacement })
        local cdata_pos = replacement:find("%[CDATA%[") + 6
        vim.api.nvim_win_set_cursor(0, { row, cdata_pos })
        return
    end
end

---@param buf number
function M.check_inline_delimiter(buf)
    local char = vim.v.char
    if char ~= "*" and char ~= "`" and char ~= "~" and char ~= "$" and char ~= ")" then
        return
    end

    local cursor = vim.api.nvim_win_get_cursor(0)
    local row = cursor[1]
    local col = cursor[2]
    local line = vim.api.nvim_buf_get_lines(buf, row - 1, row, false)[1] or ""
    local before = line:sub(1, col)

    -- Link: [text](url) — closing )
    if char == ")" then
        -- Match ![alt](url pattern for image
        local img_open = before:match("^(.-)!%[([^%]]+)%]%(([^%)]+)$")
        if not img_open then
            -- Match [text](url pattern for link
            local link_prefix, link_text, link_url = before:match("^(.-)%[([^%]]+)%]%(([^%)]+)$")
            if link_prefix and link_text and link_url then
                local tag = '<a href="' .. link_url .. '">' .. link_text .. '</a>'
                local new_line = link_prefix .. tag .. line:sub(col + 1)
                vim.v.char = ""
                vim.schedule(function()
                    vim.api.nvim_buf_set_lines(buf, row - 1, row, false, { new_line })
                    vim.api.nvim_win_set_cursor(0, { row, #(link_prefix .. tag) })
                end)
                return
            end
        else
            -- Image: ![alt](url)
            local img_prefix, img_alt, img_url = before:match("^(.-)!%[([^%]]*)%]%(([^%)]+)$")
            if img_prefix and img_url then
                local tag = '<ac:image><ri:url ri:value="' .. img_url .. '" /></ac:image>'
                local new_line = img_prefix .. tag .. line:sub(col + 1)
                vim.v.char = ""
                vim.schedule(function()
                    vim.api.nvim_buf_set_lines(buf, row - 1, row, false, { new_line })
                    vim.api.nvim_win_set_cursor(0, { row, #(img_prefix .. tag) })
                end)
                return
            end
        end
    end

    -- Inline math: closing $
    if char == "$" then
        local open_pos = before:find("%$([^%$]+)$")
        if open_pos then
            local content = before:sub(open_pos + 1)
            local math_conf = get_math_config()
            local replacement = '<ac:structured-macro ac:name="' .. math_conf.inline_macro .. '">'
                .. '<ac:parameter ac:name="' .. math_conf.inline_param .. '">'
                .. content .. '</ac:parameter></ac:structured-macro>'
            local new_line = before:sub(1, open_pos - 1) .. replacement .. line:sub(col + 1)
            vim.v.char = ""
            vim.schedule(function()
                vim.api.nvim_buf_set_lines(buf, row - 1, row, false, { new_line })
                vim.api.nvim_win_set_cursor(0, { row, #(before:sub(1, open_pos - 1) .. replacement) })
            end)
            return
        end
    end

    -- Bold: closing ** (char is *, previous char is *)
    if char == "*" and before:sub(-1) == "*" then
        local text_before = before:sub(1, -2)
        local open_pos = text_before:find("%*%*([^*]+)$")
        if open_pos then
            local content = text_before:sub(open_pos + 2)
            local new_line = text_before:sub(1, open_pos - 1) .. "<strong>" .. content .. "</strong>" .. line:sub(col + 1)
            vim.v.char = ""
            vim.schedule(function()
                vim.api.nvim_buf_set_lines(buf, row - 1, row, false, { new_line })
                local end_pos = #(text_before:sub(1, open_pos - 1) .. "<strong>" .. content .. "</strong>")
                vim.api.nvim_win_set_cursor(0, { row, end_pos })
            end)
            return
        end
    end

    -- Italic: closing * (but not **)
    if char == "*" and before:sub(-1) ~= "*" then
        local open_pos = before:find("%*([^*]+)$")
        if open_pos and not before:sub(open_pos - 1, open_pos - 1):match("%*") then
            local content = before:sub(open_pos + 1)
            local new_line = before:sub(1, open_pos - 1) .. "<em>" .. content .. "</em>" .. line:sub(col + 1)
            vim.v.char = ""
            vim.schedule(function()
                vim.api.nvim_buf_set_lines(buf, row - 1, row, false, { new_line })
                local end_pos = #(before:sub(1, open_pos - 1) .. "<em>" .. content .. "</em>")
                vim.api.nvim_win_set_cursor(0, { row, end_pos })
            end)
            return
        end
    end

    -- Inline code: closing `
    if char == "`" then
        local open_pos = before:find("`([^`]+)$")
        if open_pos then
            local content = before:sub(open_pos + 1)
            local new_line = before:sub(1, open_pos - 1) .. "<code>" .. content .. "</code>" .. line:sub(col + 1)
            vim.v.char = ""
            vim.schedule(function()
                vim.api.nvim_buf_set_lines(buf, row - 1, row, false, { new_line })
                local end_pos = #(before:sub(1, open_pos - 1) .. "<code>" .. content .. "</code>")
                vim.api.nvim_win_set_cursor(0, { row, end_pos })
            end)
            return
        end
    end

    -- Strikethrough: closing ~~ (char is ~, previous char is ~)
    if char == "~" and before:sub(-1) == "~" then
        local text_before = before:sub(1, -2)
        local open_pos = text_before:find("~~([^~]+)$")
        if open_pos then
            local content = text_before:sub(open_pos + 2)
            local new_line = text_before:sub(1, open_pos - 1) .. "<s>" .. content .. "</s>" .. line:sub(col + 1)
            vim.v.char = ""
            vim.schedule(function()
                vim.api.nvim_buf_set_lines(buf, row - 1, row, false, { new_line })
                local end_pos = #(text_before:sub(1, open_pos - 1) .. "<s>" .. content .. "</s>")
                vim.api.nvim_win_set_cursor(0, { row, end_pos })
            end)
            return
        end
    end
end

---@param buf number
---@return string Key sequence
function M.handle_enter(buf)
    local cursor = vim.api.nvim_win_get_cursor(0)
    local row = cursor[1]
    local col = cursor[2]
    local line = vim.api.nvim_buf_get_lines(buf, row - 1, row, false)[1] or ""

    -- ── Empty list item: remove it (exit list) ──
    if line:match("^<li><p></p></li>$") then
        vim.schedule(function()
            vim.api.nvim_buf_set_lines(buf, row - 1, row, false, { "" })
            vim.api.nvim_win_set_cursor(0, { row, 0 })
        end)
        return ""
    end

    -- ── Empty task: remove it (exit task list) ──
    if line:match("<ac:task><ac:task%-status>%w+</ac:task%-status><ac:task%-body></ac:task%-body></ac:task>") then
        vim.schedule(function()
            vim.api.nvim_buf_set_lines(buf, row - 1, row, false, { "" })
            vim.api.nvim_win_set_cursor(0, { row, 0 })
        end)
        return ""
    end

    -- ── List continuation (ul/ol): only when cursor is past content ──
    if line:match("<li>") then
        local close_pos = line:find("</p></li>")
        if close_pos and col >= close_pos - 1 then
            vim.schedule(function()
                -- If </ul> or </ol> is on the next line, insert before it
                local next_line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1] or ""
                if next_line:match("^</[ou]l>$") then
                    vim.api.nvim_buf_set_lines(buf, row, row, false, { "<li><p></p></li>" })
                else
                    vim.api.nvim_buf_set_lines(buf, row, row, false, { "<li><p></p></li>" })
                end
                vim.api.nvim_win_set_cursor(0, { row + 1, 7 })
            end)
            return ""
        end
    end

    -- ── Task continuation: only when cursor is past body content ──
    if line:match("<ac:task>") then
        local close_pos = line:find("</ac:task%-body>")
        if close_pos and col >= close_pos - 1 then
            local new_task = "<ac:task><ac:task-status>incomplete</ac:task-status>"
                .. "<ac:task-body></ac:task-body></ac:task>"
            vim.schedule(function()
                local list_close = line:find("</ac:task%-list>")
                if list_close then
                    local before = line:sub(1, list_close - 1)
                    local after = line:sub(list_close)
                    vim.api.nvim_buf_set_lines(buf, row - 1, row, false, { before, new_task, after })
                else
                    vim.api.nvim_buf_set_lines(buf, row, row, false, { new_task })
                end
                local body_pos = new_task:find("<ac:task%-body>") + 13
                vim.api.nvim_win_set_cursor(0, { row + 1, body_pos })
            end)
            return ""
        end
    end

    -- Default enter
    return "<CR>"
end

--- Jump to next/previous heading section
---@param buf number
---@param direction number 1 for forward, -1 for backward
function M.jump_section(buf, direction)
    local cursor = vim.api.nvim_win_get_cursor(0)
    local row = cursor[1]
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local total = #lines

    local i = row + direction
    while i >= 1 and i <= total do
        if lines[i]:match("^<h[1-6]>") then
            vim.api.nvim_win_set_cursor(0, { i, 0 })
            return
        end
        i = i + direction
    end
end

return M
