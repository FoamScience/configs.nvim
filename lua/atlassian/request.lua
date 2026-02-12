local M = {}

local error_mod = require("atlassian.error")
local notify = require("atlassian.notify")

-- Counter for unique progress keys across all requests
local request_counter = 0

--- Derive a human-readable progress label from the endpoint and HTTP method.
---@param endpoint string API endpoint path
---@param method string HTTP method (GET, POST, PUT, DELETE)
---@return string
local function get_progress_label(endpoint, method)
    -- Order matters: more specific patterns first
    local patterns = {
        { "/search",          { GET = "Searching" } },
        { "/myself",          { GET = "Connecting" } },
        { "/serverInfo",      { GET = "Connecting" } },
        { "/issueLinkType",   { GET = "Loading link types" } },
        { "/issueLink",       { POST = "Creating link", DELETE = "Deleting link" } },
        { "/transitions",     { GET = "Loading transitions", POST = "Transitioning" } },
        { "/comment",         { GET = "Loading comments", POST = "Adding comment", PUT = "Updating comment", DELETE = "Deleting comment" } },
        { "/assignee",        { PUT = "Assigning" } },
        { "/issue/createmeta", { GET = "Loading metadata" } },
        { "/issue",           { GET = "Loading issue", POST = "Creating issue", PUT = "Updating issue" } },
        { "/project",         { GET = "Loading projects" } },
        { "/user",            { GET = "Loading users" } },
        { "/spaces",          { GET = "Loading spaces" } },
        { "/pages",           { GET = "Loading page", POST = "Creating page", PUT = "Updating page", DELETE = "Deleting page" } },
    }

    for _, entry in ipairs(patterns) do
        local pattern, labels = entry[1], entry[2]
        if endpoint:find(pattern, 1, true) then
            if labels[method] then
                return labels[method]
            end
        end
    end

    -- Fallback
    local fallback = { GET = "Loading...", POST = "Creating...", PUT = "Updating...", DELETE = "Deleting..." }
    return fallback[method] or "Working..."
end

---@class AtlassianAuthConfig
---@field url string Instance URL
---@field email string User email
---@field token string API token

---@param auth AtlassianAuthConfig
---@return string
function M.get_auth_header(auth)
    local credentials = auth.email .. ":" .. auth.token
    return "Basic " .. vim.base64.encode(credentials)
end

---@param url string
---@return string
function M.normalize_url(url)
    if not url:match("^https?://") then
        url = "https://" .. url
    end
    return url:gsub("/$", "")
end

---@class RequestOptions
---@field auth AtlassianAuthConfig
---@field base_url string
---@field endpoint string
---@field method string
---@field body? table
---@field callback fun(err: AtlassianError|nil, data: table|nil)

