local M = {
    "saghen/blink.cmp",
    version = '1.*',
    dependencies = {
        { 'rafamadriz/friendly-snippets', },
        { 'L3MON4D3/LuaSnip',             version = 'v2.*' },
        { 'Kaiser-Yang/blink-cmp-git', },
    },
}

M.config = function()
    require('blink.cmp').setup({
        keymap = {
            preset = 'super-tab',
            ['<CR>'] = {
                function(cmp)
                    if cmp.snippet_active() then
                        return cmp.accept()
                    else
                        return cmp.select_and_accept()
                    end
                end,
                'snippet_forward',
                'fallback'
            },
        },
        sources = {
            default = { 'lsp', 'path', 'snippets', 'git', 'lazydev', 'unicode' },
            providers = {
                git = {
                    module = 'blink-cmp-git',
                    name = 'Git',
                },
                lazydev = {
                    name = "LazyDev",
                    module = "lazydev.integrations.blink",
                    score_offset = 100,
                },
                unicode = {
                    module = "cmp_providers.unicode",
                    score_offset = 10,
                    min_keyword_length = 0,
                },
            }
        },
        snippets = { preset = 'luasnip' },
        signature = { window = { border = 'single' } },
        term = { enabled = true },
        completion = {
            keyword = { range = 'prefix' },
            documentation = {
                window = { border = 'single' },
                auto_show = true,
                auto_show_delay_ms = 500,
            },
            menu = {
                border = 'single',
                draw = {
                    padding = { 1, 1 },
                    treesitter = { 'lsp' },
                    columns = { { "kind_icon" }, { "label", "label_description", gap = 1 }, { "kind" } },
                    components = {
                        kind_icon = {
                            text = function(ctx)
                                local kind_icon, _, _ = require('mini.icons').get('lsp', ctx.kind)
                                return kind_icon
                            end,
                            highlight = function(ctx)
                                local _, hl, _ = require('mini.icons').get('lsp', ctx.kind)
                                return hl
                            end,
                        },
                        kind = {
                            highlight = function(ctx)
                                local _, hl, _ = require('mini.icons').get('lsp', ctx.kind)
                                return hl
                            end,
                        }
                    }
                }
            }
        }
    })
end

return M
