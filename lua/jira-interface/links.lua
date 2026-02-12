local M = {}

local api = require("jira-interface.api")
local types = require("jira-interface.types")
local cache = require("jira-interface.cache")
local config = require("jira-interface.config")
local notify = require("jira-interface.notify")

--- Wipe any existing issue view buffer so show_issue can recreate it
---@param issue_key string
local function wipe_issue_buf(issue_key)
    local bufname = "jira://" .. issue_key
    local existing = vim.fn.bufnr(bufname)
    if existing ~= -1 and vim.api.nvim_buf_is_valid(existing) then
        vim.api.nvim_buf_delete(existing, { force = true })
    end
end

--- Refresh the issue view buffer after a link action
---@param issue_key string
local function refresh_issue_view(issue_key)
    api.get_issue(issue_key, function(err, fresh_issue)
        if err then
            notify.info("Link updated for " .. issue_key)
        else
            wipe_issue_buf(issue_key)
            local ui = require("jira-interface.ui")
            ui.show_issue(fresh_issue)
        end
    end)
end

---@param issue JiraIssue
---@return string[] CSF lines for the links section
function M.render_links_section(issue)
    local lines = {}
    local links = issue.links or {}

    if #links == 0 then
        return lines
    end

    table.insert(lines, "<hr />")
    table.insert(lines, "<h2>Links (" .. #links .. ")</h2>")

    -- Group links by label (e.g., "blocks", "is blocked by")
    local groups = {}
    local group_order = {}
    for _, link in ipairs(links) do
        if not groups[link.label] then
            groups[link.label] = {}
            table.insert(group_order, link.label)
        end
        table.insert(groups[link.label], link)
    end

    table.insert(lines, "<ul>")
    for _, label in ipairs(group_order) do
        for _, link in ipairs(groups[label]) do
            local status_info = types.get_status_display(link.issue_status)
            table.insert(lines, "<li><strong>" .. label .. "</strong> "
                .. link.issue_key .. " " .. status_info.icon .. " " .. link.issue_summary .. "</li>")
        end
    end
    table.insert(lines, "</ul>")

    return lines
end

---@param issue_key string
function M.add_link(issue_key)
    api.get_link_types(function(err, link_types)
        if err then
            notify.error("Failed to fetch link types: " .. err)
            return
        end

        if not link_types or #link_types == 0 then
            notify.warn("No link types available")
            return
        end

        -- Build direction options: each type appears twice (outward + inward)
        local items = {}
        local item_data = {}
        for _, lt in ipairs(link_types) do
            table.insert(items, lt.outward .. " (outward)")
            table.insert(item_data, { type_name = lt.name, direction = "outward", label = lt.outward })
            table.insert(items, lt.inward .. " (inward)")
            table.insert(item_data, { type_name = lt.name, direction = "inward", label = lt.inward })
        end

        vim.ui.select(items, { prompt = "Link type:" }, function(_, idx)
            if not idx then
                return
            end

            local selected = item_data[idx]

            -- Search for target issue: prompt for query, then show picker
            vim.schedule(function()
            vim.ui.input({ prompt = "Search target issue: " }, function(query)
                if not query or query == "" then
                    return
                end

                local escaped = query:gsub('"', '\\"')
                local project = config.options.default_project
                local jql
                if project and project ~= "" then
                    jql = string.format('project = "%s" AND text ~ "%s" ORDER BY updated DESC', project, escaped)
                else
                    jql = string.format('text ~ "%s" ORDER BY updated DESC', escaped)
                end

                local picker = require("jira-interface.picker")
                picker.search(jql, {
                    title = issue_key .. ": " .. selected.label .. " ...",
                    on_confirm = function(target_issue)
                    local target_key = target_issue.key
                    local inward_key, outward_key
                    if selected.direction == "outward" then
                        inward_key = target_key
                        outward_key = issue_key
                    else
                        inward_key = issue_key
                        outward_key = target_key
                    end

                    api.create_link(selected.type_name, inward_key, outward_key, function(link_err)
                        if link_err then
                            notify.error("Failed to create link: " .. link_err)
                        else
                            cache.invalidate_project(config.options.default_project)
                            notify.info("Link created: " .. issue_key .. " " .. selected.label .. " " .. target_key)
                            refresh_issue_view(issue_key)
                        end
                    end)
                end,
                })
            end)
            end)
        end)
    end)
end

---@param issue_key string
---@param links JiraIssueLink[]
function M.delete_link(issue_key, links)
    if #links == 0 then
        notify.info("No links on " .. issue_key)
        return
    end

    local items = {}
    for _, link in ipairs(links) do
        table.insert(items, link.label .. " " .. link.issue_key .. ": " .. link.issue_summary)
    end

    vim.ui.select(items, { prompt = "Select link to delete:" }, function(_, idx)
        if not idx then
            return
        end

        local link = links[idx]
        vim.ui.input({ prompt = "Delete link '" .. link.label .. " " .. link.issue_key .. "'? [yes/no]: " }, function(input)
            if not input or input:lower() ~= "yes" then
                return
            end

            api.delete_link(link.id, function(err)
                if err then
                    notify.error("Failed to delete link: " .. err)
                else
                    cache.invalidate_project(config.options.default_project)
                    notify.info("Link deleted from " .. issue_key)
                    refresh_issue_view(issue_key)
                end
            end)
        end)
    end)
end

---@param issue_key string
function M.fetch_and_delete_link(issue_key)
    api.get_issue(issue_key, function(err, issue)
        if err then
            notify.error("Failed to fetch issue: " .. err)
            return
        end
        M.delete_link(issue_key, issue.links or {})
    end)
end

return M
