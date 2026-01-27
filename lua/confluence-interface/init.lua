local M = {}

local config = require("confluence-interface.config")
local notify = require("confluence-interface.notify")

---@param opts? ConfluenceConfig
function M.setup(opts)
    config.setup(opts)

    local valid, err = config.validate()
    if not valid then
        notify.warn("confluence-interface: " .. err)
    end

    M.create_commands()
end

function M.create_commands()
    local cmd = vim.api.nvim_create_user_command

    -- Space commands
    cmd("ConfluenceSpaces", function()
        local picker = require("confluence-interface.picker")
        picker.spaces()
    end, { desc = "List Confluence spaces" })

    -- Page commands
    cmd("ConfluencePages", function(args)
        local picker = require("confluence-interface.picker")
        local space_key = args.args ~= "" and args.args or nil
        picker.pages_in_space(space_key)
    end, { nargs = "?", desc = "List pages in space" })

    cmd("ConfluenceRecent", function()
        local picker = require("confluence-interface.picker")
        picker.recent_pages()
    end, { desc = "Show recent pages" })

    cmd("ConfluenceSearch", function(args)
        local picker = require("confluence-interface.picker")
        picker.search(args.args)
    end, { nargs = "?", desc = "Search Confluence pages" })

    cmd("ConfluenceMentions", function(args)
        local picker = require("confluence-interface.picker")
        local username = args.args ~= "" and args.args or nil
        picker.mentions(username)
    end, {
        nargs = "?",
        desc = "Search pages mentioning user (default: me)",
        complete = function()
            return { "me" }
        end,
    })

    cmd("ConfluenceView", function(args)
        if not args.args or args.args == "" then
            notify.error("Usage: :ConfluenceView <page_id>")
            return
        end
        local ui = require("confluence-interface.ui")
        ui.view_page(args.args)
    end, { nargs = "?", desc = "View page by ID" })

    cmd("ConfluenceEdit", function(args)
        if not args.args or args.args == "" then
            notify.error("Usage: :ConfluenceEdit <page_id>")
            return
        end
        local ui = require("confluence-interface.ui")
        ui.edit_page(args.args)
    end, { nargs = "?", desc = "Edit page by ID" })

    cmd("ConfluenceCreate", function(args)
        local picker = require("confluence-interface.picker")
        local space_key = args.args ~= "" and args.args or nil
        picker.create_page(space_key)
    end, { nargs = "?", desc = "Create new page" })

    cmd("ConfluenceDelete", function(args)
        if not args.args or args.args == "" then
            notify.error("Usage: :ConfluenceDelete <page_id>")
            return
        end
        local page_id = args.args
        vim.ui.input({ prompt = "Delete page " .. page_id .. "? (yes/no): " }, function(input)
            if input == "yes" then
                local api = require("confluence-interface.api")
                api.delete_page(page_id, function(err)
                    if err then
                        notify.error("Delete failed: " .. err)
                    else
                        notify.info("Page deleted")
                        local cache = require("confluence-interface.cache")
                        cache.clear()
                    end
                end)
            end
        end)
    end, { nargs = 1, desc = "Delete page by ID" })

    -- Cache commands
    cmd("ConfluenceRefresh", function()
        local cache = require("confluence-interface.cache")
        cache.clear()
        notify.info("Confluence cache cleared")
    end, { desc = "Clear cache" })

    cmd("ConfluenceClearCache", function()
        local cache = require("confluence-interface.cache")
        cache.clear()
        notify.info("Confluence cache cleared")
    end, { desc = "Clear cache" })

    -- Status commands
    cmd("ConfluenceStatus", function()
        local ui = require("confluence-interface.ui")
        ui.show_status()
    end, { desc = "Show connection status" })

    cmd("ConfluenceHelp", function()
        local ui = require("confluence-interface.ui")
        ui.show_help()
    end, { desc = "Show help" })

    -- Debug commands
    cmd("ConfluenceDebug", function(args)
        local api = require("confluence-interface.api")

        if not args.args or args.args == "" then
            api.check_connectivity(function(online)
                if online then
                    notify.info("Confluence API: Connected")
                else
                    notify.error("Confluence API: Connection failed")
                end
            end)
        else
            -- Fetch raw page for debugging
            api.request("/pages/" .. args.args, "GET", nil, function(err, data)
                if err then
                    notify.error("Error: " .. err)
                else
                    local buf = vim.api.nvim_create_buf(false, true)
                    vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(vim.inspect(data), "\n"))
                    vim.bo[buf].filetype = "lua"
                    vim.cmd("vsplit")
                    vim.api.nvim_win_set_buf(0, buf)
                end
            end)
        end
    end, { nargs = "?", desc = "Debug: test connection or fetch raw page" })
end

-- Expose modules for external use
M.api = require("confluence-interface.api")
M.picker = require("confluence-interface.picker")
M.ui = require("confluence-interface.ui")
M.cache = require("confluence-interface.cache")
M.types = require("confluence-interface.types")
M.config = config

return M