---@param opts RequestOptions
function M.request(opts)
    local url = M.normalize_url(opts.base_url) .. opts.endpoint

    local args = {
        "curl",
        "-s",
        "-L",
        "-w", "\n%{http_code}",
        "-X", opts.method,
        "-H", "Authorization: " .. M.get_auth_header(opts.auth),
        "-H", "Content-Type: application/json",
        "-H", "Accept: application/json",
    }

    if opts.body then
        table.insert(args, "-d")
        table.insert(args, vim.json.encode(opts.body))
    end

    table.insert(args, url)

    vim.system(args, { text = true }, function(result)
        vim.schedule(function()
            if result.code ~= 0 then
                opts.callback(
                    error_mod.network("Network error: " .. (result.stderr or "Unknown error"), result.stderr),
                    nil
                )
                return
            end

            local output = result.stdout or ""
            local lines = vim.split(output, "\n")
            local http_code = tonumber(lines[#lines]) or 0
            table.remove(lines)
            local response_body = table.concat(lines, "\n")

            if http_code >= 400 then
                local err_msg = "HTTP " .. http_code
                local ok, err_data = pcall(vim.json.decode, response_body)
                if ok and err_data then
                    local parts = {}
                    -- Jira classic: { errorMessages: [...], errors: { field: msg } }
                    if err_data.errorMessages and type(err_data.errorMessages) == "table" and #err_data.errorMessages > 0 then
                        for _, m in ipairs(err_data.errorMessages) do
                            table.insert(parts, type(m) == "string" and m or vim.inspect(m))
                        end
                    end
                    if err_data.errors and type(err_data.errors) == "table" then
                        for field, msg in pairs(err_data.errors) do
                            local msg_str = type(msg) == "string" and msg or vim.inspect(msg)
                            table.insert(parts, field .. ": " .. msg_str)
                        end
                    end
                    -- Jira Cloud next-gen: { status, title, detail, errors[] }
                    if err_data.title and type(err_data.title) == "string" then
                        table.insert(parts, err_data.title)
                    end
                    if err_data.detail and type(err_data.detail) == "string" then
                        table.insert(parts, err_data.detail)
                    end
                    -- Jira Cloud: nested errors array with field/message pairs
                    if type(err_data.errors) == "table" and err_data.errors[1] then
                        for _, e in ipairs(err_data.errors) do
                            if type(e) == "table" and e.message then
                                local prefix = e.field and (e.field .. ": ") or ""
                                table.insert(parts, prefix .. e.message)
                            end
                        end
                    end
                    -- Confluence-style: { message: "..." }
                    if err_data.message and type(err_data.message) == "string" then
                        table.insert(parts, err_data.message)
                    end
                    if #parts > 0 then
                        local parts_text = table.concat(parts, "; ")
                        err_msg = err_msg .. ": " .. parts_text
                        -- Include raw response when parsed error lacks detail
                        if #parts_text < 100 then
                            err_msg = err_msg .. "\n" .. response_body:sub(1, 500)
                        end
                    else
                        -- Unknown error structure — include truncated raw response
                        err_msg = err_msg .. ": " .. response_body:sub(1, 500)
                    end
                else
                    -- Not JSON — include truncated raw body
                    err_msg = err_msg .. ": " .. response_body:sub(1, 300)
                end
                opts.callback(
                    error_mod.http(http_code, err_msg, response_body),
                    nil
                )
                return
            end

            if response_body == "" then
                opts.callback(nil, {})
                return
            end

            local ok, data = pcall(vim.json.decode, response_body)
            if not ok then
                opts.callback(
                    error_mod.parse("Failed to parse response: " .. response_body:sub(1, 200), response_body),
                    nil
                )
                return
            end

            opts.callback(nil, data)
        end)
    end)
end

---@param url string Full URL to download
---@param output_path string Local file path to save to
---@param auth AtlassianAuthConfig|nil Auth config (nil for unauthenticated)
---@param cb fun(err: string|nil, path: string|nil)
function M.download_file(url, output_path, auth, cb)
    local args = { "curl", "-s", "-L", "-o", output_path }

    if auth then
        table.insert(args, "-H")
        table.insert(args, "Authorization: " .. M.get_auth_header(auth))
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

---@class UploadFileOptions
---@field url string Full upload URL
---@field auth AtlassianAuthConfig
---@field file_path string Local file path
---@field callback fun(err: AtlassianError|nil, data: table|nil)

---@param opts UploadFileOptions
function M.upload_file(opts)
    local args = {
        "curl", "-s", "-L",
        "-w", "\n%{http_code}",
        "-X", "POST",
        "-H", "Authorization: " .. M.get_auth_header(opts.auth),
        "-H", "X-Atlassian-Token: no-check",
        "-F", "file=@" .. opts.file_path,
        opts.url,
    }

    vim.system(args, { text = true }, function(result)
        vim.schedule(function()
            if result.code ~= 0 then
                opts.callback(
                    error_mod.network("Network error: " .. (result.stderr or "Unknown error"), result.stderr),
                    nil
                )
                return
            end

            local output = result.stdout or ""
            local lines = vim.split(output, "\n")
            local http_code = tonumber(lines[#lines]) or 0
            table.remove(lines)
            local response_body = table.concat(lines, "\n")

            if http_code >= 400 then
                local err_msg = "HTTP " .. http_code .. ": " .. response_body:sub(1, 300)
                opts.callback(error_mod.http(http_code, err_msg, response_body), nil)
                return
            end

            if response_body == "" then
                opts.callback(nil, {})
                return
            end

            local ok, data = pcall(vim.json.decode, response_body)
            if not ok then
                opts.callback(
                    error_mod.parse("Failed to parse response: " .. response_body:sub(1, 200), response_body),
                    nil
                )
                return
            end

            opts.callback(nil, data)
        end)
    end)
end

---@class ApiClientConfig
---@field auth AtlassianAuthConfig
---@field api_path string API path prefix (e.g., "/rest/api/3" or "/wiki/api/v2")

---@param config ApiClientConfig
---@return table Client with request method
function M.create_client(config)
    local client = {
        is_online = true,
    }

    ---@param endpoint string
    ---@param method string
    ---@param body? table
    ---@param callback fun(err: AtlassianError|nil, data: table|nil)
    function client.request(endpoint, method, body, callback)
        -- Automatic fidget progress for every API request
        request_counter = request_counter + 1
        local progress_key = "atlassian_req_" .. request_counter
        local title = config.api_path:find("/wiki", 1, true) and "Confluence" or "Jira"
        local label = get_progress_label(endpoint, method)
        notify.progress_start(progress_key, title, label)

        M.request({
            auth = config.auth,
            base_url = config.auth.url .. config.api_path,
            endpoint = endpoint,
            method = method,
            body = body,
            callback = function(err, data)
                client.is_online = err == nil or not error_mod.is_network_error(err)
                if err then
                    notify.progress_finish(progress_key, "Failed")
                else
                    notify.progress_finish(progress_key)
                end
                callback(err, data)
            end,
        })
    end

    return client
end

return M
