local M = {}

local config = require("confluence-interface.config")
local types = require("confluence-interface.types")
local atlassian_request = require("atlassian.request")

---@type boolean
M.is_online = true

-- Create API client for v2 API
local function get_client_v2()
    return atlassian_request.create_client({
        auth = config.options.auth,
        api_path = "/wiki/api/v2",
    })
end

-- Create API client for v1 API (needed for CQL search)
local function get_client_v1()
    return atlassian_request.create_client({
        auth = config.options.auth,
        api_path = "/wiki/rest/api",
    })
end

---@param endpoint string
---@param method string
---@param body? table
---@param callback fun(err: string|nil, data: table|nil)
---@param use_v1? boolean Use v1 API instead of v2
function M.request(endpoint, method, body, callback, use_v1)
    local client = use_v1 and get_client_v1() or get_client_v2()
    client.request(endpoint, method, body, function(err, data)
        M.is_online = client.is_online
        callback(err, data)
    end)
end

---@param callback fun(online: boolean)
function M.check_connectivity(callback)
    M.request("/spaces?limit=1", "GET", nil, function(err, _)
        M.is_online = err == nil
        callback(M.is_online)
    end)
end

---@param callback fun(err: string|nil, spaces: ConfluenceSpace[]|nil)
function M.get_spaces(callback)
    local max_results = config.options.max_results or 100
    M.request("/spaces?limit=" .. max_results, "GET", nil, function(err, data)
        if err then
            callback(err, nil)
            return
        end

        local spaces = {}
        for _, raw in ipairs(data.results or {}) do
            table.insert(spaces, types.parse_space(raw))
        end
        callback(nil, spaces)
    end)
end

---@param space_key string Space key (e.g., "KBSoftware") or numeric ID
---@param callback fun(err: string|nil, space: ConfluenceSpace|nil)
function M.get_space(space_key, callback)
    -- If it's a numeric ID, fetch directly
    if space_key:match("^%d+$") then
        M.request("/spaces/" .. space_key, "GET", nil, function(err, data)
            if err then
                callback(err, nil)
                return
            end
            callback(nil, types.parse_space(data))
        end)
        return
    end

    -- Otherwise, search for space by key
    M.request("/spaces?keys=" .. vim.uri_encode(space_key) .. "&limit=1", "GET", nil, function(err, data)
        if err then
            callback(err, nil)
            return
        end
        if data.results and #data.results > 0 then
            callback(nil, types.parse_space(data.results[1]))
        else
            callback("Space not found: " .. space_key, nil)
        end
    end)
end

---@param space_key? string
---@param query? string
---@param callback fun(err: string|nil, pages: ConfluencePage[]|nil)
function M.get_pages(space_key, query, callback)
    local max_results = config.options.max_results or 100
    local endpoint = "/pages?limit=" .. max_results .. "&sort=-modified-date"

    if space_key and space_key ~= "" then
        endpoint = endpoint .. "&space-id=" .. space_key
    end

    -- If we have a space key, we need to get the space ID first
    if space_key and space_key ~= "" and not space_key:match("^%d+$") then
        M.get_space(space_key, function(space_err, space)
            if space_err then
                callback(space_err, nil)
                return
            end
            if space then
                M.get_pages(space.id, query, callback)
            else
                callback("Space not found", nil)
            end
        end)
        return
    end

    M.request(endpoint, "GET", nil, function(err, data)
        if err then
            callback(err, nil)
            return
        end

        local pages = {}
        for _, raw in ipairs(data.results or {}) do
            table.insert(pages, types.parse_page(raw))
        end

        -- Client-side filter if query provided
        if query and query ~= "" then
            local filtered = {}
            local q_lower = query:lower()
            for _, page in ipairs(pages) do
                if page.title:lower():find(q_lower, 1, true) then
                    table.insert(filtered, page)
                end
            end
            pages = filtered
        end

        callback(nil, pages)
    end)
end

---@param query string
---@param space_key? string
---@param callback fun(err: string|nil, pages: ConfluencePage[]|nil)
function M.search_pages(query, space_key, callback)
    -- Try CQL title search first, fall back to client-side filtering on error
    M.search_pages_cql(query, space_key, function(err, pages)
        if err then
            M.get_pages(space_key, query, callback)
            return
        end
        callback(nil, pages)
    end)
end

---@param cql string Raw CQL query
---@param callback fun(err: string|nil, pages: ConfluencePage[]|nil)
function M.search_raw_cql(cql, callback)
    local max_results = config.options.max_results or 100
    local endpoint = "/content/search?cql=" .. vim.uri_encode(cql) .. "&limit=" .. max_results
    M.request(endpoint, "GET", nil, function(err, data)
        if err then
            callback(err, nil)
            return
        end

        local pages = {}
        for _, raw in ipairs(data.results or {}) do
            table.insert(pages, types.parse_page_v1(raw))
        end
        callback(nil, pages)
    end, true)
end

