local M = {}

local types = require('blink.cmp.types')

local enabled_filetypes = {
    atlassian_jira = true,
    atlassian_confluence = true,
    gitcommit = true,
    NeogitCommitMessage = true,
}

--- Session-level cache for search results
local result_cache = {}
local debounce_timer = nil
local DEBOUNCE_MS = 300

function M.new(opts)
    local self = setmetatable({}, { __index = M })
    self.opts = opts
    self.opts.name = "jira"
    return self
end

function M:enabled()
    return enabled_filetypes[vim.bo.filetype] == true
end

function M:get_trigger_characters()
    return {}
end

function M:get_completions(ctx, callback)
    local keyword = ctx.query
    if #keyword < 2 then
        callback({ items = {}, is_incomplete_backward = false, is_incomplete_forward = false })
        return function() end
    end

    -- Return cached results immediately if available
    if result_cache[keyword] then
        callback({
            items = result_cache[keyword],
            is_incomplete_backward = true,
            is_incomplete_forward = true,
        })
        return function() end
    end

    -- Debounce API calls
    if debounce_timer then
        debounce_timer:stop()
    end

    local cancel = false
    debounce_timer = vim.uv.new_timer()
    debounce_timer:start(DEBOUNCE_MS, 0, vim.schedule_wrap(function()
        if cancel then return end

        local ok, api = pcall(require, "jira-interface.api")
        if not ok then
            callback({ items = {}, is_incomplete_backward = false, is_incomplete_forward = false })
            return
        end

        local config = require("jira-interface.config")
        local escaped = keyword:gsub('"', '\\"')
        local jql = string.format('text ~ "%s" ORDER BY updated DESC', escaped)
        if config.options and config.options.default_project and config.options.default_project ~= "" then
            jql = string.format('project = "%s" AND text ~ "%s" ORDER BY updated DESC',
                config.options.default_project, escaped)
        end

        api.search(jql, function(err, issues)
            if err or not issues then
                callback({ items = {}, is_incomplete_backward = false, is_incomplete_forward = false })
                return
            end

            local items = {}
            for _, issue in ipairs(issues) do
                local status_display = ""
                local ok_types, issue_types = pcall(require, "jira-interface.types")
                if ok_types then
                    local status_info = issue_types.get_status_display(issue.status)
                    status_display = status_info.icon .. " " .. issue.status
                else
                    status_display = issue.status
                end

                table.insert(items, {
                    label = issue.key .. ": " .. (issue.summary or ""),
                    insertText = issue.key,
                    kind = types.CompletionItemKind.Reference,
                    filterText = table.concat({
                        issue.key,
                        issue.summary or "",
                        issue.assignee or "",
                    }, " "),
                    documentation = {
                        kind = "markdown",
                        value = table.concat({
                            "**" .. issue.key .. "** - " .. (issue.summary or ""),
                            "",
                            "- **Status:** " .. status_display,
                            "- **Type:** " .. (issue.type or ""),
                            "- **Assignee:** " .. (issue.assignee or "Unassigned"),
                            "- **Project:** " .. (issue.project or ""),
                        }, "\n"),
                    },
                })
            end

            result_cache[keyword] = items

            vim.schedule(function()
                if not cancel then
                    callback({
                        items = items,
                        is_incomplete_backward = true,
                        is_incomplete_forward = true,
                    })
                end
            end)
        end)
    end))

    return function()
        cancel = true
    end
end

return M
