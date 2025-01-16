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
    local ok, settings = pcall(require, vim.loop.os_getenv("USER") .. ".user-settings")
    if not ok then
        settings = {}
    end
    local neorg_settings = settings.neorg or {}
    require("neorg").setup {
        load = {
            ["core.defaults"] = {},
            ["core.concealer"] = {},
            ["core.export"] = {},
            ["core.dirman"] = {
                config = {
                    workspaces = neorg_settings.workspaces or {
                        tasks = "~/notes/tasks",
                    },
                    default_workspace = neorg_settings.default_workspace or "tasks",
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
