-- Re-export shared notify module with Jira-specific helpers
local base = require("atlassian.notify")
local error_mod = require("atlassian.error")

local M = setmetatable({}, { __index = base })

--- Format an API error with user-friendly context and hints.
---@param err AtlassianError|string
---@param context string What was being attempted (e.g., "updating PROJ-123", "adding comment")
---@return string User-friendly error message
function M.format_api_error(err, context)
    local msg = "Failed " .. context .. ": "
    if error_mod.is_validation_error(err) then
        msg = msg .. tostring(err)
        local raw = (error_mod.is_error(err) and err.raw_response) or ""
        if raw:match("taskList") or raw:match("taskItem") then
            msg = msg .. "\n(Hint: task lists are not supported — they should have been converted to bullet lists)"
        elseif raw:match("content should not be empty") or raw:match("Invalid content") then
            msg = msg .. "\n(Hint: the document contains empty or invalid nodes)"
        end
    else
        msg = msg .. tostring(err)
    end
    return msg
end

return M
