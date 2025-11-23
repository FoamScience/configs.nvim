local M = {
    'b0o/incline.nvim',
    config = function()
        require('incline').setup()
    end,
    event = 'VeryLazy',
    dependencies = {
        "nvim-tree/nvim-web-devicons",
        "SmiteshP/nvim-navic",
    }
}

-- Get colors from catppuccin theme
function M.get_mode_colors(props, ft_color)
    local helpers = require 'incline.helpers'
    local palette = require("catppuccin.palettes").get_palette()
    local fg, bg, ifg, ibg
    local m = vim.api.nvim_get_mode().mode
    ifg = helpers.contrast_color(ft_color)
    ibg = ft_color

    if not props.focused then
        fg = palette.overlay0
        bg = palette.mantle
        ifg = palette.overlay0
        ibg = palette.mantle
    elseif m:match('n') then
        fg = palette.base
        bg = palette.blue
    elseif m:match('i') then
        fg = palette.base
        bg = palette.green
    elseif m:match('R') then
        fg = palette.base
        bg = palette.yellow
    elseif m:match('v') or m:match('V') then
        fg = palette.base
        bg = palette.mauve
    else -- unknown mode!
        fg = palette.text
        bg = palette.surface0
    end
    return { fg = fg, bg = bg, ifg = ifg, ibg = ibg }
end

function M.config()
    local helpers = require 'incline.helpers'
    local devicons = require 'nvim-web-devicons'
    local navic_ok, navic = pcall(require, "nvim-navic")
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
            -- Use default color if no filetype icon color
            if ft_color == nil then
                local palette = require("catppuccin.palettes").get_palette()
                ft_color = palette.blue
            end
            local colors = M.get_mode_colors(props, ft_color)
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
            local data_length = #res[3][1] + 6

            local res_no_navic = {}
            for i, v in ipairs(res) do
                res_no_navic[i] = v
            end
            if props.focused then
                local data = navic.get_data(props.buf) or {}
                for _, item in ipairs(data) do
                    if item.name then
                        data_length = data_length + #item.name + #"> {}"
                    end
                    table.insert(res, {
                        { ' > ', },
                        { item.icon, },
                        { item.name, },
                    })
                end
            end
            table.insert(res, ' ')
            local winid = vim.api.nvim_get_current_win()
            local cursor_line = vim.fn.line("w0", winid)
            local curpos = vim.fn.line(".", winid)
            local win_width = vim.api.nvim_win_get_width(winid)
            if curpos == cursor_line then
                local first_line = vim.api.nvim_buf_get_lines(props.buf, cursor_line - 1, cursor_line, false)[1] or ""
                local total_length = #first_line + data_length
                if total_length > win_width then
                    return res_no_navic
                end
            end
            return res
        end,
    }
end

return M
