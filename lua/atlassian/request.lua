local M = {}

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
---@field callback fun(err: string|nil, data: table|nil)

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
                opts.callback("Network error: " .. (result.stderr or "Unknown error"), nil)
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
                    -- Handle Jira-style errors
                    if err_data.errorMessages and type(err_data.errorMessages) == "table" and #err_data.errorMessages > 0 then
                        local msgs = {}
                        for _, m in ipairs(err_data.errorMessages) do
                            table.insert(msgs, type(m) == "string" and m or vim.inspect(m))
                        end
                        err_msg = err_msg .. ": " .. table.concat(msgs, ", ")
                    end
                    if err_data.errors and type(err_data.errors) == "table" then
                        local field_errors = {}
                        for field, msg in pairs(err_data.errors) do
                            local msg_str = type(msg) == "string" and msg or vim.inspect(msg)
                            table.insert(field_errors, field .. ": " .. msg_str)
                        end
                        if #field_errors > 0 then
                            err_msg = err_msg .. " [" .. table.concat(field_errors, "; ") .. "]"
                        end
                    end
                    -- Handle Confluence-style errors
                    if err_data.message then
                        local msg_str = type(err_data.message) == "string" and err_data.message or
                            vim.inspect(err_data.message)
                        err_msg = err_msg .. ": " .. msg_str
                    end
                end
                opts.callback(err_msg, nil)
                return
            end

            if response_body == "" then
                opts.callback(nil, {})
                return
            end

            local ok, data = pcall(vim.json.decode, response_body)
            if not ok then
                opts.callback("Failed to parse response: " .. response_body:sub(1, 200), nil)
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
    ---@param callback fun(err: string|nil, data: table|nil)
    function client.request(endpoint, method, body, callback)
        M.request({
            auth = config.auth,
            base_url = config.auth.url .. config.api_path,
            endpoint = endpoint,
            method = method,
            body = body,
            callback = function(err, data)
                client.is_online = err == nil or not err:match("^Network error")
                callback(err, data)
            end,
        })
    end

    return client
end

return M
