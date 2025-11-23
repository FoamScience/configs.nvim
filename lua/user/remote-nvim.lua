local M = {
    "amitds1997/remote-nvim.nvim",
    version = "*", -- Pin to GitHub releases
    dependencies = {
        "nvim-lua/plenary.nvim", -- For standard functions
        "MunifTanjim/nui.nvim", -- To build the plugin UI
        --"nvim-telescope/telescope.nvim", -- For picking b/w different remote methods
        -- Note: This is the only plugin that requires telescope in this config
        -- In SSH preset, snacks.picker is excluded but telescope will still be
        -- available through this dependency
    },
    lazy = true,
    cmd = {
        "RemoteStart",
        "RemoteStop",
        "RemoteInfo",
        "RemoteCleanup",
        "RemoteConfigDel",
        "RemoteLog",
    },
}

function M.config()
    require("remote-nvim").setup({})
end

return M
