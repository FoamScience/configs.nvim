if not (vim.env.CONFLUENCE_API_TOKEN or vim.env.JIRA_API_TOKEN) then
    return {}
end

require("confluence-interface").setup({
    auth = {
        url = vim.env.CONFLUENCE_URL or vim.env.JIRA_URL,
        email = vim.env.CONFLUENCE_EMAIL or vim.env.JIRA_EMAIL,
        token = vim.env.CONFLUENCE_API_TOKEN or vim.env.JIRA_API_TOKEN,
    },
    display = {
        mode = "vsplit",
        width = "60%",
    },
    default_space = vim.env.CONFLUENCE_SPACE or nil,
})

return {}
