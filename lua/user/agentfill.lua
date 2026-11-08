-- Coding agents as a manual-trigger inline completion source, served from an
-- in-process LSP server through vim.lsp.inline_completion. <M-c> requests.
-- Agents: native `claude -p` (default, Claude Code subscription) or any ACP agent.
return {
    "FoamScience/agentfill-lsp.nvim",
    main = "agentfill",
    -- start its LSP client before copilot so its suggestion sorts first
    lazy = false,
    opts = {
        debug = true,
        agents = { claude = { model = "sonnet" } },
    },
}
