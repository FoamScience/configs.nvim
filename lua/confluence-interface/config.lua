local M = {}

---@class ConfluenceAuthConfig
---@field url string Confluence instance URL (e.g., "your-domain.atlassian.net")
---@field email string User email
---@field token string API token

---@class ConfluenceDisplayConfig
---@field mode string Display mode: "float", "vsplit", "split", "tab"
---@field width number|string Width for float/vsplit (number = columns, string like "80%" = percentage)
---@field height number|string Height for float/split (number = lines, string like "80%" = percentage)
---@field border string Border style for floats
---@field wrap boolean Enable line wrapping
---@field linebreak boolean Break at word boundaries when wrapping
---@field conceallevel number Conceal level for markdown (0-3)
---@field cursorline boolean Highlight current line

---@class ConfluenceConfig
---@field auth ConfluenceAuthConfig
---@field default_space string Default space key
---@field cache_ttl number Cache time-to-live in seconds
---@field max_results number Maximum pages to fetch per query
---@field data_dir string Directory for storing cache
---@field display ConfluenceDisplayConfig Display settings

---@type ConfluenceConfig
M.defaults = {
    auth = {
        url = vim.env.CONFLUENCE_URL or vim.env.JIRA_URL or "",
        email = vim.env.CONFLUENCE_EMAIL or vim.env.JIRA_EMAIL or "",
        token = vim.env.CONFLUENCE_API_TOKEN or vim.env.JIRA_API_TOKEN or "",
    },
    default_space = vim.env.CONFLUENCE_SPACE or "",
    cache_ttl = 300,
    max_results = 100,
    data_dir = vim.fn.stdpath("data") .. "/confluence-interface",
    display = {
        mode = "float",
        width = "80%",
        height = "80%",
        border = "rounded",
        wrap = true,
        linebreak = true,
        conceallevel = 2,
        cursorline = true,
    },
}

---@type ConfluenceConfig
M.options = {}

---@param opts? ConfluenceConfig
---@return ConfluenceConfig
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
        return false, "CONFLUENCE_URL is not set"
    end
    if not auth.email or auth.email == "" then
        return false, "CONFLUENCE_EMAIL is not set"
    end
    if not auth.token or auth.token == "" then
        return false, "CONFLUENCE_API_TOKEN is not set"
    end
    return true, nil
end

---@return string
function M.get_cache_path()
    return M.options.data_dir .. "/cache.json"
end

return M
