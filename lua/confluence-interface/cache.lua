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

function M.invalidate_space(space)
    return get_cache().invalidate_scope(space)
end

function M.clear()
    return get_cache().clear()
end

function M.get_or_fetch(key, fetcher, callback, space)
    return get_cache().get_or_fetch(key, fetcher, callback, space)
end

return M
