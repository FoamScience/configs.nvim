local atlassian_cache = require("atlassian.cache")
local config = require("confluence-interface.config")

-- Create cache instance with confluence-specific config
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

function M.set(key, data, space)
    return get_cache().set(key, data, space)
end

function M.invalidate(key)
    return get_cache().invalidate(key)
end

function M.invalidate_space(space)
    return get_cache().invalidate_scope(space)
end

function M.clear()
    return get_cache().clear()
end

function M.get_or_fetch(key, fetcher, callback, space)
    return get_cache().get_or_fetch(key, fetcher, callback, space)
end

function M.stats()
    return get_cache().stats()
end

return M
