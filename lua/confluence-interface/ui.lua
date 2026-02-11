local M = {}

local api = require("confluence-interface.api")
local types = require("confluence-interface.types")
local config = require("confluence-interface.config")
local cache = require("confluence-interface.cache")
local notify = require("confluence-interface.notify")
local atlassian_ui = require("atlassian.ui")
local atlassian_format = require("atlassian.format")
local csf = require("atlassian.csf")

-- Use shared UI helpers
local parse_dimension = atlassian_ui.parse_dimension

---@param opts { width?: number, height?: number, title?: string, mode?: string }
---@return number, number Buffer and window IDs
local function create_window(opts)
    local display = vim.tbl_extend("force", config.options.display or {}, {})
    if opts and opts.mode then
        display.mode = opts.mode
    end
    return atlassian_ui.create_window({
        width = opts and opts.width,
        height = opts and opts.height,
        title = opts and opts.title,
        bufname = opts and opts.bufname,
        display = display,
        filetype = "csf",
    })
end

---@param page ConfluencePage
function M.show_page(page)
    local buf, win = create_window({
        title = page.title,
        bufname = "confluence://" .. page.id,
        mode = "buffer",
    })

    local lines = {}

    -- CSF metadata comment
    table.insert(lines, csf.generate_metadata({ type = "confluence", id = page.id, version = page.version }))

    -- Page info as CSF
    table.insert(lines, "<h1>" .. page.title .. "</h1>")
    table.insert(lines, "<p><strong>ID:</strong> " .. page.id .. "</p>")
    table.insert(lines, "<p><strong>Version:</strong> " .. page.version .. "</p>")
    table.insert(lines, "<p><strong>Status:</strong> " .. page.status .. "</p>")

    if page.space_key then
        table.insert(lines, "<p><strong>Space:</strong> " .. page.space_key .. "</p>")
    end

    table.insert(lines, "<hr />")

    -- Raw CSF body content (formatted: block tags on own lines)
    if page.body and page.body ~= "" then
        vim.list_extend(lines, csf.format_lines(page.body))
    else
        table.insert(lines, "<p><em>No content</em></p>")
    end

    table.insert(lines, "<hr />")

    if page.web_url then
        local base_url = config.options.auth.url
        if not base_url:match("^https?://") then
            base_url = "https://" .. base_url
        end
        local url = base_url .. "/wiki" .. page.web_url
        table.insert(lines, '<p><strong>URL:</strong> <a href="' .. url .. '">' .. url .. '</a></p>')
    end

    table.insert(lines, "<p><em>Updated: " .. atlassian_format.format_timestamp(page.updated) ..
        " (" .. atlassian_format.format_relative_time(page.updated) .. ")</em></p>")

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false

    -- Keymaps
    vim.keymap.set("n", "e", function()
        M.edit_page(page.id)
    end, { buffer = buf, desc = "Edit page" })

    vim.keymap.set("n", "c", function()
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
        vim.cmd("help atlassian-confluence-keymaps")
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
        vim.bo[buf].filetype = "csf"

        -- Direct CSF — no markdown conversion
        local lines = {
            csf.generate_metadata({ type = "confluence", id = page.id, version = page.version }),
            "<h1>" .. page.title .. "</h1>",
        }

        -- Insert raw page body (formatted: block tags on own lines)
        if page.body and page.body ~= "" then
            vim.list_extend(lines, csf.format_lines(page.body))
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
                local meta = csf.parse_metadata(content[1] or "")
                local meta_id = meta and meta.id or page.id
                local meta_version = meta and meta.version or page.version

                -- Remove metadata line
                table.remove(content, 1)

                -- Extract title from <h1>
                local title, remaining = csf.extract_title(content)
                title = title or page.title
                content = remaining

                -- Remove leading empty lines
                while content[1] and content[1]:match("^%s*$") do
                    table.remove(content, 1)
                end

                -- Content is already CSF storage format — send directly
                local storage_content = table.concat(content, "\n")

                notify.progress_start("save", "Saving page...")
                api.update_page(meta_id, title, storage_content, meta_version,
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
    vim.bo[buf].filetype = "csf"

    -- Metadata line as CSF comment
    local meta_line = csf.generate_metadata({
        type = "confluence", id = "NEW", version = 1,
        space_id = space_id, parent_id = parent_id,
    })

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { meta_line, "" })

    -- Open in current window
    vim.api.nvim_set_current_buf(buf)
    atlassian_ui.apply_window_options(buf, vim.api.nvim_get_current_win(), config.options.display)
    vim.bo[buf].modified = false

    -- Save handler
    vim.api.nvim_create_autocmd("BufWriteCmd", {
        buffer = buf,
        callback = function()
            -- Exit snippet session if active
            local luasnip_ok, luasnip = pcall(require, "luasnip")
            if luasnip_ok and luasnip.get_active_snip() then
                luasnip.unlink_current()
            end

            local content = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

            -- Parse CSF metadata
            local meta = csf.parse_metadata(content[1] or "")
            local meta_space_id = meta and meta.space_id or space_id
            local meta_parent_id = meta and meta.parent_id or parent_id

            -- Remove metadata line
            table.remove(content, 1)

            -- Extract title from <h1>
            local title, remaining = csf.extract_title(content)
            title = title or "Untitled"
            content = remaining

            while content[1] and content[1]:match("^%s*$") do
                table.remove(content, 1)
            end

            -- Content is already CSF — send directly
            local storage_content = table.concat(content, "\n")

            notify.progress_start("create", "Creating page...")
            api.create_page(meta_space_id, title, storage_content, meta_parent_id,
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
