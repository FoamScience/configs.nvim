-- Post-insertion interactive pickers for slash commands
-- Invoked after snippet expansion for commands with interactive = true
local M = {}

local STATUS_COLORS = {
    { name = "Green",  desc = "Success / Done" },
    { name = "Yellow", desc = "In Progress / Warning" },
    { name = "Red",    desc = "Error / Blocked" },
    { name = "Blue",   desc = "Info / New" },
    { name = "Grey",   desc = "Neutral / Default" },
}

---@param command_name string
function M.run(command_name)
    if command_name == "Mention" then
        M.pick_user()
    elseif command_name == "Page link" then
        M.pick_page()
    elseif command_name == "Jira issue" then
        M.pick_issue()
    elseif command_name == "Status" then
        M.pick_status_color()
    end
end

function M.pick_user()
    -- Try Jira project members first
    local jira_ok, jira_api = pcall(require, "jira-interface.api")
    if jira_ok then
        local jira_config = require("jira-interface.config")
        local project = jira_config.options.default_project or ""
        if project ~= "" then
            jira_api.get_project_members(project, function(err, members)
                if err or not members then
                    -- Fallback to manual input
                    vim.schedule(function()
                        vim.ui.input({ prompt = "User account ID: " }, function(input)
                            if input and input ~= "" then
                                M.replace_snippet_placeholder(input)
                            end
                        end)
                    end)
                    return
                end
                M.show_user_picker(members)
            end)
            return
        end
    end

    -- Fallback: prompt for account ID
    vim.ui.input({ prompt = "User account ID: " }, function(input)
        if input and input ~= "" then
            M.replace_snippet_placeholder(input)
        end
    end)
end

