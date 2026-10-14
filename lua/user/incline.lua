local M = {
    "b0o/incline.nvim",
    config = function()
        require("incline").setup()
    end,
    event = "VeryLazy",
    cond = function()
        return vim.env.SSH_CONNECTION == nil
    end,
    dependencies = {
        "nvim-mini/mini.nvim",
        "SmiteshP/nvim-navic",
    },
}

-- Get colors from catppuccin theme
function M.get_mode_colors(props, ft_color)
    local helpers = require("incline.helpers")
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
    elseif m:match("n") then
        fg = palette.base
        bg = palette.blue
    elseif m:match("i") then
        fg = palette.base
        bg = palette.green
    elseif m:match("R") then
        fg = palette.base
        bg = palette.yellow
    elseif m:match("v") or m:match("V") then
        fg = palette.base
        bg = palette.mauve
    else -- unknown mode!
        fg = palette.text
        bg = palette.surface0
    end
    return { fg = fg, bg = bg, ifg = ifg, ibg = ibg }
end

-- Get diffview info for a buffer: { side = "left"|"right", label = "abc1234" or "LOCAL" }
function M.get_diffview_info(bufname)
    if not bufname:match("^diffview://") then
        return nil
    end
    local ok, lib = pcall(require, "diffview.lib")
    if not ok then
        return nil
    end
    local view = lib.get_current_view()
    if not view then
        return nil
    end

    -- Extract the context segment from diffview://<repo>/<context>/<path>
    -- The context is the commit abbrev, ":0:" for staged, or "[custom]"
    local context = bufname:match("^diffview://.-/([^/]+)/")
    if not context then
        return nil
    end

    local side, label
    if view.left and view.left.commit and context == view.left:abbrev(11) then
        side = "left"
        label = view.rev_arg or view.left:abbrev()
    elseif view.right and view.right.commit and context == view.right:abbrev(11) then
        side = "right"
        label = view.right:abbrev()
    elseif context:match("^:%d+:$") then
        -- Stage revision: :0: = merged, :2: = ours, :3: = theirs
        local stage = tonumber(context:match(":(%d+):"))
        if stage == 2 then
            side = "left"
            label = "OURS (staged)"
        elseif stage == 3 then
            side = "right"
            label = "THEIRS (staged)"
        else
            side = "left"
            label = "INDEX"
        end
    else
        side = "left"
        label = context
    end

    return { side = side, label = label }
end

function M.config()
    local helpers = require("incline.helpers")
    local devicons = require("nvim-web-devicons")
    local navic_ok, navic = pcall(require, "nvim-navic")
    require("incline").setup({
        hide = {
            only_win = "count_ignored",
        },
        ignore = {
            buftypes = function(bufnr, buftype)
                -- Allow atlassian buffers even though they're nofile
                local ft = vim.bo[bufnr].filetype
                if ft == "atlassian_jira" or ft == "atlassian_confluence" then
                    return false
                end
                -- Allow diffview buffers
                local bufname = vim.api.nvim_buf_get_name(bufnr)
                if bufname:match("^diffview://") then
                    return false
                end
                -- Default ignore list
                return buftype == "terminal" or buftype == "nofile" or buftype == "quickfix" or buftype == "prompt"
            end,
        },
        window = {
            padding = 0,
            margin = { horizontal = 0, vertical = 0 },
        },
        render = function(props)
            local raw_bufname = vim.api.nvim_buf_get_name(props.buf)
            local filename = vim.fn.fnamemodify(raw_bufname, ":t")
            -- For diffview buffers, extract the actual filename from the URI
            if raw_bufname:match("^diffview://") then
                local dv_path = raw_bufname:match("^diffview://.-/[^/]+/(.+)$")
                if dv_path then
                    filename = vim.fn.fnamemodify(dv_path, ":t")
                end
            end
            if filename == "" then
                filename = "[No Name]"
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
                    " ",
                    ft_icon,
                    " ",
                    guibg = colors.bg or ft_color,
                    guifg = colors.fg or helpers.contrast_color(ft_color),
                } or "",
                " ",
                { filename, gui = modified and "bold,italic" or "bold" },
                guibg = colors.bg or ft_color,
                guifg = colors.fg or helpers.contrast_color(ft_color),
            }
            -- Append diffview rev badge
            local dv_info = M.get_diffview_info(raw_bufname)
            -- Also detect local working-copy files in a diffview tab
            if not dv_info and not raw_bufname:match("^diffview://") then
                local ok_dv, dv_lib = pcall(require, "diffview.lib")
                if ok_dv then
                    local view = dv_lib.get_current_view()
                    if view and view.right and vim.wo[vim.fn.bufwinid(props.buf)].diff then
                        local RevType = require("diffview.vcs.rev").RevType
                        if view.right.type == RevType.LOCAL then
                            dv_info = { side = "right", label = "LOCAL" }
                        end
                    end
                end
            end
            if dv_info then
                local palette = require("catppuccin.palettes").get_palette()
                local dv_bg = dv_info.side == "left" and palette.peach or palette.lavender
                table.insert(res, {
                    { "  " .. dv_info.label .. " ", gui = "bold" },
                    guibg = dv_bg,
                    guifg = helpers.contrast_color(dv_bg),
                })
            end
            -- NotebookLM artifact status
            local nlm_ok, nlm_incline = pcall(require, "notebooklm.incline")
            if nlm_ok then
                local nlm_segs = nlm_incline.render_segments()
                if nlm_segs then
                    table.insert(res, { "  ", guifg = "#585b70" })
                    for _, seg in ipairs(nlm_segs) do
                        table.insert(res, seg)
                    end
                end
            end

            if not navic_ok then
                return res
            end
            if props.focused then
                local data = navic.get_data(props.buf) or {}
                for _, item in ipairs(data) do
                    table.insert(res, {
                        { " > " },
                        { item.icon },
                        { item.name },
                    })
                end
            end
            table.insert(res, " ")
            return res
        end,
    })
    M.patch_placement()
end

-- Drop the winline to the bottom of its window when buffer text runs under it at the top.
-- incline has no per-window placement hook, so wrap its (private) row computation.
function M.patch_placement()
    local config = require("incline.config")
    local Winline = getmetatable(require("incline.winline")(0)).__index
    local get_row = Winline.get_win_geom_row

    local function text_under(self, row)
        local win = self.target_win
        local winline = row + (vim.wo[win].winbar == "" and 1 or 0)
        if winline < 1 then
            return false
        end
        -- Assumes one buffer line per screen line; wrapped/folded lines above may misplace the check
        local lnum = vim.fn.line("w0", win) + winline - 1
        local line = vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(win), lnum - 1, lnum, false)[1]
        if not line then
            return false
        end
        local info = vim.fn.getwininfo(win)[1]
        local leftcol = vim.api.nvim_win_call(win, vim.fn.winsaveview).leftcol
        local text_end = info.textoff + vim.api.nvim_win_call(win, function()
            return vim.fn.strdisplaywidth(line)
        end) - leftcol
        local win_width = vim.api.nvim_win_get_width(win)
        return text_end > self:get_win_geom_col(win_width, self:get_win_geom_width(win_width))
    end

    function Winline:get_win_geom_row()
        local row = get_row(self)
        if config.window.placement.vertical ~= "top" or not text_under(self, row) then
            return row
        end
        return vim.api.nvim_win_get_height(self.target_win) - 1
    end
end

return M
