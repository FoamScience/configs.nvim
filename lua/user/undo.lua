local M = {
    "jiaoshijie/undotree",
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = {
    },
    event = "VeryLazy",
    keys = {
        { "<leader>u", "<cmd>lua require('undotree').toggle()<cr>" },
    },
}

function M.config()
    require("undotree").setup{
        layout = "left_bottom",
        window = {
            winblend = 0,
        },
        ignore_filetype = require("user.lualine").filetypes_to_ignore or {
            "undotree",
            'undotreeDiff',
            'qf',
            'TelescopePrompt',
            'spectre_panel',
            'tsplayground',
        }
    }
end

return M
