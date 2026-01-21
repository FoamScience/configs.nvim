local M = {}

local api = require("jira-interface.api")
local config = require("jira-interface.config")
local notify = require("jira-interface.notify")
local types = require("jira-interface.types")

---@class TodoItem
---@field file string
---@field lnum number
---@field col number
---@field keyword string
---@field text string

---@param scope? "buffer"|"project"
---@param callback fun(todos: TodoItem[])
function M.get_todos(scope, callback)
    scope = scope or "buffer"

    local has_todo_comments, todo_search = pcall(require, "todo-comments.search")
    if not has_todo_comments then
        notify.error("todo-comments.nvim is required for this feature")
        callback({})
        return
    end

    local cwd = vim.fn.getcwd()
    local current_file = vim.fn.expand("%:p") -- Absolute path of current buffer

    -- Search using todo-comments
    todo_search.search(function(results)
        local todos = {}

        for _, item in ipairs(results) do
            -- Normalize the filename to absolute path
            -- item.filename from todo-comments can be relative or absolute
            local abs_path = vim.fn.fnamemodify(item.filename, ":p")

            -- For buffer scope, filter to current file only
            local include = (scope == "project") or (abs_path == current_file)

            if include then
                -- Get relative path for display
                local rel_file = vim.fn.fnamemodify(item.filename, ":.")

                table.insert(todos, {
                    file = rel_file,
                    full_path = abs_path,
                    lnum = item.lnum,
                    col = item.col,
                    keyword = item.tag,
                    text = item.message or item.text or "",
                })
            end
        end

        callback(todos)
    end, { cwd = cwd, disable_not_found_warnings = true })
end

---@param scope? "buffer"|"project"
function M.todo_to_issue(scope)
    scope = scope or "buffer"

    notify.progress_start("todos", "Searching for TODOs")

    M.get_todos(scope, function(todos)
        notify.progress_finish("todos")

        if #todos == 0 then
            notify.info("No TODO comments found" .. (scope == "buffer" and " in current buffer" or ""))
            return
        end

        M.show_todo_picker(todos)
    end)
end

---@param todos TodoItem[]
function M.show_todo_picker(todos)
    local Snacks = require("snacks")

    local items = {}
    for idx, todo in ipairs(todos) do
        table.insert(items, {
            idx = idx,
            text = todo.file .. ":" .. todo.lnum .. " @" .. todo.keyword .. ": " .. todo.text,
            todo = todo,
            file = todo.file,
            lnum = todo.lnum,
            keyword = todo.keyword,
            todo_text = todo.text,
            selected = false,
        })
    end

    -- Track selections
    local selected = {}

    Snacks.picker.pick({
        title = "Select TODOs to Convert (" .. #todos .. " found)",
        items = items,
        format = function(item, _picker)
            local ret = {}
            -- Selection indicator
            local is_selected = selected[item.idx]
            table.insert(ret, { is_selected and "[x] " or "[ ] ", is_selected and "String" or "Comment" })
            -- Location
            table.insert(ret, { item.file .. ":" .. item.lnum, "Comment" })
            table.insert(ret, { "  ", "Normal" })
            -- Keyword with color
            local keyword_hl = "WarningMsg"
            if item.keyword == "FIX" then keyword_hl = "ErrorMsg" end
            if item.keyword == "NOTE" then keyword_hl = "DiagnosticInfo" end
            table.insert(ret, { "@" .. item.keyword .. ": ", keyword_hl })
            -- Text
            table.insert(ret, { item.todo_text, "Normal" })
            return ret
        end,
        confirm = function(picker, item)
            -- On confirm, proceed with selected items
            local selected_todos = {}
            for idx, _ in pairs(selected) do
                table.insert(selected_todos, todos[idx])
            end

            if #selected_todos == 0 then
                -- If nothing selected, use current item
                if item and item.todo then
                    selected_todos = { item.todo }
                end
            end

            if #selected_todos > 0 then
                picker:close()
                M.show_parent_picker(selected_todos)
            else
                notify.warn("No TODOs selected")
            end
        end,
        actions = {
            toggle = function(picker, item)
                if item then
                    if selected[item.idx] then
                        selected[item.idx] = nil
                    else
                        selected[item.idx] = true
                    end
                    -- Refresh display
                    picker:refresh()
                end
            end,
            select_all = function(picker, _)
                for _, item in ipairs(items) do
                    selected[item.idx] = true
                end
                picker:refresh()
            end,
            select_none = function(picker, _)
                selected = {}
                picker:refresh()
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
                { win = "input", height = 1, border = "bottom" },
                { win = "list", border = "none" },
            },
        },
        preview = false,
        win = {
            input = {
                keys = {
                    ["<Tab>"] = { "toggle", mode = { "n", "i" }, desc = "Toggle selection" },
                    ["<C-a>"] = { "select_all", mode = { "n", "i" }, desc = "Select all" },
                    ["<C-n>"] = { "select_none", mode = { "n", "i" }, desc = "Select none" },
                },
            },
        },
    })
