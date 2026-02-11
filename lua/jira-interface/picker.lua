local M = {}

local api = require("jira-interface.api")
local types = require("jira-interface.types")
local cache = require("jira-interface.cache")
local filters = require("jira-interface.filters")
local config = require("jira-interface.config")
local notify = require("jira-interface.notify")
local createmeta = require("jira-interface.createmeta")
local atlassian_ui = require("atlassian.ui")
local atlassian_format = require("atlassian.format")
local csf = require("atlassian.csf")
local bridge = require("atlassian.csf.bridge")

-- Fixed column widths
local COL_KEY = 12
local COL_STATUS = 14
local COL_TYPE = 10
local COL_DUE = 20

-- Use shared UI helpers
local pad_right = atlassian_ui.pad_right

---@param issues JiraIssue[]
---@param opts? { title?: string, on_confirm?: fun(issue: JiraIssue) }
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
        local due_status = atlassian_format.get_duedate_status(issue.duedate)
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
            due_display = atlassian_format.format_duedate_relative(issue.duedate),
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
                if opts.on_confirm then
                    opts.on_confirm(item.issue)
                else
                    local ui = require("jira-interface.ui")
                    ui.view(item.issue.key)
                end
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
    local show_opts = { title = opts.title, on_confirm = opts.on_confirm }

    local function fetch_and_show()
        api.search(jql, function(err, issues)
            if err then
                notify.error("Jira search failed: " .. err)
                return
            end

            if opts.cache_key then
                cache.set(opts.cache_key, issues)
            end

            M.show_issues(issues, show_opts)
        end)
    end

    -- Try cache first
    if opts.cache_key then
        local cached = cache.get(opts.cache_key)
        if cached then
            M.show_issues(cached, show_opts)
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
    -- Prompt for a search query, then do server-side text search via JQL
    vim.ui.input({ prompt = "Search Jira issues: " }, function(query)
        if not query or query == "" then
            return
        end

        local escaped = query:gsub('"', '\\"')
        local project = config.options.default_project
        local jql
        if project and project ~= "" then
            jql = string.format('project = "%s" AND text ~ "%s" ORDER BY updated DESC', project, escaped)
        else
            jql = string.format('text ~ "%s" ORDER BY updated DESC', escaped)
        end

        M.search(jql, { title = "Search: " .. query })
    end)
end

function M.search_all_edit()
    vim.ui.input({ prompt = "Search Jira issues (edit): " }, function(query)
        if not query or query == "" then
            return
        end

        local escaped = query:gsub('"', '\\"')
        local project = config.options.default_project
        local jql
        if project and project ~= "" then
            jql = string.format('project = "%s" AND text ~ "%s" ORDER BY updated DESC', project, escaped)
        else
            jql = string.format('text ~ "%s" ORDER BY updated DESC', escaped)
        end

        M.search(jql, {
            title = "Edit: " .. query,
            on_confirm = function(issue)
                local ui = require("jira-interface.ui")
                ui.edit_issue(issue.key)
            end,
        })
    end)
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

-- Module-level storage for create buffer metadata (avoids vim.b serialization issues)
local create_buf_meta = {}

---@param type_name? string
---@param project? string
---@param parent_key? string
function M.create_issue(type_name, project, parent_key)
    project = project or config.options.default_project

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

    -- Fetch issue types from server (with cache)
    createmeta.get_issue_types(project, function(err, issue_types)
        if err then
            notify.error("Failed to fetch issue types: " .. tostring(err))
            return
        end

        if not issue_types or #issue_types == 0 then
            notify.error("No issue types available")
            return
        end

        -- If type_name was provided, find matching server type
        if type_name then
            local matched
            for _, it in ipairs(issue_types) do
                if it.name:lower() == type_name:lower() then
                    matched = it
                    break
                end
            end
            if matched then
                M.after_type_selected(project, matched, parent_key)
            else
                notify.error("Issue type '" .. type_name .. "' not found")
            end
            return
        end

        -- Show picker with server-sourced types
        local display_names = {}
        local type_map = {}
        for _, it in ipairs(issue_types) do
            local label = it.name
            if it.subtask then
                label = label .. " (subtask)"
            end
            table.insert(display_names, label)
            type_map[label] = it
        end

        vim.ui.select(display_names, { prompt = "Issue type:" }, function(choice)
            if choice then
                M.after_type_selected(project, type_map[choice], parent_key)
            end
        end)
    end)
