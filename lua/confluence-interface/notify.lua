-- Re-export shared notify module with Confluence-specific helpers
local base = require("atlassian.notify")
local error_mod = require("atlassian.error")

local M = setmetatable({}, { __index = base })

--- Format an API error with user-friendly context and hints.
---@param err AtlassianError|string
---@param context string What was being attempted (e.g., "saving page", "creating page")
---@return string User-friendly error message
function M.format_api_error(err, context)
    local msg = "Failed " .. context .. ": "
    if error_mod.is_validation_error(err) then
        msg = msg .. tostring(err)
        local raw = (error_mod.is_error(err) and err.raw_response) or ""
        if raw:match("title") and raw:match("already exists") then
            msg = msg .. "\n(Hint: a page with this title already exists in the space)"
        elseif raw:match("storage") or raw:match("XHTML") or raw:match("parsing") then
            msg = msg .. "\n(Hint: the page body contains invalid storage format / XHTML)"
        elseif raw:match("version") then
            msg = msg .. "\n(Hint: version conflict — the page may have been edited elsewhere)"
        end
    else
        msg = msg .. tostring(err)
    end
    return msg
end

return M
