local M = {}

local api = require("jira-interface.api")
local types = require("jira-interface.types")
local cache = require("jira-interface.cache")
local config = require("jira-interface.config")
local notify = require("jira-interface.notify")
local atlassian_ui = require("atlassian.ui")
local atlassian_format = require("atlassian.format")
local csf = require("atlassian.csf")
local bridge = require("atlassian.csf.bridge")

---@param opts { width?: number, height?: number, title?: string, mode?: string }
---@return number, number Buffer and window IDs
local function create_window(opts)
    local display = vim.tbl_extend("force", config.options.display or {}, {})
    if opts and opts.mode then
        display.mode = opts.mode
    end
    return atlassian_ui.create_window({
        width = opts and opts.width,
        height = opts and opts.height,
        title = opts and opts.title,
        bufname = opts and opts.bufname,
        display = display,
        filetype = "csf",
    })
end

---@param issue JiraIssue
function M.show_issue(issue)
    local buf, win = create_window({
        title = issue.key .. " - " .. issue.summary,
        bufname = "jira://" .. issue.key,
        mode = "buffer",
    })

    local status_info = types.get_status_display(issue.status)
    local lines = {}

    -- CSF metadata
    table.insert(lines, csf.generate_metadata({ type = "jira", key = issue.key, project = issue.project }))

    table.insert(lines, "<h1>" .. issue.summary .. "</h1>")
    table.insert(lines, "<p><strong>Key:</strong> " .. issue.key .. "</p>")
    table.insert(lines, "<p><strong>Type:</strong> " .. issue.type .. " (Level " .. issue.level .. ")</p>")
    table.insert(lines, "<p><strong>Status:</strong> " .. status_info.icon .. " " .. issue.status .. "</p>")
    table.insert(lines, "<p><strong>Project:</strong> " .. issue.project .. "</p>")
    table.insert(lines, "<p><strong>Assignee:</strong> " .. (issue.assignee or "Unassigned") .. "</p>")

    if issue.parent then
        table.insert(lines, "<p><strong>Parent:</strong> " .. issue.parent .. "</p>")
    end

    if issue.duedate then
        local due_status = atlassian_format.get_duedate_status(issue.duedate)
        local due_display = types.duedate_display[due_status] or types.duedate_display.none
        table.insert(lines, "<p><strong>Due:</strong> " .. due_display.icon .. " " ..
            atlassian_format.format_duedate(issue.duedate) .. " (" .. atlassian_format.format_duedate_relative(issue.duedate) .. ")</p>")
    end

    table.insert(lines, "<hr />")
    table.insert(lines, "<h2>Description</h2>")

    -- Use raw ADF → CSF for lossless description display
    if issue.description_raw and type(issue.description_raw) == "table" then
        local desc_csf = bridge.adf_to_csf(issue.description_raw)
        vim.list_extend(lines, csf.format_lines(desc_csf))
    elseif issue.description and issue.description ~= "" then
        table.insert(lines, "<p>" .. issue.description .. "</p>")
    else
        table.insert(lines, "<p><em>No description</em></p>")
    end

    -- Custom field sections
    for heading, _ in pairs(config.options.custom_fields or {}) do
        table.insert(lines, "<hr />")
        table.insert(lines, "<h2>" .. heading .. "</h2>")
        local raw = (issue.custom_fields_raw or {})[heading]

        if raw and type(raw) == "table" and raw.content then
            -- Promote bullet lists to task lists for acceptance-style fields
            local adf = vim.deepcopy(raw)
            for _, node in ipairs(adf.content) do
                if node.type == "bulletList" then
                    node.type = "taskList"
                    for _, item in ipairs(node.content or {}) do
                        if item.type == "listItem" then
                            item.type = "taskItem"
                            item.attrs = item.attrs or {}
                            item.attrs.state = item.attrs.state or "TODO"
                        end
                    end
                end
            end
            local field_csf = bridge.adf_to_csf(adf)
            vim.list_extend(lines, csf.format_lines(field_csf))
        elseif raw and type(raw) == "string" and raw ~= "" then
            table.insert(lines, "<p>" .. raw .. "</p>")
        else
            table.insert(lines, "<p><em>No " .. heading:lower() .. "</em></p>")
        end
    end

    -- Links
    local links_mod = require("jira-interface.links")
    vim.list_extend(lines, links_mod.render_links_section(issue))

    -- Comments
    local comments_mod = require("jira-interface.comments")
    vim.list_extend(lines, comments_mod.render_comments_section(issue))

    -- Attachments
    if issue.attachments and #issue.attachments > 0 then
        table.insert(lines, "<hr />")
        table.insert(lines, "<h2>Attachments (" .. #issue.attachments .. ")</h2>")
        table.insert(lines, "<ul>")
        for _, att in ipairs(issue.attachments) do
            local size = atlassian_format.format_file_size(att.size or 0)
            table.insert(lines, '<li><a href="' .. att.url .. '">' .. att.filename .. '</a> (' .. size .. ')</li>')
        end
        table.insert(lines, "</ul>")
    end

    table.insert(lines, "<hr />")
    table.insert(lines, '<p><strong>URL:</strong> <a href="' .. issue.web_url .. '">' .. issue.web_url .. '</a></p>')
    table.insert(lines, "<p><em>Created: " .. atlassian_format.format_timestamp(issue.created) ..
        " (" .. atlassian_format.format_relative_time(issue.created) .. ")</em></p>")
    table.insert(lines, "<p><em>Updated: " .. atlassian_format.format_timestamp(issue.updated) ..
        " (" .. atlassian_format.format_relative_time(issue.updated) .. ")</em></p>")

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false

    -- Store attachment data for image resolution
    if issue.attachments and #issue.attachments > 0 then
        vim.b[buf].atlassian_attachments = issue.attachments
    end

    -- Keymaps for actions
    vim.keymap.set("n", "t", function()
        M.show_transition_picker(issue.key)
    end, { buffer = buf, desc = "Transition status" })

    vim.keymap.set("n", "e", function()
        M.edit_issue(issue.key)
    end, { buffer = buf, desc = "Edit issue" })

    vim.keymap.set("n", "s", function()
        M.show_children(issue.key)
    end, { buffer = buf, desc = "Show children / sub-tasks" })

    vim.keymap.set("n", "y", function()
        vim.fn.setreg("+", issue.key)
        notify.info("Copied: " .. issue.key)
    end, { buffer = buf, desc = "Copy issue key" })

    vim.keymap.set("n", "Y", function()
        local url = config.options.auth.url .. "/browse/" .. issue.key
        vim.fn.setreg("+", url)
        notify.info("Copied: " .. url)
    end, { buffer = buf, desc = "Copy issue URL" })

    vim.keymap.set("n", "?", function()
        vim.cmd("help atlassian-jira-keymaps")
    end, { buffer = buf, desc = "Show help" })

    vim.keymap.set("n", "c", function()
        comments_mod.add_comment(issue.key)
    end, { buffer = buf, desc = "Add comment" })

    vim.keymap.set("n", "C", function()
        comments_mod.fetch_and_select_comment(issue.key, "edit", function(comment)
            comments_mod.edit_comment(issue.key, comment)
        end)
    end, { buffer = buf, desc = "Edit comment" })

    vim.keymap.set("n", "D", function()
        comments_mod.fetch_and_select_comment(issue.key, "delete", function(comment)
            comments_mod.delete_comment(issue.key, comment)
        end)
    end, { buffer = buf, desc = "Delete comment" })

    vim.keymap.set("n", "L", function()
        links_mod.add_link(issue.key)
    end, { buffer = buf, desc = "Add issue link" })

    vim.keymap.set("n", "X", function()
        links_mod.fetch_and_delete_link(issue.key)
    end, { buffer = buf, desc = "Delete issue link" })

    vim.keymap.set("n", "a", function()
        M.show_assign_picker(issue.key, issue.project)
    end, { buffer = buf, desc = "Assign issue" })

    vim.keymap.set("n", "n", function()
        local picker = require("jira-interface.picker")
        picker.create_issue(nil, issue.project, issue.key)
    end, { buffer = buf, desc = "Create child issue" })
end

---@param key string
function M.view(key)
    api.get_issue(key, function(err, issue)
        if err then
            notify.error("Failed to fetch issue: " .. err)
            return
        end
        M.show_issue(issue)
    end)
end

---@param key string
function M.show_transition_picker(key)
    api.get_transitions(key, function(err, transitions)
        if err then
            notify.error("Failed to get transitions: " .. err)
            return
        end

        if #transitions == 0 then
            notify.warn("No transitions available")
            return
        end

        local items = {}
        for _, t in ipairs(transitions) do
            table.insert(items, t.name .. " -> " .. t.to)
        end

        vim.ui.select(items, { prompt = "Select transition:" }, function(choice, idx)
            if not choice then
                return
            end

            local transition = transitions[idx]
            if api.is_online then
                api.do_transition(key, transition.id, function(trans_err)
                    if trans_err then
                        notify.error("Transition failed: " .. trans_err)
                    else
                        notify.info(string.format("%s -> %s", key, transition.to))
                    end
                end)
            else
                local queue = require("jira-interface.queue")
                queue.queue_transition(key, transition.id, transition.to)
            end
        end)
    end)
end

---@param key string
---@param project string
function M.show_assign_picker(key, project)
    api.get_project_members(project, function(err, members)
        if err then
            notify.error("Failed to get users: " .. err)
            return
        end

        -- Build display items: Unassign first, then all assignable members
        local items = { "Unassigned" }
        for _, m in ipairs(members or {}) do
            table.insert(items, m.displayName)
        end

        vim.ui.select(items, { prompt = "Assign " .. key .. " to:" }, function(choice, idx)
            if not choice then
                return
            end

            local account_id
            if idx == 1 then
                -- Unassign: Jira expects null accountId
                account_id = nil
            else
                account_id = members[idx - 1].accountId
            end

            if api.is_online then
                -- For unassign, Jira Cloud needs accountId: null (vim.NIL encodes as JSON null)
                local effective_id = account_id or vim.NIL
                api.assign_issue(key, effective_id, function(assign_err)
                    if assign_err then
                        notify.error("Assign failed: " .. assign_err)
                    else
                        local msg = idx == 1 and (key .. " unassigned") or (key .. " assigned to " .. choice)
                        notify.info(msg)
                        api.get_issue(key, function(fetch_err, fresh_issue)
                            if not fetch_err and fresh_issue then
                                M.show_issue(fresh_issue)
                            end
                        end)
                    end
                end)
            else
                local queue = require("jira-interface.queue")
                local desc = idx == 1 and ("Unassign " .. key) or ("Assign " .. key .. " to " .. choice)
                queue.queue_update(key, { assignee = { accountId = account_id } }, desc)
            end
        end)
    end)
end

---@param key string
function M.edit_issue(key)
    api.get_issue(key, function(err, issue)
        if err then
            notify.error("Failed to fetch issue: " .. err)
            return
        end

        local buf, _ = create_window({ title = "Edit " .. key, bufname = "jira://" .. key .. "/edit", mode = "buffer" })
        vim.bo[buf].buftype = "acwrite"

        -- Build CSF content: <h1> = summary, <h2> sections = editable fields
        local lines = {
            csf.generate_metadata({ type = "jira", key = key, project = issue.project, issue_type = issue.type }),
            "<h1>" .. (issue.summary or "") .. "</h1>",
            "<h2>Description</h2>",
        }

        -- Use raw ADF → CSF for lossless description
        if issue.description_raw and type(issue.description_raw) == "table" then
            local desc_csf = bridge.adf_to_csf(issue.description_raw)
            for _, line in ipairs(vim.split(desc_csf, "\n")) do
                table.insert(lines, line)
            end
        elseif issue.description and issue.description ~= "" then
            table.insert(lines, "<p>" .. issue.description .. "</p>")
        end

        -- Custom field sections (Acceptance Criteria, etc.)
        for heading, _ in pairs(config.options.custom_fields or {}) do
            table.insert(lines, "<h2>" .. heading .. "</h2>")
            local raw = (issue.custom_fields_raw or {})[heading]
            if raw and type(raw) == "table" and raw.content then
                -- Promote bullet lists to task lists for acceptance-style fields
                local adf = vim.deepcopy(raw)
                for _, node in ipairs(adf.content) do
                    if node.type == "bulletList" then
                        node.type = "taskList"
                        for _, item in ipairs(node.content or {}) do
                            if item.type == "listItem" then
                                item.type = "taskItem"
                                item.attrs = item.attrs or {}
                                item.attrs.state = item.attrs.state or "TODO"
                            end
                        end
                    end
                end
                local field_csf = bridge.adf_to_csf(adf)
                for _, line in ipairs(vim.split(field_csf, "\n")) do
                    table.insert(lines, line)
                end
            elseif raw and type(raw) == "string" and raw ~= "" then
                table.insert(lines, "<p>" .. raw .. "</p>")
            end
        end

        table.insert(lines, "<hr />")

        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

        -- Store attachment data for image resolution
        if issue.attachments and #issue.attachments > 0 then
            vim.b[buf].atlassian_attachments = issue.attachments
        end

        -- Save handler
        vim.api.nvim_create_autocmd("BufWriteCmd", {
            buffer = buf,
            callback = function()
                local content = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

                -- Remove metadata line
                table.remove(content, 1)
                -- Extract summary from <h1> title
                local summary_text, remaining = csf.extract_title(content)
                content = remaining

                local fields = {}

                if summary_text and summary_text ~= issue.summary then
                    fields.summary = summary_text
                end

                -- Build section names from custom_fields config
                local section_names = { "description" }
                local custom_fields = config.options.custom_fields or {}
                for heading, _ in pairs(custom_fields) do
                    table.insert(section_names, (heading:lower():gsub("%s+", "_")))
                end
                local parsed = csf.extract_sections(content, section_names)

                -- Convert description CSF → ADF
                if parsed.description then
                    fields.description = bridge.sanitize_for_jira(bridge.csf_to_adf(parsed.description))
                end

                -- Convert custom field sections CSF → ADF
                local resolved_ids = (issue.custom_fields_raw or {})._resolved_ids or {}
                for heading, _ in pairs(custom_fields) do
                    local skey = heading:lower():gsub("%s+", "_")
                    if parsed[skey] then
                        -- Use the resolved field ID that had data, or first candidate
                        local field_id = resolved_ids[heading]
                        if not field_id then
                            local ref = custom_fields[heading]
                            field_id = type(ref) == "table" and ref[1] or ref
                        end
                        if field_id then
                            fields[field_id] = bridge.sanitize_for_jira(bridge.csf_to_adf(parsed[skey]))
                        end
                    end
                end

                if vim.tbl_isempty(fields) then
                    notify.info("No changes to save")
                    if vim.api.nvim_buf_is_valid(buf) then
                        vim.api.nvim_buf_delete(buf, { force = true })
                    end
                    return
                end

                if api.is_online then
                    api.update_issue(key, fields, function(update_err)
                        if update_err then
                            notify.error(notify.format_api_error(update_err, "updating " .. key))
                        else
                            if vim.api.nvim_buf_is_valid(buf) then
                                vim.api.nvim_buf_delete(buf, { force = true })
                            end
                            cache.invalidate_project(issue.project)
                            api.get_issue(key, function(fetch_err, fresh_issue)
                                if fetch_err then
                                    notify.info("Issue updated: " .. key)
                                else
                                    notify.info("Issue updated: " .. key)
                                    M.show_issue(fresh_issue)
                                end
                            end)
                        end
                    end)
                else
                    local queue = require("jira-interface.queue")
                    queue.queue_update(key, fields, "Update " .. key)
                    if vim.api.nvim_buf_is_valid(buf) then
                        vim.api.nvim_buf_delete(buf, { force = true })
                    end
                end
            end,
        })
    end)
end

---@param parent_key string
function M.show_children(parent_key)
    api.get_children(parent_key, function(err, children)
        if err then
            notify.error("Failed to fetch children: " .. err)
            return
        end

        if #children == 0 then
            notify.info("No children found for " .. parent_key)
            return
        end

        local picker = require("jira-interface.picker")
        picker.show_issues(children, { title = "Children of " .. parent_key })
    end)
end

function M.show_queue()
    local queue = require("jira-interface.queue")
    local edits = queue.get_all()

    if #edits == 0 then
        notify.info("No pending edits in queue")
        return
    end

    local buf, win = create_window({ title = "Offline Queue", bufname = "jira://queue" })

    local lines = {
        "<h1>Offline Edit Queue</h1>",
        string.format("<p><strong>%d pending edit(s)</strong></p>", #edits),
    }

    for idx, edit in ipairs(edits) do
        table.insert(lines, string.format("<h2>%d. %s</h2>", idx, edit.description))
        table.insert(lines, string.format("<p>Type: %s</p>", edit.type))
        if edit.issue_key then
            table.insert(lines, string.format("<p>Issue: %s</p>", edit.issue_key))
        end
        table.insert(lines, string.format("<p>Queued: %s</p>", os.date("%Y-%m-%d %H:%M", edit.timestamp)))
    end

    table.insert(lines, "<hr />")
    table.insert(lines, "<p><strong>Actions:</strong> [s]ync all | [d]elete item | [c]lear all</p>")

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false

    vim.keymap.set("n", "s", function()
        queue.sync_all(function(results)
            local success = 0
            local failed = 0
            for _, r in ipairs(results) do
                if r.success then
                    success = success + 1
                else
                    failed = failed + 1
                end
            end
            notify.info(string.format("Sync: %d succeeded, %d failed", success, failed))
        end)
    end, { buffer = buf, desc = "Sync all" })

    vim.keymap.set("n", "c", function()
        vim.ui.input({ prompt = "Clear all pending edits? (yes/no): " }, function(input)
            if input == "yes" then
                queue.clear()
                vim.api.nvim_win_close(win, true)
                notify.info("Queue cleared")
            end
        end)
    end, { buffer = buf, desc = "Clear all" })

    vim.keymap.set("n", "?", function()
        vim.cmd("help atlassian-jira-keymaps")
    end, { buffer = buf, desc = "Show help" })
end

function M.show_status()
    local queue = require("jira-interface.queue")
    local cache = require("jira-interface.cache")

    local cache_stats = cache.stats()
    local queue_count = queue.count()

    api.check_connectivity(function(online)
        local status = online and "Online" or "Offline"
        local icon = online and "" or ""

        local lines = {
            string.format("%s %s", icon, status),
            string.format("Cache: %d entries (%.1f KB)", cache_stats.entries, cache_stats.size_bytes / 1024),
            string.format("Queue: %d pending edit(s)", queue_count),
            string.format("Project: %s", config.options.default_project),
        }

        notify.info(table.concat(lines, "\n"))
    end)
end

return M