end

---@param selected_todos TodoItem[]
function M.show_parent_picker(selected_todos)
    local project = config.options.default_project
    local context = require("jira-interface.context")

    if not project or project == "" then
        notify.error("No default project configured")
        return
    end

    -- Try to detect parent from branch
    local branch_key = context.get_issue_from_branch()

    notify.progress_start("load_tasks", "Loading your Tasks")

    -- Get Tasks (level 3) assigned to current user
    local jql = 'assignee = currentUser() AND issuetype = Task AND status != Done ORDER BY updated DESC'
    api.search(jql, function(err, tasks)
        notify.progress_finish("load_tasks")

        if err then
            notify.error("Failed to load tasks: " .. err)
            return
        end

        if #tasks == 0 then
            notify.warn("No active Tasks found. Create a Task first to attach Sub-Tasks.")
            return
        end

        -- If branch has issue key, try to auto-select it
        if branch_key then
            for _, task in ipairs(tasks) do
                if task.key == branch_key then
                    notify.info("Auto-selected parent from branch: " .. branch_key)
                    M.create_subtasks(selected_todos, task)
                    return
                end
            end
            -- Branch key not in tasks list, fall through to picker
        end

        M.show_task_picker(selected_todos, tasks)
    end)
end

---@param selected_todos TodoItem[]
---@param tasks JiraIssue[]
function M.show_task_picker(selected_todos, tasks)
    local Snacks = require("snacks")

    local items = {}
    for idx, task in ipairs(tasks) do
        local status_info = types.get_status_display(task.status)
        table.insert(items, {
            idx = idx,
            text = task.key .. " " .. task.status .. " " .. task.summary,
            task = task,
            key = task.key,
            status = task.status,
            status_icon = status_info.icon,
            status_hl = status_info.hl,
            summary = task.summary,
        })
    end

    Snacks.picker.pick({
        title = "Select Parent Task for " .. #selected_todos .. " Sub-Task(s)",
        items = items,
        format = function(item, _picker)
            local ret = {}
            table.insert(ret, { item.key, "Special" })
            table.insert(ret, { "  ", "Normal" })
            table.insert(ret, { item.status_icon .. " ", item.status_hl })
            table.insert(ret, { item.status, item.status_hl })
            table.insert(ret, { "  ", "Normal" })
            table.insert(ret, { item.summary, "Normal" })
            return ret
        end,
        confirm = function(picker, item)
            if item and item.task then
                picker:close()
                M.create_subtasks(selected_todos, item.task)
            end
        end,
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
                { win = "input", height = 1, border = "bottom" },
                { win = "list", border = "none" },
            },
        },
        preview = false,
    })
end

---@param todos TodoItem[]
---@param parent_task JiraIssue
function M.create_subtasks(todos, parent_task)
    local project = parent_task.project
    local created = {}
    local failed = {}
    local pending = #todos

    notify.progress_start("create_subtasks", "Creating " .. pending .. " Sub-Task(s)")

    local function on_complete()
        pending = pending - 1
        notify.progress_update("create_subtasks",
            "Created " .. #created .. "/" .. (#created + #failed + pending))

        if pending == 0 then
            if #failed > 0 then
                notify.progress_error("create_subtasks",
                    "Created " .. #created .. ", failed " .. #failed)
            else
                notify.progress_finish("create_subtasks",
                    "Created " .. #created .. " Sub-Task(s)")
            end

            -- Show summary
            if #created > 0 then
                local keys = {}
                for _, c in ipairs(created) do
                    table.insert(keys, c.key)
                end
                notify.info("Created: " .. table.concat(keys, ", "))
            end
        end
    end

    for _, todo in ipairs(todos) do
        local summary = todo.text
        -- Truncate if too long
        if #summary > 200 then
            summary = summary:sub(1, 197) .. "..."
        end

        local description = string.format(
            "**Source:** `%s:%d`\n\n**Original comment:**\n> @%s: %s\n\n---\n_Created from code via jira-interface_",
            todo.file,
            todo.lnum,
            todo.keyword,
            todo.text
        )

        api.create_issue(project, "Sub-Task", summary, description, parent_task.key, function(err, issue)
            if err then
                table.insert(failed, { todo = todo, error = err })
            else
                table.insert(created, { todo = todo, key = issue.key })
            end
            on_complete()
        end)
    end
end

return M
