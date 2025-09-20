local M = {
    "catppuccin/nvim",
    lazy = false,    -- load at startup cuz it's the main colorscheme
    priority = 1000, -- load it before anything else
    name = "catppuccin",
    init = function()
        vim.cmd.colorscheme "catppuccin"
    end,
}

function M.config()
    require("catppuccin").setup({
        auto_integrations = true,
    })
end

return M
