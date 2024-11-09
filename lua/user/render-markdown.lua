local M = {
    'MeanderingProgrammer/render-markdown.nvim',
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
    }
end

return M
