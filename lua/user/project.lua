local M = {
    'DrKJeff16/project.nvim',
    dependencies = { 'folke/snacks.nvim', },
    cmd = {
        'Project',
        'ProjectAdd',
        'ProjectConfig',
        'ProjectDelete',
        'ProjectExport',
        'ProjectFzf', -- If using `fzf-lua` integration
        'ProjectHealth',
        'ProjectHistory',
        'ProjectImport',
        'ProjectLog', -- If logging is enabled
        'ProjectRecents',
        'ProjectRoot',
        'ProjectSession',
        'ProjectSnacks', -- If using `snacks.nvim` integration
    },
}

function M.config()
    require("project").setup {
        active = true,
        on_config_done = nil,
        manual_mode = false,
        detection_methods = { "pattern" },
        patterns = { ".git", "_darcs", ".hg", ".bzr", ".svn",
            "Makefile", "package.json", "pom.xml", "Make", "system",
            ".pre-commit-config.yaml", ".pre-commit-config.yml", "pyproject.yaml", "pyproject.toml" },
        snacks = { enabled = true },
        ignore_lsp = {},
        exclude_dirs = {},
        show_hidden = false,
        silent_chdir = true,
        scope_chdir = "global",
    }

    vim.keymap.set("n", "<c-p>", function() require('snacks').picker.projects() end, { desc = "Open projects picker" })
end

return M
