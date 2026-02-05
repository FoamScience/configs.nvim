local M = {}

local api = require("jira-interface.api")
local types = require("jira-interface.types")
local config = require("jira-interface.config")
local notify = require("jira-interface.notify")
local atlassian_ui = require("atlassian.ui")

---@param opts { width?: number, height?: number, title?: string }
---@return number, number Buffer and window IDs
local function create_window(opts)
    return atlassian_ui.create_window({
        width = opts and opts.width,
        height = opts and opts.height,
        title = opts and opts.title,
        bufname = opts and opts.bufname,
        display = config.options.display,
        filetype = "atlassian_jira",
    })
end

-- Alias for backwards compatibility
local function create_float(opts)
    return create_window(opts)
end

---@param issue JiraIssue
function M.show_issue(issue)
    local buf, win = create_float({
        title = issue.key .. " - " .. issue.summary,
        bufname = "jira://" .. issue.key,
    })

    local status_info = types.get_status_display(issue.status)
    local lines = {
        "# " .. issue.summary,
        "",
        string.format("**Key:** %s", issue.key),
        string.format("**Type:** %s (Level %d)", issue.type, issue.level),
        string.format("**Status:** %s %s", status_info.icon, issue.status),
        string.format("**Project:** %s", issue.project),
        string.format("**Assignee:** %s", issue.assignee or "Unassigned"),
    }

    if issue.parent then
        table.insert(lines, string.format("**Parent:** %s", issue.parent))
    end

    -- Due date
    if issue.duedate then
        local due_status = types.get_duedate_status(issue.duedate)
        local due_display = types.duedate_display[due_status] or types.duedate_display.none
        table.insert(lines,
            string.format("**Due:** %s %s (%s)", due_display.icon, types.format_duedate(issue.duedate),
                types.format_duedate_relative(issue.duedate)))
    end

    table.insert(lines, "")
    table.insert(lines, "---")
    table.insert(lines, "")
    table.insert(lines, "## Description")
    table.insert(lines, "")

    if issue.description and issue.description ~= "" then
        for _, line in ipairs(vim.split(issue.description, "\n")) do
            table.insert(lines, line)
        end
    else
        table.insert(lines, "_No description_")
    end

    table.insert(lines, "")
    table.insert(lines, "---")
    table.insert(lines, "")
    table.insert(lines, "## Acceptance Criteria")
    table.insert(lines, "")

    if issue.acceptance_criteria and issue.acceptance_criteria ~= "" then
        for _, line in ipairs(vim.split(issue.acceptance_criteria, "\n")) do
            table.insert(lines, line)
        end
    else
        table.insert(lines, "_No acceptance criteria_")
    end

    -- Comments
    if issue.comment_count and issue.comment_count > 0 then
        table.insert(lines, "")
        table.insert(lines, "---")
        table.insert(lines, "")
        table.insert(lines, string.format("## Comments (%d)", issue.comment_count))
        table.insert(lines, "")
        table.insert(lines, string.format("[View comments in browser](%s)", issue.web_url))
    end

    -- Attachments
    if issue.attachments and #issue.attachments > 0 then
        table.insert(lines, "")
        table.insert(lines, "---")
        table.insert(lines, "")
        table.insert(lines, "## Attachments (" .. #issue.attachments .. ")")
        table.insert(lines, "")
        for _, att in ipairs(issue.attachments) do
            local size = types.format_file_size(att.size or 0)
            table.insert(lines, string.format("- [%s](%s) (%s)", att.filename, att.url, size))
        end
    end

    table.insert(lines, "")
    table.insert(lines, "---")
    table.insert(lines, "")
    table.insert(lines, "**URL:**")
    table.insert(lines, issue.web_url)
    table.insert(lines, "")
    table.insert(lines,
        string.format("_Created: %s (%s)_", types.format_timestamp(issue.created),
            types.format_relative_time(issue.created)))
    table.insert(lines,
        string.format("_Updated: %s (%s)_", types.format_timestamp(issue.updated),
            types.format_relative_time(issue.updated)))

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false

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

        local buf, win = create_window({ title = "Edit " .. key, bufname = "jira://" .. key .. "/edit" })

        local lines = {
            "# Edit Issue: " .. key,
            "",
            "## Summary",
            issue.summary or "",
            "",
            "## Description",
            issue.description or "",
            "",
            "## Acceptance Criteria",
            issue.acceptance_criteria or "",
            "",
            "---",
            "Save: :w | Cancel: :q!",
        }

        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

        -- Save handler
        vim.api.nvim_create_autocmd("BufWriteCmd", {
            buffer = buf,
            callback = function()
                local content = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
                local parsed = M.parse_edit_buffer(content)

                local fields = {}
                if parsed.summary and parsed.summary ~= issue.summary then
                    fields.summary = parsed.summary
                end
                if parsed.description and parsed.description ~= issue.description then
                    fields.description = {
                        type = "doc",
                        version = 1,
                        content = {
                            {
                                type = "paragraph",
                                content = { { type = "text", text = parsed.description } },
                            },
                        },
                    }
                end

                if vim.tbl_isempty(fields) then
                    notify.info("No changes to save")
                    vim.api.nvim_win_close(win, true)
                    return
                end

                if api.is_online then
                    api.update_issue(key, fields, function(update_err)
                        if update_err then
                            notify.error("Update failed: " .. update_err)
                        else
                            notify.info("Issue updated: " .. key)
                            vim.api.nvim_win_close(win, true)
                        end
                    end)
                else
                    local queue = require("jira-interface.queue")
                    queue.queue_update(key, fields, "Update " .. key)
                    vim.api.nvim_win_close(win, true)
                end
            end,
        })
    end)
