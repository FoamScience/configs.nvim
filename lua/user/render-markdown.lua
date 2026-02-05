local filetypes = { "markdown", "codecompanion", "latex", "tex", "typst", "yaml", "rmd", "atlassian_jira", "atlassian_confluence" }

local M = {
    'MeanderingProgrammer/render-markdown.nvim',
    dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-tree/nvim-web-devicons' },
    event = 'VeryLazy'
}

M.config = function()
    -- Register markdown treesitter parser for Atlassian filetypes
    vim.treesitter.language.register('markdown', 'atlassian_jira')
    vim.treesitter.language.register('markdown', 'atlassian_confluence')
    require("render-markdown").setup {
        render_modes = true,
        file_types = filetypes,
        completions = {
            lsp = {
                enabled = true,
            }
        },
        heading = {
            icons = { '󰲡  ', ' 󰲣  ', '  󰲥  ', '   󰲧  ', '    󰲩  ', '     󰲫  ' },
            signs = { '󰫎 ' },
            width = 'block',
            left_pad = 0,
            right_pad = 4,
        },
        code = {
            style = "full",
            sign = false,
            width = "block",
            min_width = 80,
        },
        latex = {
            enabled = true,
            render_modes = false,
            converter = 'latex2text',
            highlight = 'RenderMarkdownMath',
            position = 'above',
            top_pad = 0,
            bottom_pad = 0,
        },
        checkbox = {
            enabled = true,
            position = 'inline',
            unchecked = {
                icon = '󰄱 ',
                highlight = 'RenderMarkdownUnchecked',
                scope_highlight = nil,
            },
            checked = {
                icon = '󰱒 ',
                highlight = 'RenderMarkdownChecked',
                scope_highlight = nil,
            },
        },
    }
end

return M
