-- enable bytecode cache for lua files
vim.loader.enable()
-- selective enabling of plugin categories
vim.g.loaded_categories = {
    ux = true,
    lsp = true,
    git = true,
    winbar = true,
    finder = true,
    autocomplete = true,
    edit = true,
    navigation = true,
    whichkey = true,
    ai = true,
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

-- should check for new configuration commits?
vim.g.config_check_for_updates = false

-- -------- Actual configuration ---------

-- average startup time is estimated for:
-- - empty vim options
-- - vim opens a c++ header file with git changes and LSP errors
-- basic setup startup (msec): 16.10/16.15
require "user.base"
require "user.options"
require "user.keymaps"
require "user.autocmds"
require "user.config-check"
spec "user.colorscheme"
spec "user.devicons"

-- whichkey 16.22/16.73
if vim.g.loaded_categories.whichkey then
    spec "user.whichkey"
end

-- UX startup: 16.37/16.50
if vim.g.loaded_categories.ux then
    spec "user.snacks"
    spec "user.noice"
    spec "user.render-markdown"
    spec "user.img-clip"
    spec "user.fidget"
end

-- lsp setup startup: 36.39/37.50
if vim.g.loaded_categories.lsp then
    spec "user.treesitter"
    spec "user.lspconfig"
    spec "user.todocomments"
    --spec "user.garbage"
end

-- git startup: 17.14/17.39
if vim.g.loaded_categories.git then
    spec "user.gitsigns"
    spec "user.diffview"
    spec "user.gitconflicts"
end

---- winbar and statusline startup: 26.92/26.94
if vim.g.loaded_categories.winbar then
    spec "user.navic"
    spec "user.mini-statusline" -- Fast statusline using mini.nvim (<1ms)
    spec "user.incline"
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
    spec "user.snippets"
    spec "user.guess-indent"
    spec "user.undo"
    spec "user.markdown-toc"
    spec "user.sticky-notes"
end

-- navigation startup: 17.04/16.71
if vim.g.loaded_categories.navigation then
    spec "user.arrow"
    spec "user.flash"
    spec "user.navbuddy"
    spec "user.qf"
end

-- AI startup: 16.84/17.18
if vim.g.loaded_categories.ai then
    --spec "user.lluminate"
    spec "user.codecompanion"
end

-- optional plugins startup: 17.93/18.03
if vim.g.loaded_categories.optional then
    spec "user.optional.colorizer"
    spec "user.optional.dial"
    spec "user.optional.csv"
    spec "user.optional.dim"
    spec "user.optional.cinnamon"
    spec "user.optional.typst"
    spec "user.optional.cloack"
    spec "user.optional.debugging"
    spec "user.optional.tpipeline"
end

-- tutorials - lazy loaded only when :Tutorials is called
spec "user.tutorials"

-- load user-specific lua modules that return plugin specs (before lazy initialization)
local usr_dir = vim.fn.stdpath("config") .. "/lua/" .. vim.loop.os_getenv("USER")
local usr_stat = vim.loop.fs_stat(usr_dir)
local user_modules_to_load_after = {}
if usr_stat and usr_stat.type == "directory" then
    local files = vim.fn.glob(usr_dir .. "/*.lua", false, true)
    for _, file in ipairs(files) do
        local base_name = vim.fn.fnamemodify(file, ":t:r")
        local module_name = base_name:gsub("/", ".")
        local full_module_name = vim.loop.os_getenv("USER") .. "." .. module_name
        local ok, m = pcall(require, full_module_name)
        if ok then
            if type(m) == "table" and m.config ~= nil then
                -- treat as lazyvim spec - insert directly into LAZY_PLUGIN_SPEC
                table.insert(LAZY_PLUGIN_SPEC, m)
            else
                -- not a plugin spec, unload and defer loading until after lazy initialization
                package.loaded[full_module_name] = nil
                table.insert(user_modules_to_load_after, full_module_name)
            end
        else
            -- module errored (likely depends on lazy plugins), unload and defer
            package.loaded[full_module_name] = nil
            table.insert(user_modules_to_load_after, full_module_name)
        end
    end
end

-- lazy needs to be loaded last
require "user.lazy"

-- load remaining user-specific modules that aren't plugin specs
for _, module_name in ipairs(user_modules_to_load_after) do
    local ok, err = pcall(require, module_name)
    if not ok then
        vim.notify("Error loading " .. module_name .. ": " .. err)
    end
end
