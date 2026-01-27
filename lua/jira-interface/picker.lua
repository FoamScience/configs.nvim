local M = {}

local api = require("jira-interface.api")
local types = require("jira-interface.types")
local cache = require("jira-interface.cache")
local filters = require("jira-interface.filters")
local config = require("jira-interface.config")
local notify = require("jira-interface.notify")
local atlassian_ui = require("atlassian.ui")

-- Fixed column widths
local COL_KEY = 12
local COL_STATUS = 14
local COL_TYPE = 10
local COL_DUE = 20

-- Use shared UI helpers
local pad_right = atlassian_ui.pad_right

---@param issues JiraIssue[]
---@param opts? { title?: string }
function M.show_issues(issues, opts)
    opts = opts or {}

    if #issues == 0 then
        notify.info("No issues found")
        return
    end

    local Snacks = require("snacks")

    -- Build items with proper structure for snacks
    local items = {}
    for idx, issue in ipairs(issues) do
        local status_info = types.get_status_display(issue.status)
        local due_status = types.get_duedate_status(issue.duedate)
        local due_display = types.duedate_display[due_status] or types.duedate_display.none
        table.insert(items, {
            idx = idx,
            text = string.format("%s %s %s %s %s", issue.key, issue.status, issue.type, issue.duedate or "",
                issue.summary),
            issue = issue,
            key = issue.key,
            status = issue.status,
            status_icon = status_info.icon,
            status_hl = status_info.hl,
            issue_type = issue.type,
            duedate = issue.duedate,
            due_display = types.format_duedate_relative(issue.duedate),
            due_icon = due_display.icon,
            due_hl = due_display.hl,
            summary = issue.summary,
        })
    end

    Snacks.picker.pick({
        title = opts.title or "Jira Issues",
        items = items,
        format = function(item, _picker)
            local ret = {}
            -- Key (fixed width)
            table.insert(ret, { pad_right(item.key, COL_KEY), "Special" })
            table.insert(ret, { " ", "Normal" })
            -- Status icon and name (fixed width)
            table.insert(ret, { item.status_icon .. " ", item.status_hl })
            table.insert(ret, { pad_right(item.status, COL_STATUS), item.status_hl })
            table.insert(ret, { " ", "Normal" })
            -- Type (fixed width)
            table.insert(ret, { pad_right(item.issue_type, COL_TYPE), "Type" })
            table.insert(ret, { " ", "Normal" })
            -- Due date (fixed width)
            if item.duedate then
                table.insert(ret, { item.due_icon .. " ", item.due_hl })
                table.insert(ret, { pad_right(item.due_display, COL_DUE), item.due_hl })
            else
                table.insert(ret, { pad_right("", COL_DUE + 2), "Comment" })
            end
            table.insert(ret, { " ", "Normal" })
            -- Summary (rest of line)
            table.insert(ret, { item.summary or "", "Normal" })
            return ret
        end,
        confirm = function(picker, item)
            picker:close()
            if item and item.issue then
                local ui = require("jira-interface.ui")
                ui.show_issue(item.issue)
            end
        end,
        actions = {
            transition = function(picker, item)
                if item and item.issue then
                    picker:close()
                    local ui = require("jira-interface.ui")
                    ui.show_transition_picker(item.issue.key)
                end
            end,
            copy_key = function(_, item)
                if item and item.issue then
                    vim.fn.setreg("+", item.issue.key)
                    notify.info("Copied: " .. item.issue.key)
                end
            end,
            copy_url = function(_, item)
                if item and item.issue then
                    local base_url = config.options.auth.url
                    if not base_url:match("^https?://") then
                        base_url = "https://" .. base_url
                    end
                    local url = base_url .. "/browse/" .. item.issue.key
                    vim.fn.setreg("+", url)
                    notify.info("Copied: " .. url)
                end
            end,
            edit = function(picker, item)
                if item and item.issue then
                    picker:close()
                    local ui = require("jira-interface.ui")
                    ui.edit_issue(item.issue.key)
                end
            end,
            children = function(picker, item)
                if item and item.issue then
                    picker:close()
                    local ui = require("jira-interface.ui")
                    ui.show_children(item.issue.key)
                end
            end,
        },
        layout = {
            layout = {
                box = "vertical",
                backdrop = false,
                row = -1,
                width = 0,
                height = 0.4,
                border = "top",
                title = " {title} {live} {flags}",
                title_pos = "left",
                { win = "input", height = 1,     border = "bottom" },
                { win = "list",  border = "none" },
            },
        },
        preview = false,
        win = {
            input = {
                keys = {
                    ["<C-t>"] = { "transition", mode = { "n", "i" }, desc = "Transition status" },
                    ["<C-y>"] = { "copy_key", mode = { "n", "i" }, desc = "Copy issue key" },
                    ["<C-u>"] = { "copy_url", mode = { "n", "i" }, desc = "Copy issue URL" },
                    ["<C-e>"] = { "edit", mode = { "n", "i" }, desc = "Edit issue" },
                    ["<C-c>"] = { "children", mode = { "n", "i" }, desc = "Show children" },
                },
            },
        },
    })
