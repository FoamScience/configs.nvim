-- CSF math rendering: convert LaTeX to unicode via latex2text
-- Attaches to CSF buffers via FileType autocmd
local M = {}

local ns = vim.api.nvim_create_namespace("csf_math")

-- Cache converted LaTeX → unicode
local cache = {}

-- latex2text binary availability (nil = unchecked, true/false after check)
local latex2text_ok = nil

--- Check if latex2text binary is available (cached after first check)
---@return boolean
local function has_latex2text()
    if latex2text_ok ~= nil then return latex2text_ok end
    latex2text_ok = vim.fn.executable("latex2text") == 1
    return latex2text_ok
end

--- Convert LaTeX to unicode using latex2text binary
---@param latex string Raw LaTeX
---@param callback fun(result: string)
local function latex_to_unicode(latex, callback)
    vim.system(
        { "latex2text", "--code", latex },
        { text = true },
        function(result)
            if result.code == 0 and result.stdout then
                local text = vim.trim(result.stdout)
                vim.schedule(function() callback(text) end)
            end
        end
    )
end

--- Convert LaTeX to unicode (async with cache)
--- Does nothing if latex2text is not available.
---@param latex string
---@param callback fun(result: string)
function M.convert(latex, callback)
    if not has_latex2text() then return end
    if cache[latex] then
        callback(cache[latex])
        return
    end
    latex_to_unicode(latex, function(result)
        cache[latex] = result
        callback(result)
    end)
end

--- Find math macros in buffer and return their locations + content.
--- Works across multi-line macros by joining the full buffer and mapping
--- byte offsets back to (row, col) positions.
---@param buf number
---@return table[] List of {row, col_start, latex, type}
local function find_math_ranges(buf)
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local full_text = table.concat(lines, "\n")
    local ranges = {}

    -- Precompute byte offset → (row, col) lookup
    -- line_offsets[i] = byte offset where line i (0-indexed) starts
    local line_offsets = {}
    local offset = 0
    for i, line in ipairs(lines) do
        line_offsets[i - 1] = offset
        offset = offset + #line + 1 -- +1 for \n
    end

    ---@param byte_pos number 0-indexed byte position in full_text
    ---@return number row, number col
    local function byte_to_rowcol(byte_pos)
        for row = #lines - 1, 0, -1 do
            if byte_pos >= line_offsets[row] then
                return row, byte_pos - line_offsets[row]
            end
        end
        return 0, byte_pos
    end

    -- Block math: <ac:structured-macro ac:name="mathblock">...<![CDATA[LATEX]]>...</ac:structured-macro>
    for cdata_start, latex, cdata_end in full_text:gmatch('ac:name="mathblock".-<!%[CDATA%[()(.-)()%]%]>') do
        local row, col = byte_to_rowcol(cdata_start - 1)
        table.insert(ranges, {
            row = row,
            col_start = col,
            col_end = col + #latex,
            latex = latex,
            type = "block",
        })
    end

    -- Inline math: <ac:structured-macro ac:name="mathinline">...<ac:parameter ac:name="body">LATEX</ac:parameter>
    for body_start, latex, body_end in full_text:gmatch('ac:name="mathinline".-ac:name="body">()(.-)()</ac:parameter>') do
        local row, col = byte_to_rowcol(body_start - 1)
        table.insert(ranges, {
            row = row,
            col_start = col,
            col_end = col + #latex,
            latex = latex,
            type = "inline",
        })
    end

    return ranges
end

--- Render math in buffer using conceal + inline virtual text.
--- Conceals the raw LaTeX range and places unicode as inline virt_text,
--- so the replacement width is independent of the original text width.
--- Only active in normal mode (conceal is off in insert mode).
---@param buf number
function M.render(buf)
    if not has_latex2text() then return end
    if not vim.api.nvim_buf_is_valid(buf) then return end
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

    local ranges = find_math_ranges(buf)
    if #ranges == 0 then return end

    for _, r in ipairs(ranges) do
        M.convert(r.latex, function(unicode)
            if not vim.api.nvim_buf_is_valid(buf) then return end
            -- Conceal the LaTeX range to empty and insert unicode inline
            pcall(vim.api.nvim_buf_set_extmark, buf, ns, r.row, r.col_start, {
                end_row = r.row,
                end_col = r.col_end,
                conceal = "",
                virt_text = { { unicode, "@markup.math" } },
                virt_text_pos = "inline",
                priority = 110,
            })
        end)
    end
end

--- Attach math rendering to a buffer
---@param buf number
function M.setup(buf)
    if not has_latex2text() then return end

    local group = vim.api.nvim_create_augroup("csf_math_" .. buf, { clear = true })

    -- Render in normal mode only (conceal is typically off in insert mode)
    vim.api.nvim_create_autocmd({ "BufWinEnter", "TextChanged" }, {
        group = group,
        buffer = buf,
        callback = function()
            if M._timer then
                M._timer:stop()
            end
            M._timer = vim.defer_fn(function()
                M.render(buf)
            end, 150)
        end,
    })

    -- Clear overlays on insert enter so user sees raw LaTeX
    vim.api.nvim_create_autocmd("InsertEnter", {
        group = group,
        buffer = buf,
        callback = function()
            if M._timer then M._timer:stop() end
            vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
        end,
    })

    -- Re-render when leaving insert mode
    vim.api.nvim_create_autocmd("InsertLeave", {
        group = group,
        buffer = buf,
        callback = function()
            M.render(buf)
        end,
    })

    vim.api.nvim_create_autocmd("BufDelete", {
        group = group,
        buffer = buf,
        callback = function()
            if M._timer then M._timer:stop() end
        end,
    })

    vim.schedule(function() M.render(buf) end)
end

return M
