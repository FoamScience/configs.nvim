-- Claude as a manual-trigger infill engine. Keeps one `claude -p` stream-json
-- session alive per nvim, so it runs on the Claude Code subscription (no API key)
-- without paying CLI startup per completion. <M-c> requests (insert) or rewrites
-- the selection (visual), <M-y> accepts.
return {
    dir = vim.fn.stdpath("config") .. "/user-config/claudefill",
    name = "claudefill",
    main = "claudefill",
    event = "InsertEnter",
    keys = { { "<M-c>", mode = "x", desc = "Claude: rewrite selection" } },
    opts = {},
}
