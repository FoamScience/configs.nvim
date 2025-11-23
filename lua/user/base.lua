LAZY_PLUGIN_SPEC = {}

-- Preset system: determines which plugins to load
-- Presets can be set via:
-- 1. Environment variable: NVIM_PRESET=ssh nvim
-- 2. Local preset file: ~/.config/nvim/preset.lua (return "ssh" or "full")
-- 3. Default: "full"
local function get_active_preset()
    -- Check for local preset file first (higher priority)
    local preset_file = vim.fn.stdpath("config") .. "/preset.lua"
    if vim.loop.fs_stat(preset_file) then
        local ok, preset = pcall(dofile, preset_file)
        if ok and type(preset) == "string" then
            return preset
        end
    end

    -- Check environment variable
    local env_preset = vim.loop.os_getenv("NVIM_PRESET")
    if env_preset then
        return env_preset
    end

    -- Default to full
    return "full"
end

vim.g.active_preset = get_active_preset()

-- spec() function: adds plugin spec to load list
-- Optional presets parameter limits which presets load this plugin
-- Examples:
--   spec("user.colorscheme") -- loads in all presets
--   spec("user.nvimtree", {"full"}) -- only loads in "full" preset
function spec(item, presets)
    presets = presets or {"full", "ssh"} -- default: load in all presets

    -- Check if current preset is in the allowed presets list
    if vim.tbl_contains(presets, vim.g.active_preset) then
        table.insert(LAZY_PLUGIN_SPEC, { import = item })
    end
end
