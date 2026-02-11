local M = {}

local config = require("jira-interface.config")
local notify = require("jira-interface.notify")

---@param opts? JiraConfig
function M.setup(opts)
    config.setup(opts)

    -- Validate configuration
    local valid, err = config.validate()
    if not valid then
        notify.warn("jira-interface: " .. err)
    end

    -- Register commands
    M.create_commands()

    -- Check for pending offline edits on startup
    vim.defer_fn(function()
        local queue = require("jira-interface.queue")
        if queue.count() > 0 then
            queue.prompt_sync(function() end)
        end
    end, 2000)
end

function M.create_commands()
    local cmd = vim.api.nvim_create_user_command

    -- Utility commands
    cmd("JiraClearCache", function()
        local cache = require("jira-interface.cache")
        cache.clear()
        notify.info("Jira cache cleared")
    end, { desc = "Clear Jira cache" })

    -- Search commands
    cmd("JiraSearch", function()
        local picker = require("jira-interface.picker")
        picker.search_all()
    end, { desc = "Search Jira issues" })

    cmd("JiraMe", function()
        local picker = require("jira-interface.picker")
        picker.assigned_to_me()
    end, { desc = "Show issues assigned to me" })

    cmd("JiraCreatedByMe", function()
        local picker = require("jira-interface.picker")
        picker.created_by_me()
    end, { desc = "Show issues created by me" })

    cmd("JiraProject", function(args)
        local picker = require("jira-interface.picker")
        if args.args and args.args ~= "" then
            picker.by_project(args.args)
        else
            picker.select_project()
        end
    end, { nargs = "?", desc = "Filter by project" })

    -- Hierarchy commands
    cmd("JiraEpics", function()
        local picker = require("jira-interface.picker")
        picker.by_level(1)
    end, { desc = "Show Epics (Level 1)" })

    cmd("JiraFeatures", function()
        local picker = require("jira-interface.picker")
        picker.by_level(2)
    end, { desc = "Show Features/Bugs/Issues (Level 2)" })

    cmd("JiraTasks", function()
        local picker = require("jira-interface.picker")
        picker.by_level(3)
    end, { desc = "Show Tasks (Level 3)" })

    -- Due date commands
    cmd("JiraDue", function(args)
        local picker = require("jira-interface.picker")
        local subcommand = args.args or ""

        if subcommand == "overdue" then
            picker.due_overdue()
        elseif subcommand == "today" then
            picker.due_today()
        elseif subcommand == "week" then
            picker.due_this_week()
        elseif subcommand == "soon" then
            picker.due_soon()
        else
            -- Default: show all with due dates sorted
            picker.by_duedate()
        end
    end, {
        nargs = "?",
        desc = "Filter by due date (overdue|today|week|soon)",
        complete = function()
            return { "overdue", "today", "week", "soon" }
        end,
    })

    -- Issue commands
    cmd("JiraView", function(args)
        local context = require("jira-interface.context")
        local ui = require("jira-interface.ui")
        context.resolve_issue_key_or_pick(args.args, function(key)
            ui.view(key)
        end)
    end, { nargs = "?", desc = "View issue details" })

    cmd("JiraTransition", function(args)
        local context = require("jira-interface.context")
        local ui = require("jira-interface.ui")
        context.resolve_issue_key_or_pick(args.args, function(key)
            ui.show_transition_picker(key)
        end)
    end, { nargs = "?", desc = "Transition issue status" })

    -- Helper for quick transitions
    local function quick_transition(target_status, args)
        local context = require("jira-interface.context")
        local jira_api = require("jira-interface.api")

        context.resolve_issue_key_or_pick(args, function(key)
            jira_api.get_transitions(key, function(err, transitions)
                if err then
                    notify.error("Failed to get transitions: " .. err)
                    return
                end

                -- Find transition that leads to target status
                local target_lower = target_status:lower()
                local match = nil
                for _, t in ipairs(transitions) do
                    if t.to:lower() == target_lower or t.name:lower():match(target_lower) then
                        match = t
                        break
                    end
                end

                if not match then
                    notify.warn("No transition to '" .. target_status .. "' available for " .. key)
                    return
                end

                jira_api.do_transition(key, match.id, function(trans_err)
                    if trans_err then
                        notify.error("Transition failed: " .. trans_err)
                    else
                        notify.info(key .. " -> " .. match.to)
                    end
                end)
            end)
        end)
    end

    cmd("JiraStart", function(args)
        quick_transition("In Progress", args.args)
    end, { nargs = "?", desc = "Transition to In Progress" })

    cmd("JiraDone", function(args)
        quick_transition("Done", args.args)
    end, { nargs = "?", desc = "Transition to Done" })

    cmd("JiraReview", function(args)
        quick_transition("In Review", args.args)
    end, { nargs = "?", desc = "Transition to In Review" })

    cmd("JiraEdit", function(args)
        local context = require("jira-interface.context")
        local ui = require("jira-interface.ui")
        context.resolve_issue_key_or_pick(args.args, function(key)
            ui.edit_issue(key)
        end)
    end, { nargs = "?", desc = "Edit issue" })

    cmd("JiraCreate", function(args)
        local picker = require("jira-interface.picker")
        local issue_type = args.args ~= "" and args.args or nil
        picker.create_issue(issue_type)
    end, { nargs = "?", desc = "Create new issue" })

    cmd("JiraSearchEdit", function()
        local picker = require("jira-interface.picker")
        picker.search_all_edit()
    end, { desc = "Search issues and edit" })

    cmd("JiraQuick", function(args)
        local context = require("jira-interface.context")
        local jira_api = require("jira-interface.api")

        local summary = args.args
        if not summary or summary == "" then
            notify.error("Usage: :JiraQuick <summary>")
            return
        end

        local parent_key = context.get_issue_from_branch()
        if not parent_key then
            notify.error("No issue detected from branch. Use :JiraCreate instead.")
            return
        end

        -- Get the parent issue to determine project
        jira_api.get_issue(parent_key, function(err, parent_issue)
            if err then
                notify.error("Failed to fetch parent issue: " .. err)
                return
            end

            local project = parent_issue.project
            notify.progress_start("quick_create", "Creating Sub-Task")

            jira_api.create_issue(project, "Sub-Task", summary, nil, parent_key, function(create_err, issue)
                if create_err then
                    notify.progress_error("quick_create", "Failed: " .. create_err)
                else
                    notify.progress_finish("quick_create", "Created: " .. issue.key)
                end
            end)
        end)
    end, { nargs = "+", desc = "Quick create Sub-Task under branch issue" })

    -- Filter commands
    cmd("JiraFilter", function(args)
        local subcommand = args.fargs[1]
        local name = args.fargs[2]

        if subcommand == "save" then
            if not name then
                notify.error("Usage: :JiraFilter save <name>")
                return
            end
            vim.ui.input({ prompt = "JQL: " }, function(jql)
                if jql and jql ~= "" then
                    vim.ui.input({ prompt = "Description (optional): " }, function(desc)
                        local filters = require("jira-interface.filters")
                        filters.save(name, jql, config.options.default_project, desc)
                    end)
                end
            end)
        elseif subcommand == "load" then
            if name then
                local filters = require("jira-interface.filters")
                local filter = filters.get(name, config.options.default_project)
                if filter then
                    local picker = require("jira-interface.picker")
                    picker.search(filter.jql, { title = filter.name })
                else
                    notify.error("Filter not found: " .. name)
                end
            else
                local picker = require("jira-interface.picker")
                picker.select_filter()
            end
        elseif subcommand == "list" then
            local filters = require("jira-interface.filters")
            local all = filters.list_all()
            if #all == 0 then
                notify.info("No saved filters")
            else
                local lines = { "Saved Filters:" }
                for _, f in ipairs(all) do
                    table.insert(lines, string.format("  %s%s", f.name, f.project and (" [" .. f.project .. "]") or ""))
                end
                notify.info(table.concat(lines, "\n"))
            end
        elseif subcommand == "delete" then
            if not name then
                notify.error("Usage: :JiraFilter delete <name>")
                return
            end
            local filters = require("jira-interface.filters")
            if not filters.delete(name, config.options.default_project) then
                notify.error("Filter not found: " .. name)
            end
        else
            local picker = require("jira-interface.picker")
            picker.select_filter()
        end
    end, {
        nargs = "*",
        desc = "Manage JQL filter presets",
        complete = function(_, cmdline, _)
            local parts = vim.split(cmdline, "%s+")
            if #parts == 2 then
                return { "save", "load", "list", "delete" }
            elseif #parts == 3 and (parts[2] == "load" or parts[2] == "delete") then
                local filters = require("jira-interface.filters")
                local all = filters.list_all()
                local names = {}
                for _, f in ipairs(all) do
                    table.insert(names, f.name)
                end
                return names
            end
            return {}
        end,
    })

    -- Queue commands
    cmd("JiraQueue", function()
        local ui = require("jira-interface.ui")
        ui.show_queue()
    end, { desc = "View offline edit queue" })

    cmd("JiraSync", function()
        local queue = require("jira-interface.queue")
        queue.sync_all(function(results)
            local success = 0
            local failed = 0
            for _, r in ipairs(results) do
                if r.success then
                    success = success + 1
                else
                    failed = failed + 1
                    notify.error(string.format("Failed: %s - %s", r.description, r.error))
                end
            end
            if success > 0 or failed > 0 then
                notify.info(string.format("Sync: %d succeeded, %d failed", success, failed))
            else
                notify.info("Nothing to sync")
            end
        end)
    end, { desc = "Sync offline edits" })

    -- Team dashboard
    cmd("JiraTeam", function(args)
        local team = require("jira-interface.team")
        local project = args.args ~= "" and args.args or nil
        team.show_team_dashboard(project)
    end, { nargs = "?", desc = "Show team workload dashboard" })

    -- Board commands
    cmd("JiraBoard", function(args)
        local board = require("jira-interface.board")
        local board_id = args.args ~= "" and tonumber(args.args) or nil
        board.show_board(board_id)
    end, { nargs = "?", desc = "Show Kanban board view" })

    cmd("JiraSprint", function(args)
        local board = require("jira-interface.board")
        local board_id = args.args ~= "" and tonumber(args.args) or nil
        board.show_sprint(board_id)
    end, { nargs = "?", desc = "Show sprint board view" })

    -- TODO to Issue conversion
    cmd("JiraTodoToIssue", function(args)
        local todo = require("jira-interface.todo")
        local scope = args.args == "project" and "project" or "buffer"
        todo.todo_to_issue(scope)
    end, {
        nargs = "?",
        desc = "Convert TODO comments to Jira Sub-Tasks",
        complete = function()
            return { "buffer", "project" }
        end,
    })

    -- Utility commands
    cmd("JiraRefresh", function()
        local cache = require("jira-interface.cache")
        cache.clear()
        notify.info("Jira cache cleared")
    end, { desc = "Clear cache and refresh" })

    cmd("JiraStatus", function()
        local ui = require("jira-interface.ui")
        ui.show_status()
    end, { desc = "Show connection status" })

    cmd("JiraHelp", function()
        vim.cmd("help atlassian-jira-keymaps")
    end, { desc = "Show help" })

    cmd("JiraTest", function(args)
        local tests = require("jira-interface.tests")
        local mode = args.args

        if mode == "api" or mode == "integration" then
            tests.run_integration()
        elseif mode == "all" then
            tests.run_all()
        else
            tests.run()
        end
    end, {
        nargs = "?",
        desc = "Run tests (unit|api|all)",
        complete = function()
            return { "unit", "api", "all" }
        end,
    })

    cmd("JiraDebug", function(args)
        local key = args.args
        if not key or key == "" then
            -- Test connectivity
            local jira_api = require("jira-interface.api")
            jira_api.check_connectivity(function(online)
                if online then
                    notify.info("Jira API: Connected")
                else
                    notify.error("Jira API: Connection failed")
                end
            end)
        else
            -- Fetch raw issue for debugging
            local jira_api = require("jira-interface.api")
            jira_api.request("/issue/" .. key, "GET", nil, function(err, data)
                if err then
                    notify.error("Error: " .. err)
                else
                    -- Show raw response in a new buffer
                    local buf = vim.api.nvim_create_buf(false, true)
                    vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(vim.inspect(data), "\n"))
                    vim.bo[buf].filetype = "lua"
                    vim.cmd("vsplit")
                    vim.api.nvim_win_set_buf(0, buf)
                end
            end)
        end
    end, { nargs = "?", desc = "Debug: test connection or fetch raw issue" })

    cmd("JiraFields", function(args)
        local context = require("jira-interface.context")
        context.resolve_issue_key_or_pick(args.args, function(key)
            local jira_api = require("jira-interface.api")
            jira_api.request("/issue/" .. key, "GET", nil, function(err, data)
            if err then
                notify.error("Error: " .. err)
                return
            end

            local fields = data.fields or {}
            local lines = {
                "<h1>Fields for " .. key .. "</h1>",
                "<h2>Custom Fields (look for acceptance criteria here)</h2>",
            }

            -- Helper to extract text from ADF
            local function adf_preview(adf)
                if not adf or not adf.content then return "[empty ADF]" end
                local texts = {}
                local function extract(node)
                    if not node then return end
                    if node.text then table.insert(texts, node.text) end
                    if node.content then
                        for _, child in ipairs(node.content) do
                            extract(child)
                        end
                    end
                end
                for _, node in ipairs(adf.content) do
                    extract(node)
                end
                local result = table.concat(texts, " "):gsub("%s+", " ")
                return result:sub(1, 100) .. (result:len() > 100 and "..." or "")
            end

            -- Collect and sort custom fields
            local custom_fields = {}
            for field_name, value in pairs(fields) do
                if field_name:match("^customfield_") then
                    local preview = ""
                    if type(value) == "string" then
                        preview = value:sub(1, 80):gsub("\n", " ")
                    elseif type(value) == "table" then
                        if value.content then
                            -- ADF document - extract text preview
                            preview = "[ADF] " .. adf_preview(value)
                        elseif value.filename then
                            -- Attachment
                            preview = "[Attachment] " .. value.filename
                        elseif value[1] then
                            -- Array
                            local items = {}
                            for _, item in ipairs(value) do
                                if type(item) == "table" and item.filename then
                                    table.insert(items, item.filename)
                                elseif type(item) == "table" and item.name then
                                    table.insert(items, item.name)
                                elseif type(item) == "string" then
                                    table.insert(items, item)
                                end
                            end
                            preview = "[Array] " .. table.concat(items, ", "):sub(1, 60)
                        else
                            preview = vim.inspect(value):sub(1, 80):gsub("\n", " ")
                        end
                    elseif value == vim.NIL or value == nil then
                        preview = "(empty)"
                    else
                        preview = tostring(value)
                    end
                    table.insert(custom_fields, { name = field_name, preview = preview, value = value })
                end
            end

            table.sort(custom_fields, function(a, b) return a.name < b.name end)

            for _, cf in ipairs(custom_fields) do
                if cf.preview ~= "(empty)" then
                    table.insert(lines, string.format("<p><strong>%s</strong>: %s</p>", cf.name, cf.preview))
                end
            end

            table.insert(lines, "<hr />")
            table.insert(lines, "<h2>Standard Fields</h2>")

            local standard = { "summary", "description", "status", "issuetype", "project", "assignee", "parent",
                "created", "updated" }
            for _, fname in ipairs(standard) do
                local value = fields[fname]
                local preview = ""
                if type(value) == "string" then
                    preview = value:sub(1, 60)
                elseif type(value) == "table" and value.name then
                    preview = value.name
                elseif type(value) == "table" and value.key then
                    preview = value.key
                elseif value == vim.NIL or value == nil then
                    preview = "(empty)"
                else
                    preview = type(value)
                end
                table.insert(lines, string.format("<p><strong>%s</strong>: %s</p>", fname, preview))
            end

            -- Show in float
            local buf = vim.api.nvim_create_buf(false, true)
            vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
            vim.bo[buf].filetype = "csf"
            vim.bo[buf].bufhidden = "wipe"

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
                title = " Fields: " .. key .. " ",
                title_pos = "center",
            })

            vim.keymap.set("n", "q", function() vim.api.nvim_win_close(win, true) end, { buffer = buf })
            vim.keymap.set("n", "<Esc>", function() vim.api.nvim_win_close(win, true) end, { buffer = buf })
            end)
        end)
    end, { nargs = "?", desc = "List all fields for an issue to find custom field names" })

    cmd("JiraTypes", function(args)
        local jira_api = require("jira-interface.api")
        local project = args.args ~= "" and args.args or config.options.default_project

        if project and project ~= "" then
            -- Get project-specific issue types
            jira_api.request("/project/" .. project, "GET", nil, function(err, data)
                if err then
                    notify.error("Error: " .. err)
                    return
                end

                local lines = { "Issue Types for project " .. project .. ":", "" }
                for _, t in ipairs(data.issueTypes or {}) do
                    table.insert(lines, string.format("  %s", t.name))
                end
                notify.info(table.concat(lines, "\n"))
            end)
        else
            -- Get all issue types
            jira_api.request("/issuetype", "GET", nil, function(err, data)
                if err then
                    notify.error("Error: " .. err)
                    return
                end

                local seen = {}
                local lines = { "Available Issue Types (all projects):", "" }
                for _, t in ipairs(data) do
                    if not seen[t.name] then
                        seen[t.name] = true
                        table.insert(lines, string.format("  %s", t.name))
                    end
                end
                notify.info(table.concat(lines, "\n"))
            end)
        end
    end, { nargs = "?", desc = "List issue types (optionally for a specific project)" })
end

-- Expose modules for external use
M.api = require("jira-interface.api")
M.picker = require("jira-interface.picker")
M.ui = require("jira-interface.ui")
M.filters = require("jira-interface.filters")
M.board = require("jira-interface.board")
M.cache = require("jira-interface.cache")
M.queue = require("jira-interface.queue")
M.types = require("jira-interface.types")
M.context = require("jira-interface.context")
M.config = config

return M
