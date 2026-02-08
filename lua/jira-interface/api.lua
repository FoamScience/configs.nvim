local M = {}

local config = require("jira-interface.config")
local types = require("jira-interface.types")
local atlassian_request = require("atlassian.request")
local atlassian_adf = require("atlassian.adf")
local error_mod = require("atlassian.error")

---@type boolean
M.is_online = true

-- Create API client using shared request module
local function get_client()
    return atlassian_request.create_client({
        auth = config.options.auth,
        api_path = "/rest/api/3",
    })
end

---@param endpoint string
---@param method string
---@param body? table
---@param callback fun(err: string|nil, data: table|nil)
function M.request(endpoint, method, body, callback)
    local client = get_client()
    client.request(endpoint, method, body, function(err, data)
        M.is_online = client.is_online
        callback(err, data)
    end)
end

---@param callback fun(online: boolean)
function M.check_connectivity(callback)
    M.request("/myself", "GET", nil, function(err, _)
        if not err then
            M.is_online = true
            callback(true)
        else
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
    for _, field_id in pairs(config.options.custom_fields or {}) do
        fields = fields .. "," .. field_id
    end

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
    for _, field_id in pairs(config.options.custom_fields or {}) do
        fields = fields .. "," .. field_id
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
---@param description? string|table ADF table or plain text string
---@param extra_fields? table<string, string|table> Map of Jira field ID → value (ADF table or text)
---@param parent_key? string
---@param callback fun(err: string|nil, issue: JiraIssue|nil)
function M.create_issue_full(project, issue_type, summary, description, extra_fields, parent_key, callback)
    M.get_current_user(function(user_err, user)
        local fields = {
            project = { key = project },
            issuetype = { name = issue_type },
            summary = summary,
        }

        if not user_err and user and user.accountId then
            fields.assignee = { accountId = user.accountId }
        end

        if description and description ~= "" then
            fields.description = type(description) == "table" and description or atlassian_adf.text_to_adf(description)
        end

        if parent_key then
            fields.parent = { key = parent_key }
        end

        M.request("/issue", "POST", { fields = fields }, function(err, data)
            if err then
                if err.message:match("assignee") then
                    fields.assignee = nil
                    M.request("/issue", "POST", { fields = fields }, function(retry_err, retry_data)
                        if retry_err then
                            callback(retry_err, nil)
                        else
                            M.update_extra_fields_and_fetch(retry_data.key, extra_fields, callback)
                        end
                    end)
                    return
                end
                -- For any validation error, check raw response and enrich with valid issue types
                local raw = error_mod.is_error(err) and err.raw_response or ""
                local is_type_err = err.message:match("issuetype") or err.message:match("issue type")
                    or raw:match("issuetype")
                if is_type_err then
                    M.request("/project/" .. project, "GET", nil, function(_, proj_data)
                        local valid = {}
                        for _, t in ipairs((proj_data or {}).issueTypes or {}) do
                            table.insert(valid, t.name)
                        end
                        if #valid > 0 then
                            callback(err .. "\nValid types for " .. project .. ": " .. table.concat(valid, ", "), nil)
                        else
                            callback(err, nil)
                        end
                    end)
                    return
                end
                callback(err, nil)
                return
            end
            M.update_extra_fields_and_fetch(data.key, extra_fields, callback)
        end)
    end)
end

---@param key string
---@param extra_fields? table<string, string|table> Map of Jira field ID → value (ADF table or text)
---@param callback fun(err: string|nil, issue: JiraIssue|nil)
function M.update_extra_fields_and_fetch(key, extra_fields, callback)
    if extra_fields and not vim.tbl_isempty(extra_fields) then
        local update_fields = {}
        for field_id, value in pairs(extra_fields) do
            update_fields[field_id] = type(value) == "table" and value or atlassian_adf.text_to_adf(value)
        end
        M.update_issue(key, update_fields, function(_)
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
    local jql = string.format('project = %s AND status != Done ORDER BY assignee ASC, updated DESC', project)
    M.search(jql, function(err, issues)
        if err then
            callback(err, nil)
            return
        end

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

---@param issue_key string
---@param file_path string
---@param callback fun(err: AtlassianError|nil, data: table|nil)
function M.upload_attachment(issue_key, file_path, callback)
    local auth = config.options.auth
    local base_url = atlassian_request.normalize_url(auth.url)
    atlassian_request.upload_file({
        url = base_url .. "/rest/api/3/issue/" .. issue_key .. "/attachments",
        auth = auth,
        file_path = file_path,
        callback = callback,
    })
end

return M
