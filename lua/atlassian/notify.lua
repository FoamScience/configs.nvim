local M = {}

-- Active progress handles
local handles = {}

---@param msg string
---@param level? number vim.log.levels
function M.notify(msg, level)
    vim.notify(msg, level or vim.log.levels.INFO)
end

---@param msg string
function M.info(msg)
    vim.notify(msg, vim.log.levels.INFO)
end

---@param msg string
function M.warn(msg)
    vim.notify(msg, vim.log.levels.WARN)
end

---@param msg string
function M.error(msg)
    vim.notify(msg, vim.log.levels.ERROR)
end

---@param key string Unique key for this progress
---@param title string Title of the progress
---@param message? string Optional message
---@return string key The key to use for updates
function M.progress_start(key, title, message)
    local has_fidget, progress = pcall(require, "fidget.progress")
    if has_fidget then
        handles[key] = progress.handle.create({
            title = title,
            message = message or "Working...",
        })
    end
    return key
end

---@param key string The progress key
---@param message string New message
---@param percentage? number Optional percentage (0-100)
function M.progress_update(key, message, percentage)
    if handles[key] then
        handles[key]:report({
            message = message,
            percentage = percentage,
        })
    end
end

---@param key string The progress key
---@param message? string Final message
function M.progress_finish(key, message)
    if handles[key] then
        handles[key]:finish(message)
        handles[key] = nil
    end
end

---@param key string The progress key
---@param message string Error message
function M.progress_error(key, message)
    if handles[key] then
        handles[key]:finish(message)
        handles[key] = nil
    end
    M.error(message)
end

return M
