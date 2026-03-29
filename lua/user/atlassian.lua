local has_creds = vim.env.JIRA_API_TOKEN or vim.env.CONFLUENCE_API_TOKEN
if not has_creds then return {} end

return {
    "FoamScience/conflira.nvim",
    dependencies = { "folke/snacks.nvim" },
    lazy = false,
    config = function()
        vim.schedule(function()
            if vim.env.JIRA_API_TOKEN then
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
                    default_project = vim.env.JIRA_PROJECT or nil,
                })
            end

            if vim.env.CONFLUENCE_API_TOKEN or vim.env.JIRA_API_TOKEN then
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
            end
        end)
    end,
}