end

---@param lines string[]
---@return { summary: string|nil, description: string|nil, acceptance_criteria: string|nil }
function M.parse_edit_buffer(lines)
    local result = {}
    local current_section = nil
    local section_lines = {}

    local function save_section()
        if current_section and #section_lines > 0 then
            result[current_section] = vim.trim(table.concat(section_lines, "\n"))
        end
        section_lines = {}
    end

    for _, line in ipairs(lines) do
        if line:match("^## Summary") then
            save_section()
            current_section = "summary"
        elseif line:match("^## Description") then
            save_section()
            current_section = "description"
        elseif line:match("^## Acceptance Criteria") then
            save_section()
            current_section = "acceptance_criteria"
        elseif line:match("^%-%-%-") then
            save_section()
            current_section = nil
        elseif line:match("^# Edit Issue") then
            -- Skip header
        elseif current_section then
            table.insert(section_lines, line)
        end
    end

    save_section()
    return result
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

    local buf, win = create_float({ title = "Offline Queue", bufname = "jira://queue" })

    local lines = {
        "# Offline Edit Queue",
        "",
        string.format("**%d pending edit(s)**", #edits),
        "",
    }

    for i, edit in ipairs(edits) do
        table.insert(lines, string.format("## %d. %s", i, edit.description))
        table.insert(lines, string.format("- Type: %s", edit.type))
        if edit.issue_key then
            table.insert(lines, string.format("- Issue: %s", edit.issue_key))
        end
        table.insert(lines, string.format("- Queued: %s", os.date("%Y-%m-%d %H:%M", edit.timestamp)))
        table.insert(lines, "")
    end

    table.insert(lines, "---")
    table.insert(lines, "")
    table.insert(lines, "**Actions:** [s]ync all | [d]elete item | [c]lear all")

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
    local buf, _ = create_float({ title = "Jira Interface Help", bufname = "jira://help", width = 70, height = 52 })

    local lines = {
        "# Jira Interface - Keybindings",
        "",
        "## Issue View",
        "- `t` - Transition status",
        "- `e` - Edit issue",
        "- `c` - Show children",
        "- `y` - Copy issue key",
        "- `Y` - Copy issue URL",
        "- `q` - Close (`:q`)",
        "",
        "## Picker",
        "- `<CR>` - Open issue",
        "- `<C-t>` - Transition status",
        "- `<C-y>` - Copy issue key",
        "",
        "## Team Dashboard (<leader>jw)",
        "- `<CR>` - View issue",
        "- `<C-a>` - Assign to me",
        "- `<C-t>` - Transition status",
        "",
        "## TODO to Issue (<leader>jT)",
        "- `<Tab>` - Toggle selection",
        "- `<C-a>` - Select all",
        "- `<C-n>` - Select none",
        "- `<CR>` - Confirm (auto-uses branch issue as parent)",
        "",
        "## Context-Aware Commands (auto-detect from git branch)",
        "- `:JiraView [key]` - View issue (branch or picker)",
        "- `:JiraEdit [key]` - Edit issue (branch or picker)",
        "- `:JiraTransition [key]` - Change status (branch or picker)",
        "- `:JiraStart [key]` - Quick transition to In Progress",
        "- `:JiraDone [key]` - Quick transition to Done",
        "- `:JiraReview [key]` - Quick transition to In Review",
        "- `:JiraQuick <summary>` - Create Sub-Task under branch issue",
        "",
        "## Search Commands",
        "- `:JiraSearch` - Search all issues",
        "- `:JiraMe` - My assigned issues",
        "- `:JiraProject [name]` - Filter by project",
        "- `:JiraEpics` - Level 1 (Epics)",
        "- `:JiraFeatures` - Level 2",
        "- `:JiraTasks` - Level 3 (Tasks)",
        "- `:JiraDue [overdue|today|week|soon]` - Filter by due date",
        "",
        "## Other Commands",
        "- `:JiraCreate [type]` - Create issue (full form)",
        "- `:JiraFilter` - Manage saved filters",
        "- `:JiraTeam [project]` - Team workload dashboard",
        "- `:JiraTodoToIssue [buffer|project]` - Convert TODOs to Sub-Tasks",
        "- `:JiraQueue` - View offline queue",
        "- `:JiraRefresh` - Clear cache",
        "- `:JiraStatus` - Connection status",
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
