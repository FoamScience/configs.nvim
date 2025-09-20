local M = {
    'b0o/incline.nvim',
    config = function()
        require('incline').setup()
    end,
    event = 'VeryLazy',
    dependencies = {
        "nvim-tree/nvim-web-devicons",
        "nvim-lualine/lualine.nvim",
        "SmiteshP/nvim-navic",
    }
}

function M.get_lualine_colors(lualine, props, ft_color)
    local helpers = require 'incline.helpers'
    local fg, bg, ifg, ibg
    local theme_name = lualine.get_config().options.theme
    local theme = require("lualine.themes." .. theme_name)
    local m = vim.api.nvim_get_mode().mode
    ifg = helpers.contrast_color(ft_color)
    ibg = ft_color
    if not props.focused then
        fg = theme.inactive.a.fg
        bg = theme.inactive.a.bg
        ifg = theme.inactive.a.fg
        ibg = theme.inactive.a.bg
    elseif m:match('n') then
        fg = theme.normal.a.fg
        bg = theme.normal.a.bg
    elseif m:match('i') then
        fg = theme.insert.a.fg
        bg = theme.insert.a.bg
    elseif m:match('R') then
        fg = theme.replace.a.fg
        bg = theme.replace.a.bg
    elseif m:match('v') or m:match('V') or m:match('') then
        fg = theme.visual.a.fg
        bg = theme.visual.a.bg
    else -- unknown mode!
        fg = nil
        bg = nil
    end
    return { fg = fg, bg = bg, ifg = ifg, ibg = ibg }
end

function M.config()
    local helpers = require 'incline.helpers'
    local devicons = require 'nvim-web-devicons'
    local navic_ok, navic = pcall(require, "nvim-navic")
    local lualine_ok, lualine = pcall(require, "lualine")
    require('incline').setup {
        window = {
            padding = 0,
            margin = { horizontal = 0, vertical = 0 },
        },
        render = function(props)
            local filename = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(props.buf), ':t')
            if filename == '' then
                filename = '[No Name]'
            end
            local ft_icon, ft_color = devicons.get_icon_color(filename)
            local modified = vim.bo[props.buf].modified
            local colors = {}
            if ft_color == nil and lualine_ok then
               ft_color = require('lualine.themes.' .. lualine.get_config().options.theme).normal.a.fg
            end
            if lualine_ok then
                colors = M.get_lualine_colors(lualine, props, ft_color)
            end
            local res = {
                ft_icon and {
                    ' ',
                    ft_icon,
                    ' ',
                    guibg = colors.bg or ft_color,
                    guifg = colors.fg or helpers.contrast_color(ft_color)
                } or '',
                ' ',
                { filename, gui = modified and 'bold,italic' or 'bold' },
                guibg = colors.bg or ft_color,
                guifg = colors.fg or helpers.contrast_color(ft_color),
            }
            if not navic_ok then return res end
            if props.focused then
                for _, item in ipairs(navic.get_data(props.buf) or {}) do
                    table.insert(res, {
                        { ' > ',     group = 'NavicSeparator' },
                        { item.icon, group = 'NavicIcons' .. item.type },
                        { item.name, group = 'NavicText' },
                    })
                end
            end
            table.insert(res, ' ')
            return res
        end,
    }
end

return M
