local M = {}

-- Integration tests for API module
-- These tests make actual API calls and require valid credentials

local api = require("jira-interface.api")
local config = require("jira-interface.config")

local results = {}

local function log(msg)
    table.insert(results, msg)
    print(msg)
end

local function test_async(name, fn, timeout_ms)
    timeout_ms = timeout_ms or 10000
    local done = false
    local test_error = nil

    log("  Testing: " .. name)

    fn(function(err)
        test_error = err
        done = true
    end)

    -- Wait for completion
    local start = vim.loop.now()
    while not done and (vim.loop.now() - start) < timeout_ms do
        vim.wait(100)
    end

    if not done then
        log("    ✗ TIMEOUT after " .. timeout_ms .. "ms")
        return false
    elseif test_error then
        log("    ✗ " .. tostring(test_error))
        return false
    else
        log("    ✓ Passed")
        return true
    end
end

function M.test_connectivity()
    return test_async("Check connectivity", function(done)
        api.check_connectivity(function(online)
            if online then
                done(nil)
            else
                done("Not online")
            end
        end)
    end)
end

function M.test_get_projects()
    return test_async("Get projects", function(done)
        api.get_projects(function(err, projects)
            if err then
                done(err)
            elseif not projects or #projects == 0 then
                done("No projects returned")
            else
                log("    Found " .. #projects .. " projects")
                for i, p in ipairs(projects) do
                    if i <= 3 then
                        log("      - " .. p.key .. ": " .. p.name)
                    end
                end
                done(nil)
            end
        end)
    end)
end

function M.test_search()
    local project = config.options.default_project
    if not project or project == "" then
        log("  Skipping search test: no default project")
        return true
    end

    return test_async("Search issues in " .. project, function(done)
        local jql = "project = " .. project .. " ORDER BY updated DESC"
        api.search(jql, function(err, issues)
            if err then
                done(err)
            elseif not issues then
                done("No issues returned")
            else
                log("    Found " .. #issues .. " issues")
                for i, issue in ipairs(issues) do
                    if i <= 3 then
                        log("      - " .. issue.key .. ": " .. issue.summary:sub(1, 40))
                    end
                end
                done(nil)
            end
        end)
    end)
end

function M.test_assigned_to_me()
    return test_async("Get assigned issues", function(done)
        api.get_assigned_to_me(function(err, issues)
            if err then
                done(err)
            elseif not issues then
                done("No response")
            else
                log("    Found " .. #issues .. " assigned issues")
                done(nil)
            end
        end)
    end)
end

function M.run()
    results = {}

    log("\n========================================")
    log("  Jira API Integration Tests")
    log("========================================")

    -- Check config first
    local valid, err = config.validate()
    if not valid then
        log("\n  Configuration Error: " .. err)
        log("  Set environment variables: JIRA_URL, JIRA_EMAIL, JIRA_API_TOKEN, JIRA_PROJECT")
        log("\n========================================\n")
        return false
    end

    log("\n  Using: " .. config.options.auth.url)
    log("  Project: " .. (config.options.default_project or "none"))
    log("")

    local passed = 0
    local failed = 0

    local tests = {
        M.test_connectivity,
        M.test_get_projects,
        M.test_search,
        M.test_assigned_to_me,
    }

    for _, test_fn in ipairs(tests) do
        if test_fn() then
            passed = passed + 1
        else
            failed = failed + 1
        end
    end

    log("\n========================================")
    log(string.format("  Results: %d passed, %d failed", passed, failed))
    log("========================================\n")

    return failed == 0
end

return M
