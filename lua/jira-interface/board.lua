local M = {}

local config = require("jira-interface.config")
local types = require("jira-interface.types")
local notify = require("jira-interface.notify")
local atlassian_request = require("atlassian.request")
local atlassian_ui = require("atlassian.ui")

local COL_KEY = 12
local COL_STATUS = 14

local pad_right = atlassian_ui.pad_right
local truncate = atlassian_ui.truncate

-- Agile REST API client (separate base path from standard Jira API)
local function get_agile_client()
    return atlassian_request.create_client({
        auth = config.options.auth,
        api_path = "/rest/agile/1.0",
    })
end

---@param endpoint string
---@param method string
---@param body? table
---@param callback fun(err: any, data: table|nil)
local function agile_request(endpoint, method, body, callback)
    local client = get_agile_client()
    client.request(endpoint, method, body, callback)
end

-- ---------------------------------------------------------------------------
-- Agile API functions
-- ---------------------------------------------------------------------------

---@param project string Project key or ID
---@param callback fun(err: any, boards: table[]|nil)
function M.get_boards(project, callback)
    agile_request("/board?projectKeyOrId=" .. vim.uri_encode(project) .. "&maxResults=50", "GET", nil,
        function(err, data)
            if err then
                callback(err, nil)
                return
            end
            local boards = {}
            for _, b in ipairs(data.values or {}) do
                table.insert(boards, {
                    id = b.id,
                    name = b.name,
                    type = b.type, -- "scrum" or "kanban"
                })
            end
            callback(nil, boards)
        end)
end

---@param board_id number
---@param callback fun(err: any, columns: string[]|nil)
function M.get_board_config(board_id, callback)
    agile_request("/board/" .. board_id .. "/configuration", "GET", nil, function(err, data)
        if err then
            callback(err, nil)
            return
        end
        local columns = {}
        if data.columnConfig and data.columnConfig.columns then
            for _, col in ipairs(data.columnConfig.columns) do
                table.insert(columns, col.name)
            end
        end
        callback(nil, columns)
    end)
end

---@param board_id number
---@param state? string Sprint state filter: "active", "future", "closed"
---@param callback fun(err: any, sprints: table[]|nil)
function M.get_sprints(board_id, state, callback)
    local endpoint = "/board/" .. board_id .. "/sprint?maxResults=50"
    if state then
        endpoint = endpoint .. "&state=" .. state
    end
    agile_request(endpoint, "GET", nil, function(err, data)
        if err then
            callback(err, nil)
            return
        end
        local sprints = {}
        for _, s in ipairs(data.values or {}) do
            table.insert(sprints, {
                id = s.id,
                name = s.name,
                state = s.state,
                startDate = s.startDate,
                endDate = s.endDate,
            })
        end
        callback(nil, sprints)
    end)
end

---@param sprint_id number
---@param callback fun(err: any, issues: JiraIssue[]|nil)
function M.get_sprint_issues(sprint_id, callback)
    local fields = "summary,status,issuetype,project,assignee,duedate,updated"
    agile_request("/sprint/" .. sprint_id .. "/issue?fields=" .. fields .. "&maxResults=200", "GET", nil,
        function(err, data)
            if err then
                callback(err, nil)
                return
            end
            local issues = {}
            for _, raw in ipairs(data.issues or {}) do
                table.insert(issues, types.parse_issue(raw))
            end
            callback(nil, issues)
        end)
end

---@param board_id number
---@param callback fun(err: any, issues: JiraIssue[]|nil)
function M.get_kanban_issues(board_id, callback)
    -- For kanban boards, use JQL search for non-Done issues in the board's project
    -- First get board config to identify the project
    agile_request("/board/" .. board_id .. "/configuration", "GET", nil, function(err, data)
        if err then
            callback(err, nil)
            return
        end

        local filter_id = data.filter and data.filter.id
        if not filter_id then
            callback("Could not determine board filter", nil)
            return
        end

        -- Use the board's own backlog/issue endpoint which respects the board's filter
        local fields = "summary,status,issuetype,project,assignee,duedate,updated"
        agile_request("/board/" .. board_id .. "/issue?fields=" .. fields .. "&maxResults=200", "GET", nil,
            function(issue_err, issue_data)
                if issue_err then
                    callback(issue_err, nil)
                    return
                end
                local issues = {}
                for _, raw in ipairs(issue_data.issues or {}) do
                    local issue = types.parse_issue(raw)
                    -- Exclude Done issues for kanban view
                    if issue.status ~= "Done" then
                        table.insert(issues, issue)
                    end
                end
                callback(nil, issues)
            end)
    end)
end

-- ---------------------------------------------------------------------------
-- Kanban view (grouped by status)
-- ---------------------------------------------------------------------------

