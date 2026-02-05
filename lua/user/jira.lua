if not vim.env.JIRA_API_TOKEN then
    return {}
end

require("jira-interface").setup({
    auth = {
        url = vim.env.JIRA_URL,
        email = vim.env.JIRA_EMAIL,
        token = vim.env.JIRA_API_TOKEN,
    },
    display = {
        mode = "vsplit",
        width = "60%",
    },
    default_project = vim.env.JIRA_PROJECT or nil, -- Optional: search across all projects if not set
    acceptance_criteria_field = "customfield_10172",
})

return {}
