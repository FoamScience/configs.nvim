local M = {}

---@class AtlassianError
---@field category string Error category
---@field status_code number|nil HTTP status code (nil for network/parse errors)
---@field message string Human-readable error message
---@field raw_response string|nil Raw response body
---@field retryable boolean Whether this error is safe to retry

local AtlassianError = {}
AtlassianError.__index = AtlassianError

function AtlassianError:__tostring()
    return self.message
end

function AtlassianError:__concat(other)
    return tostring(self) .. tostring(other)
end

-- Allow "prefix: " .. err (string on left side)
---@diagnostic disable-next-line: duplicate-set-field
function AtlassianError.__concat(a, b)
    return tostring(a) .. tostring(b)
end

-- Delegate :match() to self.message for backward compat (used in api.lua create_issue)
function AtlassianError:match(pattern)
    return self.message:match(pattern)
end

-- Delegate :find() to self.message
function AtlassianError:find(pattern, init, plain)
    return self.message:find(pattern, init, plain)
end

-- Delegate :lower() to self.message
function AtlassianError:lower()
    return self.message:lower()
end

-- Delegate :sub() to self.message
function AtlassianError:sub(i, j)
    return self.message:sub(i, j)
end

---@param status_code number
---@return string
local function categorize_status(status_code)
    if status_code == 401 or status_code == 403 then
        return "auth"
    elseif status_code == 404 then
        return "not_found"
    elseif status_code == 429 then
        return "rate_limit"
    elseif status_code >= 500 then
        return "server"
    elseif status_code == 400 then
        return "validation"
    else
        return "unknown"
    end
end

---@param category string
---@param status_code number|nil
---@return boolean
local function is_retryable(category, status_code)
    return category == "network"
        or category == "rate_limit"
        or category == "server"
end

---@param opts { category: string, status_code?: number, message: string, raw_response?: string }
---@return AtlassianError
function M.new(opts)
    local err = setmetatable({}, AtlassianError)
    err.category = opts.category
    err.status_code = opts.status_code
    err.message = opts.message
    err.raw_response = opts.raw_response
    err.retryable = is_retryable(opts.category, opts.status_code)
    return err
end

---@param message string
---@param stderr? string
---@return AtlassianError
function M.network(message, stderr)
    return M.new({
        category = "network",
        message = message,
        raw_response = stderr,
    })
end

---@param status_code number
---@param message string
---@param raw_response? string
---@return AtlassianError
function M.http(status_code, message, raw_response)
    local category = categorize_status(status_code)
    local msg = message

    -- Add helpful hints for auth errors
    if category == "auth" then
        msg = msg .. " (check your API token and permissions)"
    end

    return M.new({
        category = category,
        status_code = status_code,
        message = msg,
        raw_response = raw_response,
    })
end

---@param message string
---@param raw_response? string
---@return AtlassianError
function M.parse(message, raw_response)
    return M.new({
        category = "parse",
        message = message,
        raw_response = raw_response,
    })
end

---@param err any
---@return boolean
function M.is_error(err)
    return type(err) == "table" and getmetatable(err) == AtlassianError
end

---@param err any
---@return boolean
function M.is_network_error(err)
    if M.is_error(err) then
        return err.category == "network"
    end
    -- Backward compat: check plain string
    if type(err) == "string" then
        return err:match("^Network error") ~= nil
    end
    return false
end

---@param err any
---@return boolean
function M.is_auth_error(err)
    if M.is_error(err) then
        return err.category == "auth"
    end
    if type(err) == "string" then
        return err:match("HTTP 401") ~= nil or err:match("HTTP 403") ~= nil
    end
    return false
end

---@param err any
---@return boolean
function M.is_retryable(err)
    if M.is_error(err) then
        return err.retryable
    end
    -- Backward compat: check plain string
    if type(err) == "string" then
        return err:match("^Network error") ~= nil
            or err:match("HTTP 429") ~= nil
            or err:match("HTTP 5%d%d") ~= nil
    end
    return false
end

---@param err any
---@return boolean
function M.is_rate_limit(err)
    if M.is_error(err) then
        return err.category == "rate_limit"
    end
    if type(err) == "string" then
        return err:match("HTTP 429") ~= nil
    end
    return false
end

return M