---@param title string Picker title
---@param issues JiraIssue[]
---@param column_order? string[] Status column ordering
local function show_kanban(title, issues, column_order)
    local Snacks = require("snacks")

    -- Determine column order: use provided order, fall back to config.options.statuses
    local order = column_order
    if not order or #order == 0 then
        order = config.options.statuses or { "To Do", "In Progress", "In Review", "Blocked", "Done" }
    end

    -- Group issues by status
    local by_status = {}
    local seen_statuses = {}
    for _, issue in ipairs(issues) do
        if not by_status[issue.status] then
            by_status[issue.status] = {}
            seen_statuses[issue.status] = true
        end
        table.insert(by_status[issue.status], issue)
    end

    -- Build ordered status list: configured order first, then any unseen statuses
    local status_list = {}
    for _, s in ipairs(order) do
        if by_status[s] then
            table.insert(status_list, s)
        end
    end
    for status, _ in pairs(by_status) do
        if not vim.tbl_contains(status_list, status) then
            table.insert(status_list, status)
        end
    end

    -- Build items using grouped-header pattern
    local items = {}
    local idx = 0
    for _, status in ipairs(status_list) do
        local status_issues = by_status[status] or {}
        local status_info = types.get_status_display(status)

        -- Status header
        idx = idx + 1
        table.insert(items, {
            idx = idx,
            text = status .. " " .. #status_issues .. " issues",
            is_header = true,
            status_name = status,
            status_icon = status_info.icon,
            status_hl = status_info.hl,
            issue_count = #status_issues,
        })

        -- Issues under this status
        for _, issue in ipairs(status_issues) do
            idx = idx + 1
            table.insert(items, {
                idx = idx,
                text = issue.key .. " " .. issue.status .. " " .. issue.summary,
                is_header = false,
                issue = issue,
                key = issue.key,
                status = issue.status,
                status_icon = status_info.icon,
                status_hl = status_info.hl,
                summary = issue.summary,
                assignee = issue.assignee or "Unassigned",
                issue_type = issue.type,
            })
        end
    end

    if #items == 0 then
        notify.info("No issues found")
        return
    end

    Snacks.picker.pick({
        title = title,
        items = items,
        format = function(item, _picker)
            local ret = {}
            if item.is_header then
                table.insert(ret, { item.status_icon .. " ", item.status_hl })
                table.insert(ret, { item.status_name, "Title" })
                table.insert(ret, { " (" .. item.issue_count .. ")", "Comment" })
            else
                table.insert(ret, { "  ", "Normal" })
                table.insert(ret, { pad_right(item.key, COL_KEY), "Special" })
                table.insert(ret, { " ", "Normal" })
                table.insert(ret, { pad_right(item.issue_type, 10), "Type" })
                table.insert(ret, { " ", "Normal" })
                table.insert(ret, { truncate(item.summary, 50), "Normal" })
                table.insert(ret, { " ", "Normal" })
                table.insert(ret, { item.assignee, "Comment" })
            end
            return ret
        end,
        confirm = function(picker, item)
            if item and item.issue then
                picker:close()
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
            assign_to_me = function(picker, item)
                if item and item.issue then
                    local api = require("jira-interface.api")
                    notify.progress_start("assign", "Assigning " .. item.issue.key)
                    api.get_current_user(function(user_err, user)
                        if user_err or not user then
                            notify.progress_error("assign", "Failed to get current user")
                            return
                        end
                        api.assign_issue(item.issue.key, user.accountId, function(assign_err)
                            if assign_err then
                                notify.progress_error("assign", "Failed: " .. assign_err)
                            else
                                notify.progress_finish("assign", item.issue.key .. " assigned to you")
                                picker:close()
                            end
                        end)
                    end)
                end
            end,
            view_full = function(picker, item)
                if item and item.issue then
                    picker:close()
                    local ui = require("jira-interface.ui")
                    ui.view(item.issue.key)
                end
            end,
        },
        layout = {
            layout = {
                box = "vertical",
                backdrop = false,
                row = -1,
                width = 0,
                height = 0.5,
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
                    ["<C-t>"] = { "transition", mode = { "n", "i" }, desc = "Transition status" },
                    ["<C-a>"] = { "assign_to_me", mode = { "n", "i" }, desc = "Assign to me" },
                    ["<C-v>"] = { "view_full", mode = { "n", "i" }, desc = "View full issue" },
                },
            },
        },
    })
end

-- ---------------------------------------------------------------------------
-- Board picker
-- ---------------------------------------------------------------------------

