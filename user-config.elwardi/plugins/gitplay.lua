-- gitplay.nvim — play git history as an animated vim session.
-- Local plugin at ~/repo/gitplay.nvim. Command-driven, so lazy-loaded on
-- :GitPlay. The <leader>p* keymaps live in the which-key config (user/whichkey).
--
-- In-session transport is buffer-local: the full set (n/p commit, }/{ file,
-- ]/[ hunk, <CR> play/pause, s seek, e open, i edit …) lives in the SIDEBAR
-- panes; the main code buffer keeps normal vim (search/motions) and only binds
-- q, ?, K (hunk detail) and gm/gt/gh (focus main/tree/hunks). Drive from a
-- sidebar or use gm/gt/gh to hop. :GitPlay review = static, self-paced reading.
return {
    "FoamScience/gitplay.nvim",
    name = "gitplay",
    cmd = { "GitPlay" },
    config = function()
        require("gitplay").setup({
            -- playback feel
            speed = 1.0, -- global multiplier (+/- doubles/halves live)
            typing = { cps = 45, jitter = 0.35 }, -- chars/sec + human jitter
            motion = { kps = 12 }, -- cursor motions/sec

            -- readability
            hunk_order = "comprehension", -- ordo engine: def→use + grouping
            ordo = { cmd = "~/repo/ordo/target/debug/ordo" }, -- falls back to built-in if absent
            instant_comments = true, -- drop comments/docstrings in instantly
            highlight_changes = true, -- background changed lines (add/mod/del)
            show_symbols = true, -- ordo def/use per hunk in the hunks pane (K = full detail)
            show_rationale = false, -- ordo's one-line "why" per hunk (also on in :GitPlay review)

            -- files to skip entirely (globs; match basename or full path)
            ignore = { "*.lock", "*-lock.json", "*.min.js", "*.min.css", "*.svg" },

            -- history handling
            merges = "resolve", -- animate conflict resolution
            walk = { strategy = "mainline" }, -- first-parent story

            -- edit-and-integrate (i in a sidebar -> fix in main -> gc)
            edit = {
                allow = "unpushed", -- never touch pushed history
                default_style = "ask", -- commit-on-top | --fixup | stage | absorb (GitButler)
                absorb = {
                    enable = true, -- offer "absorb into commit" when in a GitButler workspace
                    ignore_push_check = false, -- keep the all-unpushed guard on
                },
            },
        })
    end,
}
