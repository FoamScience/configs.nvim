local M = {
    "folke/which-key.nvim",
    event = "VeryLazy",
    dependencies = {
        "echasnovski/mini.nvim"
    },
}

function M.config()
    local wk = require "which-key"
    local icons = require("user.lspicons")
    local mappings = {}
    if vim.g.loaded_categories.navigation then
        vim.list_extend(mappings, {
            { "<leader>n", group = "navigation", icon = icons.ui.Forward },
            {
                "<leader>nb",
                "<cmd>lua require('arrow.ui').openMenu()<CR>",
                desc = "Arrow",
                icon = icons.ui.History,
            },
            {
                "<leader>nn",
                "<cmd>Navbuddy<cr>",
                desc = "NavBuddy",
            },
        })
    end
    if vim.g.loaded_categories.edit then
        vim.list_extend(mappings, {
            { "<leader>e",  group = "Edit",            icon = icons.ui.Pencil },
            { "<leader>ee", "<cmd>NvimTreeToggle<CR>", desc = "Explorer",     icon = icons.ui.Folder },
            { "<leader>er", "<cmd>Registers<CR>", desc = "Registers",     icon = icons.ui.List },
        })
    end
    if vim.g.loaded_categories.ai then
        vim.list_extend(mappings, {
            { "<leader>c", group = "Cody", icon = icons.misc.Robot, mode = { "n", "v" } },
            {
                "<leader>cc",
                "<cmd>CodyChat<CR>",
                desc = "Cody Chat",
            },
            {
                "<leader>cr",
                "<cmd>CodyToggle<CR>",
                desc = "Cody Toggle",
            },
            {
                "<leader>ce",
                ":CodyExplain<CR>",
                desc = "Cody Explain",
                mode = "v",
            },
            { "<leader>s", group = "Sourcegraph", icon = icons.ui.Target, mode = { "n", "v" } },
            --{
            --    "<leader>ss",
            --    "<cmd>lua require('sg.extensions.telescope').fuzzy_search_results()<cr>",
            --    desc = "Search public code"
            --},
            { "<leader>a", group = "AI", icon = icons.ui.Target, mode = { "n", "v" } },
            {
                "<leader>ac",
                "<cmd>EnrichContext<cr>",
                desc = "Entrich code context",
                mode = "v",
            },
            {
                "<leader>ax",
                function() require("codecompanion").prompt("explain") end,
                desc = "Explain with CodeCompanion",
                mode = "v",
            },
            {
                "<leader>at",
                function() require("codecompanion").prompt("tests") end,
                desc = "Generate Unit tests",
                mode = "v",
            },
            {
                "<leader>af",
                function() require("codecompanion").prompt("fix") end,
                desc = "Fix selected code",
                mode = "v",
            },
            {
                "<leader>ar",
                function() require("codecompanion").prompt("review") end,
                desc = "Review code with CodeCompanion",
                icon = icons.git.Diff,
                mode = "v",
            },
            {
                "<leader>al",
                function() require("codecompanion").prompt("lsp") end,
                desc = "Explain LSP diagnostics",
                mode = {"n", "v"},
            },
            {
                "<leader>ag",
                function() require("codecompanion").prompt("commit") end,
                desc = "Generate Git Commit from Diffs",
                mode = "n"
            },
            {
                "<leader>aw",
                function() require("codecompanion").prompt("workflow") end,
                desc = "Write code with Workflow-Guided-LLM",
                mode = "n"
            },
        })
    end
    if vim.g.loaded_categories.lsp then
        vim.list_extend(mappings, {
            { "<leader>l", group = "LSP", icon = icons.kind.Class, mode = { "n", "v" } },
            {
                "<leader>ld",
                "<cmd>Telescope lsp_definitions<cr>",
                desc = "Symbol definition",
                icon = icons.kind.Function,
            },
            {
                "<leader>lD",
                "<cmd>Telescope lsp_type_definitions<cr>",
                desc = "Type definition",
                icon = icons.kind.TypeParameter,
            },
            {
                "<leader>lf",
                "<cmd>lua vim.lsp.buf.format({timeout_ms = 1000000})<cr>",
                desc = "Format",
                icon = icons.kind.Namespace,
            },
            {
                "<leader>lg",
                "<cmd>Telescope diagnostics<cr>",
                desc = "Diagnostics",
                icon = icons.ui.Bug,
            },
            {
                "<leader>li",
                "<cmd>LspInfo<cr>",
                desc = "Info",
                icon = icons.kind.Lightbulb,
            },
            {
                "<leader>lI",
                "<cmd>Mason<cr>",
                desc = "Mason Info",
                icon = icons.kind.Gear,
            },
            {
                "<leader>lj",
                "<cmd>lua vim.diagnostic.goto_next()<cr>",
                desc = "Next diagnostic",
                icon = icons.ui.BoldArrowRight,
            },
            {
                "<leader>lk",
                "<cmd>lua vim.diagnostic.goto_prev()<cr>",
                desc = "Prev diagnostic",
                icon = icons.ui.BoldArrowLeft,
            },
            {
                "<leader>ll",
                "<cmd>lua vim.lsp.codelens.run()<cr>",
                desc = "CodeLens",
                icon = icons.ui.Watches,
            },
            {
                "<leader>lq",
                "<cmd>lua vim.diagnostic.setloclist()<cr>",
                desc = "Quickfix",
                icon = icons.ui.List,
            },
            {
                "<leader>lr",
                "<cmd>lua vim.lsp.buf.rename()<cr>",
                desc = "Rename",
                icon = icons.git.FileRename,
            },
            {
                "<leader>lR",
                "<cmd>Telescope lsp_references<cr>",
                desc = "References",
                icon = icons.kind.Reference,
            },
            {
                "<leader>ls",
                "<cmd>Telescope lsp_document_symbols<cr>",
                desc = "Document Symbols",
                icon = icons.kind.Keyword,
            },
            {
                "<leader>lS",
                "<cmd>Telescope lsp_dynamic_workspace_symbols<cr>",
                desc = "Workspace Symbols",
                icon = icons.kind.Variable,
            },
            {
                "<leader>la",
                function() require("tiny-code-action").code_action() end,
                desc = "Code actions",
                icon = icons.ui.Target,
            },
            {
                "<leader>lor",
                "<cmd>OverseerRun<cr>",
                desc = "Overseer Run",
                icon = icons.ui.Run
            },
            {
                "<leader>lot",
                "<cmd>OverseerToggle<cr>",
                desc = "Overseer Toggle",
                icon = icons.ui.Gear
            },
            {
                "<leader>lob",
                "<cmd>OverseerBuild<cr>",
                desc = "Overseer Build",
                icon = icons.ui.Gears
            },

            { "<leader>T", group = "TreeSitter", icon = icons.ui.Code },
            {
                "<leader>Ti",
                "<cmd>TSConfigInfo<cr>",
                desc = "Info",
                icon = icons.kind.Lightbulb,
            },
            {
                "<leader>Tt",
                "<cmd>InspectTree<cr>",
                desc = "Inspect Tree",
                icon = icons.ui.Search
            },
        })
    end
    if vim.g.loaded_categories.git then
        vim.list_extend(mappings, {
            { "<leader>d", group = "Diff", icon = icons.git.Diff },
            {
                "<leader>do",
                "<cmd>DiffviewOpen<cr>",
                desc = "Open Diff",
            },
            {
                "<leader>dh",
                "<cmd>DiffviewFileHistory<cr>",
                desc = "File History",
            },

            { "<leader>g", group = "Git",  icon = icons.git.Branch },
            {
                "<leader>gn",
                "<cmd>Neogit<cr>",
                desc = "Neogit",
            },
            {
                "<leader>gj",
                "<cmd>lua require 'gitsigns'.next_hunk({navigation_message = false})<cr>",
                desc = "Next Hunk"
            },
            {
                "<leader>gk",
                "<cmd>lua require 'gitsigns'.prev_hunk({navigation_message = false})<cr>",
                desc = "Previous Hunk"
            },
            {
                "<leader>gl",
                "<cmd>lua require 'gitsigns'.blame_line()<cr>",
                desc = "Blame"
            },
            {
                "<leader>gP",
                "<cmd>lua require 'gitsigns'.preview_hunk()<cr>",
                desc = "Preview Hunk"
            },
            {
                "<leader>gr",
                "<cmd>lua require 'gitsigns'.reset_hunk()<cr>",
                desc = "Reset Hunk"
            },
            {
                "<leader>gR",
                "<cmd>lua require 'gitsigns'.reset_buffer()<cr>",
                desc = "Reset Buffer",
            },
            {
                "<leader>gs",
                "<cmd>lua require 'gitsigns'.stage_hunk()<cr>",
                desc = "Stage Hunk",
            },
            {
                "<leader>gu",
                "<cmd>lua require 'gitsigns'.undo_stage_hunk()<cr>",
                desc = "Undo Stage Hunk",
            },
            {
                "<leader>gd",
                "<cmd>Gitsigns diffthis HEAD<cr>",
                desc = "Git Diff",
            },
            {
                "<leader>gt",
                "<cmd>DiffConflicts<cr>",
                desc = "Diff Conflicts",
            },
        })
    end
    if vim.g.loaded_categories.telescope then
        vim.list_extend(mappings, {
            { "<leader>f", group = "Telescope", icons.ui.Telescope },
            {
                "<leader>fb",
                "<cmd>Telescope git_branches<cr>",
                desc = "Checkout branch",
            },
            {
                "<leader>fB",
                "<cmd>Telescope buffers previewer=false<cr>",
                desc = "Buffers",
            },
            {
                "<leader>fc",
                "<cmd>Telescope colorscheme<cr>",
                desc = "Colorscheme",
            },
            {
                "<leader>ff",
                "<cmd>Telescope find_files<cr>",
                desc = "Find files",
            },
            {
                "<leader>fF",
                "<cmd>Telescope git_file_history<cr>",
                desc = "Git file history",
            },
            {
                "<leader>fs",
                "<cmd>Telescope grep_string<cr>",
                desc = "Find String",
            },
            {
                "<leader>fh",
                "<cmd>Telescope help_tags<cr>",
                desc = "Help",
            },
            {
                "<leader>fH",
                "<cmd>Telescope highlights<cr>",
                desc = "Highlights",
            },
            {
                "<leader>fl",
                "<cmd>Telescope resume<cr>",
                desc = "Last Search",
            },
            {
                "<leader>fM",
                "<cmd>Telescope man_pages<cr>",
                desc = "Man Pages",
            },
            {
                "<leader>fr",
                "<cmd>Telescope oldfiles<cr>",
                desc = "Recent File",
            },
            {
                "<leader>fR",
                "<cmd>Telescope registers<cr>",
                desc = "Registers",
            },
            {
                "<leader>fk",
                "<cmd>Telescope keymaps<cr>",
                desc = "Keymaps",
            },
            {
                "<leader>fC",
                "<cmd>Telescope commands<cr>",
                desc = "Commands",
            },
            {
                "<leader>fp",
                "<cmd>Telescope projects<cr>",
                desc = "List projects",
            },
            {
                "<leader>fP",
                "<cmd>Telescope lazy_plugins<cr>",
                desc = "Plugin configs",
            },
            {
                "<leader>fu",
                "<cmd>Telescope undo<cr>",
                desc = "Unto tree",
            },
        })
    end
    if vim.g.loaded_categories.optional then
        vim.list_extend(mappings, {
            { "<leader>o",  group = "Neorg",  icon=icons.ui.Note },
            { "<leader>oc", group = "Code", icons.ui.Files },
            {
                "<leader>ocm",
                "<Plug>(neorg.looking-glass.magnify-code-block)",
                desc = "Magnify code block",
            },
            { "<leader>oi", group = "Insert", icons.ui.Forward },
            {
                "<leader>oid",
                "<Plug>(neorg.tempus.insert-date)",
                desc = "Insertion date",
            },
            {
                "<leader>oif",
                "<cmd>Telescope neorg insert_file_link",
                desc = "Insert file link",
            },
            {
                "<leader>oil",
                "<cmd>Telescope neorg insert_link",
                desc = "Insert link",
            },
            { "<leader>ol", group = "List", icons.ui.List },
            {
                "<leader>oli",
                "<Plug>(neorg.pivot.list.invert)",
                desc = "List invert",
            },
            {
                "<leader>olt",
                "<Plug>(neorg.pivot.list.toggle)",
                desc = "List toggle",
            },
            { "<leader>on", group = "Note", icons.ui.Note },
            {
                "<leader>onn",
                "<Plug>(neorg.dirman.new-note)",
                desc = "New note",
            },
            { "<leader>ot", group = "Task", icons.ui.Tab },
            {
                "<leader>ota",
                "<Plug>(neorg.qol.todo-items.todo.task-ambiguous)",
                desc = "Task ambiguous",
            },
            {
                "<leader>otc",
                "<Plug>(neorg.qol.todo-items.todo.task-cancelled)",
                desc = "Task cancelled",
            },
            {
                "<leader>otd",
                "<Plug>(neorg.qol.todo-items.todo.task-done)",
                desc = "Task done",
            },
            {
                "<leader>oth",
                "<Plug>(neorg.qol.todo-items.todo.task-on-hold)",
                desc = "Task on hold",
            },
            {
                "<leader>oti",
                "<Plug>(neorg.qol.todo-items.todo.task-important)",
                desc = "Task important",
            },
            {
                "<leader>otp",
                "<Plug>(neorg.qol.todo-items.todo.task-pending)",
                desc = "Task pending",
            },
            {
                "<leader>otr",
                "<Plug>(neorg.qol.todo-items.todo.task-recurring)",
                desc = "Task recurring",
            },
            {
                "<leader>otu",
                "<Plug>(neorg.qol.todo-items.todo.task-undone)",
                desc = "Task undone",
            },
            { "<leader>of", group = "Find", icons.ui.Search },
            {
                "<leader>off",
                "<cmd>Telescope neorg find_neorg_files<cr>",
                desc = "Find files",
            },
            {
                "<leader>ofl",
                "<cmd>Telescope neorg find_linkable<cr>",
                desc = "Find linkable",
            },
            { "<leader>ow", group = "Workspaces", icons.ui.Files },
            {
                "<leader>ows",
                "<cmd>Telescope neorg switch_workspace<cr>",
                desc = "Workspace switch",
            },
        })
    end

    wk.setup {
        preset = "helix",
        spec = mappings,
        keys = {
            scroll_down = "<c-d>",
            scroll_up = "<c-u>",
        },
    }
end

return M
