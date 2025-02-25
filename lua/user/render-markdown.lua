local M = {
    'MeanderingProgrammer/render-markdown.nvim',
    ft = { 'markdown', 'codecompanion' },
    dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-tree/nvim-web-devicons' },
}

M.config = function()
    require("render-markdown").setup {
        render_modes = true,
        heading = {
            icons = { '󰲡  ', ' 󰲣  ', '  󰲥  ', '   󰲧  ', '    󰲩  ', '     󰲫  ' },
            signs = { '󰫎 ' },
            width = 'block',
            left_pad = 0,
            right_pad = 4,
        },
        code = {
            style = "full",
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
