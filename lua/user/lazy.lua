local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
    vim.fn.system({
        "git",
        "clone",
        "--filter=blob:none",
        "https://github.com/folke/lazy.nvim.git",
        "--branch=stable",
        lazypath,
    })
end
vim.opt.rtp:prepend(lazypath)

-- the tracked lockfile only seeds the local one, so :Lazy update never dirties the repo
local seed_lockfile = vim.fn.stdpath("config") .. "/lazy-lock.json"
local lockfile = vim.fn.stdpath("data") .. "/lazy-lock.json"
if not vim.uv.fs_stat(lockfile) then
    vim.uv.fs_copyfile(seed_lockfile, lockfile)
end

vim.api.nvim_create_user_command("ConfigLockReset", function()
    assert(vim.uv.fs_copyfile(seed_lockfile, lockfile))
    vim.cmd("Lazy restore")
end, { desc = "Restore plugins to the versions pinned by this config" })

require("lazy").setup({
    spec = require("user.base").specs,
    lockfile = lockfile,
    git = {
        log = { "-10" },
    },
    install = {
        missing = true, -- install missing plugins on startup
        colorscheme = { "primer_dark", "habamax" },
    },
    -- image.nvim runs with processor = "magick_cli", so no plugin needs luarocks
    rocks = {
        enabled = false,
    },
    checker = {
        enabled = false, -- disable automatic update checks
    },
    ui = {
        border = "rounded",
        title = "Lazy Plugins",
    },
    change_detection = {
        enabled = true,
        notify = false,
    },
    performance = {
        reset_packpath = true,
        rtp = {
            disabled_plugins = {
                "matchparen",
                "netrwPlugin",
                "rplugin",
                "spellfile",
                "tutor",
            },
        },
    },
})
