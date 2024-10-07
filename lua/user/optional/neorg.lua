local M = {
    "nvim-neorg/neorg",
    cmd = "Neorg",
    ft = "neorg",
    version = "*",
    dependencies = {
        { "nvim-neorg/neorg-telescope" }
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
                    },
                    default_workspace = "tasks",
                },
            },
            ["core.integrations.telescope"] = {},
        },
    }
    vim.wo.foldlevel = 99
end

return M
