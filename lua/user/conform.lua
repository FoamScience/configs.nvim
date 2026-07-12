-- conform.nvim — format orchestration. Replaces raw vim.lsp.buf.format on
-- <leader>lf (rebound in whichkey.lua) and adds format-on-save with an LSP
-- fallback. Formatters are mason-installed via the ensure_installed extend below.
local M = {
    "stevearc/conform.nvim",
    -- BufReadPre so <leader>lf (defined centrally in whichkey) can require it;
    -- BufWritePre so format-on-save works on freshly created buffers too.
    event = { "BufReadPre", "BufWritePre" },
    cmd = { "ConformInfo" },
}

M.opts = {
    formatters_by_ft = {
        lua = { "stylua" },
        python = { "ruff_format" },
        c = { "clang-format" },
        cpp = { "clang-format" },
        tex = { "latexindent" },
        plaintex = { "latexindent" },
        typst = { "typstyle" },
        sh = { "shfmt" },
        bash = { "shfmt" },
    },
    default_format_opts = {
        lsp_format = "fallback",
    },
    format_on_save = function(bufnr)
        if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
            return
        end
        return { timeout_ms = 3000, lsp_format = "fallback" }
    end,
}

function M.config(_, opts)
    require("conform").setup(opts)
    -- Let conform drive gq / gw.
    vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"

    vim.api.nvim_create_user_command("FormatDisable", function(args)
        if args.bang then
            vim.b.disable_autoformat = true
        else
            vim.g.disable_autoformat = true
        end
    end, { desc = "Disable format-on-save (bang = buffer only)", bang = true })

    vim.api.nvim_create_user_command("FormatEnable", function()
        vim.b.disable_autoformat = false
        vim.g.disable_autoformat = false
    end, { desc = "Re-enable format-on-save" })
end

return {
    M,
    -- Mason installs conform's formatters (opts_extend merges ensure_installed).
    {
        "mason-org/mason.nvim",
        opts = { ensure_installed = { "clang-format", "ruff", "latexindent", "typstyle" } },
    },
}
