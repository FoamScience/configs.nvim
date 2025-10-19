-- 0.33ms replacement for lualine
local icons = require("user.lspicons")

local M = {
    "echasnovski/mini.nvim",
    event = "VeryLazy",
}

local function clients_lsp()
    local clients = vim.lsp.get_clients({ bufnr = 0 })
    if next(clients) == nil then
        return ""
    end
    local c = {}
    for _, client in pairs(clients) do
        if not (client.name == "null-ls") then
            table.insert(c, client.name)
        end
    end
    return "\u{f085} " .. table.concat(c, "|")
end

local function flash_in_search()
    local flash_ok, _ = pcall(require, "flash")
    if not flash_ok then return "" end
    if not require("flash.plugins.search").enabled then return "" end
    return "/" .. icons.kind.Event
end

local function arrow_status()
    local arrow_ok, arrow = pcall(require, "arrow.statusline")
    if not arrow_ok then return "" end
    if arrow.is_on_arrow_file() == nil then return "" end
    return arrow.text_for_statusline_with_icons()
end

local function recording()
    local rec = vim.fn.reg_recording()
    if rec == "" then return "" end
    return "Recording @" .. rec
end

local function git_blame()
    local gitsigns_ok, _ = pcall(require, "gitsigns")
    if not gitsigns_ok then return "" end
    if not vim.b.gitsigns_blame_line then return "" end
    return vim.b.gitsigns_blame_line
end

local function diagnostics()
    local diag = vim.diagnostic.get(0)
    local errors = #vim.tbl_filter(function(d) return d.severity == vim.diagnostic.severity.ERROR end, diag)
    local warnings = #vim.tbl_filter(function(d) return d.severity == vim.diagnostic.severity.WARN end, diag)
    local hints = #vim.tbl_filter(function(d) return d.severity == vim.diagnostic.severity.HINT end, diag)
    local info = #vim.tbl_filter(function(d) return d.severity == vim.diagnostic.severity.INFO end, diag)

    local result = {}
    if errors > 0 then table.insert(result, icons.diagnostics.Error .. errors) end
    if warnings > 0 then table.insert(result, icons.diagnostics.Warning .. warnings) end
    if hints > 0 then table.insert(result, icons.diagnostics.Hint .. hints) end
    if info > 0 then table.insert(result, icons.diagnostics.Information .. info) end
    return table.concat(result, " ")
end

local function fileformat()
    local format_icons = {
        unix = icons.misc.Unix,
        dos = icons.misc.Dos,
        mac = icons.misc.Mac,
    }
    return format_icons[vim.bo.fileformat] or vim.bo.fileformat
end

M.sidebar_filetypes = {
    'NvimTree',
    'neo-tree',
    'undotree',
    'undotreeDiff',
    'Outline',
    'toggleterm',
    'trouble',
    'qf',
}

