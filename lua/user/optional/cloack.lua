local M = {
    "laytan/cloak.nvim",
    event = { "BufRead .env*", "BufRead .*rc" },
}

M.config = function()
    require('cloak').setup({
        patterns = {
            {
                file_pattern = {'.env*'},
                cloak_pattern = '=.+',
                replace = nil,
            },
            {
                file_pattern = {'.bashrc'},
                cloak_pattern = 'export ([A-Z_ ]+=)[^$]+',
                replace = "[cloaked export] %1",
            },
        },
    })
end

return M
