local M = {}

local api = require("jira-interface.api")
local cache = require("jira-interface.cache")
local config = require("jira-interface.config")
local notify = require("jira-interface.notify")
local atlassian_ui = require("atlassian.ui")
local atlassian_format = require("atlassian.format")
local csf = require("atlassian.csf")
local bridge = require("atlassian.csf.bridge")

-- Module-level storage for comment ADF bodies (can't serialize to vim.b)
---@type table<number, { issue_key: string, comments: JiraComment[] }>
M._buf_comments = {}

---@param issue JiraIssue
---@return string[] CSF lines for the comments section
function M.render_comments_section(issue)
    local lines = {}
    local comments = issue.comments or {}
    local total = issue.comments_total or 0

    table.insert(lines, "<hr />")
    table.insert(lines, "<h2>Comments (" .. total .. ")</h2>")

    if #comments == 0 then
        table.insert(lines, "<p><em>No comments</em></p>")
        return lines
    end

    for i, comment in ipairs(comments) do
        if i > 1 then
            table.insert(lines, "<hr />")
        end

        -- Header: author + relative time + edited indicator
        local time_str = atlassian_format.format_relative_time(comment.created)
        local header = comment.author_name .. " - " .. time_str
        if comment.updated ~= "" and comment.updated ~= comment.created then
            header = header .. " (edited)"
        end
        table.insert(lines, "<h3>" .. header .. "</h3>")

        -- Body: ADF -> CSF
        if comment.body and type(comment.body) == "table" and comment.body.content then
            local body_csf = bridge.adf_to_csf(comment.body)
            vim.list_extend(lines, csf.format_lines(body_csf))
        else
            table.insert(lines, "<p><em>Empty comment</em></p>")
        end
    end

    return lines
end

---@param opts { width?: number, height?: number, title?: string }
---@return number, number Buffer and window IDs
local function create_window(opts)
    local display = vim.tbl_extend("force", config.options.display or {}, {})
    display.mode = "buffer"
    return atlassian_ui.create_window({
        width = opts and opts.width,
        height = opts and opts.height,
        title = opts and opts.title,
        bufname = opts and opts.bufname,
        display = display,
        filetype = "csf",
    })
end

--- Refresh the issue view buffer after a comment action
---@param issue_key string
local function refresh_issue_view(issue_key)
    api.get_issue(issue_key, function(err, fresh_issue)
        if err then
            notify.info("Comment saved for " .. issue_key)
        else
            local ui = require("jira-interface.ui")
            ui.show_issue(fresh_issue)
        end
    end)
end

---@param issue_key string
function M.add_comment(issue_key)
    local buf, _ = create_window({
        title = "Add Comment - " .. issue_key,
        bufname = "jira://" .. issue_key .. "/comment/new",
    })

    local lines = {
        csf.generate_metadata({ type = "jira", key = issue_key }),
        "<h2>New Comment</h2>",
        "<p></p>",
    }

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

    -- Place cursor inside the <p> tag
    vim.api.nvim_win_set_cursor(0, { 3, 3 })

    vim.api.nvim_create_autocmd("BufWriteCmd", {
        buffer = buf,
        callback = function()
            local content = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

            -- Remove metadata line and <h2> header
            table.remove(content, 1)
            -- Remove section header
            local body_lines = {}
            local past_header = false
            for _, line in ipairs(content) do
                if past_header then
                    table.insert(body_lines, line)
                elseif vim.trim(line):match("^<h2>") then
                    past_header = true
                else
                    table.insert(body_lines, line)
                end
            end

            local body_csf = table.concat(body_lines, "\n")
            if vim.trim(body_csf) == "" or vim.trim(body_csf) == "<p></p>" then
                notify.info("Empty comment, not saving")
                return
            end

            local body_adf = bridge.sanitize_for_jira(bridge.csf_to_adf(body_csf))

            if api.is_online then
                api.add_comment(issue_key, body_adf, function(add_err)
                    if add_err then
                        notify.error(notify.format_api_error(add_err, "adding comment"))
                    else
                        if vim.api.nvim_buf_is_valid(buf) then
                            vim.api.nvim_buf_delete(buf, { force = true })
                        end
                        cache.invalidate_project(config.options.default_project)
                        notify.info("Comment added to " .. issue_key)
                        refresh_issue_view(issue_key)
                    end
                end)
            else
                local queue = require("jira-interface.queue")
                queue.queue_comment(issue_key, body_csf)
                if vim.api.nvim_buf_is_valid(buf) then
                    vim.api.nvim_buf_delete(buf, { force = true })
                end
            end
        end,
    })
end

---@param issue_key string
---@param comment JiraComment
function M.edit_comment(issue_key, comment)
    local buf, _ = create_window({
        title = "Edit Comment - " .. issue_key,
        bufname = "jira://" .. issue_key .. "/comment/" .. comment.id,
    })

    local lines = {
        csf.generate_metadata({ type = "jira", key = issue_key }),
        "<h2>Edit Comment</h2>",
    }

    -- Pre-populate with existing comment body (ADF -> CSF)
    if comment.body and type(comment.body) == "table" and comment.body.content then
        local body_csf = bridge.adf_to_csf(comment.body)
        vim.list_extend(lines, csf.format_lines(body_csf))
    else
        table.insert(lines, "<p></p>")
    end

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

    -- Store ADF body for reference
    M._buf_comments[buf] = { issue_key = issue_key, comment = comment }
    vim.api.nvim_create_autocmd("BufWipeout", {
        buffer = buf,
        callback = function()
            M._buf_comments[buf] = nil
        end,
    })

    vim.api.nvim_create_autocmd("BufWriteCmd", {
        buffer = buf,
        callback = function()
            local content = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

            -- Remove metadata line and section header
            table.remove(content, 1)
            local body_lines = {}
            local past_header = false
            for _, line in ipairs(content) do
                if past_header then
                    table.insert(body_lines, line)
                elseif vim.trim(line):match("^<h2>") then
                    past_header = true
                else
                    table.insert(body_lines, line)
                end
            end

            local body_csf = table.concat(body_lines, "\n")
            local body_adf = bridge.sanitize_for_jira(bridge.csf_to_adf(body_csf))

            api.update_comment(issue_key, comment.id, body_adf, function(update_err)
                if update_err then
                    notify.error(notify.format_api_error(update_err, "updating comment"))
                else
                    if vim.api.nvim_buf_is_valid(buf) then
                        vim.api.nvim_buf_delete(buf, { force = true })
                    end
                    notify.info("Comment updated on " .. issue_key)
                    refresh_issue_view(issue_key)
                end
            end)
        end,
    })
end

---@param issue_key string
---@param comment JiraComment
function M.delete_comment(issue_key, comment)
    -- Build a preview of the comment
    local preview = comment.author_name .. ": "
    if comment.body and type(comment.body) == "table" and comment.body.content then
        local text = require("atlassian.adf").adf_to_text(comment.body)
        preview = preview .. (text:sub(1, 60) .. (text:len() > 60 and "..." or ""))
    end

    vim.ui.input({ prompt = "Delete comment? (" .. preview .. ") [yes/no]: " }, function(input)
        if not input or input:lower() ~= "yes" then
            return
        end

        api.delete_comment(issue_key, comment.id, function(err)
            if err then
                notify.error("Failed to delete comment: " .. err)
            else
                notify.info("Comment deleted from " .. issue_key)
                refresh_issue_view(issue_key)
            end
        end)
    end)
end

---@param issue_key string
---@param comments JiraComment[]
---@param action_name string Display name for the action (e.g., "edit", "delete")
---@param cb fun(comment: JiraComment)
function M.select_comment(issue_key, comments, action_name, cb)
    if #comments == 0 then
        notify.info("No comments on " .. issue_key)
        return
    end

    local items = {}
    for _, comment in ipairs(comments) do
        local time_str = atlassian_format.format_relative_time(comment.created)
        local preview = ""
        if comment.body and type(comment.body) == "table" and comment.body.content then
            local text = require("atlassian.adf").adf_to_text(comment.body)
            preview = text:sub(1, 50):gsub("\n", " ")
        end
        table.insert(items, string.format("%s (%s): %s", comment.author_name, time_str, preview))
    end

    vim.ui.select(items, { prompt = "Select comment to " .. action_name .. ":" }, function(_, idx)
        if not idx then
            return
        end
        cb(comments[idx])
    end)
end

---@param issue_key string
---@param action_name string
---@param cb fun(comment: JiraComment)
function M.fetch_and_select_comment(issue_key, action_name, cb)
    api.get_comments(issue_key, nil, function(err, data)
        if err then
            notify.error("Failed to fetch comments: " .. err)
            return
        end
        M.select_comment(issue_key, data.comments, action_name, cb)
    end)
end

return M