---@param members table[]
function M.show_user_picker(members)
    local Snacks = require("snacks")
    local items = {}
    for idx, member in ipairs(members) do
        table.insert(items, {
            idx = idx,
            text = (member.displayName or "") .. " " .. (member.emailAddress or ""),
            member = member,
            name = member.displayName or "",
        })
    end

    Snacks.picker.pick({
        title = "Select User",
        items = items,
        format = function(item, _picker)
            return { { item.name, "Normal" } }
        end,
        confirm = function(picker, item)
            picker:close()
            if item and item.member then
                -- CSF uses account ID for ri:user
                M.replace_snippet_placeholder(item.member.accountId or item.member.displayName or "")
            end
        end,
        layout = {
            layout = {
                box = "vertical",
                backdrop = false,
                row = -1,
                width = 0,
                height = 0.3,
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

function M.pick_page()
    local ok, api = pcall(require, "confluence-interface.api")
    if not ok then return end
    local config = require("confluence-interface.config")

    vim.ui.input({ prompt = "Search pages: " }, function(query)
        if not query or query == "" then return end

        api.search_pages(query, config.options.default_space, function(err, pages)
            if err or not pages or #pages == 0 then return end

            local Snacks = require("snacks")
            local items = {}
            for idx, page in ipairs(pages) do
                table.insert(items, {
                    idx = idx,
                    text = page.title .. " " .. (page.space_key or ""),
                    page = page,
                    title = page.title,
                    space_key = page.space_key or "",
                })
            end

            Snacks.picker.pick({
                title = "Select Page",
                items = items,
                format = function(item, _picker)
                    return {
                        { item.title, "Normal" },
                        { " ", "Normal" },
                        { "[" .. item.space_key .. "]", "Comment" },
                    }
                end,
                confirm = function(picker, item)
                    picker:close()
                    if item and item.page then
                        -- Replace the first placeholder with page title
                        M.replace_snippet_placeholder(item.page.title)
                        -- Then advance and replace space key
                        vim.schedule(function()
                            -- Try to jump to next placeholder and fill space key
                            local luasnip_ok, luasnip = pcall(require, "luasnip")
                            if luasnip_ok and luasnip.jumpable(1) then
                                luasnip.jump(1)
                                M.replace_snippet_placeholder(item.page.space_key or "")
                            end
                        end)
                    end
                end,
                layout = {
                    layout = {
                        box = "vertical",
                        backdrop = false,
                        row = -1,
                        width = 0,
                        height = 0.3,
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
    end)
end

function M.pick_issue()
    local ok, api = pcall(require, "jira-interface.api")
    if not ok then return end

    vim.ui.input({ prompt = "Search issues: " }, function(query)
        if not query or query == "" then return end

        local config = require("jira-interface.config")
        local escaped = query:gsub('"', '\\"')
        local jql = string.format('text ~ "%s" ORDER BY updated DESC', escaped)
        if config.options.default_project and config.options.default_project ~= "" then
            jql = string.format('project = "%s" AND text ~ "%s" ORDER BY updated DESC',
                config.options.default_project, escaped)
        end

        api.search(jql, function(err, issues)
            if err or not issues or #issues == 0 then return end

            local Snacks = require("snacks")
            local items = {}
            for idx, issue in ipairs(issues) do
                table.insert(items, {
                    idx = idx,
                    text = issue.key .. " " .. issue.summary,
                    issue = issue,
                    key = issue.key,
                    summary = issue.summary,
                })
            end

            Snacks.picker.pick({
                title = "Select Issue",
                items = items,
                format = function(item, _picker)
                    return {
                        { item.key, "Special" },
                        { " ", "Normal" },
                        { item.summary, "Normal" },
                    }
                end,
                confirm = function(picker, item)
                    picker:close()
                    if item and item.issue then
                        M.replace_snippet_placeholder(item.issue.key)
                    end
                end,
                layout = {
                    layout = {
                        box = "vertical",
                        backdrop = false,
                        row = -1,
                        width = 0,
                        height = 0.3,
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
    end)
end

function M.pick_status_color()
    local Snacks = require("snacks")
    local items = {}
    for idx, color in ipairs(STATUS_COLORS) do
        table.insert(items, {
            idx = idx,
            text = color.name .. " " .. color.desc,
            color = color,
            name = color.name,
            desc = color.desc,
        })
    end

    Snacks.picker.pick({
        title = "Select Status Color",
        items = items,
        format = function(item, _picker)
            local hl_map = {
                Green = "String", Yellow = "WarningMsg", Red = "Error",
                Blue = "Function", Grey = "Comment",
            }
            return {
                { item.name, hl_map[item.name] or "Normal" },
                { " - ", "Normal" },
                { item.desc, "Comment" },
            }
        end,
        confirm = function(picker, item)
            picker:close()
            if item then
                -- Jump to the colour placeholder and replace
                local luasnip_ok, luasnip = pcall(require, "luasnip")
                if luasnip_ok and luasnip.jumpable(1) then
                    luasnip.jump(1)
                end
                M.replace_snippet_placeholder(item.name)
            end
        end,
        layout = {
            layout = {
                box = "vertical",
                backdrop = false,
                row = -1,
                width = 0,
                height = 0.3,
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

--- Replace the currently selected snippet placeholder text with new text.
--- Works by selecting all text in the current tabstop and typing over it.
---@param text string
function M.replace_snippet_placeholder(text)
    -- In insert mode with an active snippet, the placeholder is selected.
    -- We can just feed keys to type the replacement.
    local escaped = vim.fn.escape(text, "\\|")
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-g>s" .. escaped, true, false, true), "n", false)
end

--- Setup buffer-local keymap for <C-Space> to trigger interactive picker
--- Called when entering atlassian/csf buffers
function M.setup_keymap(buf)
    vim.keymap.set("i", "<C-Space>", function()
        -- Unified CSF detection — both Confluence and Jira buffers contain CSF
        local line = vim.api.nvim_get_current_line()

        if line:match("ri:user") then
            M.run("Mention")
        elseif line:match("ri:page") or line:match("ri:content%-title") then
            M.run("Page link")
        elseif line:match('ac:name="jira"') then
            M.run("Jira issue")
        elseif line:match('ac:name="status"') then
            M.run("Status")
        else
            M.run("Mention")
        end
    end, { buffer = buf, desc = "Slash command interactive picker" })
end

return M
