local M = {}

---Extract issue key from current git branch
---@return string|nil Issue key (e.g., "PROJ-123") or nil if not found
function M.get_issue_from_branch()
    local result = vim.fn.system("git branch --show-current 2>/dev/null")
    if vim.v.shell_error ~= 0 then
        return nil
    end

    local branch = result:gsub("\n", "")
    -- Match patterns: PROJ-123, feature/PROJ-123-desc, bugfix/PROJ-123, etc.
    local key = branch:match("([A-Z][A-Z0-9]*%-[0-9]+)")
    return key
end

---Get issue key from args, branch, or nil
---@param args string|nil Command argument
---@return string|nil Issue key or nil
function M.resolve_issue_key(args)
    -- Explicit arg takes priority
    if args and args ~= "" then
        return args
    end

    -- Try branch detection
    return M.get_issue_from_branch()
end

---Resolve issue key, falling back to picker if needed
---@param args string|nil Command argument
---@param callback fun(key: string) Called with resolved issue key
function M.resolve_issue_key_or_pick(args, callback)
    local key = M.resolve_issue_key(args)

    if key then
        callback(key)
        return
    end

    -- Fall back to assigned issues picker
    local api = require("jira-interface.api")
    local filters = require("jira-interface.filters")
    local notify = require("jira-interface.notify")

    local jql = filters.builtin.assigned_to_me()
    api.search(jql, function(err, issues)
        if err then
            notify.error("Failed to fetch issues: " .. err)
            return
        end

        if #issues == 0 then
            notify.info("No assigned issues found")
            return
        end

        M.show_issue_picker(issues, "Select Issue", callback)
    end)
end

---Show a simple issue picker and call callback with selected key
---@param issues JiraIssue[]
---@param title string
---@param callback fun(key: string)
function M.show_issue_picker(issues, title, callback)
    local Snacks = require("snacks")
    local types = require("jira-interface.types")

    local items = {}
    for idx, issue in ipairs(issues) do
        local status_info = types.get_status_display(issue.status)
        table.insert(items, {
            idx = idx,
            text = issue.key .. " " .. issue.status .. " " .. issue.summary,
            issue = issue,
            key = issue.key,
            status = issue.status,
            status_icon = status_info.icon,
            status_hl = status_info.hl,
            summary = issue.summary,
        })
    end

    Snacks.picker.pick({
        title = title,
        items = items,
        format = function(item, _picker)
            return {
                { item.key,                "Special" },
                { "  ",                    "Normal" },
                { item.status_icon .. " ", item.status_hl },
                { item.status,             item.status_hl },
                { "  ",                    "Normal" },
                { item.summary or "",      "Normal" },
            }
        end,
        confirm = function(picker, item)
            picker:close()
            if item and item.key then
                callback(item.key)
            end
        end,
        layout = {
            layout = {
                box = "vertical",
                backdrop = false,
                row = -1,
                width = 0,
                height = 0.4,
                border = "top",
                title = " {title} {live} {flags}",
                title_pos = "left",
                { win = "input", height = 1, border = "bottom" },
                { win = "list", border = "none" },
            },
        },
        preview = false,
    })
end

return M
