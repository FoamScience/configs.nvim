local M = {
    "folke/snacks.nvim",
    priority = 1000,
}

M.config = function()
    local v = vim.version()
    local version_str = string.format("v%d.%d.%d", v.major, v.minor, v.patch)
    local minor_str = string.format("v%d.%d", v.major, v.minor)

    local header = table.concat({
        "",
        "NVIM " .. version_str,
        "",
        "Nvim is open source and freely distributable",
        "https://neovim.io/#chat",
        "",
        "type  :help nvim<Enter>       if you are new!",
        "type  :checkhealth<Enter>     to optimize Nvim",
        "type  :q<Enter>               to exit",
        "type  :help<Enter>            for help",
        "",
        "type  :help news<Enter> to see changes in " .. minor_str,
        "",
        "Help poor children in Uganda!",
        "type  :help Kuwasha<Enter>    for information",
    }, "\n")

    -- Quick health check (all local, fast)
    local checks = {
        { "node",        vim.fn.executable("node") == 1 },
        { "python",      vim.fn.executable("python3") == 1 or vim.fn.executable("python") == 1 },
        { "rg",          vim.fn.executable("rg") == 1 },
        { "tree-sitter", vim.fn.executable("tree-sitter") == 1 },
        { "rust",        vim.fn.executable("rustc") == 1 },
        { "git",         vim.fn.executable("git") == 1 },
    }
    local health_parts = {}
    for _, c in ipairs(checks) do
        table.insert(health_parts, (c[2] and "✓" or "✗") .. " " .. c[1])
    end
    local health_line = table.concat(health_parts, "  ")

    -- Config git status (local only, no fetch)
    local config_dir = vim.fn.stdpath("config")
    local behind_raw = vim.fn.system("cd " .. config_dir .. " && git rev-list HEAD..origin/master --count 2>/dev/null")
    local behind_count = tonumber(behind_raw and behind_raw:gsub("%s+", "")) or 0
    local git_line = behind_count > 0
        and string.format("Config is %d commit(s) behind  —  :ConfigNews", behind_count)
        or "Config is up to date"

    require("snacks").setup({
        dashboard = {
            enabled = true,
            preset = { header = header },
            sections = {
                { section = "header" },
                { padding = 1 },
                { text = health_line, align = "center" },
                { text = git_line, align = "center" },
                { section = "startup" },
            },
        },
        styles = {
            snacks_image = {
                relative = "editor",
                col = -1,
                row = 2,
            },
        },
        -- @WARN: NEVER INCLUDE THIS. IT IS JUST SLOW
        --  quickfile = {
        --      enabled = true,
        --  },
        animate = {},
        indent = {
            enabled = true,
        },
        input = {
            border = "rounded",
        },
        image = {
            enabled = true,
            doc = {
                inline = false,
                float = true,
            },
            convert = {
                notify = false,
            }
        },
        picker = {
            enabled = true,
            layout = {
                width = 0.9,
                --reverse = true,
                --layout = {
                --    box = "horizontal",
                --    backdrop = false,
                --    width = 0.9,
                --    height = 0.9,
                --    border = "none",
                --    {
                --        box = "vertical",
                --        {
                --            win = "list",
                --            title = " Results ",
                --            title_pos = "center",
                --            border = "rounded"
                --        },
                --        {
                --            win = "input",
                --            height = 1,
                --            border = "rounded",
                --            title = "{title} {live} {flags}",
                --            title_pos = "center"
                --        },
                --    },
                --    {
                --        win = "preview",
                --        title = "{preview:Preview}",
                --        width = 0.50,
                --        border = "rounded",
                --        title_pos = "center",
                --    },
                --},
            }
        }
    })

    -- redirect :marks and :registers to snacks picker
    vim.cmd([[
        cnoreabbrev <expr> marks getcmdtype() == ':' && getcmdline() == 'marks' ? 'lua require("snacks").picker.marks()' : 'marks'
        cnoreabbrev <expr> registers getcmdtype() == ':' && getcmdline() == 'registers' ? 'lua require("snacks").picker.registers()' : 'registers'
        cnoreabbrev <expr> reg getcmdtype() == ':' && getcmdline() == 'reg' ? 'lua require("snacks").picker.registers()' : 'reg'
    ]])
end

return M
