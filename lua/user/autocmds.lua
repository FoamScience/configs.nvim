-- OpenFOAM filetype detection (extends upstream vim to support .suffix files)
local function check_foam()
    -- this could be efficient if I figure out how to run dist#ft#FTfoam
    -- from vim's runtime/autoload/dist/ft.vim
    local ffile = false
    for lnum = 1, math.min(15, vim.api.nvim_buf_line_count(0)) do
        local line = vim.fn.getline(lnum)
        if line:match("^FoamFile") then
            ffile = true
        end
        if ffile and line:match("^%s*object") then
            return "foam"
        end
    end
end

vim.filetype.add({
    pattern = {
        -- Dict files with optional suffix: controlDict, controlDict.bak, etc.
        ["[a-zA-Z0-9]*Dict[.a-zA-Z0-9]*"] = check_foam,
        -- Properties files with optional suffix
        ["[a-zA-Z]*Properties[.a-zA-Z0-9]*"] = check_foam,
        -- Transport files with optional suffix
        [".*Transport[.a-zA-Z0-9]*"] = check_foam,
        -- Core OpenFOAM files with optional suffix
        ["fvSchemes[.a-zA-Z0-9]*"] = check_foam,
        ["fvSolution[.a-zA-Z0-9]*"] = check_foam,
        ["fvConstraints[.a-zA-Z0-9]*"] = check_foam,
        ["fvModels[.a-zA-Z0-9]*"] = check_foam,
        ["functionObjects[.a-zA-Z0-9]*"] = check_foam,
        -- Files in constant/ directory
        [".*/constant/g[.a-zA-Z0-9]*"] = check_foam,
        -- Files in 0/ or 0.orig/ directory
        [".*/0/.*"] = check_foam,
        [".*/0%.orig/.*"] = check_foam,
    },
})

vim.filetype.add({
    extension = { xsh = 'xonsh', xonshrc = 'xonsh' },
    filename = { ['.xonshrc'] = 'xonsh', ['xonshrc'] = 'xonsh' },
})

vim.api.nvim_create_autocmd({ 'BufRead', 'BufNewFile' }, {
    pattern = { '*.xsh', '*.xonshrc', '.xonshrc', 'xonshrc' },
    callback = function()
        vim.bo.filetype = 'xonsh'
    end,
})

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
vim.api.nvim_create_autocmd({ "BufReadPre", "FileReadPre" }, {
    pattern = "*.gz",
    group = gzip_grp,
    callback = function()
        vim.bo.binary = true
    end
})
vim.api.nvim_create_autocmd({ "BufReadPost", "FileReadPost" }, {
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
vim.api.nvim_create_autocmd({ "BufWritePost", "FileWritePost" }, {
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

vim.api.nvim_create_autocmd('User', {
    pattern = 'TSUpdate',
    callback = function()
        require('nvim-treesitter.parsers').xonsh = {
            install_info = {
                url = 'https://github.com/FoamScience/tree-sitter-xonsh',
                queries = 'queries/',
            },
        }
    end
})

vim.api.nvim_create_autocmd('FileType', {
    pattern = 'xonsh',
    callback = function(args)
        if require('nvim-treesitter.parsers').xonsh then
            vim.treesitter.start(args.buf, 'xonsh')
        end
    end,
})
