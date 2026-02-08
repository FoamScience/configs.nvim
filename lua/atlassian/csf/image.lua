-- CSF image display via snacks.image
-- Fetches and caches Confluence/Jira attachments, shows float on hover
local M = {}

local request = require("atlassian.request")

--- Current hover state per buffer
---@type { buf: number, win: number, placement: table, src: string }|nil
local hover = nil

---@param key string Cache key
---@return string|nil path Cached image path
function M.get_cached(key)
    local cache_dir = M.get_cache_dir()
    local path = cache_dir .. "/" .. key
    if vim.fn.filereadable(path) == 1 then
        return path
    end
    return nil
end

---@return string
function M.get_cache_dir()
    local ok, cc = pcall(require, "confluence-interface.config")
    if ok and cc.options and cc.options.image and cc.options.image.cache_dir then
        return cc.options.image.cache_dir
    end
    local ok2, jc = pcall(require, "jira-interface.config")
    if ok2 and jc.options and jc.options.image and jc.options.image.cache_dir then
        return jc.options.image.cache_dir
    end
    return vim.fn.stdpath("cache") .. "/atlassian/images"
end

---@return number Max file size in bytes
function M.get_max_file_size()
    local ok, cc = pcall(require, "confluence-interface.config")
    if ok and cc.options and cc.options.image and cc.options.image.max_file_size then
        return cc.options.image.max_file_size
    end
    return 2 * 1024 * 1024 -- 2MB default
end

---@param url string
---@param auth table|nil Auth config
---@param cb fun(err: string|nil, path: string|nil)
---@param opts? { ext?: string }
function M.download_file(url, auth, cb, opts)
    local ext = (opts and opts.ext) or url:match("%.(%w+)[%?#]?") or ""
    local hash = vim.fn.sha256(url):sub(1, 16)
    local cache_key = ext ~= "" and (hash .. "." .. ext) or hash

    local cached = M.get_cached(cache_key)
    if cached then
        cb(nil, cached)
        return
    end

    local cache_dir = M.get_cache_dir()
    vim.fn.mkdir(cache_dir, "p")
    local output_path = cache_dir .. "/" .. cache_key

    local args = { "curl", "-s", "-L", "-o", output_path }
    if auth then
        table.insert(args, "-H")
        table.insert(args, "Authorization: " .. request.get_auth_header(auth))
    end
    table.insert(args, url)

    vim.system(args, { text = false }, function(result)
        vim.schedule(function()
            if result.code ~= 0 then
                cb("Download failed: " .. (result.stderr or ""), nil)
                return
            end
            if vim.fn.filereadable(output_path) == 1 then
                cb(nil, output_path)
            else
                cb("File not saved", nil)
            end
        end)
    end)
end

---@param page_id string
---@param filename string
---@param cb fun(err: string|nil, path: string|nil)
function M.fetch_confluence_attachment(page_id, filename, cb)
    local ok, cc = pcall(require, "confluence-interface.config")
    if not ok then
        cb("Confluence not configured", nil)
        return
    end

    local base_url = request.normalize_url(cc.options.auth.url)
    request.request({
        auth = cc.options.auth,
        base_url = base_url,
        endpoint = "/wiki/rest/api/content/" .. page_id .. "/child/attachment"
            .. "?filename=" .. vim.uri_encode(filename),
        method = "GET",
        callback = function(err, data)
            if err then
                cb(tostring(err), nil)
                return
            end
            if data and data.results and data.results[1] then
                local att = data.results[1]
                local download_url = base_url .. "/wiki" .. att._links.download
                if att.extensions and att.extensions.fileSize then
                    local size = tonumber(att.extensions.fileSize) or 0
                    if size > M.get_max_file_size() then
                        cb(nil, nil)
                        return
                    end
                end
                local ext = filename:match("%.(%w+)$") or ""
                M.download_file(download_url, cc.options.auth, cb, { ext = ext })
            else
                cb("Attachment not found: " .. filename, nil)
            end
        end,
    })
end