end

---@param project string
---@param issue_type CreateMetaIssueType
---@param parent_key? string
function M.after_type_selected(project, issue_type, parent_key)
    -- Determine if parent selection is needed
    local needs_parent = not parent_key
        and (issue_type.subtask or issue_type.hierarchyLevel < 0
            or (issue_type.hierarchyLevel == 0 and types.get_level(issue_type.name) > 1))

    if needs_parent then
        M.select_parent(project, issue_type, function(selected_parent)
            M.proceed_to_fields(project, issue_type, selected_parent)
        end)
    else
        M.proceed_to_fields(project, issue_type, parent_key)
    end
end

---@param project string
---@param issue_type CreateMetaIssueType
---@param parent_key? string
function M.proceed_to_fields(project, issue_type, parent_key)
    createmeta.get_fields(project, issue_type.id, function(err, server_fields)
        if err then
            notify.error("Failed to fetch fields: " .. tostring(err))
            return
        end

        local classified = createmeta.classify_all(server_fields or {})

        -- Run picker chain for option fields, then open buffer
        if #classified.picker > 0 then
            M.run_picker_chain(classified.picker, {}, function(picker_values)
                M.open_create_buffer(project, issue_type, parent_key, classified, picker_values)
            end)
        else
            M.open_create_buffer(project, issue_type, parent_key, classified, {})
        end
    end)
end

---@param picker_fields ClassifiedField[]
---@param values table Accumulated picker selections (fieldId → API value)
---@param callback fun(values: table)
function M.run_picker_chain(picker_fields, values, callback)
    if #picker_fields == 0 then
        callback(values)
        return
    end

    local field = picker_fields[1]
    local remaining = { unpack(picker_fields, 2) }
    local allowed = field.allowedValues or {}

    if #allowed == 0 then
        -- No allowed values to pick from, skip
        M.run_picker_chain(remaining, values, callback)
        return
    end

    local display_names = {}
    local value_map = {}

    -- Optional fields get a skip option
    if not field.required then
        table.insert(display_names, "(skip)")
        value_map["(skip)"] = nil
    end

    for _, av in ipairs(allowed) do
        local label = av.name or av.value or tostring(av.id)
        table.insert(display_names, label)
        value_map[label] = av
    end

    local prompt = field.name
    if field.required then
        prompt = prompt .. " (required)"
    end

    vim.ui.select(display_names, { prompt = prompt .. ":" }, function(choice)
        if not choice then
            -- User cancelled: if required, abort; otherwise skip
            if field.required then
                notify.warn("Required field '" .. field.name .. "' was not selected, aborting")
                return
            end
        elseif choice ~= "(skip)" and value_map[choice] then
            values[field.fieldId] = createmeta.serialize_picker_value(field, value_map[choice])
        end

        M.run_picker_chain(remaining, values, callback)
    end)
end

