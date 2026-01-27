local M = {}

---@class AtlassianCacheConfig
---@field cache_path string Path to cache file
---@field cache_ttl number Time-to-live in seconds

---@class CacheEntry
---@field data any Cached data
---@field timestamp number Unix timestamp when cached
---@field scope string|nil Scope identifier (project/space)

---@param config AtlassianCacheConfig
---@return table Cache instance
function M.create_cache(config)
    local cache = {}
    local memory_cache = {}

    local function load_disk_cache()
        local file = io.open(config.cache_path, "r")
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

    local function save_disk_cache(disk_cache)
        local file = io.open(config.cache_path, "w")
        if not file then
            return
        end
        file:write(vim.json.encode(disk_cache))
        file:close()
    end

    ---@param key string
    ---@return any|nil
    function cache.get(key)
        local entry = memory_cache[key]
        if not entry then
            local disk = load_disk_cache()
            entry = disk[key]
            if entry then
                memory_cache[key] = entry
            end
        end

        if not entry then
            return nil
        end

        local age = os.time() - entry.timestamp
        if age > config.cache_ttl then
            cache.invalidate(key)
            return nil
        end

        return entry.data
    end

    ---@param key string
    ---@param data any
    ---@param scope? string
    function cache.set(key, data, scope)
        local entry = {
            data = data,
            timestamp = os.time(),
            scope = scope,
        }

        memory_cache[key] = entry

        local disk = load_disk_cache()
        disk[key] = entry
        save_disk_cache(disk)
    end

    ---@param key string
    function cache.invalidate(key)
        memory_cache[key] = nil

        local disk = load_disk_cache()
        disk[key] = nil
        save_disk_cache(disk)
    end

    ---@param scope? string
    function cache.invalidate_scope(scope)
        for key, entry in pairs(memory_cache) do
            if not scope or entry.scope == scope then
                memory_cache[key] = nil
            end
        end

        local disk = load_disk_cache()
        for key, entry in pairs(disk) do
            if not scope or entry.scope == scope then
                disk[key] = nil
            end
        end
        save_disk_cache(disk)
    end

    function cache.clear()
        memory_cache = {}
        save_disk_cache({})
    end

    ---@param key string
    ---@param fetcher fun(callback: fun(err: string|nil, data: any))
    ---@param callback fun(err: string|nil, data: any)
    ---@param scope? string
    function cache.get_or_fetch(key, fetcher, callback, scope)
        local cached = cache.get(key)
        if cached then
            callback(nil, cached)
            return
        end

        fetcher(function(err, data)
            if err then
                callback(err, nil)
                return
            end
            cache.set(key, data, scope)
            callback(nil, data)
        end)
    end

    ---@return { entries: number, size_bytes: number }
    function cache.stats()
        local disk = load_disk_cache()
        local count = 0
        for _ in pairs(disk) do
            count = count + 1
        end

        local file = io.open(config.cache_path, "r")
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

    return cache
end

return M
