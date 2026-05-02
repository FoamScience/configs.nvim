-- Standalone ANSI SGR -> extmark highlight converter.
-- Strips ESC[...m sequences from the buffer and applies matching highlights.
-- Commands:
--   :AnsiColorize        apply once to current buffer
--   :AnsiColorize!       apply and keep updating on TextChanged
--   :AnsiStop            stop auto-updating current buffer
-- Default mapping covers 8/16 basic colors, bright, bg, bold/italic/underline,
-- 256-color (38;5;N / 48;5;N), and truecolor (38;2;R;G;B / 48;2;R;G;B).
return {
    "folke/lazy.nvim",  -- dummy anchor so lazy loads this spec's init
    lazy = false,
    init = function()
        local ns = vim.api.nvim_create_namespace("ansi_colorize")
        local M = {}

        -- Map ANSI color index -> list of highlight groups to probe for fg color.
        -- First group that has a resolved fg wins. Order = preferred -> fallback.
        local hl_sources = {
            [0]  = { "Comment" },                           -- black
            [1]  = { "DiagnosticError", "ErrorMsg", "Error" },
            [2]  = { "DiagnosticOk", "String" },
            [3]  = { "DiagnosticWarn", "WarningMsg", "Type" },
            [4]  = { "DiagnosticInfo", "Function" },
            [5]  = { "Statement", "Keyword" },
            [6]  = { "Special", "Constant" },
            [7]  = { "Normal" },
            [8]  = { "NonText", "Comment" },                -- bright black
            [9]  = { "DiagnosticError", "ErrorMsg" },
            [10] = { "DiagnosticOk", "String" },
            [11] = { "DiagnosticWarn", "Type" },
            [12] = { "DiagnosticInfo", "Function" },
            [13] = { "Statement", "Keyword" },
            [14] = { "Special", "Constant" },
            [15] = { "Normal" },
        }

        local function hl_fg(group)
            local ok, h = pcall(vim.api.nvim_get_hl, 0, { name = group, link = false })
            if not ok or not h then return nil end
            if h.fg then return string.format("#%06x", h.fg) end
            return nil
        end

        local function term_color(idx)
            local override = vim.g.ansi_colors
            if type(override) == "table" and override[idx] then
                return override[idx]
            end
            for _, group in ipairs(hl_sources[idx] or {}) do
                local c = hl_fg(group)
                if c then return c end
            end
            return vim.g["terminal_color_" .. idx]
        end

        -- SGR code -> terminal_color index.
        local sgr_to_idx = {
            [30]=0, [31]=1, [32]=2, [33]=3, [34]=4, [35]=5, [36]=6, [37]=7,
            [90]=8, [91]=9, [92]=10, [93]=11, [94]=12, [95]=13, [96]=14, [97]=15,
        }

        -- xterm 256-color palette (cube + grayscale). First 16 reuse terminal colors.
        local function color256(n)
            if n < 16 then
                return term_color(n)
            elseif n < 232 then
                local i = n - 16
                local r = math.floor(i / 36) % 6
                local g = math.floor(i / 6) % 6
                local b = i % 6
                local v = { [0]=0, [1]=95, [2]=135, [3]=175, [4]=215, [5]=255 }
                return string.format("#%02x%02x%02x", v[r], v[g], v[b])
            else
                local v = 8 + (n - 232) * 10
                return string.format("#%02x%02x%02x", v, v, v)
            end
        end

        -- Cache hl groups so we don't create thousands of duplicates.
        local hl_cache = {}
        local function get_hl(attrs)
            local key = table.concat({
                attrs.fg or "", attrs.bg or "",
                attrs.bold and "b" or "", attrs.italic and "i" or "",
                attrs.underline and "u" or "", attrs.reverse and "r" or "",
            }, "|")
            if hl_cache[key] then return hl_cache[key] end
            local name = "AnsiColorize_" .. vim.fn.sha256(key):sub(1, 10)
            local spec = {}
            if attrs.reverse then
                spec.fg, spec.bg = attrs.bg, attrs.fg
            else
                spec.fg, spec.bg = attrs.fg, attrs.bg
            end
            spec.bold = attrs.bold or nil
            spec.italic = attrs.italic or nil
            spec.underline = attrs.underline or nil
            vim.api.nvim_set_hl(0, name, spec)
            hl_cache[key] = name
            return name
        end

        -- Parse an SGR parameter list, mutating `st` (current style state).
        local function apply_sgr(params, st)
            local i = 1
            while i <= #params do
                local p = params[i]
                if p == 0 or p == nil then
                    st.fg, st.bg = nil, nil
                    st.bold, st.italic, st.underline, st.reverse = false, false, false, false
                elseif p == 1 then st.bold = true
                elseif p == 3 then st.italic = true
                elseif p == 4 then st.underline = true
                elseif p == 7 then st.reverse = true
                elseif p == 22 then st.bold = false
                elseif p == 23 then st.italic = false
                elseif p == 24 then st.underline = false
                elseif p == 27 then st.reverse = false
                elseif p >= 30 and p <= 37 then st.fg = term_color(sgr_to_idx[p])
                elseif p == 39 then st.fg = nil
                elseif p >= 40 and p <= 47 then st.bg = term_color(sgr_to_idx[p - 10])
                elseif p == 49 then st.bg = nil
                elseif p >= 90 and p <= 97 then st.fg = term_color(sgr_to_idx[p])
                elseif p >= 100 and p <= 107 then st.bg = term_color(sgr_to_idx[p - 10])
                elseif p == 38 or p == 48 then
                    local target = (p == 38) and "fg" or "bg"
                    local mode = params[i + 1]
                    if mode == 5 and params[i + 2] then
                        st[target] = color256(params[i + 2])
                        i = i + 2
                    elseif mode == 2 and params[i + 4] then
                        st[target] = string.format("#%02x%02x%02x",
                            params[i + 2] or 0, params[i + 3] or 0, params[i + 4] or 0)
                        i = i + 4
                    end
                end
                i = i + 1
            end
        end

        function M.colorize(buf)
            buf = buf or 0
            if not vim.api.nvim_buf_is_valid(buf) then return end
            vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

            local was_ro = vim.bo[buf].readonly
            local was_mod = vim.bo[buf].modifiable
            vim.bo[buf].readonly = false
            vim.bo[buf].modifiable = true

            local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
            local state = {}
            local spans = {}  -- { row, col_start, col_end, hl }
            local new_lines = {}

            for row, line in ipairs(lines) do
                local out = {}
                local col = 0
                local cur_start = col
                local cur_style = vim.deepcopy(state)
                local pos = 1
                while pos <= #line do
                    local s, e, body = line:find("\27%[([0-9;]*)m", pos)
                    if not s then
                        local chunk = line:sub(pos)
                        out[#out + 1] = chunk
                        col = col + #chunk
                        break
                    end
                    if s > pos then
                        local chunk = line:sub(pos, s - 1)
                        out[#out + 1] = chunk
                        col = col + #chunk
                    end
                    -- flush previous style span
                    if col > cur_start
                        and (cur_style.fg or cur_style.bg or cur_style.bold
                             or cur_style.italic or cur_style.underline or cur_style.reverse)
                    then
                        spans[#spans + 1] = {
                            row - 1, cur_start, col, get_hl(cur_style),
                        }
                    end
                    cur_start = col
                    local params = {}
                    if body == "" then
                        params = { 0 }
                    else
                        for num in body:gmatch("([0-9]+)") do
                            params[#params + 1] = tonumber(num)
                        end
                        if #params == 0 then params = { 0 } end
                    end
                    apply_sgr(params, state)
                    cur_style = vim.deepcopy(state)
                    pos = e + 1
                end
                -- tail of line
                if col > cur_start
                    and (cur_style.fg or cur_style.bg or cur_style.bold
                         or cur_style.italic or cur_style.underline or cur_style.reverse)
                then
                    spans[#spans + 1] = {
                        row - 1, cur_start, col, get_hl(cur_style),
                    }
                end
                new_lines[row] = table.concat(out)
            end

            vim.api.nvim_buf_set_lines(buf, 0, -1, false, new_lines)
            for _, sp in ipairs(spans) do
                pcall(vim.api.nvim_buf_set_extmark, buf, ns, sp[1], sp[2], {
                    end_row = sp[1],
                    end_col = sp[3],
                    hl_group = sp[4],
                })
            end

            vim.bo[buf].modifiable = was_mod
            vim.bo[buf].readonly = was_ro
        end

        local auto_group = vim.api.nvim_create_augroup("AnsiColorizeAuto", { clear = true })
        local tracked = {}

        function M.watch(buf)
            buf = buf or vim.api.nvim_get_current_buf()
            if tracked[buf] then return end
            tracked[buf] = true
            vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
                group = auto_group,
                buffer = buf,
                callback = function() M.colorize(buf) end,
            })
            vim.api.nvim_create_autocmd({ "BufWipeout", "BufDelete" }, {
                group = auto_group,
                buffer = buf,
                callback = function() tracked[buf] = nil end,
            })
            M.colorize(buf)
        end

        function M.unwatch(buf)
            buf = buf or vim.api.nvim_get_current_buf()
            tracked[buf] = nil
            vim.api.nvim_clear_autocmds({ group = auto_group, buffer = buf })
        end

        vim.api.nvim_create_user_command("AnsiColorize", function(opts)
            if opts.bang then M.watch(0) else M.colorize(0) end
        end, { bang = true })

        vim.api.nvim_create_user_command("AnsiStop", function() M.unwatch(0) end, {})

        vim.api.nvim_create_user_command("AnsiDump", function()
            local lines = { "ANSI palette in use (override > terminal_color_* > fallback):" }
            for i = 0, 15 do
                table.insert(lines, string.format("  %2d -> %s", i, term_color(i) or "?"))
            end
            vim.notify(table.concat(lines, "\n"))
        end, {})

        -- Invalidate cached hl groups when colorscheme changes, then refresh watched buffers.
        vim.api.nvim_create_autocmd("ColorScheme", {
            group = auto_group,
            callback = function()
                hl_cache = {}
                for buf in pairs(tracked) do
                    if vim.api.nvim_buf_is_valid(buf) then M.colorize(buf) end
                end
            end,
        })

        vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
            group = auto_group,
            pattern = { "log.*", "*.log" },
            callback = function(args) M.watch(args.buf) end,
        })

        _G.AnsiColorize = M
    end,
}