---@param project string
---@param issue_type CreateMetaIssueType
---@param callback fun(parent_key: string|nil)
function M.select_parent(project, issue_type, callback)
    -- Build JQL for potential parents
    -- Use hierarchyLevel: if current type is subtask/level<=0, parents are level 0+
    -- For fallback types, use config-based level logic
    local jql
    local level = types.get_level(issue_type.name)
    if level > 1 then
        local parent_level = level - 1
        jql = filters.builtin.by_level(parent_level, project)
    else
        -- Generic: search open issues in project as potential parents
        if project and project ~= "" then
            jql = string.format('project = "%s" AND status != Done ORDER BY updated DESC', project)
        else
            jql = 'status != Done ORDER BY updated DESC'
        end
    end

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
---@param issue_type CreateMetaIssueType
---@param parent_key? string
---@param classified ClassifiedFields
---@param picker_values table<string, any> Picker field selections (fieldId → API value)
function M.open_create_buffer(project, issue_type, parent_key, classified, picker_values)
    local buf = vim.api.nvim_create_buf(false, false)
    local tmp_name = vim.fn.tempname() .. "_jira_create_" .. project .. "_" .. issue_type.name .. ".csf"
    vim.api.nvim_buf_set_name(buf, tmp_name)
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].buftype = "acwrite"
    vim.bo[buf].filetype = "csf"

    -- CSF metadata line + template from classified fields
    local meta_line = csf.generate_metadata({
        type = "jira", key = "NEW", project = project, issue_type = issue_type.name,
    })
    local template_lines = createmeta.generate_template(classified, issue_type.name)
    table.insert(template_lines, 1, meta_line)

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, template_lines)

    -- Store metadata in module-level table (not vim.b, to avoid serialization issues)
    create_buf_meta[buf] = {
        project = project,
        issue_type = issue_type,
        parent_key = parent_key,
        classified = classified,
        picker_values = picker_values,
    }

    -- Cleanup on buffer wipe
    vim.api.nvim_create_autocmd("BufWipeout", {
        buffer = buf,
        once = true,
        callback = function()
            create_buf_meta[buf] = nil
        end,
    })

    vim.api.nvim_set_current_buf(buf)
    atlassian_ui.apply_window_options(buf, vim.api.nvim_get_current_win(), config.options.display)
    vim.bo[buf].modified = false

    -- Save handler
    vim.api.nvim_create_autocmd("BufWriteCmd", {
        buffer = buf,
        callback = function()
            -- Exit snippet session if active
            local ls_ok2, ls = pcall(require, "luasnip")
            if ls_ok2 and ls.get_active_snip() then
                ls.unlink_current()
            end

            local meta = create_buf_meta[buf]
            if not meta then
                notify.error("Buffer metadata lost")
                return
            end

            -- Extract all fields from buffer using createmeta
            local fields = createmeta.extract_fields_from_buffer(buf, meta.classified)

            if not fields.summary or fields.summary == "" or fields.summary == meta.issue_type.name then
                notify.error("Summary is required (edit the <h1> title)")
                return
            end

            -- Add project and issuetype
            fields.project = { key = meta.project }
            fields.issuetype = { id = meta.issue_type.id }

            -- Add parent if specified
            if meta.parent_key then
                fields.parent = { key = meta.parent_key }
            end

            -- Merge picker values
            for field_id, value in pairs(meta.picker_values or {}) do
                fields[field_id] = value
            end

            if api.is_online then
                notify.progress_start("create_issue", "Creating " .. meta.issue_type.name)
                api.create_issue_with_fields(fields, function(create_err, issue)
                    if create_err then
                        notify.progress_error("create_issue", "Create failed: " .. tostring(create_err))
                    else
                        notify.progress_finish("create_issue", "Created: " .. issue.key)
                        if vim.api.nvim_buf_is_valid(buf) then
                            vim.api.nvim_buf_delete(buf, { force = true })
                        end
                        cache.invalidate_project(meta.project)
                        local ui = require("jira-interface.ui")
                        ui.show_issue(issue)
                    end
                end)
            else
                -- Offline: queue with summary + description only
                local desc_csf = nil
                local content = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
                table.remove(content, 1) -- metadata
                local _, remaining = csf.extract_title(content)
                local parsed = csf.extract_sections(remaining, { "description" })
                if parsed.description and parsed.description ~= "" then
                    desc_csf = parsed.description
                end

                local queue = require("jira-interface.queue")
                queue.queue_create(meta.project, meta.issue_type.name, fields.summary, desc_csf, meta.parent_key)
                if vim.api.nvim_buf_is_valid(buf) then
                    vim.api.nvim_buf_delete(buf, { force = true })
                end
            end
        end,
    })
end

return M
