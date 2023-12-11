local M = {
    "luckasRanarison/nvim-devdocs",
    dependencies = {
        "nvim-lua/plenary.nvim",
        "nvim-telescope/telescope.nvim",
        "nvim-treesitter/nvim-treesitter",
    },
    event = "VeryLazy",
    cmd = { "DevdocsFetch", "DevdocsOpen", "DevdocsToggle" },
}

function M.config()
    require("nvim-devdocs").setup({
        float_win = {
            relative = "editor",
            width = math.floor(vim.opt.columns:get()*0.8),
            height = math.floor((vim.opt.lines:get() - vim.opt.cmdheight:get())*0.8),
            col = math.floor(vim.opt.columns:get()*0.1),
            row = math.floor((vim.opt.lines:get() - vim.opt.cmdheight:get())*0.1),
            anchor = "NW",
            border = "rounded",
        },
        previewer_cmd = "glow",
        cmd_args = { "-s", "dark", "-w", "80", },
        picker_cmd = true,
        picker_cmd_args = { "-s", "dark", "-w", "40" },
        ensure_installed = { "cpp" },
    })
end

return M
