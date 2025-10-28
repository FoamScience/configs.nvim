vim.api.nvim_create_autocmd({ "CmdWinEnter" }, {
    desc = "Huh?",
    callback = function()
        vim.cmd "quit"
    end,
})

vim.api.nvim_create_autocmd({ "TextYankPost" }, {
    desc = "Highight when yanking",
    callback = function()
        vim.hl.on_yank { higroup = "@comment.warning", timeout = 40 }
    end,
})

vim.api.nvim_create_autocmd({ "FileType" }, {
    desc = "Set wrap for some file types",
    pattern = { "gitcommit", "markdown", "latex", "tex", "NeogitCommitMessage", "typst", "rmd" },
    callback = function()
        vim.opt_local.wrap = true
    end,
})


vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
    desc = "Apptainer files as shell ft",
    pattern = "*.def",
    callback = function()
        vim.bo.ft = "bash"
    end,
})

vim.api.nvim_create_autocmd({ "BufWinEnter", "BufReadPost" }, {
    desc = "Move help window to vsplit right position",
    pattern = "*",
    callback = function(_)
        if vim.bo.filetype == "help" then
            vim.cmd("wincmd L")
            vim.o.wrap = true
            vim.o.linebreak = true
            vim.o.breakindent = true
        end
    end,
})

-- LSP autocmd moved to lspconfig.lua to avoid loading lspconfig module at startup


vim.api.nvim_create_autocmd("CmdlineEnter", {
    pattern = ":",
    callback = function()
        local ok, cmp = pcall(require, "cmp")
        if not ok then
            return
        end
        cmp.setup.cmdline(":", {
            mapping = cmp.mapping.preset.cmdline(),
            sources = cmp.config.sources({
                { name = "path" },
            }, {
                { name = "cmdline", option = { ignore_cmds = { "!", "x", "w" } } },
            }),
        })
        cmp.setup.cmdline(":'<,'>", {
            mapping = cmp.mapping.preset.cmdline(),
            sources = cmp.config.sources({
                { name = "path" },
            }, {
                { name = "cmdline", option = { ignore_cmds = { "!", "x", "w" } } },
            }),
        })
    end,
})

vim.api.nvim_create_autocmd("CmdlineEnter", {
    pattern = { "/", "?" },
    callback = function()
        local ok, cmp = pcall(require, "cmp")
        if not ok then
            return
        end
        cmp.setup.cmdline({ "/", "?" }, {
            mapping = cmp.mapping.preset.cmdline(),
            sources = {
                { name = "buffer" },
                {
                    name = "nvim_lsp_document_symbol",
                    option = {
                        kinds_to_show = { foam = { "Variable", "Constant", "Number", "Boolean" } }
                    }
                },
            },
        })
    end,
})

-- Arrow setup moved to arrow.lua lazy config

vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
    pattern = "*",
    callback = function(args)
        local path = args.file
        if path:match("Make/files$") or path:match("Make/options$") then
            vim.bo.commentstring = "/* %s */"
        end
    end,
})

-- Handle 
local gzip_grp = vim.api.nvim_create_augroup("gzip", { clear = true })
vim.api.nvim_create_autocmd({"BufReadPre", "FileReadPre"}, {
    pattern = "*.gz",
    group = gzip_grp,
    callback = function()
        vim.bo.binary = true
    end
})
vim.api.nvim_create_autocmd({"BufReadPost", "FileReadPost"}, {
    pattern = "*.gz",
    group = gzip_grp,
    callback = function()
        local filename = vim.fn.expand("%")
        local handle = io.popen("gunzip -c " .. vim.fn.shellescape(filename))
        if handle then
            local content = handle:read("*a")
            handle:close()
            vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(content, "\n"))
            vim.bo.binary = false
        end
    end
})
vim.api.nvim_create_autocmd({"BufWritePost", "FileWritePost"}, {
    pattern = "*.gz",
    group = gzip_grp,
    callback = function()
        local filename = vim.fn.expand("%")
        local tmpfile = vim.fn.tempname()
        vim.cmd("write! " .. tmpfile)
        os.execute("gzip -f " .. vim.fn.shellescape(tmpfile))
        os.execute("mv " .. tmpfile .. ".gz " .. vim.fn.shellescape(filename))
    end
})
