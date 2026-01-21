local M = {}

local api = require("jira-interface.api")
local config = require("jira-interface.config")
local notify = require("jira-interface.notify")
local types = require("jira-interface.types")

-- Fixed column widths
local COL_KEY = 12
local COL_STATUS = 14

---@param str string
---@param width number
---@return string
local function pad_right(str, width)
    str = str or ""
    if #str >= width then
        return str:sub(1, width)
    end
    return str .. string.rep(" ", width - #str)
end

---@param project? string
function M.show_team_dashboard(project)
    project = project or config.options.default_project

    if not project or project == "" then
        M.select_project_then_show()
        return
    end

    notify.progress_start("team", "Loading team workload")

    api.get_team_workload(project, function(err, workload)
        if err then
            notify.progress_error("team", "Failed to load team: " .. err)
            return
        end

        notify.progress_finish("team", "Team loaded")
        M.show_workload_picker(project, workload)
    end)
end

---@param project string
---@param workload table
function M.show_workload_picker(project, workload)
    local Snacks = require("snacks")

    local items = {}
    local idx = 0

    -- Add team members with their issues
    for _, member in ipairs(workload.members) do
        -- Count statuses
        local in_progress = 0
        local blocked = 0
        local todo = 0
        for _, issue in ipairs(member.issues) do
            if issue.status == "In Progress" or issue.status == "In Review" then
                in_progress = in_progress + 1
            elseif issue.status == "Blocked" then
                blocked = blocked + 1
            else
                todo = todo + 1
            end
        end

        -- Member header
        idx = idx + 1
        local status_summary = {}
        if in_progress > 0 then table.insert(status_summary, in_progress .. " active") end
        if blocked > 0 then table.insert(status_summary, blocked .. " blocked") end
        if todo > 0 then table.insert(status_summary, todo .. " todo") end

        table.insert(items, {
            idx = idx,
            text = member.name .. " " .. table.concat(status_summary, ", "),
            is_header = true,
            member_name = member.name,
            issue_count = #member.issues,
            status_summary = table.concat(status_summary, ", "),
        })

        -- Member's issues
        for _, issue in ipairs(member.issues) do
            idx = idx + 1
            local status_info = types.get_status_display(issue.status)
            table.insert(items, {
                idx = idx,
                text = issue.key .. " " .. issue.status .. " " .. issue.summary,
                is_header = false,
                issue = issue,
                key = issue.key,
                status = issue.status,
                status_icon = status_info.icon,
                status_hl = status_info.hl,
                summary = issue.summary,
                indent = true,
            })
        end
    end

    -- Add unassigned section
    if #workload.unassigned > 0 then
        idx = idx + 1
        table.insert(items, {
            idx = idx,
            text = "Unassigned " .. #workload.unassigned .. " items",
            is_header = true,
            is_unassigned = true,
            member_name = "Unassigned",
            issue_count = #workload.unassigned,
            status_summary = #workload.unassigned .. " items",
        })

        for _, issue in ipairs(workload.unassigned) do
            idx = idx + 1
            local status_info = types.get_status_display(issue.status)
            table.insert(items, {
                idx = idx,
                text = issue.key .. " " .. issue.status .. " " .. issue.summary,
                is_header = false,
                issue = issue,
                key = issue.key,
                status = issue.status,
                status_icon = status_info.icon,
                status_hl = status_info.hl,
                summary = issue.summary,
                indent = true,
                is_unassigned = true,
            })
        end
    end

    if #items == 0 then
        notify.info("No active issues found for project " .. project)
        return
    end

    Snacks.picker.pick({
        title = "Team Dashboard: " .. project .. " (" .. workload.total .. " issues)",
        items = items,
        format = function(item, _picker)
            local ret = {}
            if item.is_header then
                -- Member header row
                local icon = item.is_unassigned and "" or ""
                table.insert(ret, { icon .. " ", item.is_unassigned and "WarningMsg" or "Title" })
                table.insert(ret, { item.member_name, "Title" })
                table.insert(ret, { " (" .. item.status_summary .. ")", "Comment" })
            else
                -- Issue row
                if item.indent then
                    table.insert(ret, { "  ", "Normal" })
                end
                table.insert(ret, { pad_right(item.key, COL_KEY), "Special" })
                table.insert(ret, { " ", "Normal" })
                table.insert(ret, { item.status_icon .. " ", item.status_hl })
                table.insert(ret, { pad_right(item.status, COL_STATUS), item.status_hl })
                table.insert(ret, { " ", "Normal" })
                table.insert(ret, { item.summary or "", "Normal" })
            end
            return ret
        end,
        confirm = function(picker, item)
            if item and item.issue then
                picker:close()
                local ui = require("jira-interface.ui")
                ui.show_issue(item.issue)
            end
        end,
        actions = {
            assign_to_me = function(picker, item)
                if item and item.issue then
                    M.assign_to_me(item.issue.key, function(success)
                        if success then
                            picker:close()
                            -- Refresh
                            M.show_team_dashboard(project)
                        end
                    end)
                end
            end,
            transition = function(picker, item)
                if item and item.issue then
                    picker:close()
                    local ui = require("jira-interface.ui")
                    ui.show_transition_picker(item.issue.key)
                end
            end,
        },
        layout = {
            layout = {
                box = "vertical",
                backdrop = false,
                row = -1,
                width = 0,
                height = 0.5,
                border = "top",
                title = " {title} {live} {flags}",
                title_pos = "left",
                { win = "input", height = 1, border = "bottom" },
                { win = "list", border = "none" },
            },
        },
        preview = false,
        win = {
            input = {
                keys = {
                    ["<C-a>"] = { "assign_to_me", mode = { "n", "i" }, desc = "Assign to me" },
                    ["<C-t>"] = { "transition", mode = { "n", "i" }, desc = "Transition status" },
                },
            },
        },
    })
end

---@param key string
---@param callback fun(success: boolean)
function M.assign_to_me(key, callback)
    notify.progress_start("assign", "Assigning " .. key)

    api.get_current_user(function(user_err, user)
        if user_err or not user then
            notify.progress_error("assign", "Failed to get current user")
            callback(false)
            return
        end

        api.assign_issue(key, user.accountId, function(err)
            if err then
                notify.progress_error("assign", "Failed to assign: " .. err)
                callback(false)
            else
                notify.progress_finish("assign", key .. " assigned to you")
                callback(true)
            end
        end)
    end)
end

function M.select_project_then_show()
    notify.progress_start("projects", "Loading projects")

    api.get_projects(function(err, projects)
        if err then
            notify.progress_error("projects", "Failed to load projects: " .. err)
            return
        end

        notify.progress_finish("projects")

        if #projects == 0 then
            notify.warn("No projects found")
            return
        end

        local Snacks = require("snacks")

        local items = {}
        for idx, p in ipairs(projects) do
            table.insert(items, {
                idx = idx,
                text = p.key .. " " .. p.name,
                project = p,
                key = p.key,
                name = p.name,
            })
        end

        Snacks.picker.pick({
            title = "Select Project for Team Dashboard",
            items = items,
            format = function(item, _picker)
                return {
                    { pad_right(item.key, 10), "Special" },
                    { "  ", "Normal" },
                    { item.name, "Normal" },
                }
            end,
            confirm = function(picker, item)
                picker:close()
                if item and item.project then
                    M.show_team_dashboard(item.project.key)
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
    end)
end

return M
