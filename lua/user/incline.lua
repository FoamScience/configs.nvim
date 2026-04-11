local M = {
    'b0o/incline.nvim',
    config = function()
        require('incline').setup()
    end,
    event = 'VeryLazy',
    cond = function()
        return vim.env.SSH_CONNECTION == nil
    end,
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

-- Get merge branch info for DiffConflicts decoration
function M.get_merge_info()
    if M._merge_info then return M._merge_info end
    local info = { head = nil, incoming = nil }
    local head = vim.fn.system("git rev-parse --abbrev-ref HEAD 2>/dev/null"):gsub("%s+$", "")
    if vim.v.shell_error == 0 and head ~= "" then
        info.head = head
    end
    -- Try MERGE_HEAD for merge, REBASE_HEAD for rebase
    local merge_head = vim.fn.system("git log --oneline -1 MERGE_HEAD 2>/dev/null"):gsub("%s+$", "")
    if vim.v.shell_error == 0 and merge_head ~= "" then
        -- Try to get the branch name from MERGE_MSG
        local merge_msg = vim.fn.system("head -1 $(git rev-parse --git-dir)/MERGE_MSG 2>/dev/null"):gsub("%s+$", "")
        local branch = merge_msg:match("Merge branch '([^']+)'") or merge_msg:match("Merge .+ '([^']+)'")
        info.incoming = branch or merge_head
    end
    M._merge_info = info
    return info
end

-- Detect DiffConflicts buffer role
function M.get_diffconflicts_role(bufname)
    local name = vim.fn.fnamemodify(bufname, ":t")
    -- Explicit DiffConflicts buffer names
    if name == "RCONFL" then return "REMOTE" end
    if name == "LOCAL" then return "LOCAL" end
    if name == "BASE" then return "BASE" end
    if name == "REMOTE" then return "REMOTE" end
    -- jj-style names
    if name == "snapshot" then return "REMOTE" end
    if name == "left" then return "LOCAL" end
    if name == "base" then return "BASE" end
    if name == "right" then return "REMOTE" end
    return nil
end

-- Get diffview info for a buffer: { side = "left"|"right", label = "abc1234" or "LOCAL" }
function M.get_diffview_info(bufname)
    if not bufname:match("^diffview://") then return nil end
    local ok, lib = pcall(require, "diffview.lib")
    if not ok then return nil end
    local view = lib.get_current_view()
    if not view then return nil end

    -- Extract the context segment from diffview://<repo>/<context>/<path>
    -- The context is the commit abbrev, ":0:" for staged, or "[custom]"
    local context = bufname:match("^diffview://.-/([^/]+)/")
    if not context then return nil end

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

-- Check if a buffer is the LOCAL side in git DiffConflicts (original file diffed with RCONFL)
function M.get_diffconflicts_role_for_win(bufnr, winid)
    local bufname = vim.api.nvim_buf_get_name(bufnr)
    local explicit = M.get_diffconflicts_role(bufname)
    if explicit then return explicit end
    -- Check if this window is in diff mode alongside an RCONFL buffer
    if not vim.wo[winid].diff then return nil end
    local tab_wins = vim.api.nvim_tabpage_list_wins(0)
    for _, w in ipairs(tab_wins) do
        if w ~= winid then
            local b = vim.api.nvim_win_get_buf(w)
            local n = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(b), ":t")
            if n == "RCONFL" or n == "snapshot" then
                return "LOCAL"
            end
        end
    end
    return nil
end

function M.config()
    local helpers = require 'incline.helpers'
    local devicons = require 'nvim-web-devicons'
    local navic_ok, navic = pcall(require, "nvim-navic")
    -- Clear cached merge info on new merge sessions
    M._merge_info = nil
    require('incline').setup {
        hide = {
            only_win = 'count_ignored',
        },
        ignore = {
            buftypes = function(bufnr, buftype)
                -- Allow atlassian buffers even though they're nofile
                local ft = vim.bo[bufnr].filetype
                if ft == "atlassian_jira" or ft == "atlassian_confluence" then
                    return false
                end
                -- Allow DiffConflicts and diffview buffers
                local bufname = vim.api.nvim_buf_get_name(bufnr)
                if M.get_diffconflicts_role(bufname) then
                    return false
                end
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
            local filename = vim.fn.fnamemodify(raw_bufname, ':t')
            -- For diffview buffers, extract the actual filename from the URI
            if raw_bufname:match("^diffview://") then
                local dv_path = raw_bufname:match("^diffview://.-/[^/]+/(.+)$")
                if dv_path then
                    filename = vim.fn.fnamemodify(dv_path, ':t')
                end
            end
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
            -- DiffConflicts decoration: show role and branch/commit
            local winid = vim.fn.bufwinid(props.buf)
            local dc_role = M.get_diffconflicts_role_for_win(props.buf, winid ~= -1 and winid or 0)
            local dc_label = nil
            if dc_role then
                local palette = require("catppuccin.palettes").get_palette()
                local info = M.get_merge_info()
                local branch
                if dc_role == "LOCAL" then
                    branch = info.head
                elseif dc_role == "REMOTE" then
                    branch = info.incoming
                end
                dc_label = dc_role .. (branch and (" ← " .. branch) or "")
                -- For DiffConflicts buffers, use the original file's icon
                if winid ~= -1 then
                    local diff_wins = vim.tbl_filter(function(w)
                        return vim.wo[w].diff
                    end, vim.api.nvim_tabpage_list_wins(0))
                    for _, w in ipairs(diff_wins) do
                        local b = vim.api.nvim_win_get_buf(w)
                        local n = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(b), ":t")
                        if not M.get_diffconflicts_role(vim.api.nvim_buf_get_name(b)) then
                            local icon, color = devicons.get_icon_color(n)
                            if icon then ft_icon, ft_color = icon, color end
                            filename = n
                            break
                        end
                    end
                end
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
            -- Append DiffConflicts role badge
            if dc_label then
                table.insert(res, {
                    { ' ' .. dc_label .. ' ', gui = 'bold' },
                    guibg = colors.bg or ft_color,
                    guifg = colors.fg or helpers.contrast_color(ft_color),
                })
            end
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
                    { '  ' .. dv_info.label .. ' ', gui = 'bold' },
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
            local cur_winid = vim.api.nvim_get_current_win()
            local cursor_line = vim.fn.line("w0", cur_winid)
            local curpos = vim.fn.line(".", cur_winid)
            local win_width = vim.api.nvim_win_get_width(cur_winid)
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