end

---@param jql string
---@param opts? { title?: string, cache_key?: string }
function M.search(jql, opts)
    opts = opts or {}

    local function fetch_and_show()
        api.search(jql, function(err, issues)
            if err then
                notify.error("Jira search failed: " .. err)
                return
            end

            if opts.cache_key then
                cache.set(opts.cache_key, issues)
            end

            M.show_issues(issues, { title = opts.title })
        end)
    end

    -- Try cache first
    if opts.cache_key then
        local cached = cache.get(opts.cache_key)
        if cached then
            M.show_issues(cached, { title = opts.title })
            return
        end
    end

    fetch_and_show()
end

function M.assigned_to_me()
    local jql = filters.builtin.assigned_to_me()
    M.search(jql, { title = "Assigned to Me", cache_key = "assigned_to_me" })
end

function M.created_by_me()
    local jql = filters.builtin.created_by_me()
    M.search(jql, { title = "Created by Me", cache_key = "created_by_me" })
end

---@param project? string
function M.by_project(project)
    project = project or config.options.default_project
    if not project or project == "" then
        M.select_project()
        return
    end
    local jql = filters.builtin.by_project(project)
    M.search(jql, { title = "Project: " .. project, cache_key = "project_" .. project })
end

---@param level number
---@param project? string
function M.by_level(level, project)
    project = project or config.options.default_project
    local jql = filters.builtin.by_level(level, project)
    local titles = { [1] = "Epics", [2] = "Features/Bugs/Issues", [3] = "Tasks" }
    local title = titles[level] or ("Level " .. level)
    local cache_key = "level_" .. level
    if project and project ~= "" then
        title = title .. " (" .. project .. ")"
        cache_key = cache_key .. "_" .. project
    end
    M.search(jql, { title = title, cache_key = cache_key })
end

function M.search_all()
    -- Search all issues (the 'since' filter in api.lua bounds the query)
    local jql = "ORDER BY updated DESC"
    M.search(jql, { title = "All Issues", cache_key = "all_issues" })
end

-- Due date filters
function M.due_overdue()
    local project = config.options.default_project
    local jql = filters.builtin.overdue(project)
    M.search(jql, { title = "Overdue Issues", cache_key = "due_overdue" })
end

function M.due_today()
    local project = config.options.default_project
    local jql = filters.builtin.due_today(project)
    M.search(jql, { title = "Due Today", cache_key = "due_today" })
end

function M.due_this_week()
    local project = config.options.default_project
    local jql = filters.builtin.due_this_week(project)
    M.search(jql, { title = "Due This Week", cache_key = "due_week" })
end

function M.due_soon()
    local project = config.options.default_project
    local jql = filters.builtin.due_soon(project)
    M.search(jql, { title = "Due Soon (7 days)", cache_key = "due_soon" })
end

function M.by_duedate()
    local project = config.options.default_project
    local jql = filters.builtin.by_duedate(project)
    M.search(jql, { title = "By Due Date", cache_key = "by_duedate" })
end

function M.select_project()
    api.get_projects(function(err, projects)
        if err then
            notify.error("Failed to fetch projects: " .. err)
            return
        end

        if #projects == 0 then
            notify.warn("No projects found")
            return
        end

        local Snacks = require("snacks")

        local items = {}
        for idx, p in ipairs(projects) do
            table.insert(items, {
                idx = idx,
                text = p.key .. " " .. p.name,
                project = p,
                key = p.key,
                name = p.name,
            })
        end

        Snacks.picker.pick({
            title = "Select Project",
            items = items,
            layout = {
                layout = {
                    box = "vertical",
                    backdrop = false,
                    row = -1,
                    width = 0,
                    height = 0.4,
                    border = "top",
                    title = " {title} {live} {flags}",
                    title_pos = "left",
                    { win = "input", height = 1,     border = "bottom" },
                    { win = "list",  border = "none" },
                },
            },
            preview = false,
            format = function(item, _picker)
                return {
                    { pad_right(item.key, 10), "Special" },
                    { "  ",                    "Normal" },
                    { item.name,               "Normal" },
                }
            end,
            confirm = function(picker, item)
                picker:close()
                if item and item.project then
                    M.by_project(item.project.key)
                end
            end,
        })
    end)
