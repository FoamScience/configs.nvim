-- enable bytecode cache for lua files
vim.loader.enable()
-- selective enabling of plugin categories
vim.g.loaded_categories = {
    ux = true,
    lsp = true,
    git = true,
    winbar = true,
    telescope = true,
    autocomplete = true,
    edit = true,
    navigation = true,
    whichkey = true,
    ai = true,
    custom_ai = true,
    optional = true,
}
-- function to override vim.g.loaded_categories from the command line
local function override_load_plugins(settings)
    local new_load_plugins = {}
    for setting in settings:gmatch("[^,]+") do
        local key, value = setting:match("(%w+)=([a-z]+)")
        if key and value then
            value = (value == "true")
            new_load_plugins[key] = value
        else
            print("Invalid argument format: " .. setting)
        end
    end
    return new_load_plugins
end
if vim.g.plugin_settings then
    -- Go like this to enable specific plugin categories
    -- vim --cmd "lua vim.g.plugin_settings = 'ux=true,lsp=true'"
    vim.g.loaded_categories = override_load_plugins(vim.g.plugin_settings)
end

-- -------- Actual configuration ---------

-- average startup time is estimated for:
-- - empty vim options
-- - vim opens a c++ header file with git changes and LSP errors
-- basic setup startup (msec): 16.10/16.15
require "user.base"
require "user.options"
require "user.keymaps"
require "user.autocmds"
spec "user.colorscheme"
spec "user.devicons"

-- UX startup: 16.37/16.50
if vim.g.loaded_categories.ux then
    spec "user.noice"
    spec "user.significant"
    spec "user.indentline" -- costs ~0.03 msecs
end

-- lsp setup startup: 36.39/37.50
if vim.g.loaded_categories.lsp then
    spec "user.treesitter"
    spec "user.mason"
    spec "user.lspconfig"
    spec "user.todocomments"
    spec "user.garbage"
end

-- git startup: 17.14/17.39
if vim.g.loaded_categories.git then
    spec "user.gitsigns"
    spec "user.diffview"
    spec "user.neogit"
    spec "user.gitconflicts"
    spec "user.blame"
end

---- winbar and statusline startup: 26.92/26.94
if vim.g.loaded_categories.winbar then
    spec "user.navic"
    spec "user.lualine"
    spec "user.unclutter"
end

-- telescope startup 17.07/17.08
if vim.g.loaded_categories.telescope then
    spec "user.telescope"
    spec "user.telescope-tabs"
end

-- autocomplete startup: 17.03/17.11
if vim.g.loaded_categories.autocomplete then
    spec "user.cmp"
end

-- edit startup: 17.14/16.75
if vim.g.loaded_categories.edit then
    spec "user.autopairs"
    spec "user.project"
    spec "user.nvimtree"
end

-- navigation startup: 17.04/16.71
if vim.g.loaded_categories.navigation then
    spec "user.arrow"
    spec "user.hop"
    spec "user.navbuddy"
    spec "user.qf"
end

-- whichkey 16.22/16.73
if vim.g.loaded_categories.whichkey then
    spec "user.whichkey"
end

-- AI startup: 16.84/17.18
if vim.g.loaded_categories.ai then
    spec "user.sg"
    spec "user.copilot"
end

-- optional plugins startup: 17.93/18.03
if vim.g.loaded_categories.optional then
    spec "user.optional.colorizer"
    spec "user.optional.dial"
    spec "user.optional.dressing"
    spec "user.optional.csv"
    spec "user.optional.dim"
    spec "user.optional.lens"
    spec "user.optional.winsep"
    spec "user.optional.neoscroll"
end


-- lazy needs to be loaded last
require "user.lazy"
-- custom AI configuration; startup: 16.60/16.65
if vim.g.loaded_categories.custom_ai then
    require "user.ai"
end
