local M = {
    "saghen/blink.cmp",
    version = '1.*',
    dependencies = {
        { 'rafamadriz/friendly-snippets', },
        { 'L3MON4D3/LuaSnip',             version = 'v2.*' },
        { 'saghen/blink.compat',          version = '2.*',                       lazy = true, opts = {} },
        { 'petertriho/cmp-git',           dependencies = 'nvim-lua/plenary.nvim' },
    },
}

M.config = function()
    require('cmp_git').setup({
        github = {
            issues = { state = "all", limit = 50 },
            pull_requests = { state = "all", limit = 50 },
        },
        filetypes = { 'gitcommit', 'octo', 'markdown', 'NeogitCommitMessage' },
        -- triggers: : (commits), # (issues/PRs), @ (mentions), ! (GitLab MRs)
    })
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
            default = { 'lsp', 'path', 'snippets', 'lazydev', 'unicode' },
            per_filetype = {
                gitcommit = { 'jira', 'confluence', 'git', 'lsp', 'path', 'snippets' },
                NeogitCommitMessage = { 'jira', 'confluence', 'git', 'lsp', 'path', 'snippets' },
                markdown = { 'git', 'lsp', 'path', 'snippets' },
                octo = { 'git', 'lsp', 'path', 'snippets' },
                atlassian_jira = { 'jira', 'confluence', 'lsp', 'path', 'snippets' },
                atlassian_confluence = { 'jira', 'confluence', 'lsp', 'path', 'snippets' },
            },
            providers = {
                git = {
                    name = 'git',
                    module = 'blink.compat.source',
                },
                lazydev = {
                    name = "LazyDev",
                    module = "lazydev.integrations.blink",
                    score_offset = 100,
                },
                jira = {
                    module = "cmp_providers.jira",
                    min_keyword_length = 2,
                },
                confluence = {
                    module = "cmp_providers.confluence",
                    min_keyword_length = 2,
                },
                unicode = {
                    module = "cmp_providers.unicode",
                    min_keyword_length = 1,
                    should_show_items = function(ctx)
                        -- Don't trigger on dot
                        local col = ctx.cursor[2]
                        if col > 0 then
                            local char = ctx.line:sub(col, col)
                            if char == "." then return false end
                        end
                        return true
                    end,
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
