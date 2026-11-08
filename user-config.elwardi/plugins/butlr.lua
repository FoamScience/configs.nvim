return {
    "FoamScience/butlr.nvim",
    lazy = false,
    -- butlr enables itself per repo on VimEnter/DirChanged; only gate on the CLI.
    enabled = function()
        return vim.fn.executable("but") == 1
    end,
    config = function()
        local butlr = require("butlr")
        butlr.setup()

        local function map(key, fn, desc)
            vim.keymap.set("n", key, function()
                if not butlr.is_enabled() then
                    return
                end
                fn()
            end, { desc = desc, silent = true })
        end

        local nav = require("butlr.navigation")
        local picker = require("butlr.picker")
        local actions = require("butlr.actions")
        local state = require("butlr.state")

        local wk = require("which-key")
        wk.add({
            { "<leader>b", group = "Butler", icon = "" },
            { "<leader>bd", group = "Diff/Discard" },
        })

        -- Navigation (buffer)
        map("<leader>bj", nav.next_hunk, "Next Hunk")
        map("<leader>bk", nav.prev_hunk, "Previous Hunk")

        -- Navigation (repo-wide)
        map("<leader>bJ", nav.next_hunk_global, "Next Hunk (repo)")
        map("<leader>bK", nav.prev_hunk_global, "Previous Hunk (repo)")

        -- Pickers
        map("<leader>br", picker.rub, "Rub (assign hunk)")
        map("<leader>bb", picker.branches, "Branches")

        -- Actions
        map("<leader>ba", actions.absorb, "Absorb")
        map("<leader>bu", actions.undo, "Undo")
        map("<leader>bdd", function()
            local hunk, file_data = state.get_hunk_at_cursor()
            local id = hunk and hunk.id or (file_data and file_data.id)
            if id then
                actions.discard(id)
            else
                vim.notify("[butlr] no hunk under cursor", vim.log.levels.INFO)
            end
        end, "Discard hunk")

        -- Mark/unmark
        map("<leader>bm", function()
            picker.branches()
        end, "Mark branch (via picker)")

        -- Quick uncommit (back to @)
        map("<leader>bz", function()
            local hunk, file_data = state.get_hunk_at_cursor()
            local source = hunk or file_data
            if source and source.commit_id then
                actions.uncommit(source.id)
            else
                vim.notify("[butlr] no committed hunk under cursor", vim.log.levels.INFO)
            end
        end, "Uncommit hunk")

        -- Refresh
        map("<leader>bR", function()
            state.refresh_now()
        end, "Refresh state")
    end,
}
