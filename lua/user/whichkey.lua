local M = {
    "folke/which-key.nvim",
    event = "VeryLazy",
}

local is_file_type = function(filetype)
    local buf = vim.api.nvim_get_current_buf()
    local ft = vim.api.nvim_get_option_value("filetype", { buf = buf })
    return ft == filetype
end

function M.config()
    local wk = require "which-key"
    local icons = require("user.lspicons")
    local mappings = {
        {
            "<leader>?",
            function()
                require("which-key").show({ global = false })
            end,
            desc = "Buffer Local Keymaps",
        },
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
    }

    local mtoc_keys = {}
    if vim.bo.filetype == "markdown" or vim.bo.filetype == "rmd" then
        mtoc_keys = {
            { "<leader>et",  group = "Markdown TOC", icon = icons.ui.List },
            { "<leader>eti", "<cmd>Mtoc insert<CR>", desc = "Insert the ToC for current buffer",  icon = icons.ui.Plus,                 mode = { "n" } },
            { "<leader>etu", "<cmd>Mtoc update<CR>", desc = "Update the ToC for current buffer",  icon = icons.ui.History },
            { "<leader>etp", "<cmd>Mtoc pick<CR>",   desc = "Pick the ToC ",                      icon = icons.diagnostics.BoldQuestion },
            { "<leader>etr", "<cmd>Mtoc remove<CR>", desc = "Remove the ToC from current buffer", icon = icons.diagnostics.BoldError },
        }
        vim.keymap.set({ 'x', 'o' }, 'aT',
            function() return require('mtoc')._select_toc_textobj(false) end,
            { expr = true, desc = 'outer ToC' })
        vim.keymap.set({ 'x', 'o' }, 'iT',
            function() return require('mtoc')._select_toc_textobj(true) end,
            { expr = true, desc = 'inner ToC' })
    end
    vim.list_extend(mappings, {
        { "<leader>e",  group = "Edit",                              icon = icons.ui.Pencil },
        { "<leader>ee", "<cmd>NvimTreeToggle<CR>",                   desc = "Explorer",     icon = icons.ui.Folder },
        { "<leader>eu", "<cmd>lua require('undotree').toggle()<CR>", desc = "Undo Tree",    icon = icons.ui.History },
        unpack(mtoc_keys),
    })
    local sticky_ok, _ = pcall(require, "stickynotes")
    if sticky_ok then
        vim.list_extend(mappings, {
            { "<leader>k", group = "StickyNotes", icon = icons.ui.BookMark },
            {
                "<leader>kk",
                "<cmd>StickyNotes<cr>",
                desc = "Create a default note",
            },
            {
                "<leader>kl",
                "<cmd>StickyNotesList<cr>",
                desc = "List current project notes",
            },
            {
                "<leader>kn",
                "<cmd>StickyNotesNew<cr>",
                desc = "Create a named project note",
            },
        })
    end

    vim.list_extend(mappings, {
        { "<leader>l",  group = "LSP",        icon = icons.kind.Class,  mode = { "n", "v" } },
            {
                "<leader>la",
                vim.lsp.buf.code_action,
                desc = "Code actions",
                icon = icons.ui.BoxChecked,
            },
            {
                "<leader>ld",
                function() require("snacks").picker.lsp_definitions() end,
                desc = "Symbol definition",
                icon = icons.kind.Function,
            },
            {
                "gd",
                vim.lsp.buf.definition,
                desc = "Native LSP definition",
                icon = icons.kind.Function,
            },
            {
                "<leader>lD",
                function() require("snacks").picker.lsp_type_definitions() end,
                desc = "Type definition",
                icon = icons.kind.TypeParameter,
            },
            {
                "gD",
                vim.lsp.buf.declaration,
                desc = "Native LSP definition",
                icon = icons.kind.Function,
            },
            {
                "<leader>lh",
                vim.lsp.buf.typehierarchy,
                cond = function() return not is_file_type("cpp") end,
                desc = "Inheritence tree",
                icon = icons.kind.Class,
            },
            {
                "<leader>lh",
                "<cmd>ClangdTypeHierarchy<CR>",
                cond = function() return is_file_type("cpp") end,
                desc = "Inheritence tree",
                icon = icons.kind.Class,
            },
            {
                "<leader>lH",
                "<cmd>ClangdSwitchSourceHeader<CR>",
                cond = function() return is_file_type("cpp") end,
                desc = "Switch header/source file",
                icon = icons.kind.Boolean,
            },
            {
                "<leader>lf",
                "<cmd>lua vim.lsp.buf.format({async = true, timeout_ms = 1000000})<cr>",
                desc = "Format",
                icon = icons.kind.Namespace,
            },
            {
                "<leader>lg",
                function() vim.diagnostic.open_float(nil, { focus = false }) end,
                desc = "Line diagnostics",
                icon = icons.ui.Bug,
            },
            {
                "<leader>lG",
                function() require("snacks").picker.diagnostics() end,
                desc = "Diagnostics",
                icon = icons.ui.Bug,
            },
            { "<leader>lc", group = "Call graph", icon = icons.kind.Struct, mode = { "n", "v" } },
            {
                "<leader>lco",
                vim.lsp.buf.outgoing_calls,
                desc = "Outgoing calls",
                icon = icons.ui.ArrowCircleUp,
            },
            {
                "<leader>lci",
                vim.lsp.buf.incoming_calls,
                desc = "Incoming calls",
                icon = icons.ui.ArrowCircleDown,
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
                function() require("snacks").picker.lsp_references() end,
                desc = "References",
                icon = icons.kind.Reference,
            },
            {
                "gR",
                vim.lsp.buf.references,
                desc = "Native LSP references",
                icon = icons.kind.Function,
            },
            {
                "gi",
                vim.lsp.buf.implementation,
                desc = "Native LSP implementation",
                icon = icons.kind.Function,
            },
            {
                "gt",
                vim.lsp.buf.type_definition,
                desc = "Native LSP type definition",
                icon = icons.kind.Function,
            },
            {
                "<c-k>",
                vim.lsp.buf.signature_help,
                desc = "Native LSP type definition",
                icon = icons.kind.Function,
            },
            {
                "<leader>ls",
                function() require("snacks").picker.lsp_symbols() end,
                desc = "Document Symbols",
                icon = icons.kind.Keyword,
            },
            {
                "<leader>lS",
                function() require("snacks").picker.lsp_workspace_symbols() end,
                desc = "Workspace Symbols",
                icon = icons.kind.Variable,
            },
            {
                "<leader>ln",
                function()
                    local hints_on = vim.lsp.inlay_hint.is_enabled({})
                    vim.lsp.inlay_hint.enable(not hints_on)
                end,
                desc = "Toggle inlay hints",
                icon = icons.ui.Fire
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

            { "<leader>q", group = "QuickFix",   icon = icons.ui.Watches, mode = { "n", "v" } },
            {
                "<leader>qd",
                function() vim.diagnostic.setqflist({ open = true }) end,
                desc = "Quick diagnostics",
                icon = icons.ui.Bug
            },
            {
                "<leader>qt",
                "<cmd>TodoQuickFix<CR>",
                desc = "Todos",
                icon = icons.ui.Note
            },
            {
                "<leader>qq",
                "<cmd>copen<CR>",
                desc = "Open quickfix list",
                icon = icons.ui.Search
            },
    })

    vim.list_extend(mappings, {
            { "<leader>g", group = "Git", icon = icons.git.Branch },
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
                "<leader>gp",
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
                "<leader>gdd",
                "<cmd>Gitsigns diffthis HEAD<cr>",
                desc = "Diff this buffer against HEAD",
            },
            {
                "<leader>gdv",
                "<cmd>DiffviewOpen<cr>",
                desc = "Open repo diff view",
            },
            {
                "<leader>gh",
                "<cmd>DiffviewFileHistory<cr>",
                desc = "Git History for All files",
            },
            {
                "<leader>gt",
                "<cmd>DiffConflicts<cr>",
                desc = "Diff Conflicts",
            },
    })

    vim.list_extend(mappings, {
            { "<leader>f", group = "Find", icons.ui.Telescope },
            {
                "<leader>f:",
                function() require("snacks").picker.command_history() end,
                desc = "Command history",
            },
            {
                "<leader>fb",
                function() require("snacks").picker.git_branches() end,
                desc = "Checkout branch",
            },
            {
                "<leader>fB",
                function() require("snacks").picker.buffers() end,
                desc = "Buffers",
            },
            {
                "<leader>fc",
                function() require("snacks").picker.colorschemes() end,
                desc = "Colorscheme",
            },
            {
                "<leader>ff",
                function() require("snacks").picker.files() end,
                desc = "Find files",
            },
            {
                "<leader>fg",
                function() require("snacks").picker.git_log_file() end,
                desc = "This buffer's Git history",
            },
            {
                "<leader>fs",
                function() require("snacks").picker.grep_word() end,
                desc = "Find String",
            },
            {
                "<leader>fh",
                function() require("snacks").picker.help() end,
                desc = "Help",
            },
            {
                "<leader>fH",
                function() require("snacks").picker.highlights() end,
                desc = "Highlights",
            },
            {
                "<leader>fl",
                function() require("snacks").picker.resume() end,
                desc = "Last Search",
            },
            {
                "<leader>fM",
                function() require("snacks").picker.man() end,
                desc = "Man Pages",
            },
            {
                "<leader>fr",
                function() require("snacks").picker.recent() end,
                desc = "Recent File",
            },
            {
                "<leader>fR",
                function() require("snacks").picker.registers() end,
                desc = "Registers",
            },
            {
                "<leader>fk",
                function() require("snacks").picker.keymaps() end,
                desc = "Keymaps",
            },
            {
                "<leader>fC",
                function() require("snacks").picker.commands() end,
                desc = "Commands",
            },
            {
                "<leader>fp",
                function() require("snacks").picker.projects() end,
                desc = "List projects",
            },
            {
                "<leader>fP",
                function() require("snacks").picker.lazy() end,
                desc = "Plugin configs",
            },
            {
                "<leader>fu",
                function() require("snacks").picker.undo() end,
                desc = "Undo tree",
            },
    })

    if vim.bo.filetype == "csv" then
        vim.list_extend(mappings, {
            { "<leader>c", group = "CSV", icon = icons.ui.Table },
            {
                "<leader>cv",
                "<cmd>CsvViewToggle display_mode=border<cr>",
                desc = "Toggle CSV display",
            },
        })
    end

    -- Tutorial system (only if started without files)
    local function started_with_files()
        local args = vim.fn.argv()
        for _, arg in ipairs(args) do
            if not arg:match("^%-") then
                return true
            end
        end
        return false
    end

    if not started_with_files() then
        vim.list_extend(mappings, {
            { "<leader>t", group = "Tutorials", icon = icons.ui.BookMark },
            {
                "<leader>tt",
                "<cmd>Tutorials<cr>",
                desc = "Open tutorial picker",
            },
            {
                "<leader>tn",
                "<cmd>TutorialNext<cr>",
                desc = "Next step",
            },
            {
                "<leader>tp",
                "<cmd>TutorialPrev<cr>",
                desc = "Previous step",
            },
            {
                "<leader>tq",
                "<cmd>TutorialQuit<cr>",
                desc = "Quit tutorial",
            },
            {
                "<leader>tr",
                "<cmd>TutorialRestart<cr>",
                desc = "Restart tutorial",
            },
        })
    end

    wk.setup {
        preset = "helix",
        spec = mappings,
        notify = true,
        keys = {
            scroll_down = "<c-d>",
            scroll_up = "<c-u>",
        },
        sort = { "local", "order", "manual", "group", "alphanum", "mod" },
    }
end

return M
