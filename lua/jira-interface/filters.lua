local M = {}

local config = require("jira-interface.config")
local notify = require("jira-interface.notify")

---@class JiraFilter
---@field name string Filter name
---@field jql string JQL query
---@field project string|nil Project scope (nil = global)
---@field description string|nil Optional description

---@type JiraFilter[]
local filters = {}

---@type boolean
local loaded = false

---@return JiraFilter[]
local function load_filters()
    if loaded then
        return filters
    end

    local path = config.get_filters_path()
    local file = io.open(path, "r")
    if not file then
        loaded = true
        return filters
    end

    local content = file:read("*a")
    file:close()

    local ok, data = pcall(vim.json.decode, content)
    if ok and type(data) == "table" then
        filters = data
    end

    loaded = true
    return filters
end

local function save_filters()
    local path = config.get_filters_path()
    local file = io.open(path, "w")
    if not file then
        notify.error("Failed to write filters file")
        return
    end
    file:write(vim.json.encode(filters))
    file:close()
end

-- Built-in filter generators
M.builtin = {}

---@return string
function M.builtin.assigned_to_me()
    return "assignee = currentUser() AND status != Done ORDER BY updated DESC"
end

---@return string
function M.builtin.created_by_me()
    return "reporter = currentUser() ORDER BY created DESC"
end

---@param project string
---@return string
function M.builtin.by_project(project)
    return string.format("project = %s ORDER BY updated DESC", project)
end

---@param status string
---@return string
function M.builtin.by_status(status)
    return string.format('status = "%s" ORDER BY updated DESC', status)
end

---@param type_name string
---@return string
function M.builtin.by_type(type_name)
    return string.format('issuetype = "%s" ORDER BY updated DESC', type_name)
end

---@param level number
---@param project? string
---@return string
function M.builtin.by_level(level, project)
    local types_mod = require("jira-interface.types")
    local type_list = types_mod.get_types_for_level(level)

    local jql = 'issuetype in ("' .. table.concat(type_list, '","') .. '")'
    if project and project ~= "" then
        jql = jql .. " AND project = " .. project
    end
    return jql .. " ORDER BY updated DESC"
end

---@param parent_key string
---@return string
function M.builtin.children_of(parent_key)
    return string.format("parent = %s ORDER BY created ASC", parent_key)
end

---@param project? string
---@return string
function M.builtin.overdue(project)
    local jql = "duedate < now() AND status != Done"
    if project and project ~= "" then
        jql = jql .. " AND project = " .. project
    end
    return jql .. " ORDER BY duedate ASC"
end

---@param project? string
---@return string
function M.builtin.due_today(project)
    local jql = "duedate = startOfDay() AND status != Done"
    if project and project ~= "" then
        jql = jql .. " AND project = " .. project
    end
    return jql .. " ORDER BY duedate ASC"
end

---@param project? string
---@return string
function M.builtin.due_this_week(project)
    local jql = "duedate >= startOfDay() AND duedate <= endOfWeek() AND status != Done"
    if project and project ~= "" then
        jql = jql .. " AND project = " .. project
    end
    return jql .. " ORDER BY duedate ASC"
end

---@param project? string
---@return string
function M.builtin.due_soon(project)
    local jql = "duedate >= startOfDay() AND duedate <= 7d AND status != Done"
    if project and project ~= "" then
        jql = jql .. " AND project = " .. project
    end
    return jql .. " ORDER BY duedate ASC"
end

---@param project? string
---@return string
function M.builtin.by_duedate(project)
    local jql = "duedate is not EMPTY"
    if project and project ~= "" then
        jql = jql .. " AND project = " .. project
    end
    return jql .. " ORDER BY duedate ASC"
end

---@param name string
---@param jql string
---@param project? string
---@param description? string
function M.save(name, jql, project, description)
    load_filters()

    -- Check if filter with same name exists
    for i, f in ipairs(filters) do
        if f.name == name and f.project == project then
            filters[i] = {
                name = name,
                jql = jql,
                project = project,
                description = description,
            }
            save_filters()
            notify.info(string.format("Filter '%s' updated", name))
            return
        end
    end

    table.insert(filters, {
        name = name,
        jql = jql,
        project = project,
        description = description,
    })
    save_filters()
    notify.info(string.format("Filter '%s' saved", name))
end

---@param name string
---@param project? string
---@return JiraFilter|nil
function M.get(name, project)
    load_filters()
    for _, f in ipairs(filters) do
        if f.name == name then
            -- Prefer project-specific, fall back to global
            if f.project == project then
                return f
            elseif f.project == nil then
                return f
            end
        end
    end
    return nil
end

---@param name string
---@param project? string
---@return boolean
function M.delete(name, project)
    load_filters()
    for i, f in ipairs(filters) do
        if f.name == name and (f.project == project or f.project == nil) then
            table.remove(filters, i)
            save_filters()
            notify.info(string.format("Filter '%s' deleted", name))
            return true
        end
    end
    return false
end

---@return JiraFilter[]
function M.list_all()
    return load_filters()
end

---@param jql string
---@param additional_clause string
---@return string
function M.combine_jql(jql, additional_clause)
    -- Remove ORDER BY from original JQL
    local base = jql:gsub("%s+ORDER%s+BY%s+.+$", "")
    -- Extract ORDER BY from original
    local order_by = jql:match("ORDER%s+BY%s+.+$") or "ORDER BY updated DESC"

    return string.format("(%s) AND (%s) %s", base, additional_clause, order_by)
end

return M
