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
    self.opts.name = "confluence"
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

        local ok, api = pcall(require, "confluence-interface.api")
        if not ok then
            callback({ items = {}, is_incomplete_backward = false, is_incomplete_forward = false })
            return
        end

        local config = require("confluence-interface.config")
        local space_key = config.options and config.options.default_space or nil

        api.search_pages(keyword, space_key, function(err, pages)
            if err or not pages then
                callback({ items = {}, is_incomplete_backward = false, is_incomplete_forward = false })
                return
            end

            local items = {}
            for _, page in ipairs(pages) do
                local url = ""
                if page.web_url then
                    local base_url = config.options.auth.url
                    if not base_url:match("^https?://") then
                        base_url = "https://" .. base_url
                    end
                    url = base_url .. "/wiki" .. page.web_url
                end

                local ok_fmt, fmt = pcall(require, "atlassian.format")
                local updated_display = page.updated or ""
                if ok_fmt and page.updated then
                    updated_display = fmt.format_relative_time(page.updated)
                end

                table.insert(items, {
                    label = page.title,
                    insertText = url ~= "" and string.format("[%s](%s)", page.title, url) or page.title,
                    kind = types.CompletionItemKind.Reference,
                    filterText = table.concat({
                        page.title,
                        page.space_key or "",
                    }, " "),
                    documentation = {
                        kind = "markdown",
                        value = table.concat({
                            "**" .. page.title .. "**",
                            "",
                            "- **Space:** " .. (page.space_key or ""),
                            "- **Version:** " .. tostring(page.version or 0),
                            "- **Updated:** " .. updated_display,
                            "- **Status:** " .. (page.status or ""),
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
