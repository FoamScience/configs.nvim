local M = {}

local api = require("confluence-interface.api")
local types = require("confluence-interface.types")
local cache = require("confluence-interface.cache")
local config = require("confluence-interface.config")
local notify = require("confluence-interface.notify")
local atlassian_ui = require("atlassian.ui")
local atlassian_format = require("atlassian.format")

local COL_TITLE = 40
local COL_SPACE = 12
local COL_UPDATED = 16

-- Use shared UI helpers
local pad_right = atlassian_ui.pad_right
local truncate = atlassian_ui.truncate

---@param pages ConfluencePage[]
---@param opts? { title?: string, on_confirm?: fun(page: ConfluencePage) }
function M.show_pages(pages, opts)
    opts = opts or {}

    if #pages == 0 then
        notify.info("No pages found")
        return
    end

    local Snacks = require("snacks")

    local items = {}
    for idx, page in ipairs(pages) do
        table.insert(items, {
            idx = idx,
            text = string.format("%s %s %s", page.title, page.space_key or "", page.updated),
            page = page,
            title = page.title,
            space_key = page.space_key or "",
            updated = atlassian_format.format_relative_time(page.updated),
            version = page.version,
        })
    end

    Snacks.picker.pick({
        title = opts.title or "Confluence Pages",
        items = items,
        format = function(item, _picker)
            local ret = {}
            table.insert(ret, { truncate(item.title, COL_TITLE), "Function" })
            table.insert(ret, { " ", "Normal" })
            table.insert(ret, { pad_right(item.space_key, COL_SPACE), "Comment" })
            table.insert(ret, { " ", "Normal" })
            table.insert(ret, { pad_right(item.updated, COL_UPDATED), "Special" })
            table.insert(ret, { " ", "Normal" })
            table.insert(ret, { "v" .. tostring(item.version), "Number" })
            return ret
        end,
        confirm = function(picker, item)
            picker:close()
            if item and item.page then
                if opts.on_confirm then
                    opts.on_confirm(item.page)
                else
                    local ui = require("confluence-interface.ui")
                    ui.view_page(item.page.id)
                end
            end
        end,
        actions = {
            edit = function(picker, item)
                if item and item.page then
                    picker:close()
                    local ui = require("confluence-interface.ui")
                    ui.edit_page(item.page.id)
                end
            end,
            copy_url = function(_, item)
                if item and item.page and item.page.web_url then
                    local base_url = config.options.auth.url
                    if not base_url:match("^https?://") then
                        base_url = "https://" .. base_url
                    end
                    local url = base_url .. "/wiki" .. item.page.web_url
                    vim.fn.setreg("+", url)
                    notify.info("Copied: " .. url)
                end
            end,
            open_browser = function(_, item)
                if item and item.page and item.page.web_url then
                    local base_url = config.options.auth.url
                    if not base_url:match("^https?://") then
                        base_url = "https://" .. base_url
                    end
                    local url = base_url .. "/wiki" .. item.page.web_url
                    vim.ui.open(url)
                end
            end,
            children = function(picker, item)
                if item and item.page then
                    picker:close()
                    M.show_children(item.page.id, item.page.title)
                end
            end,
            delete = function(picker, item)
                if item and item.page then
                    vim.ui.input({ prompt = "Delete page '" .. item.page.title .. "'? (yes/no): " }, function(input)
                        if input == "yes" then
                            api.delete_page(item.page.id, function(err)
                                if err then
                                    notify.error(notify.format_api_error(err, "deleting page"))
                                else
                                    notify.info("Deleted: " .. item.page.title)
                                    picker:close()
                                    cache.clear()
                                end
                            end)
                        end
                    end)
                end
            end,
        },
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
                { win = "input", height = 1,     border = "bottom" },
                { win = "list",  border = "none" },
            },
        },
        preview = false,
        win = {
            input = {
                keys = {
                    ["<C-e>"] = { "edit", mode = { "n", "i" }, desc = "Edit page" },
                    ["<C-y>"] = { "copy_url", mode = { "n", "i" }, desc = "Copy URL" },
                    ["<C-o>"] = { "open_browser", mode = { "n", "i" }, desc = "Open in browser" },
                    ["<C-c>"] = { "children", mode = { "n", "i" }, desc = "Show children" },
                    ["<C-x>"] = { "delete", mode = { "n", "i" }, desc = "Delete page" },
                },
            },
        },
    })