---@param username? string Username to search for (defaults to current user)
---@param space_key? string
---@param callback fun(err: string|nil, pages: ConfluencePage[]|nil)
function M.search_mentions(username, space_key, callback)
    local max_results = config.options.max_results or 100

    -- If no username, get current user first
    if not username or username == "" then
        M.get_current_user(function(err, user)
            if err then
                callback(err, nil)
                return
            end
            local display_name = user.displayName or user.username or ""
            M.search_mentions(display_name, space_key, callback)
        end)
        return
    end

    -- Use CQL to search for mentions in page content
    local cql = string.format('type=page AND text~"@%s"', username:gsub('"', '\\"'))
    if space_key and space_key ~= "" then
        cql = cql .. string.format(' AND space.key="%s"', space_key)
    end
    cql = cql .. " ORDER BY lastmodified DESC"

    local endpoint = "/content/search?cql=" .. vim.uri_encode(cql) .. "&limit=" .. max_results
    M.request(endpoint, "GET", nil, function(err, data)
        if err then
            callback(err, nil)
            return
        end

        local pages = {}
        for _, raw in ipairs(data.results or {}) do
            table.insert(pages, types.parse_page_v1(raw))
        end
        callback(nil, pages)
    end, true) -- Use v1 API for CQL search
end

---@param query string
---@param space_key? string
---@param callback fun(err: string|nil, pages: ConfluencePage[]|nil)
function M.search_pages_cql(query, space_key, callback)
    local max_results = config.options.max_results or 100
    -- Use CQL (Confluence Query Language) - may fail if service is overloaded
    local cql = string.format('type=page AND title~"%s"', query:gsub('"', '\\"'))
    if space_key and space_key ~= "" then
        cql = cql .. string.format(' AND space.key="%s"', space_key)
    end

    local endpoint = "/content/search?cql=" .. vim.uri_encode(cql) .. "&limit=" .. max_results
    M.request(endpoint, "GET", nil, function(err, data)
        if err then
            callback(err, nil)
            return
        end

        local pages = {}
        for _, raw in ipairs(data.results or {}) do
            table.insert(pages, types.parse_page_v1(raw))
        end
        callback(nil, pages)
    end, true) -- Use v1 API for CQL search
end

---@param page_id string
---@param callback fun(err: string|nil, page: ConfluencePage|nil)
function M.get_page(page_id, callback)
    M.request("/pages/" .. page_id .. "?body-format=storage", "GET", nil, function(err, data)
        if err then
            callback(err, nil)
            return
        end
        callback(nil, types.parse_page(data))
    end)
end

---@param space_id string
---@param title string
---@param body string Storage format HTML
---@param parent_id? string
---@param callback fun(err: string|nil, page: ConfluencePage|nil)
function M.create_page(space_id, title, body, parent_id, callback)
    local payload = {
        spaceId = space_id,
        status = "current",
        title = title,
        body = {
            representation = "storage",
            value = body,
        },
    }

    if parent_id then
        payload.parentId = parent_id
    end

    M.request("/pages", "POST", payload, function(err, data)
        if err then
            callback(err, nil)
            return
        end
        callback(nil, types.parse_page(data))
    end)
end

---@param page_id string
---@param title string
---@param body string Storage format HTML
---@param version number Current version number
---@param callback fun(err: string|nil, page: ConfluencePage|nil)
function M.update_page(page_id, title, body, version, callback)
    local payload = {
        id = page_id,
        status = "current",
        title = title,
        body = {
            representation = "storage",
            value = body,
        },
        version = {
            number = version + 1,
            message = "Updated via confluence-interface",
        },
    }

    M.request("/pages/" .. page_id, "PUT", payload, function(err, data)
        if err then
            callback(err, nil)
            return
        end
        callback(nil, types.parse_page(data))
    end)
end

---@param page_id string
---@param callback fun(err: string|nil)
function M.delete_page(page_id, callback)
    M.request("/pages/" .. page_id, "DELETE", nil, function(err, _)
        callback(err)
    end)
end

---@param page_id string
---@param callback fun(err: string|nil, children: ConfluencePage[]|nil)
function M.get_page_children(page_id, callback)
    M.request("/pages/" .. page_id .. "/children?limit=100", "GET", nil, function(err, data)
        if err then
            callback(err, nil)
            return
        end

        local pages = {}
        for _, raw in ipairs(data.results or {}) do
            table.insert(pages, types.parse_page(raw))
        end
        callback(nil, pages)
    end)
end

---@param callback fun(err: string|nil, user: table|nil)
function M.get_current_user(callback)
    -- Use v1 API for user info
    M.request("/user/current", "GET", nil, function(err, data)
        if err then
            callback(err, nil)
            return
        end
        callback(nil, data)
    end, true)
end

---@param page_id string
---@param file_path string
---@param callback fun(err: AtlassianError|nil, data: table|nil)
function M.upload_attachment(page_id, file_path, callback)
    local auth = config.options.auth
    local base_url = atlassian_request.normalize_url(auth.url)
    atlassian_request.upload_file({
        url = base_url .. "/wiki/rest/api/content/" .. page_id .. "/child/attachment",
        auth = auth,
        file_path = file_path,
        callback = callback,
    })
end

return M
