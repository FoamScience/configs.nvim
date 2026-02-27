local M = {
    "laytan/cloak.nvim",
    event = { "BufRead .env*", "BufRead .*rc" },
}

-- Only cloak values for sensitive keys (tokens, passwords, secrets, keys, auth, credentials)
local sensitive_keywords = { 'TOKEN', 'SECRET', 'PASS', 'KEY', 'AUTH', 'CRED' }

local function env_patterns()
    local patterns = {}
    for _, kw in ipairs(sensitive_keywords) do
        -- case-insensitive match: KEY_NAME=value -> cloak value
        local ci = kw:gsub('.', function(c) return '[' .. c .. c:lower() .. ']' end)
        table.insert(patterns, '([%w_]*' .. ci .. '[%w_]*=)(.+)')
    end
    return patterns
end

local function bashrc_patterns()
    local patterns = {}
    for _, kw in ipairs(sensitive_keywords) do
        local ci = kw:gsub('.', function(c) return '[' .. c .. c:lower() .. ']' end)
        table.insert(patterns, '(export [%w_]*' .. ci .. '[%w_]*=)([^$]+)')
    end
    return patterns
end

M.config = function()
    require('cloak').setup({
        patterns = {
            {
                file_pattern = { '.env*' },
                cloak_pattern = env_patterns(),
                replace = '%1',
            },
            {
                file_pattern = { '.bashrc' },
                cloak_pattern = bashrc_patterns(),
                replace = '%1',
            },
        },
    })
end

return M