end

---@param spaces ConfluenceSpace[]
---@param opts? { title?: string }
function M.show_spaces(spaces, opts)
    opts = opts or {}

    if #spaces == 0 then
        notify.info("No spaces found")
        return
    end

    local Snacks = require("snacks")

    local items = {}
    for idx, space in ipairs(spaces) do
        table.insert(items, {
            idx = idx,
            text = string.format("%s %s %s", space.key, space.name, space.type),
            space = space,
            key = space.key,
            name = space.name,
            space_type = space.type,
        })
    end

    Snacks.picker.pick({
        title = opts.title or "Confluence Spaces",
        items = items,
        format = function(item, _picker)
            local ret = {}
            table.insert(ret, { pad_right(item.key, 12), "Special" })
            table.insert(ret, { " ", "Normal" })
            table.insert(ret, { truncate(item.name, 40), "Function" })
            table.insert(ret, { " ", "Normal" })
            table.insert(ret, { item.space_type, "Comment" })
            return ret
        end,
        confirm = function(picker, item)
            picker:close()
            if item and item.space then
                M.pages_in_space(item.space.key)
            end
        end,
        actions = {
            copy_key = function(_, item)
                if item and item.space then
                    vim.fn.setreg("+", item.space.key)
                    notify.info("Copied: " .. item.space.key)
                end
            end,
        },
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
                { win = "input", height = 1,     border = "bottom" },
                { win = "list",  border = "none" },
            },
        },
        preview = false,
        win = {
            input = {
                keys = {
                    ["<C-y>"] = { "copy_key", mode = { "n", "i" }, desc = "Copy space key" },
                },
            },
        },
    })
end

function M.spaces()
    local cache_key = "spaces"
    cache.get_or_fetch(cache_key, function(cb)
        api.get_spaces(cb)
    end, function(err, spaces)
        if err then
            notify.error("Failed to fetch spaces: " .. err)
            return
        end
        M.show_spaces(spaces, { title = "Spaces" })
    end)
end

---@param space_key? string
function M.pages_in_space(space_key)
    space_key = space_key or config.options.default_space

    if not space_key or space_key == "" then
        M.spaces()
        return
    end

    local cache_key = "pages_" .. space_key
    cache.get_or_fetch(cache_key, function(cb)
        api.get_pages(space_key, nil, cb)
    end, function(err, pages)
        if err then
            notify.error("Failed to fetch pages: " .. err)
            return
        end
        M.show_pages(pages, { title = "Pages in " .. space_key })
    end, space_key)
end

function M.recent_pages()
    local cache_key = "recent_pages"
    cache.get_or_fetch(cache_key, function(cb)
        api.get_pages(nil, nil, cb)
    end, function(err, pages)
        if err then
            notify.error("Failed to fetch pages: " .. err)
            return
        end
        M.show_pages(pages, { title = "Recent Pages" })
    end)
end

---@param query string
---@param space_key? string
---@param opts? { on_confirm?: fun(page: ConfluencePage) }
function M.search(query, space_key, opts)
    opts = opts or {}
    -- Default to configured space
    space_key = space_key or config.options.default_space

    if not query or query == "" then
        vim.ui.input({ prompt = "Search pages: " }, function(input)
            if input and input ~= "" then
                M.search(input, space_key, opts)
            end
        end)
        return
    end

    notify.progress_start("search", "Searching (CQL)...")
    api.search_pages(query, space_key, function(err, pages)
        notify.progress_finish("search")
        if err then
            notify.error("Search failed: " .. err)
            return
        end
        M.show_pages(pages, { title = "Search: " .. query, on_confirm = opts.on_confirm })
    end)
end

function M.search_edit(query, space_key)
    M.search(query, space_key, {
        on_confirm = function(page)
            local ui = require("confluence-interface.ui")
            ui.edit_page(page.id)
        end,
    })
end

---@param cql? string Raw CQL query (prompts if nil)
function M.search_cql(cql)
    if not cql or cql == "" then
        vim.ui.input({ prompt = "CQL query: " }, function(input)
            if input and input ~= "" then
                M.search_cql(input)
            end
        end)
        return
    end

    notify.progress_start("cql_search", "Running CQL...")
    api.search_raw_cql(cql, function(err, pages)
        notify.progress_finish("cql_search")
        if err then
            notify.error("CQL search failed: " .. err)
            return
        end
        M.show_pages(pages, { title = "CQL: " .. cql:sub(1, 40) })
    end)
