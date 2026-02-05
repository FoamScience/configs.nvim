local M = {}

local error_mod = require("atlassian.error")

---@class RetryConfig
---@field max_retries? number Maximum retry attempts (default: 3)
---@field base_delay_ms? number Initial delay in milliseconds (default: 1000)
---@field backoff_factor? number Multiplier per retry (default: 2)
---@field max_delay_ms? number Maximum delay cap (default: 10000)

---@type RetryConfig
M.defaults = {
    max_retries = 3,
    base_delay_ms = 1000,
    backoff_factor = 2,
    max_delay_ms = 10000,
}

---@param delay number
---@return number delay with +/- 25% jitter
local function add_jitter(delay)
    local jitter_range = delay * 0.25
    local jitter = (math.random() * 2 - 1) * jitter_range
    return math.max(1, math.floor(delay + jitter))
end

--- Wraps an async callback-based function with exponential backoff retry.
--- The wrapped function `fn` must accept a callback as its last argument:
---   fn(callback) where callback(err, data)
---
--- Only retries when error.is_retryable(err) is true (network, 429, 5xx).
---
---@param fn fun(callback: fun(err: any, data: any)) The async function to retry
---@param callback fun(err: any, data: any) Final callback after all retries exhausted
---@param config? RetryConfig Override default retry settings
function M.with_retry(fn, callback, config)
    config = vim.tbl_deep_extend("force", {}, M.defaults, config or {})
    local attempt = 0

    local function try()
        fn(function(err, data)
            if not err then
                callback(nil, data)
                return
            end

            attempt = attempt + 1

            if attempt >= config.max_retries or not error_mod.is_retryable(err) then
                callback(err, data)
                return
            end

            local delay = config.base_delay_ms * (config.backoff_factor ^ (attempt - 1))
            delay = math.min(delay, config.max_delay_ms)
            delay = add_jitter(delay)

            vim.defer_fn(try, delay)
        end)
    end

    try()
end

return M
