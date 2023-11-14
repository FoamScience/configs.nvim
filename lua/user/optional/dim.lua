local M = {
	"folke/twilight.nvim",
	event = "VeryLazy",
    ft = {
        'cpp',
        'python',
        'lua',
        'foam',
    },
}

function M.config()
	require("twilight").setup ({
        dimming = {
            inactive = true,
        },
        context = 2,
        treesitter = true,
        expand = {
            "function",
            "method",
            "table",
            "if_statement",
            "for_statement",
            "for_in_statement",
            "while_statement",
            "array",
            -- foam
            "dict_body",
            -- c++
            "function_definition",
            "field_decleration",
        }
    })
end

return M
