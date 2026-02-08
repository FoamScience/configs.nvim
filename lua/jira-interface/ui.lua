local M = {}

local api = require("jira-interface.api")
local types = require("jira-interface.types")
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
            local field_csf = bridge.adf_to_csf(raw)
            vim.list_extend(lines, csf.format_lines(field_csf))
        elseif raw and type(raw) == "string" and raw ~= "" then
            table.insert(lines, "<p>" .. raw .. "</p>")
        else
            table.insert(lines, "<p><em>No " .. heading:lower() .. "</em></p>")
        end
    end

    -- Comments
    if issue.comment_count and issue.comment_count > 0 then
        table.insert(lines, "<hr />")
        table.insert(lines, "<h2>Comments (" .. issue.comment_count .. ")</h2>")
        table.insert(lines, '<p><a href="' .. issue.web_url .. '">View comments in browser</a></p>')
    end

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

    vim.keymap.set("n", "c", function()
        M.show_children(issue.key)
    end, { buffer = buf, desc = "Show children" })

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
        M.show_help()
    end, { buffer = buf, desc = "Show help" })
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
function M.edit_issue(key)
    api.get_issue(key, function(err, issue)
        if err then
            notify.error("Failed to fetch issue: " .. err)
            return
        end

        local buf, _ = create_window({ title = "Edit " .. key, bufname = "jira://" .. key .. "/edit", mode = "buffer" })

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
                local field_csf = bridge.adf_to_csf(raw)
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
                    fields.description = bridge.csf_to_adf(parsed.description)
                end

                -- Convert custom field sections CSF → ADF
                for heading, field_id in pairs(custom_fields) do
                    local skey = heading:lower():gsub("%s+", "_")
                    if parsed[skey] then
                        fields[field_id] = bridge.csf_to_adf(parsed[skey])
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
                            notify.error("Update failed: " .. update_err)
                        else
                            notify.info("Issue updated: " .. key)
                            if vim.api.nvim_buf_is_valid(buf) then
                                vim.api.nvim_buf_delete(buf, { force = true })
                            end
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
end

function M.show_help()
    local buf, _ = create_window({ title = "Jira Interface Help", bufname = "jira://help", width = 70, height = 52 })

    local lines = {
        "<h1>Jira Interface - Keybindings</h1>",
        "<h2>Issue View</h2>",
        "<ul>",
        "<li><p><code>t</code> - Transition status</p></li>",
        "<li><p><code>e</code> - Edit issue</p></li>",
        "<li><p><code>c</code> - Show children</p></li>",
        "<li><p><code>y</code> - Copy issue key</p></li>",
        "<li><p><code>Y</code> - Copy issue URL</p></li>",
        "<li><p><code>q</code> - Close (<code>:q</code>)</p></li>",
        "</ul>",
        "<h2>Picker</h2>",
        "<ul>",
        "<li><p><code>&lt;CR&gt;</code> - Open issue</p></li>",
        "<li><p><code>&lt;C-t&gt;</code> - Transition status</p></li>",
        "<li><p><code>&lt;C-y&gt;</code> - Copy issue key</p></li>",
        "</ul>",
        "<h2>Team Dashboard (&lt;leader&gt;jw)</h2>",
        "<ul>",
        "<li><p><code>&lt;CR&gt;</code> - View issue</p></li>",
        "<li><p><code>&lt;C-a&gt;</code> - Assign to me</p></li>",
        "<li><p><code>&lt;C-t&gt;</code> - Transition status</p></li>",
        "</ul>",
        "<h2>TODO to Issue (&lt;leader&gt;jT)</h2>",
        "<ul>",
        "<li><p><code>&lt;Tab&gt;</code> - Toggle selection</p></li>",
        "<li><p><code>&lt;C-a&gt;</code> - Select all</p></li>",
        "<li><p><code>&lt;C-n&gt;</code> - Select none</p></li>",
        "<li><p><code>&lt;CR&gt;</code> - Confirm (auto-uses branch issue as parent)</p></li>",
        "</ul>",
        "<h2>Context-Aware Commands</h2>",
        "<ul>",
        "<li><p><code>:JiraView [key]</code> - View issue (branch or picker)</p></li>",
        "<li><p><code>:JiraEdit [key]</code> - Edit issue (branch or picker)</p></li>",
        "<li><p><code>:JiraTransition [key]</code> - Change status</p></li>",
        "<li><p><code>:JiraStart [key]</code> - Quick transition to In Progress</p></li>",
        "<li><p><code>:JiraDone [key]</code> - Quick transition to Done</p></li>",
        "<li><p><code>:JiraReview [key]</code> - Quick transition to In Review</p></li>",
        "<li><p><code>:JiraQuick &lt;summary&gt;</code> - Create Sub-Task under branch issue</p></li>",
        "</ul>",
        "<h2>Search Commands</h2>",
        "<ul>",
        "<li><p><code>:JiraSearch</code> - Search all issues</p></li>",
        "<li><p><code>:JiraMe</code> - My assigned issues</p></li>",
        "<li><p><code>:JiraProject [name]</code> - Filter by project</p></li>",
        "<li><p><code>:JiraEpics</code> - Level 1 (Epics)</p></li>",
        "<li><p><code>:JiraFeatures</code> - Level 2</p></li>",
        "<li><p><code>:JiraTasks</code> - Level 3 (Tasks)</p></li>",
        "<li><p><code>:JiraDue [overdue|today|week|soon]</code> - Filter by due date</p></li>",
        "</ul>",
        "<h2>Other Commands</h2>",
        "<ul>",
        "<li><p><code>:JiraCreate [type]</code> - Create issue (full form)</p></li>",
        "<li><p><code>:JiraFilter</code> - Manage saved filters</p></li>",
        "<li><p><code>:JiraTeam [project]</code> - Team workload dashboard</p></li>",
        "<li><p><code>:JiraTodoToIssue [buffer|project]</code> - Convert TODOs to Sub-Tasks</p></li>",
        "<li><p><code>:JiraQueue</code> - View offline queue</p></li>",
        "<li><p><code>:JiraRefresh</code> - Clear cache</p></li>",
        "<li><p><code>:JiraStatus</code> - Connection status</p></li>",
        "</ul>",
    }

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
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