end

function M.select_cql_filter()
    local cql_filters = require("confluence-interface.cql_filters")
    local all_filters = cql_filters.list_all()

    if #all_filters == 0 then
        notify.info("No saved CQL filters. Use :ConfluenceCQLFilter save to create one.")
        return
    end

    local Snacks = require("snacks")
    local atlassian_ui_mod = require("atlassian.ui")

    local items = {}
    for idx, f in ipairs(all_filters) do
        table.insert(items, {
            idx = idx,
            text = f.name .. " " .. f.cql .. " " .. (f.description or ""),
            filter = f,
            name = f.name,
            cql = f.cql,
            space_key = f.space_key or "",
            description = f.description or "",
        })
    end

    Snacks.picker.pick({
        title = "CQL Filters",
        items = items,
        format = function(item, _picker)
            local ret = {}
            table.insert(ret, { atlassian_ui_mod.pad_right(item.name, 20), "Function" })
            table.insert(ret, { " ", "Normal" })
            table.insert(ret, { atlassian_ui_mod.truncate(item.cql, 50), "Comment" })
            if item.space_key ~= "" then
                table.insert(ret, { " ", "Normal" })
                table.insert(ret, { "[" .. item.space_key .. "]", "Special" })
            end
            return ret
        end,
        confirm = function(picker, item)
            picker:close()
            if item and item.filter then
                M.search_cql(item.filter.cql)
            end
        end,
        actions = {
            delete_filter = function(picker, item)
                if item and item.filter then
                    vim.ui.input({ prompt = "Delete filter '" .. item.filter.name .. "'? (yes/no): " }, function(input)
                        if input == "yes" then
                            cql_filters.delete(item.filter.name, item.filter.space_key)
                            picker:close()
                            M.select_cql_filter()
                        end
                    end)
                end
            end,
        },
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
        win = {
            input = {
                keys = {
                    ["<C-x>"] = { "delete_filter", mode = { "n", "i" }, desc = "Delete filter" },
                },
            },
        },
    })
end

---@param username? string Use "me" for current user
---@param space_key? string
function M.mentions(username, space_key)
    space_key = space_key or config.options.default_space

    -- "me" is shorthand for current user
    if username == "me" then
        username = nil
    end

    notify.progress_start("mentions", "Searching mentions...")
    api.search_mentions(username, space_key, function(err, pages)
        notify.progress_finish("mentions")
        if err then
            notify.error("Mention search failed: " .. err)
            return
        end
        local title_text = username and ("Mentions of @" .. username) or "My Mentions"
        M.show_pages(pages, { title = title_text })
    end)
end

---@param page_id string
---@param title? string
function M.show_children(page_id, title)
    api.get_page_children(page_id, function(err, children)
        if err then
            notify.error("Failed to fetch children: " .. err)
            return
        end

        if #children == 0 then
            notify.info("No children found")
            return
        end

        M.show_pages(children, { title = "Children of " .. (title or page_id) })
    end)
end

---@param space_key? string
---@param parent_id? string
function M.create_page(space_key, parent_id)
    space_key = space_key or config.options.default_space

    if not space_key or space_key == "" then
        api.get_spaces(function(err, spaces)
            if err then
                notify.error("Failed to fetch spaces: " .. err)
                return
            end

            local space_names = {}
            local space_map = {}
            for _, s in ipairs(spaces) do
                table.insert(space_names, s.key .. " - " .. s.name)
                space_map[s.key .. " - " .. s.name] = s
            end

            vim.ui.select(space_names, { prompt = "Select space:" }, function(choice)
                if choice then
                    local space = space_map[choice]
                    M.create_page(space.key, parent_id)
                end
            end)
        end)
        return
    end

    -- Get space ID from space key
    api.get_space(space_key, function(err, space)
        if err then
            notify.error("Failed to get space: " .. err)
            return
        end

        local ui = require("confluence-interface.ui")
        ui.create_page_buffer(space.id, space_key, parent_id)
    end)
end

return M
