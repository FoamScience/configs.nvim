local M = {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
}
M.config = function()
    local util = require("gitsigns.util")

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
            virt_text = true,
            virt_text_pos = 'right_align',
            delay = 500,
            ignore_whitespace = false,
            virt_text_priority = 100,
            use_focus = true,
        },
        current_line_blame_formatter = function(name, info)
            -- "|| <author> • <author_time:%R>"
            return {
                {
                    "|| ",
                    "@lsp.type.variable"
                },
                {
                    info.author,
                    "@lsp.type.comment"
                },
                {
                    " • ",
                    "@lsp.type.variable"
                },
                {
                    util.expand_format("<author_time:%R>", info),
                    "@lsp.type.operator"
                },
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
