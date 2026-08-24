-- image.nvim loads integrations by `require("image/integrations/" .. name)`, so
-- this lives under the plugin's module namespace to be reachable as the
-- `mermaid` integration (enabled in lua/user/image.lua).
local document = require("image/utils/document")
local mermaid = require("utils.mermaid")

local query = nil
local function get_query()
    if not query then
        query = vim.treesitter.query.parse(
            "markdown",
            [[
            (fenced_code_block
              (info_string (language) @_lang (#eq? @_lang "mermaid"))
              (code_fence_content) @content) @block
            ]]
        )
    end
    return query
end

return document.create_document_integration({
    name = "mermaid",
    -- Matches depend on whether a render has landed yet, not just on buffer
    -- content, so the changedtick cache would pin stale results.
    disable_cache = true,
    default_options = {
        clear_in_insert_mode = false,
        only_render_image_at_cursor = false,
        floating_windows = false,
        filetypes = { "markdown", "vimwiki" },
    },
    query_buffer_images = function(buffer)
        local buf = buffer or vim.api.nvim_get_current_buf()
        local ok, parser = pcall(vim.treesitter.get_parser, buf, "markdown")
        if not ok or not parser then
            return {}
        end
        parser:parse(true)

        local tree = parser:trees()[1]
        if not tree then
            return {}
        end

        local images = {}
        for _, match in get_query():iter_matches(tree:root(), buf) do
            local captures = get_query().captures
            local block, content
            for id, nodes in pairs(match) do
                if captures[id] == "block" then
                    block = nodes[#nodes]
                elseif captures[id] == "content" then
                    content = nodes[#nodes]
                end
            end
            if block and content then
                local code = vim.treesitter.get_node_text(content, buf)
                local path = mermaid.ensure(code, function()
                    -- Re-enter the integration's render pass now that the PNG exists.
                    if vim.api.nvim_buf_is_valid(buf) then
                        vim.api.nvim_exec_autocmds("BufWinEnter", { buffer = buf })
                    end
                end)
                if path then
                    local _, _, end_row, end_col = block:range()
                    -- The fence node spans the trailing newline, so a zero end
                    -- column means the range already rolled onto the next line.
                    if end_col == 0 then
                        end_row = end_row - 1
                    end
                    table.insert(images, {
                        node = block,
                        -- Anchor on the closing fence so the chart renders under the source.
                        range = { start_row = end_row, start_col = 0, end_row = end_row, end_col = 0 },
                        url = path,
                    })
                end
            end
        end
        return images
    end,
})
