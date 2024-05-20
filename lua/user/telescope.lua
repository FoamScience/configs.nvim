local M = {
    "nvim-telescope/telescope.nvim",
    dependencies = {
        "nvim-lua/plenary.nvim",
        {
            "nvim-telescope/telescope-fzf-native.nvim",
            build = "make",
            lazy = true
        },
        { "nvim-telescope/telescope-symbols.nvim" },
        { "polirritmico/telescope-lazy-plugins.nvim" },
        { "isak102/telescope-git-file-history.nvim",  dependencies = { "tpope/vim-fugitive" } },
        { "debugloop/telescope-undo.nvim" },
    },
    lazy = true,
    cmd = "Telescope",
}

function M.config()
    local icons = require("user.lspicons")
    local actions = require("telescope.actions")
    local layout_ops = {
        layout_config = {
            width = 0.90,
            height = 0.85,
            preview_cutoff = 120,
            horizontal = {
                prompt_position = "top",
                preview_width = 0.55,
            },
            vertical = {
                mirror = false,
            },
        },
        layout_strategy = "horizontal",
        winblend = 0,
        border = {},
    }

    require("telescope").setup({
        defaults = {
            prompt_prefix = icons.ui.Telescope .. " ",
            selection_caret = icons.ui.Forward .. " ",
            scroll_strategy = "limit",
            entry_prefix = "   ",
            initial_mode = "insert",
            selection_strategy = "reset",
            path_display = { "smart" },
            file_ignore_patterns = {
                ".git/",
                "lnInclude/",
                ".cache", "build/",
                "%.png", "%.jpg", "%.jpeg", "%.gif", "%.svg", "%.ico",
                "%.otf", "%.ttf", "%.woff", "%.woff2",
                "%.pdf",
                "%.zip",
            },
            color_devicons = true,
            set_env = { ["COLORTERM"] = "truecolor" },
            sorting_strategy = "ascending",
            file_previewer = require("telescope.previewers").vim_buffer_cat.new,
            grep_previewer = require("telescope.previewers").vim_buffer_vimgrep.new,
            qflist_previewer = require("telescope.previewers").vim_buffer_qflist.new,
            file_sorter = require("telescope.sorters").get_fzy_sorter,
            generic_sorter = require("telescope.sorters").get_fzy_sorter,
            buffer_previewer_maker = require("telescope.previewers").buffer_previewer_maker,
            vimgrep_arguments = {
                "rg",
                "--color=never",
                "--no-heading",
                "--with-filename",
                "--line-number",
                "--column",
                "--smart-case",
                "--hidden",
                "--glob=!.git/",
                "--glob=!lnInclude/",
            },

            mappings = {
                i = {
                    ["<C-n>"] = actions.cycle_history_next,
                    ["<C-p>"] = actions.cycle_history_prev,

                    ["<C-j>"] = actions.move_selection_next,
                    ["<C-k>"] = actions.move_selection_previous,
                },
                n = {
                    ["<esc>"] = actions.close,
                    ["j"] = actions.move_selection_next,
                    ["k"] = actions.move_selection_previous,
                    ["q"] = actions.close,
                },
            },
        },
        pickers = {
            live_grep = vim.tbl_extend("force", layout_ops, {
                previewer = true,
            }),

            grep_string = vim.tbl_extend("force", layout_ops, {
                previewer = true,
            }),

            find_files = vim.tbl_extend("force", layout_ops, {
                previewer = true,
            }),

            buffers = {
                theme = "dropdown",
                previewer = false,
                initial_mode = "normal",
                mappings = {
                    i = {
                        ["<C-d>"] = actions.delete_buffer,
                    },
                    n = {
                        ["dd"] = actions.delete_buffer,
                    },
                },
            },

            colorscheme = {
                enable_preview = true,
            },

            lsp_references = {
                theme = "dropdown",
                initial_mode = "normal",
            },

            lsp_definitions = {
                theme = "dropdown",
                initial_mode = "normal",
            },

            lsp_declarations = {
                theme = "dropdown",
                initial_mode = "normal",
            },

            lsp_implementations = {
                theme = "dropdown",
                initial_mode = "normal",
            },
        },
        extensions = {
            fzf = {
                fuzzy = true,                   -- false will only do exact matching
                override_generic_sorter = true, -- override the generic sorter
                override_file_sorter = true,    -- override the file sorter
                case_mode = "smart_case",       -- or "ignore_case" or "respect_case"
            },
            lazy_plugins = {},
            git_file_history = {},
            undo = {
                use_delta = true,
                diff_context_lines = 10,
            },
        },
    })
end

return M
