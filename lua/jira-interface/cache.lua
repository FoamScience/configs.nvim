local atlassian_cache = require("atlassian.cache")
local config = require("jira-interface.config")

-- Create cache instance with jira-specific config
local cache_instance = nil

local M = {}

local function get_cache()
    if not cache_instance then
        cache_instance = atlassian_cache.create_cache({
            cache_path = config.get_cache_path(),
            cache_ttl = config.options.cache_ttl,
        })
    end
    return cache_instance
end

function M.get(key)
    return get_cache().get(key)
end

function M.set(key, data, project)
    return get_cache().set(key, data, project)
end

function M.invalidate_project(project)
    return get_cache().invalidate_scope(project)
end

function M.clear()
    return get_cache().clear()
end

function M.stats()
    return get_cache().stats()
end

---@param key string Cache key
---@param fetcher fun(callback: fun(err: string|nil, data: any))
---@param callback fun(err: string|nil, data: any)
---@param scope? string Optional scope for cache invalidation
function M.get_or_fetch(key, fetcher, callback, scope)
    return get_cache().get_or_fetch(key, fetcher, callback, scope)
end

return M