--- Fetch Jira attachment using stored attachment data from buffer variable
---@param buf number
---@param id_or_name string Attachment ID or filename
---@param cb fun(err: string|nil, path: string|nil)
function M.fetch_jira_attachment(buf, id_or_name, cb)
    local ok, jc = pcall(require, "jira-interface.config")
    if not ok then
        cb("Jira not configured", nil)
        return
    end

    local attachments = vim.b[buf] and vim.b[buf].atlassian_attachments
    if attachments then
        for _, att in ipairs(attachments) do
            if att.id == id_or_name or att.filename == id_or_name then
                if att.size and att.size > M.get_max_file_size() then
                    cb(nil, nil)
                    return
                end
                local ext = (att.filename or ""):match("%.(%w+)$") or ""
                M.download_file(att.url, jc.options.auth, cb, { ext = ext })
                return
            end
        end
    end

    local base_url = request.normalize_url(jc.options.auth.url)
    local download_url = base_url .. "/rest/api/3/attachment/content/" .. id_or_name
    M.download_file(download_url, jc.options.auth, cb)
end

---@param url string Direct URL for ri:url images
---@param cb fun(err: string|nil, path: string|nil)
function M.fetch_url(url, cb)
    M.download_file(url, nil, cb)
end

--- Get buffer metadata and auth config
---@param buf number
---@return table|nil meta, table|nil auth
local function get_buf_context(buf)
    local first_line = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] or ""
    local csf_mod = require("atlassian.csf")
    local meta = csf_mod.parse_metadata(first_line)
    if not meta then return nil, nil end

    if meta.type == "confluence" then
        local ok, cc = pcall(require, "confluence-interface.config")
        if ok then return meta, cc.options.auth end
    elseif meta.type == "jira" then
        local ok, jc = pcall(require, "jira-interface.config")
        if ok then return meta, jc.options.auth end
    end
    return meta, nil
end

local IMAGE_EXTS = { png = true, jpg = true, jpeg = true, gif = true, bmp = true, webp = true, svg = true, tiff = true }

--- Check if a filename has an image extension
---@param name string
---@return boolean
local function is_image_filename(name)
    local ext = name:lower():match("%.(%w+)$")
    return ext and IMAGE_EXTS[ext] or false
end

--- Fetch an image reference, dispatching to the right backend
---@param buf number
---@param ref { filename?: string, url?: string, auth_url?: string }
---@param meta table Buffer metadata
---@param cb fun(err: string|nil, path: string|nil)
local function fetch_image_ref(buf, ref, meta, cb)
    if ref.auth_url then
        local _, auth = get_buf_context(buf)
        local ext = ref.filename and ref.filename:match("%.(%w+)$") or ""
        M.download_file(ref.auth_url, auth, cb, { ext = ext })
    elseif ref.url then
        M.fetch_url(ref.url, cb)
    elseif ref.filename and meta.type == "confluence" and meta.id then
        M.fetch_confluence_attachment(meta.id, ref.filename, cb)
    elseif ref.filename and meta.type == "jira" then
        M.fetch_jira_attachment(buf, ref.filename, cb)
    else
        cb("Cannot resolve image reference", nil)
    end
end

--- Parse image reference from a buffer line
---@param line string
---@return table|nil ref
local function parse_image_ref(line)
    -- <ac:image> with ri:attachment
    local filename = line:match('ri:filename="([^"]+)"')
    if filename then
        return { filename = filename }
    end
    -- <ac:image> with ri:url
    local url = line:match('ri:value="([^"]+)"')
    if url and line:match("ac:image") then
        return { url = url }
    end
    -- <a href="...">image_filename.png</a> (attachment links)
    local href, link_text = line:match('<a href="([^"]+)">([^<]+)</a>')
    if href and link_text and is_image_filename(link_text) then
        return { auth_url = href, filename = link_text }
    end
    return nil
end

--- Close current hover float
function M.hover_close()
    if hover then
        if hover.placement then
            pcall(function() hover.placement:close() end)
        end
        pcall(vim.api.nvim_win_close, hover.win, true)
        hover = nil
    end
end