end

function M.select_filter()
    local saved_filters = filters.list_all()

    if #saved_filters == 0 then
        notify.info("No saved filters")
        return
    end

    local Snacks = require("snacks")

    local items = {}
    for idx, f in ipairs(saved_filters) do
        local scope = f.project and ("[" .. f.project .. "]") or "[global]"
        table.insert(items, {
            idx = idx,
            text = f.name .. " " .. scope .. " " .. f.jql,
            filter = f,
            name = f.name,
            scope = scope,
            jql = f.jql,
            description = f.description,
        })
    end

    Snacks.picker.pick({
        title = "Select Filter",
        items = items,
        layout = {
            layout = {
                box = "vertical",
                backdrop = false,
                row = -1,
                width = 0,
                height = 0.4,
                border = "top",
                title = " {title} {live} {flags}",
                title_pos = "left",
                { win = "input", height = 1,     border = "bottom" },
                { win = "list",  border = "none" },
            },
        },
        preview = false,
        format = function(item, _picker)
            return {
                { pad_right(item.name, 20), "Function" },
                { "  ",                     "Normal" },
                { item.scope,               "Comment" },
            }
        end,
        confirm = function(picker, item)
            picker:close()
            if item and item.filter then
                M.search(item.filter.jql, { title = item.filter.name })
            end
        end,
    })
end

---@param type_name? string
---@param project? string
---@param parent_key? string
function M.create_issue(type_name, project, parent_key)
    project = project or config.options.default_project
    local opts = config.options

    -- If no project, prompt for one first
    if not project or project == "" then
        api.get_projects(function(err, projects)
            if err then
                notify.error("Failed to fetch projects: " .. err)
                return
            end

            local project_names = {}
            local project_map = {}
            for _, p in ipairs(projects) do
                table.insert(project_names, p.key .. " - " .. p.name)
                project_map[p.key .. " - " .. p.name] = p.key
            end

            vim.ui.select(project_names, { prompt = "Select project:" }, function(choice)
                if choice then
                    M.create_issue(type_name, project_map[choice], parent_key)
                end
            end)
        end)
        return
    end

    -- If no type specified, show picker
    if not type_name then
        local all_types = {}
        for _, t in ipairs(opts.types.lvl1) do
            table.insert(all_types, t)
        end
        for _, t in ipairs(opts.types.lvl2) do
            table.insert(all_types, t)
        end
        for _, t in ipairs(opts.types.lvl3) do
            table.insert(all_types, t)
        end

        vim.ui.select(all_types, { prompt = "Issue type:" }, function(choice)
            if choice then
                M.create_issue(choice, project, parent_key)
            end
        end)
        return
    end

    -- Show parent picker for non-epic types
    local level = types.get_level(type_name)
    if not parent_key and level > 1 then
        M.select_parent(project, level, function(selected_parent)
            M.open_create_buffer(project, type_name, selected_parent)
        end)
    else
        M.open_create_buffer(project, type_name, parent_key)
    end
end

---@param project string
---@param level number Current issue level (2 or 3)
---@param callback fun(parent_key: string|nil)
function M.select_parent(project, level, callback)
    -- Level 2 (Feature/Bug) -> parent should be Level 1 (Epic)
    -- Level 3 (Task) -> parent should be Level 2 (Feature/Bug)
    local parent_level = level - 1
    if parent_level < 1 then
        callback(nil)
        return
    end

    local jql = filters.builtin.by_level(parent_level, project)
    api.search(jql, function(err, issues)
        if err then
            notify.error("Failed to fetch parent issues: " .. err)
            callback(nil)
            return
        end

        if #issues == 0 then
            notify.info("No parent issues found")
            callback(nil)
            return
        end

        local Snacks = require("snacks")

        local items = { { idx = 0, text = "(No parent)", key = "", summary = "Create without parent" } }
        for idx, issue in ipairs(issues) do
            table.insert(items, {
                idx = idx,
                text = issue.key .. " " .. issue.summary,
                key = issue.key,
                summary = issue.summary,
            })
        end

        Snacks.picker.pick({
            title = "Select Parent Issue",
            items = items,
            layout = {
                layout = {
                    box = "vertical",
                    backdrop = false,
                    row = -1,
                    width = 0,
                    height = 0.4,
                    border = "top",
                    title = " {title} {live} {flags}",
                    title_pos = "left",
                    { win = "input", height = 1,     border = "bottom" },
                    { win = "list",  border = "none" },
                },
            },
            preview = false,
            format = function(item, _picker)
                return {
                    { pad_right(item.key or "(none)", 12), "Special" },
                    { "  ",                                "Normal" },
                    { item.summary or "",                  "Normal" },
                }
            end,
            confirm = function(picker, item)
                picker:close()
                if item then
                    callback(item.key ~= "" and item.key or nil)
                else
                    callback(nil)
                end
            end,
        })
    end)