function M.config()
    require('mini.ai').setup()
    require('mini.operators').setup({
        multiply = { prefix = nil },
        sort = { prefix = nil },
    })
    require('mini.splitjoin').setup({
        mappings = {
            toggle = 'gj'
        }
    })
    require('which-key').add({
        { "<leader>s", group = "Surround", icon = icons.git.FileIgnored },
    })
    require('mini.surround').setup({
        mappings = {
            add = '<leader>sa',
            delete = '<leader>sd',
            find = '<leader>sf',
            find_left = '<leader>sF',
            highlight = '<leader>sh',
            replace = '<leader>sr',
        },
    })
    require('mini.diff').setup()
    require('which-key').add({
        "<leader>gdD",
        function()
            MiniDiff.toggle_overlay()
        end,
        desc = "Toggle hunk overlay",
        icon = icons.kind.Boolean
    })
    local statusline = require('mini.statusline')

    -- Custom content function matching old lualine layout
    statusline.section_location = function()
        return '%l:%c %p%%'
    end

    local function custom_content()
        local mode, mode_hl = statusline.section_mode({ trunc_width = 120 })
        local git = statusline.section_git({ trunc_width = 75 })

        -- Powerline-style separators - slanted triangles (matching lualine)
        local sep_left = ""  -- U+E0B2 (left-pointing filled triangle)
        local sep_right = "" -- U+E0B0 (right-pointing filled triangle)

        -- Get mode color for dynamic separators
        local mode_color = vim.api.nvim_get_hl(0, { name = mode_hl }).bg
        local devinfo_color = vim.api.nvim_get_hl(0, { name = 'MiniStatuslineDevinfo' }).bg
        local fileinfo_color = vim.api.nvim_get_hl(0, { name = 'MiniStatuslineFileinfo' }).bg
        local bg_color = vim.api.nvim_get_hl(0, { name = 'StatusLine' }).bg

        -- Dynamic separator highlights
        vim.api.nvim_set_hl(0, 'StatusLineSep1', { fg = mode_color, bg = devinfo_color })
        vim.api.nvim_set_hl(0, 'StatusLineSep2', { fg = devinfo_color, bg = bg_color })
        vim.api.nvim_set_hl(0, 'StatusLineSep3', { fg = fileinfo_color, bg = bg_color })
        vim.api.nvim_set_hl(0, 'StatusLineSep4', { fg = mode_color, bg = fileinfo_color })

        local section_a = mode .. (arrow_status() ~= "" and " " .. arrow_status() or "")
            .. (recording() ~= "" and " " .. recording() or "") .. " "
        local section_b = " " .. git .. (git_blame() ~= "" and " " .. git_blame() or "") .. " "
        local section_x = " " .. diagnostics() .. " " .. clients_lsp() .. " "
        local section_y = " " .. flash_in_search() .. " " .. fileformat() .. " " .. vim.bo.filetype .. " "
        local section_z = " " .. statusline.section_location() .. " "

        return statusline.combine_groups({
            { hl = mode_hl,                 strings = { section_a } },
            { hl = 'StatusLineSep1',        strings = { sep_right } },
            { hl = 'MiniStatuslineDevinfo', strings = { section_b } },
            { hl = 'StatusLineSep2',        strings = { sep_right } },
            '%<', -- Truncation point
            '%=', -- Right align
            { hl = 'StatusLineSep3',         strings = { sep_left } },
            { hl = 'MiniStatuslineFileinfo', strings = { section_x } },
            { hl = 'MiniStatuslineFileinfo', strings = { sep_left } },
            { hl = 'MiniStatuslineFileinfo', strings = { section_y } },
            { hl = 'StatusLineSep4',         strings = { sep_left } },
            { hl = mode_hl,                  strings = { section_z } },
        })
    end

    statusline.setup({
        use_icons = true,
        set_vim_settings = false,
        content = {
            active = custom_content,
            inactive = function()
                return statusline.combine_groups({
                    { hl = 'MiniStatuslineInactive', strings = { '%f' } },
                    '%=',
                    { hl = 'MiniStatuslineInactive', strings = { vim.bo.filetype } },
                })
            end,
        },
    })

    local tabline = require('mini.tabline')

    tabline.setup({
        show_icons = true,
        set_vim_settings = false,
        tabpage_section = 'right',
    })


    -- Custom tabline function with sidebar offset
    _G.custom_tabline = function()
        local offset = 0

        -- Check for sidebar windows on the left
        for _, win in ipairs(vim.api.nvim_list_wins()) do
            local buf = vim.api.nvim_win_get_buf(win)
            local ft = vim.bo[buf].filetype
            local win_config = vim.api.nvim_win_get_config(win)

            -- Check if it's a sidebar (left-side split with matching filetype)
            if vim.tbl_contains(M.sidebar_filetypes, ft) and win_config.relative == "" then
                local win_width = vim.api.nvim_win_get_width(win)
                local win_pos = vim.api.nvim_win_get_position(win)

                -- Only offset if window is on the left (col == 0)
                if win_pos[2] == 0 then
                    offset = math.max(offset, win_width)
                end
            end
        end

        local tabline_string = MiniTabline.make_tabline_string()

        if offset > 0 then
            -- Add padding with highlight
            local padding = string.rep(" ", offset)
            return "%#MiniTablineFill#" .. padding .. tabline_string
        else
            return tabline_string
        end
    end

    -- Set custom tabline
    vim.o.tabline = "%!v:lua.custom_tabline()"

    -- Refresh tabline when windows change
    vim.api.nvim_create_autocmd({ "WinNew", "WinClosed", "WinResized", "BufWinEnter", "FileType" }, {
        callback = function()
            vim.cmd("redrawtabline")
        end,
    })

    local function update_tabline_visibility()
        local buf_count = #vim.fn.getbufinfo({ buflisted = 1 })
        vim.o.showtabline = buf_count > 1 and 2 or 0
    end

    vim.api.nvim_create_autocmd({ "BufAdd", "BufDelete" }, {
        callback = update_tabline_visibility,
    })

    update_tabline_visibility()
    local function apply_colors()
        if vim.g.colors_name and vim.g.colors_name:match("catppuccin") then
            local ok, cp = pcall(require, "catppuccin.palettes")
            if ok then
                local palette = cp.get_palette()
                vim.api.nvim_set_hl(0, 'MiniStatuslineModeNormal', { fg = palette.base, bg = palette.blue, bold = true })
                vim.api.nvim_set_hl(0, 'MiniStatuslineModeInsert', { fg = palette.base, bg = palette.green, bold = true })
                vim.api.nvim_set_hl(0, 'MiniStatuslineModeVisual', { fg = palette.base, bg = palette.mauve, bold = true })
                vim.api.nvim_set_hl(0, 'MiniStatuslineModeReplace', { fg = palette.base, bg = palette.red, bold = true })
                vim.api.nvim_set_hl(0, 'MiniStatuslineModeCommand',
                    { fg = palette.base, bg = palette.peach, bold = true })
                vim.api.nvim_set_hl(0, 'MiniStatuslineDevinfo', { fg = palette.peach, bg = palette.surface3 })
                vim.api.nvim_set_hl(0, 'MiniStatuslineFilename', { fg = palette.base, bg = palette.surface0 })
                vim.api.nvim_set_hl(0, 'MiniStatuslineFileinfo', { fg = palette.text, bg = palette.surface0 })
                vim.api.nvim_set_hl(0, 'MiniStatuslineInactive', { fg = palette.overlay0, bg = palette.mantle })
                vim.api.nvim_set_hl(0, 'MiniTablineCurrent', { fg = palette.base, bg = palette.blue, bold = true })
                vim.api.nvim_set_hl(0, 'MiniTablineVisible', { fg = palette.subtext0, bg = palette.surface0 })
                vim.api.nvim_set_hl(0, 'MiniTablineHidden', { fg = palette.overlay0, bg = palette.mantle })
                vim.api.nvim_set_hl(0, 'MiniTablineModifiedCurrent',
                    { fg = palette.peach, bg = palette.surface1, bold = true })
                vim.api.nvim_set_hl(0, 'MiniTablineModifiedVisible', { fg = palette.peach, bg = palette.surface0 })
                vim.api.nvim_set_hl(0, 'MiniTablineModifiedHidden', { fg = palette.peach, bg = palette.mantle })
                vim.api.nvim_set_hl(0, 'MiniTablineFill', { bg = palette.mantle })
                vim.api.nvim_set_hl(0, 'MiniTablineTabpagesection',
                    { fg = palette.blue, bg = palette.surface0, bold = true })
            end
        end
    end

    vim.api.nvim_create_autocmd("ColorScheme", {
        callback = apply_colors,
    })
    apply_colors()
end

return M
