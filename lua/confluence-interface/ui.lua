local M = {}

local api = require("confluence-interface.api")
local types = require("confluence-interface.types")
local config = require("confluence-interface.config")
local cache = require("confluence-interface.cache")
local notify = require("confluence-interface.notify")
local atlassian_ui = require("atlassian.ui")

-- Use shared UI helpers
local parse_dimension = atlassian_ui.parse_dimension

---@param opts { width?: number, height?: number, title?: string }
---@return number, number Buffer and window IDs
local function create_window(opts)
    return atlassian_ui.create_window({
        width = opts and opts.width,
        height = opts and opts.height,
        title = opts and opts.title,
        display = config.options.display,
    })
end

---@param page ConfluencePage
function M.show_page(page)
    local buf, win = create_window({ title = page.title })

    local lines = {
        "# " .. page.title,
        "",
        string.format("**ID:** %s", page.id),
        string.format("**Version:** %d", page.version),
        string.format("**Status:** %s", page.status),
    }

    if page.space_key then
        table.insert(lines, string.format("**Space:** %s", page.space_key))
    end

    table.insert(lines, "")
    table.insert(lines, "---")
    table.insert(lines, "")

    -- Convert storage format to markdown
    if page.body and page.body ~= "" then
        local markdown = types.storage_to_markdown(page.body)
        for _, line in ipairs(vim.split(markdown, "\n")) do
            table.insert(lines, line)
        end
    else
        table.insert(lines, "_No content_")
    end

    table.insert(lines, "")
    table.insert(lines, "---")
    table.insert(lines, "")

    if page.web_url then
        local base_url = config.options.auth.url
        if not base_url:match("^https?://") then
            base_url = "https://" .. base_url
        end
        table.insert(lines, "**URL:** " .. base_url .. "/wiki" .. page.web_url)
    end

    table.insert(lines, "")
    table.insert(lines,
        string.format("_Updated: %s (%s)_", types.format_timestamp(page.updated),
            types.format_relative_time(page.updated)))

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false

    -- Keymaps
    vim.keymap.set("n", "e", function()
        vim.api.nvim_win_close(win, true)
        M.edit_page(page.id)
    end, { buffer = buf, desc = "Edit page" })

    vim.keymap.set("n", "c", function()
        vim.api.nvim_win_close(win, true)
        local picker = require("confluence-interface.picker")
        picker.show_children(page.id, page.title)
    end, { buffer = buf, desc = "Show children" })

    vim.keymap.set("n", "y", function()
        vim.fn.setreg("+", page.id)
        notify.info("Copied page ID: " .. page.id)
    end, { buffer = buf, desc = "Copy page ID" })

    vim.keymap.set("n", "Y", function()
        if page.web_url then
            local base_url = config.options.auth.url
            if not base_url:match("^https?://") then
                base_url = "https://" .. base_url
            end
            local url = base_url .. "/wiki" .. page.web_url
            vim.fn.setreg("+", url)
            notify.info("Copied: " .. url)
        end
    end, { buffer = buf, desc = "Copy page URL" })

    vim.keymap.set("n", "o", function()
        if page.web_url then
            local base_url = config.options.auth.url
            if not base_url:match("^https?://") then
                base_url = "https://" .. base_url
            end
            local url = base_url .. "/wiki" .. page.web_url
            vim.ui.open(url)
        end
    end, { buffer = buf, desc = "Open in browser" })

    vim.keymap.set("n", "?", function()
        M.show_help()
    end, { buffer = buf, desc = "Show help" })
end

---@param page_id string
function M.view_page(page_id)
    notify.progress_start("view", "Loading page...")
    api.get_page(page_id, function(err, page)
        notify.progress_finish("view")
        if err then
            notify.error("Failed to fetch page: " .. err)
            return
        end
        M.show_page(page)
    end)
end

