-- Claude as a manual-trigger infill engine. Keeps one `claude -p` stream-json
-- session alive per nvim, so it runs on the Claude Code subscription (no API key)
-- without paying CLI startup per completion. <M-c> requests, <M-y> accepts.
return {
    dir = vim.fn.stdpath("config") .. "/user-config/claudefill",
    name = "claudefill",
    main = "claudefill",
    event = "InsertEnter",
    opts = {},
}
