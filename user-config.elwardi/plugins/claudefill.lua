-- Claude as a manual-trigger inline completion source. Keeps one `claude -p`
-- stream-json session alive per nvim, so it runs on the Claude Code subscription
-- (no API key) without paying CLI startup per completion. <M-c> requests; the
-- result shows through vim.lsp.inline_completion from an in-process LSP server.
return {
    dir = vim.fn.stdpath("config") .. "/user-config/claudefill",
    name = "claudefill",
    main = "claudefill",
    -- start its LSP client before copilot so its suggestion sorts first
    lazy = false,
    opts = {},
}
