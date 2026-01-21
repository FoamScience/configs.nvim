local M = {}

local config = require("jira-interface.config")
local types = require("jira-interface.types")

---@type boolean
M.is_online = true

---@return string
local function get_auth_header()
    local auth = config.options.auth
    local credentials = auth.email .. ":" .. auth.token
    return "Basic " .. vim.base64.encode(credentials)
end

---@return string
local function get_base_url()
    local url = config.options.auth.url
    -- Add https:// if no protocol specified
    if not url:match("^https?://") then
        url = "https://" .. url
    end
    -- Remove trailing slash if present
    return url:gsub("/$", "")
end

---@param endpoint string
---@param method string
---@param body? table
---@param callback fun(err: string|nil, data: table|nil)
function M.request(endpoint, method, body, callback)
    local url = get_base_url() .. "/rest/api/3" .. endpoint

    local args = {
        "curl",
        "-s",
        "-L", -- Follow redirects
        "-w", "\n%{http_code}",
        "-X", method,
        "-H", "Authorization: " .. get_auth_header(),
        "-H", "Content-Type: application/json",
        "-H", "Accept: application/json",
    }

    if body then
        table.insert(args, "-d")
        table.insert(args, vim.json.encode(body))
    end

    table.insert(args, url)

    vim.system(args, { text = true }, function(result)
        vim.schedule(function()
            if result.code ~= 0 then
                M.is_online = false
                callback("Network error: " .. (result.stderr or "Unknown error"), nil)
                return
            end

            M.is_online = true
            local output = result.stdout or ""
            local lines = vim.split(output, "\n")
            local http_code = tonumber(lines[#lines]) or 0
            table.remove(lines)
            local response_body = table.concat(lines, "\n")

            if http_code >= 400 then
                local err_msg = "HTTP " .. http_code
                local ok, err_data = pcall(vim.json.decode, response_body)
                if ok then
                    if err_data.errorMessages and #err_data.errorMessages > 0 then
                        err_msg = err_msg .. ": " .. table.concat(err_data.errorMessages, ", ")
                    end
                    if err_data.errors then
                        local field_errors = {}
                        for field, msg in pairs(err_data.errors) do
                            table.insert(field_errors, field .. ": " .. msg)
                        end
                        if #field_errors > 0 then
                            err_msg = err_msg .. " [" .. table.concat(field_errors, "; ") .. "]"
                        end
                    end
                end
                callback(err_msg, nil)
                return
            end

            if response_body == "" then
                callback(nil, {})
                return
            end

            local ok, data = pcall(vim.json.decode, response_body)
            if not ok then
                callback("Failed to parse response: " .. response_body, nil)
                return
            end

            callback(nil, data)
        end)
    end)
end

---@param callback fun(online: boolean)
function M.check_connectivity(callback)
    -- Try /myself first, fallback to /serverInfo
    M.request("/myself", "GET", nil, function(err, _)
        if not err then
            M.is_online = true
            callback(true)
        else
            -- Fallback - /myself might be restricted
            M.request("/serverInfo", "GET", nil, function(err2, _)
                M.is_online = err2 == nil
                callback(M.is_online)
            end)
        end
    end)
end

---@param jql string
---@param callback fun(err: string|nil, issues: JiraIssue[]|nil)
function M.search(jql, callback)
    local fields =
    "summary,description,status,issuetype,project,assignee,parent,attachment,comment,duedate,created,updated"
    local ac_field = config.options.acceptance_criteria_field
    if ac_field and ac_field ~= "" then
        fields = fields .. "," .. ac_field
    end

    -- Apply "since" filter if configured (insert before ORDER BY)
    local since = config.options.since
    if since and since ~= "" then
        local order_by = jql:match("(ORDER%s+BY%s+.+)$")
        if order_by then
            local base = vim.trim(jql:gsub("%s*ORDER%s+BY%s+.+$", ""))
            if base ~= "" then
                jql = base .. " AND created >= " .. since .. " " .. order_by
            else
                jql = "created >= " .. since .. " " .. order_by
            end
        else
            jql = jql .. " AND created >= " .. since
        end
    end

    -- Use GET /search/jql endpoint
    local max_results = config.options.max_results or 100
    local endpoint = "/search/jql?jql=" .. vim.uri_encode(jql) .. "&fields=" .. fields .. "&maxResults=" .. max_results

    M.request(endpoint, "GET", nil, function(err, data)
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

---@param key string
---@param callback fun(err: string|nil, issue: JiraIssue|nil)
function M.get_issue(key, callback)
    local fields =
    "summary,description,status,issuetype,project,assignee,parent,attachment,comment,duedate,created,updated"
    local ac_field = config.options.acceptance_criteria_field
    if ac_field and ac_field ~= "" then
        fields = fields .. "," .. ac_field
    end

    M.request("/issue/" .. key .. "?fields=" .. fields, "GET", nil, function(err, data)
        if err then
            callback(err, nil)
            return
        end
        callback(nil, types.parse_issue(data))
    end)
end

---@param key string
---@param callback fun(err: string|nil, children: JiraIssue[]|nil)
function M.get_children(key, callback)
    local jql = string.format("parent = %s ORDER BY created ASC", key)
    M.search(jql, callback)
end

---@param callback fun(err: string|nil, issues: JiraIssue[]|nil)
function M.get_assigned_to_me(callback)
    local jql = "assignee = currentUser() ORDER BY updated DESC"
    M.search(jql, callback)
end

---@param project string
---@param callback fun(err: string|nil, issues: JiraIssue[]|nil)
function M.get_by_project(project, callback)
    local jql = string.format("project = %s ORDER BY updated DESC", project)
    M.search(jql, callback)
end

---@param level number
---@param project? string
---@param callback fun(err: string|nil, issues: JiraIssue[]|nil)
function M.get_by_level(level, project, callback)
    local type_list = types.get_types_for_level(level)
    if #type_list == 0 then
        callback("No types configured for level " .. level, nil)
        return
    end

    local type_jql = 'issuetype in ("' .. table.concat(type_list, '","') .. '")'
    local jql = type_jql

    if project then
        jql = jql .. " AND project = " .. project
    end

    jql = jql .. " ORDER BY updated DESC"
    M.search(jql, callback)
end

---@param key string
---@param callback fun(err: string|nil, transitions: JiraTransition[]|nil)
function M.get_transitions(key, callback)
    M.request("/issue/" .. key .. "/transitions", "GET", nil, function(err, data)
        if err then
            callback(err, nil)
            return
        end

        local transitions = {}
        for _, t in ipairs(data.transitions or {}) do
            table.insert(transitions, {
                id = t.id,
                name = t.name,
                to = t.to and t.to.name or "",
            })
        end
        callback(nil, transitions)
    end)
end

---@param key string
---@param transition_id string
---@param callback fun(err: string|nil)
function M.do_transition(key, transition_id, callback)
    local body = {
        transition = { id = transition_id },
    }
    M.request("/issue/" .. key .. "/transitions", "POST", body, function(err, _)
        callback(err)
    end)
end

---@param key string
---@param fields table
---@param callback fun(err: string|nil)
function M.update_issue(key, fields, callback)
    local body = { fields = fields }
    M.request("/issue/" .. key, "PUT", body, function(err, _)
        callback(err)
    end)
end

---@param project string
---@param issue_type string
---@param summary string
---@param description? string
---@param parent_key? string
---@param callback fun(err: string|nil, issue: JiraIssue|nil)
function M.create_issue(project, issue_type, summary, description, parent_key, callback)
    M.create_issue_full(project, issue_type, summary, description, nil, parent_key, callback)
end

---@param project string
---@param issue_type string
---@param summary string
---@param description? string
---@param acceptance_criteria? string
---@param parent_key? string
---@param callback fun(err: string|nil, issue: JiraIssue|nil)
function M.create_issue_full(project, issue_type, summary, description, acceptance_criteria, parent_key, callback)
    -- First get current user's account ID for auto-assign
    M.get_current_user(function(user_err, user)
        local fields = {
            project = { key = project },
            issuetype = { name = issue_type },
            summary = summary,
        }

        -- Auto-assign to current user if we got the account ID
        if not user_err and user and user.accountId then
            fields.assignee = { accountId = user.accountId }
        end

        if description and description ~= "" then
            fields.description = M.text_to_adf(description)
        end

        if parent_key then
            fields.parent = { key = parent_key }
        end

        M.request("/issue", "POST", { fields = fields }, function(err, data)
            if err then
                -- Retry without assignee if that might be the issue
                if err:match("assignee") then
                    fields.assignee = nil
                    M.request("/issue", "POST", { fields = fields }, function(retry_err, retry_data)
                        if retry_err then
                            callback(retry_err, nil)
                        else
                            M.update_acceptance_criteria_and_fetch(retry_data.key, acceptance_criteria, callback)
                        end
                    end)
                    return
                end
                callback(err, nil)
                return
            end
            -- Update acceptance criteria via edit, then fetch the issue
            M.update_acceptance_criteria_and_fetch(data.key, acceptance_criteria, callback)
        end)
    end)
end

---@param key string
---@param acceptance_criteria? string
---@param callback fun(err: string|nil, issue: JiraIssue|nil)
function M.update_acceptance_criteria_and_fetch(key, acceptance_criteria, callback)
    local ac_field = config.options.acceptance_criteria_field
    if ac_field and ac_field ~= "" and acceptance_criteria and acceptance_criteria ~= "" then
        local update_fields = {}
        update_fields[ac_field] = M.text_to_adf(acceptance_criteria)
        M.update_issue(key, update_fields, function(_)
            -- Silently skip if AC field not available for this issue type
            M.get_issue(key, callback)
        end)
    else
        M.get_issue(key, callback)
    end
end

---@param callback fun(err: string|nil, user: table|nil)
function M.get_current_user(callback)
    M.request("/myself", "GET", nil, function(err, data)
        if err then
            callback(err, nil)
            return
        end
        callback(nil, data)
    end)
end

---@param text string Plain text to convert to ADF
---@return table ADF document
function M.text_to_adf(text)
    local content = {}

    -- Split by double newlines for paragraphs
    local paragraphs = vim.split(text, "\n\n")

    for _, para in ipairs(paragraphs) do
        if para:match("^%s*[-*]") then
            -- Bullet list
            local items = {}
            for line in para:gmatch("[^\n]+") do
                local item_text = line:gsub("^%s*[-*]%s*", "")
                if item_text ~= "" then
                    table.insert(items, {
                        type = "listItem",
                        content = {
                            {
                                type = "paragraph",
                                content = { { type = "text", text = item_text } },
                            },
                        },
                    })
                end
            end
            if #items > 0 then
                table.insert(content, { type = "bulletList", content = items })
            end
        elseif para:match("^%s*%d+%.") then
            -- Ordered list
            local items = {}
            for line in para:gmatch("[^\n]+") do
                local item_text = line:gsub("^%s*%d+%.%s*", "")
                if item_text ~= "" then
                    table.insert(items, {
                        type = "listItem",
                        content = {
                            {
                                type = "paragraph",
                                content = { { type = "text", text = item_text } },
                            },
                        },
                    })
                end
            end
            if #items > 0 then
                table.insert(content, { type = "orderedList", content = items })
            end
        elseif para:match("^#+%s") then
            -- Heading
            local level, heading_text = para:match("^(#+)%s+(.+)")
            if heading_text then
                table.insert(content, {
                    type = "heading",
                    attrs = { level = math.min(#level, 6) },
                    content = { { type = "text", text = heading_text } },
                })
            end
        elseif vim.trim(para) ~= "" then
            -- Regular paragraph
            table.insert(content, {
                type = "paragraph",
                content = { { type = "text", text = para:gsub("\n", " ") } },
            })
        end
    end

    return {
        type = "doc",
        version = 1,
        content = content,
    }
end

---@param callback fun(err: string|nil, projects: table[]|nil)
function M.get_projects(callback)
    M.request("/project/search?maxResults=50", "GET", nil, function(err, data)
        if err then
            callback(err, nil)
            return
        end

        local projects = {}
        for _, p in ipairs(data.values or {}) do
            table.insert(projects, {
                key = p.key,
                name = p.name,
                id = p.id,
            })
        end
        callback(nil, projects)
    end)
end

---@param project string
---@param callback fun(err: string|nil, members: table[]|nil)
function M.get_project_members(project, callback)
    -- Get users who are assignable to issues in this project
    M.request("/user/assignable/search?project=" .. project .. "&maxResults=50", "GET", nil, function(err, data)
        if err then
            callback(err, nil)
            return
        end

        local members = {}
        for _, u in ipairs(data or {}) do
            table.insert(members, {
                accountId = u.accountId,
                displayName = u.displayName,
                emailAddress = u.emailAddress,
                avatarUrl = u.avatarUrls and u.avatarUrls["24x24"] or nil,
                active = u.active,
            })
        end
        callback(nil, members)
    end)
end

---@param project string
---@param callback fun(err: string|nil, workload: table|nil)
function M.get_team_workload(project, callback)
    -- Get all non-done issues for the project
    local jql = string.format('project = %s AND status != Done ORDER BY assignee ASC, updated DESC', project)
    M.search(jql, function(err, issues)
        if err then
            callback(err, nil)
            return
        end

        -- Group by assignee
        local by_assignee = {}
        local unassigned = {}

        for _, issue in ipairs(issues or {}) do
            if issue.assignee then
                if not by_assignee[issue.assignee] then
                    by_assignee[issue.assignee] = { name = issue.assignee, issues = {} }
                end
                table.insert(by_assignee[issue.assignee].issues, issue)
            else
                table.insert(unassigned, issue)
            end
        end

        -- Convert to list and sort by issue count
        local members = {}
        for _, member in pairs(by_assignee) do
            table.insert(members, member)
        end
        table.sort(members, function(a, b)
            return #a.issues > #b.issues
        end)

        callback(nil, {
            members = members,
            unassigned = unassigned,
            total = #(issues or {}),
        })
    end)
end

---@param key string
---@param account_id string
---@param callback fun(err: string|nil)
function M.assign_issue(key, account_id, callback)
    local body = { accountId = account_id }
    M.request("/issue/" .. key .. "/assignee", "PUT", body, function(err, _)
        callback(err)
    end)
end

---@param key string
---@param callback fun(err: string|nil)
function M.unassign_issue(key, callback)
    local body = { accountId = nil }
    M.request("/issue/" .. key .. "/assignee", "PUT", body, function(err, _)
        callback(err)
    end)
end

return M
