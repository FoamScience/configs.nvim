local M = {}

---@class AtlassianDisplayConfig
---@field mode string Display mode: "float", "vsplit", "split", "tab"
---@field width number|string Width for float/vsplit
---@field height number|string Height for float/split
---@field border string Border style for floats
---@field wrap boolean Enable line wrapping
---@field linebreak boolean Break at word boundaries
---@field conceallevel number Conceal level for markdown
---@field cursorline boolean Highlight current line

---@param value number|string
---@param total number
---@return number
function M.parse_dimension(value, total)
    if type(value) == "number" then
        return value
    elseif type(value) == "string" and value:match("%%$") then
        local num_str = value:gsub("%%$", "")
        local pct = tonumber(num_str) or 80
        return math.floor(total * pct / 100)
    end
    return math.floor(total * 0.8)
end

---@param buf number
---@param win number
---@param display? AtlassianDisplayConfig
function M.apply_window_options(buf, win, display)
    display = display or {}
    vim.wo[win].wrap = display.wrap ~= false
    vim.wo[win].linebreak = display.linebreak ~= false
    vim.wo[win].conceallevel = display.conceallevel or 2
    vim.wo[win].cursorline = display.cursorline ~= false
end

---@class CreateWindowOpts
---@field width? number Override width
---@field height? number Override height
---@field title? string Window title
---@field bufname? string Buffer name (e.g., "jira://PROJ-123")
---@field display? AtlassianDisplayConfig Display configuration
---@field filetype? string Custom filetype for the buffer (default: "markdown")

---@param opts CreateWindowOpts
---@return number, number Buffer and window IDs
function M.create_window(opts)
    opts = opts or {}
    local display = opts.display or {}
    local mode = display.mode or "float"

    local buf = vim.api.nvim_create_buf(true, true)
    vim.bo[buf].bufhidden = "hide"
    vim.bo[buf].filetype = opts.filetype or "markdown"
    if opts.bufname then
        vim.api.nvim_buf_set_name(buf, opts.bufname)
    end

    local win

    if mode == "float" then
        local width = opts.width or M.parse_dimension(display.width, vim.o.columns)
        local height = opts.height or M.parse_dimension(display.height, vim.o.lines)

        win = vim.api.nvim_open_win(buf, true, {
            relative = "editor",
            width = width,
            height = height,
            col = math.floor((vim.o.columns - width) / 2),
            row = math.floor((vim.o.lines - height) / 2),
            style = "minimal",
            border = display.border or "rounded",
            title = opts.title and (" " .. opts.title .. " ") or nil,
            title_pos = opts.title and "center" or nil,
        })
    elseif mode == "vsplit" then
        local width = opts.width or M.parse_dimension(display.width, vim.o.columns)
        vim.cmd("vsplit")
        win = vim.api.nvim_get_current_win()
        vim.api.nvim_win_set_buf(win, buf)
        vim.api.nvim_win_set_width(win, width)
    elseif mode == "split" then
        local height = opts.height or M.parse_dimension(display.height, vim.o.lines)
        vim.cmd("split")
        win = vim.api.nvim_get_current_win()
        vim.api.nvim_win_set_buf(win, buf)
        vim.api.nvim_win_set_height(win, height)
    elseif mode == "tab" then
        vim.cmd("tabnew")
        win = vim.api.nvim_get_current_win()
        vim.api.nvim_win_set_buf(win, buf)
    elseif mode == "buffer" then
        win = vim.api.nvim_get_current_win()
        vim.api.nvim_win_set_buf(win, buf)
    else
        -- Fallback to float
        local width = opts.width or M.parse_dimension(display.width, vim.o.columns)
        local height = opts.height or M.parse_dimension(display.height, vim.o.lines)

        win = vim.api.nvim_open_win(buf, true, {
            relative = "editor",
            width = width,
            height = height,
            col = math.floor((vim.o.columns - width) / 2),
            row = math.floor((vim.o.lines - height) / 2),
            style = "minimal",
            border = display.border or "rounded",
            title = opts.title and (" " .. opts.title .. " ") or nil,
            title_pos = opts.title and "center" or nil,
        })
    end

    M.apply_window_options(buf, win, display)

    return buf, win
end

---@param str string
---@param width number
---@return string
function M.pad_right(str, width)
    str = str or ""
    if #str >= width then
        return str:sub(1, width)
    end
    return str .. string.rep(" ", width - #str)
end

---@param str string
---@param width number
---@return string
function M.truncate(str, width)
    str = str or ""
    if #str <= width then
        return str
    end
    return str:sub(1, width - 1) .. "…"
end

return M
