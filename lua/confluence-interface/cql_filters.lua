local M = {}

local config = require("confluence-interface.config")
local notify = require("confluence-interface.notify")

---@class CqlFilter
---@field name string Filter name
---@field cql string CQL query
---@field space_key string|nil Space scope (nil = global)
---@field description string|nil Optional description

---@type CqlFilter[]
local filters = {}

---@type boolean
local loaded = false

---@return CqlFilter[]
local function load_filters()
    if loaded then
        return filters
    end

    local path = config.options.data_dir .. "/cql_filters.json"
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
    local path = config.options.data_dir .. "/cql_filters.json"
    local file = io.open(path, "w")
    if not file then
        notify.error("Failed to write CQL filters file")
        return
    end
    file:write(vim.json.encode(filters))
    file:close()
end

---@param name string
---@param cql string
---@param space_key? string
---@param description? string
function M.save(name, cql, space_key, description)
    load_filters()

    for i, f in ipairs(filters) do
        if f.name == name and f.space_key == space_key then
            filters[i] = {
                name = name,
                cql = cql,
                space_key = space_key,
                description = description,
            }
            save_filters()
            notify.info(string.format("CQL filter '%s' updated", name))
            return
        end
    end

    table.insert(filters, {
        name = name,
        cql = cql,
        space_key = space_key,
        description = description,
    })
    save_filters()
    notify.info(string.format("CQL filter '%s' saved", name))
end

---@param name string
---@param space_key? string
---@return CqlFilter|nil
function M.get(name, space_key)
    load_filters()
    for _, f in ipairs(filters) do
        if f.name == name then
            if f.space_key == space_key then
                return f
            elseif f.space_key == nil then
                return f
            end
        end
    end
    return nil
end

---@param name string
---@param space_key? string
---@return boolean
function M.delete(name, space_key)
    load_filters()
    for i, f in ipairs(filters) do
        if f.name == name and (f.space_key == space_key or f.space_key == nil) then
            table.remove(filters, i)
            save_filters()
            notify.info(string.format("CQL filter '%s' deleted", name))
            return true
        end
    end
    return false
end

---@param space_key? string
---@return CqlFilter[]
function M.list(space_key)
    load_filters()
    local result = {}
    for _, f in ipairs(filters) do
        if f.space_key == nil or f.space_key == space_key then
            table.insert(result, f)
        end
    end
    return result
end

---@return CqlFilter[]
function M.list_all()
    return load_filters()
end

return M
