local M = {}

local config = require("jira-interface.config")
local notify = require("jira-interface.notify")

---@class CacheEntry
---@field data any Cached data
---@field timestamp number Unix timestamp when cached
---@field project string|nil Project key if project-specific

---@type table<string, CacheEntry>
local memory_cache = {}

---@return table
local function load_disk_cache()
    local path = config.get_cache_path()
    local file = io.open(path, "r")
    if not file then
        return {}
    end
    local content = file:read("*a")
    file:close()

    local ok, data = pcall(vim.json.decode, content)
    if not ok then
        return {}
    end
    return data
end

---@param cache table
local function save_disk_cache(cache)
    local path = config.get_cache_path()
    local file = io.open(path, "w")
    if not file then
        notify.error("Failed to write cache file")
        return
    end
    file:write(vim.json.encode(cache))
    file:close()
end

---@param key string
---@return any|nil
function M.get(key)
    local entry = memory_cache[key]
    if not entry then
        -- Try disk cache
        local disk = load_disk_cache()
        entry = disk[key]
        if entry then
            memory_cache[key] = entry
        end
    end

    if not entry then
        return nil
    end

    -- Check TTL
    local ttl = config.options.cache_ttl
    local age = os.time() - entry.timestamp
    if age > ttl then
        M.invalidate(key)
        return nil
    end

    return entry.data
end

---@param key string
---@param data any
---@param project? string
function M.set(key, data, project)
    local entry = {
        data = data,
        timestamp = os.time(),
        project = project,
    }

    memory_cache[key] = entry

    -- Also persist to disk
    local disk = load_disk_cache()
    disk[key] = entry
    save_disk_cache(disk)
end

---@param key string
function M.invalidate(key)
    memory_cache[key] = nil

    local disk = load_disk_cache()
    disk[key] = nil
    save_disk_cache(disk)
end

---@param project? string
function M.invalidate_project(project)
    -- Invalidate memory cache
    for key, entry in pairs(memory_cache) do
        if not project or entry.project == project then
            memory_cache[key] = nil
        end
    end

    -- Invalidate disk cache
    local disk = load_disk_cache()
    for key, entry in pairs(disk) do
        if not project or entry.project == project then
            disk[key] = nil
        end
    end
    save_disk_cache(disk)
end

function M.clear()
    memory_cache = {}
    save_disk_cache({})
end

---@param key string
---@param fetcher fun(callback: fun(err: string|nil, data: any))
---@param callback fun(err: string|nil, data: any)
---@param project? string
function M.get_or_fetch(key, fetcher, callback, project)
    local cached = M.get(key)
    if cached then
        callback(nil, cached)
        return
    end

    fetcher(function(err, data)
        if err then
            callback(err, nil)
            return
        end
        M.set(key, data, project)
        callback(nil, data)
    end)
end

---@return { entries: number, size_bytes: number }
function M.stats()
    local disk = load_disk_cache()
    local count = 0
    for _ in pairs(disk) do
        count = count + 1
    end

    local path = config.get_cache_path()
    local file = io.open(path, "r")
    local size = 0
    if file then
        size = file:seek("end") or 0
        file:close()
    end

    return {
        entries = count,
        size_bytes = size,
    }
end

return M
