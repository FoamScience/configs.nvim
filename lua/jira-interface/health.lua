local M = {}

local health = vim.health

function M.check()
    health.start("jira-interface")

    -- Check configuration
    local config = require("jira-interface.config")
    local opts = config.options

    -- Check if setup was called
    if not opts or not opts.auth then
        health.error("Plugin not configured", { "Call require('jira-interface').setup()" })
        return
    end

    health.info("Configuration loaded")

    -- Check environment variables
    if opts.auth.url and opts.auth.url ~= "" then
        local url = opts.auth.url
        if not url:match("^https?://") then
            health.warn("JIRA_URL missing protocol: " .. url, { "Will auto-prepend https://" })
            url = "https://" .. url
        end
        health.ok("JIRA_URL: " .. url)
    else
        health.error("JIRA_URL is not set")
    end

    if opts.auth.email and opts.auth.email ~= "" then
        health.ok("JIRA_EMAIL: " .. opts.auth.email)
    else
        health.error("JIRA_EMAIL is not set")
    end

    if opts.auth.token and opts.auth.token ~= "" then
        health.ok("JIRA_API_TOKEN: (set)")
    else
        health.error("JIRA_API_TOKEN is not set")
    end

    if opts.default_project and opts.default_project ~= "" then
        health.ok("JIRA_PROJECT: " .. opts.default_project)
    else
        health.info("JIRA_PROJECT: (not set - will search all projects)")
    end

    -- Check acceptance criteria field
    if opts.acceptance_criteria_field and opts.acceptance_criteria_field ~= "" then
        health.ok("Acceptance criteria field: " .. opts.acceptance_criteria_field)
    else
        health.warn("Acceptance criteria field not configured")
    end

    -- Check curl
    if vim.fn.executable("curl") == 1 then
        health.ok("curl is available")
    else
        health.error("curl is not installed", { "Install curl to use jira-interface" })
        return
    end

    -- Check snacks.nvim
    local has_snacks, _ = pcall(require, "snacks")
    if has_snacks then
        health.ok("snacks.nvim is available")
    else
        health.error("snacks.nvim is not installed", { "Install folke/snacks.nvim for picker functionality" })
    end

    -- Check connectivity (async, but we'll do a sync version for health check)
    health.info("Testing API connectivity...")

    local api = require("jira-interface.api")
    local result = M.check_api_sync()

    if result.connectivity then
        health.ok("API connectivity: OK")
    else
        health.error("API connectivity: FAILED", { result.connectivity_error or "Unknown error" })
    end

    if result.projects then
        if result.project_count > 0 then
            health.ok("Projects API: OK (" .. result.project_count .. " projects found)")
        else
            health.warn("Projects API: OK but 0 projects found", { "Check if your account has access to any projects" })
        end
    else
        health.error("Projects API: FAILED", { result.projects_error or "Unknown error" })
    end

    if result.search then
        health.ok("Search API: OK")
    else
        health.error("Search API: FAILED", { result.search_error or "Unknown error" })
    end

    -- Check cache and queue status
    local cache = require("jira-interface.cache")
    local queue = require("jira-interface.queue")

    local cache_stats = cache.stats()
    health.info(string.format("Cache: %d entries (%.1f KB)", cache_stats.entries, cache_stats.size_bytes / 1024))

    local queue_count = queue.count()
    if queue_count > 0 then
        health.warn(string.format("Offline queue: %d pending edit(s)", queue_count))
    else
        health.ok("Offline queue: empty")
    end
end

-- Synchronous API check for health module
function M.check_api_sync()
    local result = {
        connectivity = false,
        connectivity_error = nil,
        projects = false,
        projects_error = nil,
        project_count = 0,
        search = false,
        search_error = nil,
    }

    local api = require("jira-interface.api")
    local config = require("jira-interface.config")

    -- Skip if not configured
    if not config.options.auth or config.options.auth.token == "" then
        result.connectivity_error = "Not configured"
        result.projects_error = "Not configured"
        result.search_error = "Not configured"
        return result
    end

    -- Use vim.system with wait for synchronous execution
    local function sync_request(endpoint)
        local base_url = config.options.auth.url
        if not base_url:match("^https?://") then
            base_url = "https://" .. base_url
        end
        local url = base_url:gsub("/$", "") .. "/rest/api/3" .. endpoint
        local credentials = config.options.auth.email .. ":" .. config.options.auth.token
        local auth_header = "Basic " .. vim.base64.encode(credentials)

        local args = {
            "curl", "-s", "-L",
            "-w", "\n%{http_code}",
            "-X", "GET",
            "-H", "Authorization: " .. auth_header,
            "-H", "Content-Type: application/json",
            "-H", "Accept: application/json",
            url,
        }

        local proc = vim.system(args, { text = true }):wait()

        if proc.code ~= 0 then
            return nil, "Network error: " .. (proc.stderr or "Unknown")
        end

        local output = proc.stdout or ""
        local lines = vim.split(output, "\n")
        local http_code = tonumber(lines[#lines]) or 0
        table.remove(lines)
        local body = table.concat(lines, "\n")

        if http_code >= 400 then
            return nil, "HTTP " .. http_code
        end

        local ok, data = pcall(vim.json.decode, body)
        if not ok then
            return nil, "Invalid JSON response"
        end

        return data, nil
    end

    -- Test connectivity (try /myself, fallback to /serverInfo)
    local data, err = sync_request("/myself")
    if data then
        result.connectivity = true
    else
        -- /myself might fail on some configs, try serverInfo
        data, err = sync_request("/serverInfo")
        if data then
            result.connectivity = true
            result.connectivity_error = "/myself failed but /serverInfo works"
        else
            result.connectivity_error = err
        end
    end

    -- Test projects
    data, err = sync_request("/project/search?maxResults=10")
    if data then
        result.projects = true
        result.project_count = #(data.values or {})
    else
        result.projects_error = err
    end

    -- Test search
    data, err = sync_request("/search/jql?jql=assignee=currentUser()&maxResults=1")
    if data then
        result.search = true
    else
        result.search_error = err
    end

    return result
end

return M
