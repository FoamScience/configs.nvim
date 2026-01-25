-- enable bytecode cache for lua files
vim.loader.enable()

-- -------- Actual configuration ---------

-- average startup time is estimated for:
-- - empty vim options
-- - vim opens a c++ header file with git changes and LSP errors
-- basic setup startup (msec): 16.10/16.15
require "user.base"
require "user.options"
require "user.keymaps"
require "user.autocmds"
require "user.news"
require("user.tree-climb")
-- Core plugins (loaded in all presets)
spec "user.colorscheme"
spec "user.devicons"
spec "user.whichkey"
spec "user.noice"
spec "user.fidget"
spec "user.treesitter"
spec "user.lspconfig"
spec "user.todocomments"
spec "user.gitsigns"
spec "user.diffview"
spec "user.gitconflicts"
spec "user.navic"
spec "user.mini-statusline"
spec "user.cmp"
spec "user.autopairs"
spec "user.snippets"
spec "user.guess-indent"
spec "user.undo"
spec "user.markdown-toc"
spec "user.arrow"
spec "user.flash"
spec "user.navbuddy"
spec "user.qf"
spec "user.optional.colorizer"
spec "user.optional.dial"
spec "user.optional.csv"
spec "user.optional.typst"
spec "user.optional.cloack"
spec "user.remote-nvim"

-- Full-only plugins (excluded from SSH due to latency/GUI dependencies)
spec("user.snacks", {"full"})             -- Heavy file scanning with latency
spec("user.img-clip", {"full"})           -- Clipboard/GUI-dependent
spec("user.project", {"full"})            -- Heavy directory scanning
spec("user.nvimtree", {"full"})           -- Large directory browsing over latency
spec("user.optional.tpipeline", {"full"}) -- Tmux statusline (moved to full-only)
spec("user.optional.cinnamon", {"full"})  -- Scrolling animations
spec("user.optional.dim", {"full"})       -- Visual dimming effects
spec("user.render-markdown", {"full"})    -- Heavy markdown rendering
spec("user.incline", {"full"})            -- Floating window decorations
spec("user.tutorials", {"full"})          -- tutorials on effective editing with this configuration
spec("user.jira", {"full"})               -- jira client

-- Load user-config directory (for separate user repo integration)
-- Users can symlink their config repo to ~/.config/nvim/user-config/
local user_config_dir = vim.fn.stdpath("config") .. "/user-config"
local user_config_stat = vim.loop.fs_stat(user_config_dir)
if user_config_stat and user_config_stat.type == "directory" then
    -- Add user-config to package path so modules can be required
    package.path = user_config_dir .. "/?.lua;" .. user_config_dir .. "/?/init.lua;" .. package.path

    -- Load init.lua from user-config if it exists
    local user_init = user_config_dir .. "/init.lua"
    if vim.loop.fs_stat(user_init) then
        dofile(user_init)
    end

    -- Load all plugin specs from user-config/plugins/
    local user_plugins_dir = user_config_dir .. "/plugins"
    if vim.loop.fs_stat(user_plugins_dir) then
        local files = vim.fn.glob(user_plugins_dir .. "/*.lua", false, true)
        for _, file in ipairs(files) do
            local ok, plugin_spec = pcall(dofile, file)
            if ok and type(plugin_spec) == "table" then
                table.insert(LAZY_PLUGIN_SPEC, plugin_spec)
            end
        end
    end
end

-- lazy needs to be loaded last
require "user.lazy"
