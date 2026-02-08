local M = {}

local config = require("jira-interface.config")
local notify = require("jira-interface.notify")

---@class QueuedEdit
---@field id string Unique ID for this edit
---@field type string "update" | "transition" | "create"
---@field issue_key string|nil Issue key (nil for create)
---@field data table Edit data
---@field timestamp number When the edit was queued
---@field description string Human-readable description

---@type QueuedEdit[]
local queue = {}

---@type boolean
local loaded = false

---@return QueuedEdit[]
local function load_queue()
    if loaded then
        return queue
    end

    local path = config.get_queue_path()
    local file = io.open(path, "r")
    if not file then
        loaded = true
        return queue
    end

    local content = file:read("*a")
    file:close()

    local ok, data = pcall(vim.json.decode, content)
    if ok and type(data) == "table" then
        queue = data
    end

    loaded = true
    return queue
end

local function save_queue()
    local path = config.get_queue_path()
    local file = io.open(path, "w")
    if not file then
        notify.error("Failed to write queue file")
        return
    end
    file:write(vim.json.encode(queue))
    file:close()
end

---@return string
local function generate_id()
    return string.format("%d-%s", os.time(), vim.fn.rand())
end

---@param edit QueuedEdit
function M.add(edit)
    load_queue()
    edit.id = generate_id()
    edit.timestamp = os.time()
    table.insert(queue, edit)
    save_queue()
    notify.info(string.format("Edit queued: %s", edit.description))
end

---@param issue_key string
---@param fields table
---@param description string
function M.queue_update(issue_key, fields, description)
    M.add({
        type = "update",
        issue_key = issue_key,
        data = { fields = fields },
        description = description,
    })
end

---@param issue_key string
---@param transition_id string
---@param transition_name string
function M.queue_transition(issue_key, transition_id, transition_name)
    M.add({
        type = "transition",
        issue_key = issue_key,
        data = { transition_id = transition_id },
        description = string.format("%s -> %s", issue_key, transition_name),
    })
end

---@param project string
---@param issue_type string
---@param summary string
---@param description string|nil
---@param parent_key string|nil
function M.queue_create(project, issue_type, summary, description, parent_key)
    M.add({
        type = "create",
        issue_key = nil,
        data = {
            project = project,
            issue_type = issue_type,
            summary = summary,
            description = description,
            parent_key = parent_key,
        },
        description = string.format("Create %s: %s", issue_type, summary),
    })
end

---@return QueuedEdit[]
function M.get_all()
    return load_queue()
end

---@return number
function M.count()
    load_queue()
    return #queue
end

---@param id string
function M.remove(id)
    load_queue()
    for i, edit in ipairs(queue) do
        if edit.id == id then
            table.remove(queue, i)
            save_queue()
            return
        end
    end
end

function M.clear()
    queue = {}
    save_queue()
end

---@param callback fun(results: { id: string, success: boolean, error: string|nil }[])
function M.sync_all(callback)
    local api = require("jira-interface.api")
    load_queue()

    if #queue == 0 then
        callback({})
        return
    end

    local results = {}
    local pending = #queue
    local edits_to_process = vim.deepcopy(queue)

    local function on_complete()
        pending = pending - 1
        if pending == 0 then
            callback(results)
        end
    end

    for _, edit in ipairs(edits_to_process) do
        if edit.type == "update" then
            api.update_issue(edit.issue_key, edit.data.fields, function(err)
                table.insert(results, {
                    id = edit.id,
                    success = err == nil,
                    error = err,
                    description = edit.description,
                })
                if not err then
                    M.remove(edit.id)
                end
                on_complete()
            end)
        elseif edit.type == "transition" then
            api.do_transition(edit.issue_key, edit.data.transition_id, function(err)
                table.insert(results, {
                    id = edit.id,
                    success = err == nil,
                    error = err,
                    description = edit.description,
                })
                if not err then
                    M.remove(edit.id)
                end
                on_complete()
            end)
        elseif edit.type == "create" then
            api.create_issue(
                edit.data.project,
                edit.data.issue_type,
                edit.data.summary,
                edit.data.description,
                edit.data.parent_key,
                function(err, _)
                    table.insert(results, {
                        id = edit.id,
                        success = err == nil,
                        error = err,
                        description = edit.description,
                    })
                    if not err then
                        M.remove(edit.id)
                    end
                    on_complete()
                end
            )
        else
            table.insert(results, {
                id = edit.id,
                success = false,
                error = "Unknown edit type: " .. (edit.type or "nil"),
                description = edit.description,
            })
            on_complete()
        end
    end
end

---@param callback fun()
function M.prompt_sync(callback)
    local api = require("jira-interface.api")
    load_queue()

    if #queue == 0 then
        callback()
        return
    end

    -- Check if online
    api.check_connectivity(function(online)
        if not online then
            callback()
            return
        end

        -- Build prompt message
        local lines = { "Pending offline edits:", "" }
        for i, edit in ipairs(queue) do
            table.insert(lines, string.format("%d. %s", i, edit.description))
        end
        table.insert(lines, "")
        table.insert(lines, "Sync now? (y/n/v to view details)")

        vim.ui.input({ prompt = table.concat(lines, "\n") .. " " }, function(input)
            if not input then
                callback()
                return
            end

            input = input:lower()
            if input == "y" or input == "yes" then
                M.sync_all(function(results)
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
                    notify.info(string.format("Sync complete: %d succeeded, %d failed", success, failed))
                    callback()
                end)
            elseif input == "v" or input == "view" then
                -- Open queue viewer
                local ui = require("jira-interface.ui")
                ui.show_queue()
                callback()
            else
                callback()
            end
        end)
    end)
end

return M
