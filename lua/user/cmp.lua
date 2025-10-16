local icons = require("user.lspicons")
local M = {
    "hrsh7th/nvim-cmp",
    dependencies = {
        {
            "hrsh7th/cmp-nvim-lsp",
        },
        --{
        --    "hrsh7th/cmp-emoji",
        --},
        {
            "hrsh7th/cmp-buffer",
        },
        {
            "hrsh7th/cmp-path",
        },
        {
            "iteratee/cmp-cmdline",
            branch = "kb/file-name-completion",
        },
        {
            "saadparwaiz1/cmp_luasnip",
        },
        {
            "L3MON4D3/LuaSnip",
            dependencies = {
                "rafamadriz/friendly-snippets",
            },
        },
        {
            "hrsh7th/cmp-nvim-lua",
        },
        --{
        --    "hrsh7th/cmp-nvim-lsp-signature-help",
        --},
        {
            "hrsh7th/cmp-calc",
        },
        {
            "FoamScience/cmp-nvim-lsp-document-symbol",
            branch = "override_kinds",
        },
        {
            "SergioRibera/cmp-dotenv",
        },
    },
    event = { "LspAttach", "InsertCharPre" },
}

local function buffer_source()
    local ft = vim.bo.filetype
    local lsp_clients = vim.lsp.get_clients({ bufnr = 0 })
    local is_non_lsp = #lsp_clients == 0
    if is_non_lsp or ft:match("markdown") or ft:match("tex") then
        return {
            name = "buffer",
            option = {
                get_bufnrs = function()
                    return { vim.api.nvim_get_current_buf() }
                end,
            }
        }
    else
        return nil
    end
end

function M.config()
    --vim.api.nvim_set_hl(0, "CmpItemKindCopilot", { fg = "#6CC644" })
    vim.api.nvim_set_hl(0, "CmpItemKindCrate", { fg = "#F64D00" })
    vim.api.nvim_set_hl(0, "CmpItemKindEmoji", { fg = "#FDE030" })

    local cmp = require("cmp")
    local luasnip = require("luasnip")
    require("luasnip/loaders/from_vscode").lazy_load()
    require("luasnip").filetype_extend("typescriptreact", { "html" })

    local check_backspace = function()
        local col = vim.fn.col(".") - 1
        return col == 0 or vim.fn.getline("."):sub(col, col):match("%s")
    end

    local source_display = {
        dotenv = { icon = icons.misc.Tag, hl_group = "CmpItemKindDefault" },
        --copilot = { icon = icons.git.Octoface, hl_group = "CmpItemKindCopilot" },
        nvim_lsp_signature_help = { icon = icons.ui.SignIn, hl_group = "CmpItemKindInterface" },
        buffer = { icon = icons.kind.File, hl_group = "CmpItemKindAbbr" },
        path = { icon = icons.ui.Files, hl_group = "CmpItemKindFile" },
        --emoji = { icon = ":) ", hl_group = "CmpItemKindEmoji" },
        treesitter = { icon = icons.ui.Tree, hl_group = "CmpItemKindClass" },
        crates = { icon = icons.ui.Package, hl_group = "CmpItemKindCrate" },
        tmux = { icon = icons.misc.Dos, hl_group = "CmpItemKindUnit" },
    }

    local cmp_important_sources = {
        { name = "path" },
        { name = "nvim_lsp" },
        { name = "luasnip" },
        { name = "nvim_lsp_document_symbol" },
    }

    cmp.setup({
        preselect = cmp.PreselectMode.None,
        snippet = {
            expand = function(args)
                luasnip.lsp_expand(args.body) -- For `luasnip` users.
            end,
        },
        mapping = cmp.mapping.preset.insert({
            ["<C-k>"] = cmp.mapping(cmp.mapping.select_prev_item(), { "i", "c" }),
            ["<C-j>"] = cmp.mapping(cmp.mapping.select_next_item(), { "i", "c" }),
            ["<Down>"] = cmp.mapping(cmp.mapping.select_next_item(), { "i", "c" }),
            ["<Up>"] = cmp.mapping(cmp.mapping.select_prev_item(), { "i", "c" }),
            ["<C-b>"] = cmp.mapping(cmp.mapping.scroll_docs(-1), { "i", "c" }),
            ["<C-f>"] = cmp.mapping(cmp.mapping.scroll_docs(1), { "i", "c" }),
            ["<C-Space>"] = cmp.mapping(cmp.mapping.complete(), { "i", "c" }),
            ["<C-e>"] = cmp.mapping({
                i = cmp.mapping.abort(),
                c = cmp.mapping.close(),
            }),
            -- Accept currently selected item. If none selected, `select` first item.
            -- Set `select` to `false` to only confirm explicitly selected items.
            ["<CR>"] = cmp.mapping.confirm({ select = true }),
            ["<Tab>"] = cmp.mapping(function(fallback)
                if cmp.visible() then
                    cmp.select_next_item()
                elseif luasnip.expandable() then
                    luasnip.expand()
                elseif luasnip.expand_or_jumpable() then
                    luasnip.expand_or_jump()
                elseif check_backspace() then
                    fallback()
                else
                    fallback()
                end
            end, {
                "i",
                "s",
            }),
            ["<S-Tab>"] = cmp.mapping(function(fallback)
                if cmp.visible() then
                    cmp.select_prev_item()
                elseif luasnip.jumpable(-1) then
                    luasnip.jump(-1)
                else
                    fallback()
                end
            end, {
                "i",
                "s",
            }),
        }),
        formatting = {
            fields = { "kind", "abbr" },
            format = function(entry, vim_item)
                if source_display[entry.source.name] ~= nil then
                    vim_item.kind = source_display[entry.source.name].icon
                    vim_item.kind_hl_group = source_display[entry.source.name].hl_group
                else
                    vim_item.kind = icons.kind[vim_item.kind]
                end
                local max_width = 50
                if #vim_item.abbr > max_width then
                    vim_item.abbr = string.sub(vim_item.abbr, 1, max_width - 3) .. "..."
                end
                return vim_item
            end,
        },
        sources = cmp_important_sources,
        confirm_opts = {
            behavior = cmp.ConfirmBehavior.Replace,
            select = false,
        },
        window = {
            completion = cmp.config.window.bordered(),
            documentation = cmp.config.window.bordered(),
        },
        experimental = {
            ghost_text = false,
        },
        sorting = {
            comparators = {
                cmp.config.compare.offset,
                cmp.config.compare.exact,
                cmp.config.compare.recently_used,
                cmp.config.compare.kind,
                cmp.config.compare.sort_text,
                cmp.config.compare.length,
                cmp.config.compare.order,
            },
        },
    })

    -- commandline and search mode cmpis configured through autocmds for
    -- optimized startup

    vim.keymap.set({ "i", "s" }, "<C-j>", function()
        if luasnip.choice_active() then
            luasnip.change_choice(1)
        end
    end, { silent = true })

    pcall(function()
        local function on_confirm_done(...)
            local autopairs_cmp_ok, autopairs_cmp = pcall(require, "nvim-autopairs.completion.cmp")
            if not autopairs_cmp_ok then return nil end
            autopairs_cmp.on_confirm_done()(...)
        end
        require("cmp").event:off("confirm_done", on_confirm_done)
        require("cmp").event:on("confirm_done", on_confirm_done)
    end)
end

return M
