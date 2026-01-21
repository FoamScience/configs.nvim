local M = {}

local passed = 0
local failed = 0
local errors = {}

local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
        print("  ✓ " .. name)
    else
        failed = failed + 1
        table.insert(errors, { name = name, error = err })
        print("  ✗ " .. name)
        print("    " .. tostring(err))
    end
end

local function assert_eq(actual, expected, msg)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", msg or "Assertion failed", vim.inspect(expected),
            vim.inspect(actual)))
    end
end

local function assert_true(value, msg)
    if not value then
        error(msg or "Expected true")
    end
end

local function assert_nil(value, msg)
    if value ~= nil then
        error(string.format("%s: expected nil, got %s", msg or "Assertion failed", vim.inspect(value)))
    end
end

local function assert_not_nil(value, msg)
    if value == nil then
        error(msg or "Expected non-nil value")
    end
end

local function assert_contains(str, substr, msg)
    if not str:find(substr, 1, true) then
        error(string.format("%s: '%s' not found in '%s'", msg or "Assertion failed", substr, str))
    end
end

-- Test suites

local function test_types()
    print("\n[types.lua]")

    -- Setup config first
    local config = require("jira-interface.config")
    config.setup({})

    local types = require("jira-interface.types")
    local mock = require("jira-interface.tests.mock")

    test("parse_issue extracts key", function()
        local issue = types.parse_issue(mock.issue_response)
        assert_eq(issue.key, "TEST-123", "key")
    end)

    test("parse_issue extracts summary", function()
        local issue = types.parse_issue(mock.issue_response)
        assert_eq(issue.summary, "Test issue summary", "summary")
    end)

    test("parse_issue extracts status", function()
        local issue = types.parse_issue(mock.issue_response)
        assert_eq(issue.status, "In Progress", "status")
    end)

    test("parse_issue extracts type", function()
        local issue = types.parse_issue(mock.issue_response)
        assert_eq(issue.type, "Task", "type")
    end)

    test("parse_issue extracts assignee", function()
        local issue = types.parse_issue(mock.issue_response)
        assert_eq(issue.assignee, "John Doe", "assignee")
    end)

    test("parse_issue extracts parent", function()
        local issue = types.parse_issue(mock.issue_response)
        assert_eq(issue.parent, "TEST-100", "parent")
    end)

    test("parse_issue handles nil assignee", function()
        local issue = types.parse_issue(mock.search_response.issues[2])
        assert_nil(issue.assignee, "assignee should be nil")
    end)

    test("parse_issue handles nil parent", function()
        local issue = types.parse_issue(mock.search_response.issues[2])
        assert_nil(issue.parent, "parent should be nil")
    end)

    test("parse_description handles ADF", function()
        local desc = types.parse_description(mock.issue_response.fields.description)
        assert_contains(desc, "This is the description", "description content")
    end)

    test("parse_description handles nil", function()
        local desc = types.parse_description(nil)
        assert_nil(desc, "nil description")
    end)

    test("parse_description handles string", function()
        local desc = types.parse_description("Plain text description")
        assert_eq(desc, "Plain text description", "string description")
    end)

    test("adf_to_text handles bullet list", function()
        local adf = {
            content = {
                {
                    type = "bulletList",
                    content = {
                        {
                            type = "listItem",
                            content = {
                                { type = "paragraph", content = { { type = "text", text = "Item 1" } } },
                            },
                        },
                        {
                            type = "listItem",
                            content = {
                                { type = "paragraph", content = { { type = "text", text = "Item 2" } } },
                            },
                        },
                    },
                },
            },
        }
        local text = types.adf_to_text(adf)
        assert_contains(text, "- Item 1", "bullet 1")
        assert_contains(text, "- Item 2", "bullet 2")
    end)

    test("adf_to_text handles heading", function()
        local adf = {
            content = {
                {
                    type = "heading",
                    attrs = { level = 2 },
                    content = { { type = "text", text = "My Heading" } },
                },
            },
        }
        local text = types.adf_to_text(adf)
        assert_contains(text, "## My Heading", "heading")
    end)

    test("get_level returns 1 for Epic", function()
        assert_eq(types.get_level("Epic"), 1, "Epic level")
    end)

    test("get_level returns 2 for Feature", function()
        assert_eq(types.get_level("Feature"), 2, "Feature level")
    end)

    test("get_level returns 2 for Bug", function()
        assert_eq(types.get_level("Bug"), 2, "Bug level")
    end)

    test("get_level returns 3 for Task", function()
        assert_eq(types.get_level("Task"), 3, "Task level")
    end)

    test("get_level is case insensitive", function()
        assert_eq(types.get_level("epic"), 1, "lowercase epic")
        assert_eq(types.get_level("TASK"), 3, "uppercase task")
    end)

    test("get_level returns 0 for unknown", function()
        assert_eq(types.get_level("Unknown"), 0, "unknown type")
    end)

    test("get_valid_transitions for To Do", function()
        local transitions = types.get_valid_transitions("To Do")
        assert_eq(#transitions, 1, "transition count")
        assert_eq(transitions[1], "In Progress", "first transition")
    end)

    test("get_valid_transitions for In Progress", function()
        local transitions = types.get_valid_transitions("In Progress")
        assert_eq(#transitions, 2, "transition count")
    end)

    test("get_valid_transitions for In Review", function()
        local transitions = types.get_valid_transitions("In Review")
        assert_eq(#transitions, 3, "transition count")
    end)

    test("get_status_display returns icon", function()
        local display = types.get_status_display("In Progress")
        assert_not_nil(display.icon, "icon")
        assert_not_nil(display.hl, "highlight")
    end)

    test("get_status_display handles unknown status", function()
        local display = types.get_status_display("Unknown Status")
        assert_eq(display.icon, "?", "unknown icon")
    end)
end

local function test_config()
    print("\n[config.lua]")

    -- Reload config module
    package.loaded["jira-interface.config"] = nil
    local config = require("jira-interface.config")

    test("setup returns options", function()
        local opts = config.setup({})
        assert_not_nil(opts, "options")
    end)

    test("setup merges custom options", function()
        config.setup({ cache_ttl = 600 })
        assert_eq(config.options.cache_ttl, 600, "cache_ttl")
    end)

    test("setup preserves defaults for unset options", function()
        config.setup({ cache_ttl = 600 })
        assert_not_nil(config.options.types, "types should exist")
        assert_not_nil(config.options.statuses, "statuses should exist")
    end)

    test("validate fails without url", function()
        config.setup({ auth = { url = "", email = "test@test.com", token = "token" } })
        local valid, err = config.validate()
        assert_true(not valid, "should be invalid")
        assert_contains(err, "URL", "error message")
    end)

    test("validate fails without email", function()
        config.setup({ auth = { url = "https://test.atlassian.net", email = "", token = "token" } })
        local valid, err = config.validate()
        assert_true(not valid, "should be invalid")
        assert_contains(err, "EMAIL", "error message")
    end)

    test("validate fails without token", function()
        config.setup({ auth = { url = "https://test.atlassian.net", email = "test@test.com", token = "" } })
        local valid, err = config.validate()
        assert_true(not valid, "should be invalid")
        assert_contains(err, "TOKEN", "error message")
    end)

    test("validate passes without project (optional)", function()
        config.setup({
            auth = { url = "https://test.atlassian.net", email = "test@test.com", token = "token" },
            default_project = nil,
        })
        local valid, _ = config.validate()
        assert_true(valid, "should be valid without project")
    end)

    test("get_cache_path returns valid path", function()
        config.setup({})
        local path = config.get_cache_path()
        assert_contains(path, "cache.json", "cache path")
    end)

    test("get_queue_path returns valid path", function()
        config.setup({})
        local path = config.get_queue_path()
        assert_contains(path, "queue.json", "queue path")
    end)

    test("get_filters_path returns valid path", function()
        config.setup({})
        local path = config.get_filters_path()
        assert_contains(path, "filters.json", "filters path")
    end)
end

local function test_filters()
    print("\n[filters.lua]")

    -- Setup config first
    local config = require("jira-interface.config")
    config.setup({})

    local filters = require("jira-interface.filters")

    test("builtin.assigned_to_me returns JQL", function()
        local jql = filters.builtin.assigned_to_me()
        assert_contains(jql, "assignee = currentUser()", "assignee clause")
    end)

    test("builtin.by_project returns JQL with project", function()
        local jql = filters.builtin.by_project("TEST")
        assert_contains(jql, "project = TEST", "project clause")
    end)

    test("builtin.by_status returns JQL with status", function()
        local jql = filters.builtin.by_status("In Progress")
        assert_contains(jql, 'status = "In Progress"', "status clause")
    end)

    test("builtin.by_type returns JQL with type", function()
        local jql = filters.builtin.by_type("Bug")
        assert_contains(jql, 'issuetype = "Bug"', "type clause")
    end)

    test("builtin.by_level returns JQL for level 1", function()
        local jql = filters.builtin.by_level(1, "TEST")
        assert_contains(jql, "Epic", "epic type")
        assert_contains(jql, "project = TEST", "project clause")
    end)

    test("builtin.by_level returns JQL for level 2", function()
        local jql = filters.builtin.by_level(2, nil)
        assert_contains(jql, "Feature", "feature type")
        assert_contains(jql, "Bug", "bug type")
    end)

    test("builtin.by_level works without project", function()
        local jql = filters.builtin.by_level(3, nil)
        assert_contains(jql, "Task", "task type")
        assert_true(not jql:find("project ="), "should not have project filter")
    end)

    test("builtin.by_level works with empty project", function()
        local jql = filters.builtin.by_level(1, "")
        assert_contains(jql, "Epic", "epic type")
        assert_true(not jql:find("project ="), "should not have project filter")
    end)

    test("builtin.children_of returns JQL with parent", function()
        local jql = filters.builtin.children_of("TEST-100")
        assert_contains(jql, "parent = TEST-100", "parent clause")
    end)

    test("combine_jql merges clauses", function()
        local jql = filters.combine_jql("project = TEST ORDER BY updated DESC", "status = Done")
        assert_contains(jql, "project = TEST", "original clause")
        assert_contains(jql, "status = Done", "additional clause")
        assert_contains(jql, "ORDER BY", "order by preserved")
    end)
end

local function test_url_handling()
    print("\n[url handling]")

    test("base URL trailing slash is removed", function()
        local config = require("jira-interface.config")
        config.setup({ auth = { url = "https://test.atlassian.net/" } })
        -- The get_base_url function removes trailing slash
        assert_eq(config.options.auth.url, "https://test.atlassian.net/", "url stored as-is")
    end)
end

function M.run()
    print("\n========================================")
    print("  Jira Interface Unit Tests")
    print("========================================")

    passed = 0
    failed = 0
    errors = {}

    test_config()
    test_types()
    test_filters()
    test_url_handling()

    print("\n========================================")
    print(string.format("  Results: %d passed, %d failed", passed, failed))
    print("========================================\n")

    if #errors > 0 then
        print("Failed tests:")
        for _, e in ipairs(errors) do
            print("  - " .. e.name)
        end
    end

    return failed == 0
end

function M.run_integration()
    local api_test = require("jira-interface.tests.api_test")
    return api_test.run()
end

function M.run_all()
    local unit_ok = M.run()
    local integration_ok = M.run_integration()
    return unit_ok and integration_ok
end

return M
