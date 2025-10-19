local M = {
    "FoamScience/markdown-toc.nvim",
    ft = { "markdown", "rmd" },
    branch = "no-nvim-clutter",
    dependencies = {
        "nvim-treesitter/nvim-treesitter", -- for efficient parsing
        "folke/snacks.nvim",
        --"nvim-telescope/telescope.nvim",   -- for picker UI
    },
    build = ":TSInstall markdown",
}

M.config = function()
    require("mtoc").setup({
        debug = false,
        picker = {
            preferred = 'snacks',
        },
        headings = {
            before_toc = false,
            min_depth = 1,
            max_depth = 4,
        },
        fences = {
            start_text = { "mtoc-start", "mtoc-old-start" },
            end_text = { "mtoc-end", "mtoc-old-end" },
        },
        auto_update = {
            enabled = true,
            events = { 'BufWritePre' },
            pattern = '*.{md,mdown,mkd,mkdn,markdown,mdwn}',
            suppress_pollution = true,
        },
        toc_list = {
            numbered = false,
        }
    })
end

return M
