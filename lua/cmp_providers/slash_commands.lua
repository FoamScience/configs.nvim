local M = {}

local types = require('blink.cmp.types')
local lsp_protocol = vim.lsp.protocol

local enabled_filetypes = {
    atlassian_jira = true,
    atlassian_confluence = true,
    csf = true,
}

function M.new(opts)
    local self = setmetatable({}, { __index = M })
    self.opts = opts
    self.opts.name = "slash_commands"
    return self
end

function M:enabled()
    return enabled_filetypes[vim.bo.filetype] == true
end

function M:get_trigger_characters()
    return { "/" }
end

function M:get_completions(ctx, callback)
    local ft = vim.bo.filetype
    if not enabled_filetypes[ft] then
        callback({ items = {}, is_incomplete_backward = false, is_incomplete_forward = false })
        return function() end
    end

    -- Only show when / is at line start or after whitespace
    local line = ctx.line
    local col = ctx.cursor[2]

    -- Find the / that triggered this
    local slash_pos = nil
    for i = col, 1, -1 do
        if line:sub(i, i) == "/" then
            slash_pos = i
            break
        end
    end

    if not slash_pos then
        callback({ items = {}, is_incomplete_backward = false, is_incomplete_forward = false })
        return function() end
    end

    -- Check that / is at position 1 or preceded by whitespace
    if slash_pos > 1 then
        local before = line:sub(slash_pos - 1, slash_pos - 1)
        if not before:match("%s") then
            callback({ items = {}, is_incomplete_backward = false, is_incomplete_forward = false })
            return function() end
        end
    end

    local registry = require("atlassian.slash_commands")
    local commands = registry.get_commands_for_filetype(ft)

    -- Unified CSF templates for all filetypes
    local templates = require("atlassian.slash_commands.csf_templates")

    -- textEdit range: from the / trigger to the current cursor position
    local edit_range = {
        start = { line = ctx.cursor[1] - 1, character = slash_pos - 1 },
        ["end"] = { line = ctx.cursor[1] - 1, character = ctx.cursor[2] },
    }

    local items = {}
    for _, cmd in ipairs(commands) do
        local snippet = templates.get(cmd.name)
        if snippet then
            -- Build filterText from name + keywords
            local filter_parts = { cmd.name }
            for _, kw in ipairs(cmd.keywords) do
                table.insert(filter_parts, kw)
            end

            table.insert(items, {
                label = "/" .. cmd.name,
                textEdit = {
                    range = edit_range,
                    newText = snippet,
                },
                insertTextFormat = lsp_protocol.InsertTextFormat.Snippet,
                kind = types.CompletionItemKind.Snippet,
                filterText = "/" .. table.concat(filter_parts, " "),
                labelDetails = {
                    description = cmd.category,
                },
                documentation = {
                    kind = "markdown",
                    value = table.concat({
                        "**" .. cmd.icon .. " " .. cmd.name .. "**",
                        "",
                        cmd.description,
                        "",
                        "*Category:* " .. cmd.category,
                        cmd.interactive and "*Interactive:* `<C-Space>` for picker" or "",
                    }, "\n"),
                },
                data = {
                    command_name = cmd.name,
                    interactive = cmd.interactive,
                },
            })
        end
    end

    callback({
        items = items,
        is_incomplete_backward = false,
        is_incomplete_forward = false,
    })

    return function() end
end

function M:execute(ctx, item, resolve, default_implementation)
    -- Apply the text edit / expand snippet first
    default_implementation()

    if item and item.data then
        if item.data.command_name == "Upload" then
            vim.schedule(function()
                local ok, upload = pcall(require, "atlassian.csf.upload")
                if ok then
                    upload.upload_attachment(vim.api.nvim_get_current_buf())
                end
            end)
        elseif item.data.interactive then
            vim.schedule(function()
                local ok, interactive = pcall(require, "atlassian.slash_commands.interactive")
                if ok then
                    interactive.run(item.data.command_name)
                end
            end)
        end
    end

    resolve()
end

return M