--- Show image hover float in top-right corner (like snacks.image for markdown)
---@param path string Local cached image path
---@param source_buf number The document buffer
function M.show_hover(path, source_buf)
    local ok, Snacks = pcall(require, "snacks")
    if not ok or not Snacks.image then return end

    -- If already showing this image, keep it
    if hover and hover.src == path then return end

    M.hover_close()

    local float_buf = vim.api.nvim_create_buf(false, true)
    vim.bo[float_buf].bufhidden = "wipe"

    local max_w = math.min(80, math.floor(vim.o.columns * 0.4))
    local max_h = math.min(40, math.floor(vim.o.lines * 0.5))

    -- Fill with empty lines for image space
    local lines = {}
    for _ = 1, max_h do
        table.insert(lines, "")
    end
    vim.api.nvim_buf_set_lines(float_buf, 0, -1, false, lines)

    -- Position: top-right corner of the editor
    local win = vim.api.nvim_open_win(float_buf, false, {
        relative = "editor",
        width = max_w,
        height = max_h,
        row = 1,
        col = vim.o.columns - max_w - 1,
        style = "minimal",
        border = "rounded",
        focusable = false,
        zindex = 50,
    })

    local placement = Snacks.image.placement.new(float_buf, path, {
        pos = { 1, 0 },
        inline = true,
        max_width = max_w,
        max_height = max_h,
    })

    hover = {
        buf = source_buf,
        win = win,
        placement = placement,
        src = path,
    }
end

--- Attach hover autocmds to a CSF buffer
---@param buf number
function M.setup_hover(buf)
    local group = vim.api.nvim_create_augroup("csf_image_hover_" .. buf, { clear = true })

    vim.api.nvim_create_autocmd("CursorHold", {
        group = group,
        buffer = buf,
        callback = function()
            if vim.fn.mode() ~= "n" then return end
            local row = vim.api.nvim_win_get_cursor(0)[1]
            local line = vim.api.nvim_buf_get_lines(buf, row - 1, row, false)[1] or ""
            local ref = parse_image_ref(line)
            if not ref then
                M.hover_close()
                return
            end

            local meta = get_buf_context(buf)
            if not meta then return end

            fetch_image_ref(buf, ref, meta, function(err, path)
                if err or not path then return end
                if not vim.api.nvim_buf_is_valid(buf) then return end
                -- Only show if cursor is still on same line
                local cur_row = vim.api.nvim_win_get_cursor(0)[1]
                if cur_row == row then
                    M.show_hover(path, buf)
                end
            end)
        end,
    })

    vim.api.nvim_create_autocmd("CursorMoved", {
        group = group,
        buffer = buf,
        callback = function()
            if not hover or hover.buf ~= buf then return end
            local row = vim.api.nvim_win_get_cursor(0)[1]
            local line = vim.api.nvim_buf_get_lines(buf, row - 1, row, false)[1] or ""
            local ref = parse_image_ref(line)
            if not ref then
                M.hover_close()
            end
        end,
    })

    vim.api.nvim_create_autocmd("BufLeave", {
        group = group,
        buffer = buf,
        callback = function()
            M.hover_close()
        end,
    })
end

--- Show image at cursor (explicit K keymap trigger)
---@param buf number
function M.show_at_cursor(buf)
    local row = vim.api.nvim_win_get_cursor(0)[1]
    local line = vim.api.nvim_buf_get_lines(buf, row - 1, row, false)[1] or ""
    local ref = parse_image_ref(line)

    if not ref then
        vim.notify("No image found at cursor", vim.log.levels.INFO)
        return
    end

    local meta = get_buf_context(buf)
    if not meta then
        vim.notify("Cannot determine buffer context for image", vim.log.levels.WARN)
        return
    end

    vim.notify("Fetching image...", vim.log.levels.INFO)
    fetch_image_ref(buf, ref, meta, function(err, path)
        if err then
            vim.notify("Image error: " .. err, vim.log.levels.ERROR)
        elseif not path then
            vim.notify("[Image too large, exceeds size limit]", vim.log.levels.WARN)
        else
            M.show_hover(path, buf)
        end
    end)
end

return M