---@param page_id string
function M.edit_page(page_id)
    notify.progress_start("edit", "Loading page for editing...")
    api.get_page(page_id, function(err, page)
        notify.progress_finish("edit")
        if err then
            notify.error("Failed to fetch page: " .. err)
            return
        end

        -- Create buffer with confluence_storage: prefix
        local buf = vim.api.nvim_create_buf(false, false)
        local buf_name = "confluence_storage:" .. page.title:gsub("[/\\]", "_")
        vim.api.nvim_buf_set_name(buf, buf_name)
        vim.bo[buf].bufhidden = "wipe"
        vim.bo[buf].buftype = "acwrite"
        vim.bo[buf].filetype = "markdown"

        -- Convert storage format to markdown for editing
        local markdown = types.storage_to_markdown(page.body or "")

        local lines = {
            "<!-- confluence-interface: id=" .. page.id .. " version=" .. page.version .. " -->",
            "# " .. page.title,
            "",
        }

        for _, line in ipairs(vim.split(markdown, "\n")) do
            table.insert(lines, line)
        end

        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

        -- Open in current window
        vim.api.nvim_set_current_buf(buf)
        vim.bo[buf].modified = false

        -- Save handler
        vim.api.nvim_create_autocmd("BufWriteCmd", {
            buffer = buf,
            callback = function()
                local content = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

                -- Parse metadata from first line
                local meta_line = content[1] or ""
                local meta_id = meta_line:match("id=([%w-]+)")
                local meta_version = tonumber(meta_line:match("version=(%d+)")) or page.version

                -- Extract title from second line (# Title)
                local title = page.title
                if content[2] and content[2]:match("^# ") then
                    title = content[2]:gsub("^# ", "")
                    table.remove(content, 2)
                end
                table.remove(content, 1) -- Remove metadata line

                -- Remove leading empty lines
                while content[1] and content[1]:match("^%s*$") do
                    table.remove(content, 1)
                end

                local markdown_content = table.concat(content, "\n")
                local storage_content = types.markdown_to_storage(markdown_content)

                notify.progress_start("save", "Saving page...")
                api.update_page(meta_id or page.id, title, storage_content, meta_version,
                    function(update_err, updated_page)
                        if update_err then
                            notify.progress_error("save", "Save failed: " .. update_err)
                        else
                            notify.progress_finish("save", "Saved: " .. updated_page.title)
                            vim.bo[buf].modified = false
                            cache.invalidate_space(page.space_key)
                        end
                    end)
            end,
        })
    end)
end

---@param space_id string
---@param space_key string
---@param parent_id? string
function M.create_page_buffer(space_id, space_key, parent_id)
    local buf = vim.api.nvim_create_buf(false, false)
    local buf_name = "confluence_storage:New_Page_" .. space_key
    vim.api.nvim_buf_set_name(buf, buf_name)
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].buftype = "acwrite"
    vim.bo[buf].filetype = "markdown"

    local lines = {
        "<!-- confluence-interface: space_id=" ..
        space_id .. (parent_id and (" parent_id=" .. parent_id) or "") .. " -->",
        "# New Page Title",
        "",
        "Start writing your content here...",
        "",
        "## Section 1",
        "",
        "Your content...",
    }

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

    -- Open in current window
    vim.api.nvim_set_current_buf(buf)
    vim.api.nvim_win_set_cursor(0, { 2, 2 })
    vim.bo[buf].modified = false

    -- Save handler
    vim.api.nvim_create_autocmd("BufWriteCmd", {
        buffer = buf,
        callback = function()
            local content = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

            -- Parse metadata
            local meta_line = content[1] or ""
            local meta_space_id = meta_line:match("space_id=([%w-]+)")
            local meta_parent_id = meta_line:match("parent_id=([%w-]+)")

            -- Extract title
            local title = "Untitled"
            if content[2] and content[2]:match("^# ") then
                title = content[2]:gsub("^# ", "")
                table.remove(content, 2)
            end
            table.remove(content, 1)

            while content[1] and content[1]:match("^%s*$") do
                table.remove(content, 1)
            end

            local markdown_content = table.concat(content, "\n")
            local storage_content = types.markdown_to_storage(markdown_content)

            notify.progress_start("create", "Creating page...")
            api.create_page(meta_space_id or space_id, title, storage_content, meta_parent_id or parent_id,
                function(err, page)
                    if err then
                        notify.progress_error("create", "Create failed: " .. err)
                    else
                        notify.progress_finish("create", "Created: " .. page.title)
                        cache.invalidate_space(space_key)
                        M.show_page(page)
                    end
                end)
        end,
    })
end

function M.show_help()
    local buf, _ = create_window({ title = "Confluence Interface Help", width = 60, height = 35 })

    local lines = {
        "# Confluence Interface - Keybindings",
        "",
        "## Page View",
        "- `e` - Edit page",
        "- `c` - Show child pages",
        "- `y` - Copy page ID",
        "- `Y` - Copy page URL",
        "- `o` - Open in browser",
        "- `q` / `Esc` - Close",
        "",
        "## Picker",
        "- `<CR>` - View page",
        "- `<C-e>` - Edit page",
        "- `<C-y>` - Copy URL",
        "- `<C-o>` - Open in browser",
        "- `<C-c>` - Show children",
        "- `<C-x>` - Delete page",
        "",
        "## Commands",
        "- `:ConfluenceSpaces` - List all spaces",
        "- `:ConfluencePages [space]` - Pages in space",
        "- `:ConfluenceRecent` - Recent pages",
        "- `:ConfluenceSearch <query>` - Search pages",
        "- `:ConfluenceView <id>` - View page by ID",
        "- `:ConfluenceEdit <id>` - Edit page by ID",
        "- `:ConfluenceCreate [space]` - Create new page",
        "- `:ConfluenceRefresh` - Clear cache",
        "- `:ConfluenceStatus` - Connection status",
    }

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
end

function M.show_status()
    local cache_mod = require("confluence-interface.cache")
    local cache_stats = cache_mod.stats()

    api.check_connectivity(function(online)
        local status = online and "Online" or "Offline"
        local icon = online and "" or ""

        local lines = {
            string.format("%s %s", icon, status),
            string.format("Cache: %d entries (%.1f KB)", cache_stats.entries, cache_stats.size_bytes / 1024),
            string.format("Default space: %s", config.options.default_space or "(none)"),
        }

        notify.info(table.concat(lines, "\n"))
    end)
end

return M
