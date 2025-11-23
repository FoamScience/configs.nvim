local M = {
    "ahmedkhalf/project.nvim",
    event = "VeryLazy",
}

function M.config()
    require("project_nvim").setup {
        active = true,
        on_config_done = nil,
        manual_mode = false,
        detection_methods = { "pattern" },
        patterns = { ".git", "_darcs", ".hg", ".bzr", ".svn", "Makefile", "package.json", "pom.xml", "Make", "system" },
        ignore_lsp = {},
        exclude_dirs = {},
        show_hidden = false,
        silent_chdir = true,
        scope_chdir = "global",
    }

    vim.keymap.set("n", "<c-p>", function() require('snacks').picker.projects() end, { desc = "Open projects picker" })
end

return M
