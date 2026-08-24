-- foam-language-server: LSP for OpenFOAM dictionaries.
--
-- nvim-lspconfig already ships an `lsp/foam_ls.lua` (correct root_dir + the
-- `foam` filetype), but it expects the npm-global `foam-ls` on $PATH. This
-- points the server at a local dev checkout instead and adds the filetype
-- detection nvim-lspconfig does not provide.
--
-- Rebuild the checkout with `npm run prepare` after pulling changes.
local foam_ls_bin = vim.fn.expand("/home/elwardi/repo/foam-language-server/bin/foam-ls")

-- Virtual plugin: no source to clone. `dir` must point at a real directory
-- or lazy skips the spec; the work lives in `init`, which lazy runs at
-- startup regardless of lazy-loading (a plain `config` is skipped for a
-- sourceless spec).
return {
    dir = vim.fn.stdpath("config"),
    name = "foam-ls",
    lazy = false,
    init = function()
        -- OpenFOAM dicts are extensionless (controlDict, fvSchemes, ...) but
        -- always open with a `FoamFile` header; detect on that rather than
        -- guessing from path, so a stray `system/` dir elsewhere is safe
        vim.filetype.add({
            pattern = {
                [".*"] = {
                    priority = -math.huge,
                    function(_, bufnr)
                        for _, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, 15, false)) do
                            if line:match("^FoamFile%s*$") then
                                return "foam"
                            end
                        end
                    end,
                },
            },
        })

        if vim.fn.filereadable(foam_ls_bin) == 0 then
            vim.notify(
                "foam-ls not found at " .. foam_ls_bin .. " — run `npm run prepare` in the repo",
                vim.log.levels.WARN
            )
            return
        end

        -- override only the cmd; the shipped config's root_dir (walks up to
        -- system/controlDict) and `foam` filetype are already right, and `*`
        -- capabilities (cmp/blink) merge in at client start.
        --
        -- diagnostic = false disables pull diagnostics for this server: it
        -- serves solver diagnostics asynchronously and pushes them, but
        -- native Neovim's pull loop never populates them from this server
        -- (a manual textDocument/diagnostic returns them, auto-pull does
        -- not). Declining pull makes the server push, which Neovim shows.
        vim.lsp.config("foam_ls", {
            cmd = { foam_ls_bin, "--stdio" },
            capabilities = { textDocument = { diagnostic = false } },
        })
        vim.lsp.enable("foam_ls")

        -- highlighting from the already-installed foam tree-sitter parser
        vim.api.nvim_create_autocmd("FileType", {
            pattern = "foam",
            callback = function(ev)
                pcall(vim.treesitter.start, ev.buf, "foam")
            end,
        })
    end,
}