---@param board_id? number Direct board ID, or nil to pick
function M.show_board(board_id)
    if board_id then
        M.load_board(board_id)
        return
    end

    local project = config.options.default_project
    if not project or project == "" then
        M.select_project_then_board()
        return
    end

    notify.progress_start("boards", "Loading boards...")
    M.get_boards(project, function(err, boards)
        notify.progress_finish("boards")
        if err then
            notify.error("Failed to load boards: " .. err)
            return
        end

        if not boards or #boards == 0 then
            notify.info("No boards found for project " .. project)
            return
        end

        if #boards == 1 then
            M.load_board(boards[1].id)
            return
        end

        M.pick_board(boards)
    end)
end

---@param boards table[]
function M.pick_board(boards)
    local Snacks = require("snacks")

    local items = {}
    for idx, board in ipairs(boards) do
        table.insert(items, {
            idx = idx,
            text = board.name .. " " .. board.type,
            board = board,
            name = board.name,
            board_type = board.type,
        })
    end

    Snacks.picker.pick({
        title = "Jira Boards",
        items = items,
        format = function(item, _picker)
            return {
                { pad_right(item.board_type, 8), "Special" },
                { " ", "Normal" },
                { item.name, "Normal" },
            }
        end,
        confirm = function(picker, item)
            picker:close()
            if item and item.board then
                M.load_board(item.board.id)
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

---@param board_id number
function M.load_board(board_id)
    notify.progress_start("board", "Loading board...")

    -- Get board config to determine type and column order
    M.get_board_config(board_id, function(config_err, columns)
        if config_err then
            notify.progress_finish("board")
            notify.error("Failed to load board config: " .. config_err)
            return
        end

        -- Try to detect board type by checking for sprints
        M.get_sprints(board_id, "active", function(sprint_err, sprints)
            if not sprint_err and sprints and #sprints > 0 then
                -- Scrum board: load active sprint issues
                local sprint = sprints[1]
                M.get_sprint_issues(sprint.id, function(issue_err, issues)
                    notify.progress_finish("board")
                    if issue_err then
                        notify.error("Failed to load sprint issues: " .. issue_err)
                        return
                    end
                    show_kanban("Sprint: " .. sprint.name, issues or {}, columns)
                end)
            else
                -- Kanban board (or scrum with no active sprint): load board issues
                M.get_kanban_issues(board_id, function(issue_err, issues)
                    notify.progress_finish("board")
                    if issue_err then
                        notify.error("Failed to load board issues: " .. issue_err)
                        return
                    end
                    show_kanban("Board #" .. board_id, issues or {}, columns)
                end)
            end
        end)
    end)
end

-- ---------------------------------------------------------------------------
-- Sprint picker
-- ---------------------------------------------------------------------------

---@param board_id? number Direct board ID, or nil to pick
function M.show_sprint(board_id)
    if board_id then
        M.pick_sprint(board_id)
        return
    end

    local project = config.options.default_project
    if not project or project == "" then
        M.select_project_then_sprint()
        return
    end

    notify.progress_start("boards", "Loading boards...")
    M.get_boards(project, function(err, boards)
        notify.progress_finish("boards")
        if err then
            notify.error("Failed to load boards: " .. err)
            return
        end

        if not boards or #boards == 0 then
            notify.info("No boards found for project " .. project)
            return
        end

        -- Filter to scrum boards
        local scrum_boards = vim.tbl_filter(function(b) return b.type == "scrum" end, boards)
        if #scrum_boards == 0 then
            notify.info("No scrum boards found for project " .. project)
            return
        end

        if #scrum_boards == 1 then
            M.pick_sprint(scrum_boards[1].id)
            return
        end

        -- Pick board first, then sprint
        local Snacks = require("snacks")
        local items = {}
        for idx, board in ipairs(scrum_boards) do
            table.insert(items, {
                idx = idx,
                text = board.name,
                board = board,
                name = board.name,
            })
        end

        Snacks.picker.pick({
            title = "Select Scrum Board",
            items = items,
            format = function(item, _picker)
                return { { item.name, "Normal" } }
            end,
            confirm = function(picker, item)
                picker:close()
                if item and item.board then
                    M.pick_sprint(item.board.id)
                end
            end,
            layout = {
                layout = {
                    box = "vertical",
                    backdrop = false,
                    row = -1,
                    width = 0,
                    height = 0.3,
                    border = "top",
                    title = " {title} {live} {flags}",
                    title_pos = "left",
                    { win = "input", height = 1, border = "bottom" },
                    { win = "list", border = "none" },
                },
            },
            preview = false,
        })
    end)
end

---@param board_id number
function M.pick_sprint(board_id)
    notify.progress_start("sprints", "Loading sprints...")
    M.get_sprints(board_id, nil, function(err, sprints)
        notify.progress_finish("sprints")
        if err then
            notify.error("Failed to load sprints: " .. err)
            return
        end

        if not sprints or #sprints == 0 then
            notify.info("No sprints found")
            return
        end

        -- Sort: active first, then future, then closed (reversed for recent first)
        local state_order = { active = 1, future = 2, closed = 3 }
        table.sort(sprints, function(a, b)
            local oa = state_order[a.state] or 9
            local ob = state_order[b.state] or 9
            if oa ~= ob then return oa < ob end
            return (a.id or 0) > (b.id or 0)
        end)

        local Snacks = require("snacks")
        local items = {}
        for idx, sprint in ipairs(sprints) do
            local state_icon = sprint.state == "active" and "" or sprint.state == "future" and "" or ""
            table.insert(items, {
                idx = idx,
                text = sprint.name .. " " .. sprint.state,
                sprint = sprint,
                name = sprint.name,
                state = sprint.state,
                state_icon = state_icon,
            })
        end

        Snacks.picker.pick({
            title = "Sprints",
            items = items,
            format = function(item, _picker)
                local state_hl = item.state == "active" and "Function"
                    or item.state == "future" and "Type"
                    or "Comment"
                return {
                    { item.state_icon .. " ", state_hl },
                    { pad_right(item.state, 8), state_hl },
                    { " ", "Normal" },
                    { item.name, "Normal" },
                }
            end,
            confirm = function(picker, item)
                picker:close()
                if item and item.sprint then
                    M.load_sprint(board_id, item.sprint)
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
    end)
end

---@param board_id number
---@param sprint table
function M.load_sprint(board_id, sprint)
    notify.progress_start("sprint", "Loading sprint issues...")

    -- Get board column order for consistent grouping
    M.get_board_config(board_id, function(_, columns)
        M.get_sprint_issues(sprint.id, function(issue_err, issues)
            notify.progress_finish("sprint")
            if issue_err then
                notify.error("Failed to load sprint issues: " .. issue_err)
                return
            end
            show_kanban("Sprint: " .. sprint.name, issues or {}, columns)
        end)
    end)
end

-- ---------------------------------------------------------------------------
-- Project selection helpers
-- ---------------------------------------------------------------------------

function M.select_project_then_board()
    local api = require("jira-interface.api")
    notify.progress_start("projects", "Loading projects...")
    api.get_projects(function(err, projects)
        notify.progress_finish("projects")
        if err then
            notify.error("Failed to load projects: " .. err)
            return
        end
        if not projects or #projects == 0 then
            notify.info("No projects found")
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
            title = "Select Project for Board",
            items = items,
            format = function(item, _picker)
                return {
                    { pad_right(item.key, 10), "Special" },
                    { "  ", "Normal" },
                    { item.name, "Normal" },
                }
            end,
            confirm = function(picker, item)
                picker:close()
                if item and item.project then
                    notify.progress_start("boards", "Loading boards...")
                    M.get_boards(item.project.key, function(board_err, boards)
                        notify.progress_finish("boards")
                        if board_err then
                            notify.error("Failed to load boards: " .. board_err)
                            return
                        end
                        if not boards or #boards == 0 then
                            notify.info("No boards found for " .. item.project.key)
                            return
                        end
                        if #boards == 1 then
                            M.load_board(boards[1].id)
                        else
                            M.pick_board(boards)
                        end
                    end)
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
    end)
end

function M.select_project_then_sprint()
    local api = require("jira-interface.api")
    notify.progress_start("projects", "Loading projects...")
    api.get_projects(function(err, projects)
        notify.progress_finish("projects")
        if err then
            notify.error("Failed to load projects: " .. err)
            return
        end
        if not projects or #projects == 0 then
            notify.info("No projects found")
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
            title = "Select Project for Sprint",
            items = items,
            format = function(item, _picker)
                return {
                    { pad_right(item.key, 10), "Special" },
                    { "  ", "Normal" },
                    { item.name, "Normal" },
                }
            end,
            confirm = function(picker, item)
                picker:close()
                if item and item.project then
                    notify.progress_start("boards", "Loading boards...")
                    M.get_boards(item.project.key, function(board_err, boards)
                        notify.progress_finish("boards")
                        if board_err then
                            notify.error("Failed to load boards: " .. board_err)
                            return
                        end
                        local scrum_boards = vim.tbl_filter(function(b) return b.type == "scrum" end, boards)
                        if #scrum_boards == 0 then
                            notify.info("No scrum boards found for " .. item.project.key)
                            return
                        end
                        if #scrum_boards == 1 then
                            M.pick_sprint(scrum_boards[1].id)
                        else
                            -- Pick board first
                            M.pick_board(scrum_boards)
                        end
                    end)
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
    end)
end

return M
