local M = {
    'akinsho/bufferline.nvim',
    event = "VeryLazy",
    version = "*",
    dependencies = {
        'nvim-tree/nvim-web-devicons',
    }
}

function M.config()
    local bufferline = require('bufferline')
    local icons = require('user.lspicons')
    bufferline.setup({
        options = {
            mode = "buffers",
            style_preset = bufferline.style_preset.minimal,
            numbers = "ordinal",
            diagnostics = "nvim_lsp",
            diagnostics_indicator = nil,
            -- display diagnostics count, but already doing this in lualine, so redundant
            --function(count, level, diagnostics_dict, context)
            --    local parts = {}
            --    for key, value in pairs(diagnostics_dict) do
            --        local icon = icons.diagnostics[key:sub(1, 1):upper() .. key:sub(2)]
            --        table.insert(parts, string.format("%s %d", icon, value))
            --    end
            --    return table.concat(parts, " ")
            --end,
            separator_style = "thick",
            max_name_length = 25,
            max_prefix_length = 15,
            truncate_names = false,
            color_icons = true,
            show_buffer_icons = true,
            show_buffer_close_icons = true,
            close_icon = ' ',
            buffer_close_icon = "🗙",
            offsets = {
                {
                    filetype = "NvimTree",
                    text = "Explorer",
                    text_align = "center",
                    highlight = "Directory",
                    saperator = true,
                },
                {
                    filetype = "qf",
                    text = "Quickfix List",
                    text_align = "center",
                    saperator = true,
                },
                {
                    filetype = "Navbuddy",
                    text = "Outline",
                    text_align = "center",
                    saperator = true,
                },
                {
                    filetype = "DiffviewFiles",
                    text = "Diffs",
                    text_align = "center",
                    separator = true,
                },
                {
                    filetype = "OverseerList",
                    text = "Build Tasks",
                    text_align = "center",
                    saperator = true,
                },
            },
        },
    })
end

return M
