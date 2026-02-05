local M = {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
}

local function short_relative_time(timestamp)
    local now = os.time()
    local diff = now - timestamp
    if diff < 60 then
        return diff .. "s"
    elseif diff < 3600 then
        return math.floor(diff / 60) .. "m"
    elseif diff < 86400 then
        return math.floor(diff / 3600) .. "h"
    elseif diff < 604800 then
        return math.floor(diff / 86400) .. "d"
    elseif diff < 2592000 then
        return math.floor(diff / 604800) .. "w"
    elseif diff < 31536000 then
        return math.floor(diff / 2592000) .. "M"
    else
        return math.floor(diff / 31536000) .. "Y"
    end
end

M.config = function()
    require("gitsigns").setup({
        watch_gitdir                 = {
            interval = 1000,
            follow_files = true,
        },
        numhl                        = true,
        linehl                       = false,
        word_diff                    = false,
        attach_to_untracked          = true,
        current_line_blame           = true,
        current_line_blame_opts      = {
            virt_text = false,
            virt_text_pos = 'right_align',
            delay = 300,
            ignore_whitespace = false,
            virt_text_priority = 100,
            use_focus = true,
        },
        current_line_blame_formatter = function(name, info)
            return {
                { "|| ", "@lsp.type.variable" },
                { info.author, "@lsp.type.comment" },
                { " • ", "@lsp.type.variable" },
                { short_relative_time(info.author_time), "@lsp.type.operator" },
                { " • ", "@lsp.type.variable" },
                { info.summary, "@lsp.type.operator" },
            }
        end,
        update_debounce              = 200,
        max_file_length              = 40000,
        preview_config               = {
            border = "rounded",
            style = "minimal",
            relative = "cursor",
            row = 0,
            col = 1,
        },
    })
end

return M
