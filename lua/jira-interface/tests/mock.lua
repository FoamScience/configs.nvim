local M = {}

-- Sample Jira API responses for testing

M.issue_response = {
    key = "TEST-123",
    id = "10001",
    fields = {
        summary = "Test issue summary",
        description = {
            type = "doc",
            version = 1,
            content = {
                {
                    type = "paragraph",
                    content = {
                        { type = "text", text = "This is the description." },
                    },
                },
            },
        },
        status = { name = "In Progress" },
        issuetype = { name = "Task" },
        project = { key = "TEST" },
        assignee = { displayName = "John Doe" },
        parent = { key = "TEST-100" },
        created = "2024-01-15T10:00:00.000Z",
        updated = "2024-01-16T14:30:00.000Z",
        customfield_10020 = {
            type = "doc",
            version = 1,
            content = {
                {
                    type = "bulletList",
                    content = {
                        {
                            type = "listItem",
                            content = {
                                {
                                    type = "paragraph",
                                    content = {
                                        { type = "text", text = "Criteria 1" },
                                    },
                                },
                            },
                        },
                        {
                            type = "listItem",
                            content = {
                                {
                                    type = "paragraph",
                                    content = {
                                        { type = "text", text = "Criteria 2" },
                                    },
                                },
                            },
                        },
                    },
                },
            },
        },
    },
}

M.search_response = {
    issues = {
        M.issue_response,
        {
            key = "TEST-124",
            id = "10002",
            fields = {
                summary = "Another test issue",
                description = nil,
                status = { name = "To Do" },
                issuetype = { name = "Bug" },
                project = { key = "TEST" },
                assignee = nil,
                parent = nil,
                created = "2024-01-14T09:00:00.000Z",
                updated = "2024-01-14T09:00:00.000Z",
            },
        },
    },
    total = 2,
    maxResults = 100,
}

M.projects_response = {
    values = {
        { key = "TEST", name = "Test Project", id = "10000" },
        { key = "DEMO", name = "Demo Project", id = "10001" },
    },
}

M.transitions_response = {
    transitions = {
        { id = "21", name = "Start Progress", to = { name = "In Progress" } },
        { id = "31", name = "Done",           to = { name = "Done" } },
    },
}

-- Mock API module
M.api = {}

local mock_responses = {}
local mock_errors = {}

function M.api.set_response(endpoint_pattern, response)
    mock_responses[endpoint_pattern] = response
end

function M.api.set_error(endpoint_pattern, error_msg)
    mock_errors[endpoint_pattern] = error_msg
end

function M.api.clear()
    mock_responses = {}
    mock_errors = {}
end

function M.api.request(endpoint, method, body, callback)
    vim.schedule(function()
        for pattern, err in pairs(mock_errors) do
            if endpoint:match(pattern) then
                callback(err, nil)
                return
            end
        end

        for pattern, response in pairs(mock_responses) do
            if endpoint:match(pattern) then
                callback(nil, response)
                return
            end
        end

        callback("No mock response for: " .. endpoint, nil)
    end)
end

return M
