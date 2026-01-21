local M = {}

---@class JiraAuthConfig
---@field url string Jira instance URL
---@field email string User email
---@field token string API token

---@class JiraTypesConfig
---@field lvl1 string[] Level 1 issue types (Epics)
---@field lvl2 string[] Level 2 issue types (Features, Bugs, Issues)
---@field lvl3 string[] Level 3 issue types (Tasks)
---@field lvl4 string[] Level 4 issue types (Sub-Tasks)

---@class JiraTemplateConfig
---@field description string Template for description field
---@field acceptance_criteria string Template for acceptance criteria field

---@class JiraDisplayConfig
---@field mode string Display mode: "float", "vsplit", "split", "tab"
---@field width number|string Width for float/vsplit (number = columns, string like "80%" = percentage)
---@field height number|string Height for float/split (number = lines, string like "80%" = percentage)
---@field border string Border style for floats: "none", "single", "double", "rounded", "solid", "shadow"
---@field wrap boolean Enable line wrapping
---@field linebreak boolean Break at word boundaries when wrapping
---@field conceallevel number Conceal level for markdown (0-3)
---@field cursorline boolean Highlight current line

---@class JiraConfig
---@field auth JiraAuthConfig
---@field default_project string
---@field cache_ttl number Cache time-to-live in seconds
---@field max_results number Maximum issues to fetch per query
---@field since string|nil Filter issues created since (e.g., "-365d", "-30d", "-7d")
---@field types JiraTypesConfig
---@field statuses string[]
---@field acceptance_criteria_field string Custom field ID for acceptance criteria
---@field data_dir string Directory for storing cache and queue
---@field templates table<string, JiraTemplateConfig> Templates per issue type
---@field display JiraDisplayConfig Display settings for issue windows

---@type JiraConfig
M.defaults = {
    auth = {
        url = vim.env.JIRA_URL or "",
        email = vim.env.JIRA_EMAIL or "",
        token = vim.env.JIRA_API_TOKEN or "",
    },
    default_project = vim.env.JIRA_PROJECT or "",
    cache_ttl = 300,
    max_results = 500, -- Max issues to fetch per query
    since = "-365d",   -- Filter by creation date (use days: -365d, -30d, -7d; set to nil to disable)
    types = {
        lvl1 = { "Epic" },
        lvl2 = { "Feature", "Bug", "Issue" },
        lvl3 = { "Task" },
        lvl4 = { "Sub-Task" },
    },
    statuses = {
        "To Do",
        "In Progress",
        "In Review",
        "Blocked",
        "Done",
    },
    acceptance_criteria_field = "customfield_10020",
    data_dir = vim.fn.stdpath("data") .. "/jira-interface",
    templates = {
        default = {
            description = "",
            acceptance_criteria = "- [ ] ",
        },
        epic = {
            description = "### Overview\n\n### Goals\n\n### Scope\n",
            acceptance_criteria = "- [ ] All child features completed\n- [ ] Documentation updated",
        },
        feature = {
            description = "### Problem\n\n### Solution\n\n### Technical Notes\n",
            acceptance_criteria = "- [ ] Implementation complete\n- [ ] Tests passing\n- [ ] Code reviewed",
        },
        bug = {
            description =
            "### Steps to Reproduce\n1. \n\n### Expected Behavior\n\n### Actual Behavior\n\n### Environment\n",
            acceptance_criteria = "- [ ] Bug fixed\n- [ ] Tests added\n- [ ] No regression",
        },
        task = {
            description = "",
            acceptance_criteria = "- [ ] Task completed\n- [ ] Verified working",
        },
    },
    display = {
        mode = "float",     -- "float", "vsplit", "split", "tab"
        width = "80%",      -- number (columns) or string ("80%")
        height = "80%",     -- number (lines) or string ("80%")
        border = "rounded", -- "none", "single", "double", "rounded", "solid", "shadow"
        wrap = true,
        linebreak = true,
        conceallevel = 2,
        cursorline = true,
    },
}

---@type JiraConfig
M.options = {}

---@param opts? JiraConfig
---@return JiraConfig
function M.setup(opts)
    M.options = vim.tbl_deep_extend("force", {}, M.defaults, opts or {})

    -- Ensure data directory exists
    vim.fn.mkdir(M.options.data_dir, "p")

    return M.options
end

---@return boolean, string?
function M.validate()
    local auth = M.options.auth
    if not auth.url or auth.url == "" then
        return false, "JIRA_URL is not set"
    end
    if not auth.email or auth.email == "" then
        return false, "JIRA_EMAIL is not set"
    end
    if not auth.token or auth.token == "" then
        return false, "JIRA_API_TOKEN is not set"
    end
    -- default_project is optional - can search across all projects
    return true, nil
end

---@return string
function M.get_cache_path()
    return M.options.data_dir .. "/cache.json"
end

---@return string
function M.get_queue_path()
    return M.options.data_dir .. "/queue.json"
end

---@return string
function M.get_filters_path()
    return M.options.data_dir .. "/filters.json"
end

return M
