local M = {
    "catppuccin/nvim",
    lazy = false, -- load at startup cuz it's the main colorscheme
    priority = 1000, -- load it before anything else
    name = "catppuccin",
}

function M.config()
    require("catppuccin").setup({
        -- auto_integrations probes every plugin catppuccin knows how to theme;
        -- list only what's actually installed to skip that scan
        integrations = {
            blink_cmp = true,
            diffview = true,
            fidget = true,
            flash = true,
            gitsigns = true,
            lsp_trouble = true,
            mason = true,
            navic = true,
            noice = true,
            snacks = true,
            telescope = true,
            which_key = true,
        },
    })
    vim.cmd.colorscheme("catppuccin")
end

return M
