local M = {
    "nvim-neorg/neorg",
    cmd = "Neorg",
    ft = "neorg",
    version = "*",
    dependencies = {
        { "nvim-neorg/neorg-telescope" },
        { "3rd/image.nvim" },
    },
}

M.config = function()
    require("neorg").setup {
        load = {
            ["core.defaults"] = {},
            ["core.concealer"] = {},
            ["core.dirman"] = {
                config = {
                    workspaces = {
                        tasks = "~/notes/tasks",
                        Meshless = "~/notes/Meshless",
                        OpenFOAMOpt = "~/notes/OpenFOAMOpt",
                        UnitTesting = "~/notes/UnitTesting",
                        TGradientAlongSolidificationPaths = "~/notes/TGradientAlongSolidificationPaths"
                    },
                    default_workspace = "tasks",
                },
            },
            ["core.integrations.telescope"] = {},
            ["core.integrations.image"] = { },
            ["core.latex.renderer"] = {
                conceal = true,
                render_on_enter = true,
                scale = 0.7,
            },
        },
    }
    vim.wo.foldlevel = 99
end

return M