end

---@param project string
---@param type_name string
---@param parent_key? string
function M.open_create_buffer(project, type_name, parent_key)
    local buf = vim.api.nvim_create_buf(false, false)
    local tmp_name = vim.fn.tempname() .. "_jira_create_" .. project .. "_" .. type_name .. ".md"
    vim.api.nvim_buf_set_name(buf, tmp_name)
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].buftype = "acwrite"
    vim.bo[buf].filetype = "markdown"

    -- Get template based on issue type
    local template = M.get_issue_template(type_name)

    local lines = {
        "# New " .. type_name,
        "",
        "## Summary",
        "",
        "",
        "## Description",
        "",
    }

    -- Add template description (skip if empty)
    if template.description and template.description ~= "" then
        for _, line in ipairs(vim.split(template.description, "\n")) do
            table.insert(lines, line)
        end
    end

    table.insert(lines, "")
    table.insert(lines, "## Acceptance Criteria")
    table.insert(lines, "")

    -- Add template acceptance criteria
    if template.acceptance_criteria and template.acceptance_criteria ~= "" then
        for _, line in ipairs(vim.split(template.acceptance_criteria, "\n")) do
            table.insert(lines, line)
        end
    end

    table.insert(lines, "")
    table.insert(lines, "---")
    table.insert(lines, string.format("Project: %s | Type: %s | Parent: %s", project, type_name, parent_key or "(none)"))
    table.insert(lines, "Save: :w | Cancel: :q!")

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

    local width = math.floor(vim.o.columns * 0.8)
    local height = math.floor(vim.o.lines * 0.8)

    local win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        width = width,
        height = height,
        col = math.floor((vim.o.columns - width) / 2),
        row = math.floor((vim.o.lines - height) / 2),
        style = "minimal",
        border = "rounded",
        title = " Create " .. type_name .. " ",
        title_pos = "center",
    })

    -- Position cursor on summary line
    vim.api.nvim_win_set_cursor(win, { 5, 0 })
    vim.bo[buf].modified = false

    -- Save handler
    vim.api.nvim_create_autocmd("BufWriteCmd", {
        buffer = buf,
        callback = function()
            local content = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
            local parsed = M.parse_create_buffer(content)

            if not parsed.summary or parsed.summary == "" then
                notify.error("Summary is required")
                return
            end

            if api.is_online then
                notify.progress_start("create_issue", "Creating " .. type_name)
                api.create_issue_full(project, type_name, parsed.summary, parsed.description, parsed.acceptance_criteria,
                    parent_key, function(err, issue)
                        if err then
                            notify.progress_error("create_issue", "Create failed: " .. err)
                        else
                            notify.progress_finish("create_issue", "Created: " .. issue.key)
                            vim.api.nvim_win_close(win, true)
                            cache.invalidate_project(project)
                            -- Open the created issue
                            local ui = require("jira-interface.ui")
                            ui.show_issue(issue)
                        end
                    end)
            else
                local queue = require("jira-interface.queue")
                queue.queue_create(project, type_name, parsed.summary, parsed.description, parent_key)
                vim.api.nvim_win_close(win, true)
            end
        end,
    })

    -- Close on q in normal mode (but not while editing)
    vim.keymap.set("n", "<leader>q", function()
        vim.api.nvim_win_close(win, true)
    end, { buffer = buf, desc = "Close without saving" })
end

---@param type_name string
---@return { description: string, acceptance_criteria: string }
function M.get_issue_template(type_name)
    local templates = config.options.templates or {}
    local template = templates[type_name:lower()] or templates.default or {}

    return {
        description = template.description or "<!-- Describe the issue here -->",
        acceptance_criteria = template.acceptance_criteria or "- [ ] Criteria 1\n- [ ] Criteria 2",
    }
end

---@param lines string[]
---@return { summary: string|nil, description: string|nil, acceptance_criteria: string|nil }
function M.parse_create_buffer(lines)
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
        elseif line:match("^# New") then
            -- Skip header
        elseif current_section then
            table.insert(section_lines, line)
        end
    end

    save_section()
    return result
end

return M
