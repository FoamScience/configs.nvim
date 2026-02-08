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
        if not require('nvim-treesitter.parsers').xonsh then
            vim.treesitter.start(args.buf, 'xonsh')
        end
    end,
})

-- CSF (Confluence Storage Format) filetype detection
vim.filetype.add({
    pattern = {
        ["csf://.*"] = "csf",
        ["confluence_storage:.*"] = "csf",
        ["confluence://.*"] = "csf",
        ["jira://.*"] = "csf",
    },
    extension = { csf = "csf" },
})

vim.api.nvim_create_autocmd('User', {
    pattern = 'TSUpdate',
    callback = function()
        require('nvim-treesitter.parsers').csf = {
            install_info = {
                url = 'https://github.com/FoamScience/tree-sitter-csf',
                queries = 'queries/',
            },
        }
    end
})

-- Merge highlights + conceal queries into a single "highlights" query group
-- so vim.treesitter.start() picks everything up together
do
    local done = false
    vim.api.nvim_create_autocmd('FileType', {
        pattern = 'csf',
        once = true,
        callback = function()
            if done then return end
            done = true
            pcall(function()
                local sources = {}
                local seen = {}
                for _, group in ipairs({ 'highlights', 'conceal' }) do
                    for _, f in ipairs(vim.api.nvim_get_runtime_file('queries/csf/' .. group .. '.scm', true)) do
                        local content = table.concat(vim.fn.readfile(f), '\n')
                        content = content:gsub('^;; extends%s*\n?', '')
                        -- Deduplicate: skip if identical content already loaded
                        if content ~= '' and not seen[content] then
                            seen[content] = true
                            table.insert(sources, content)
                        end
                    end
                end
                if #sources > 0 then
                    vim.treesitter.query.set('csf', 'highlights', table.concat(sources, '\n'))
                    -- Clear standalone conceal query to prevent double application
                    -- by nvim-treesitter or Neovim's built-in treesitter modules
                    vim.treesitter.query.set('csf', 'conceal', '')
                end
            end)
        end,
    })
end

vim.api.nvim_create_autocmd('FileType', {
    pattern = 'csf',
    callback = function(args)
        local buf = args.buf
        if not require('nvim-treesitter.parsers').csf then
            vim.treesitter.start(buf, 'csf')
        end
        -- Buffer options
        vim.bo[buf].textwidth = 0
        -- Window options — defer to ensure window exists
        vim.schedule(function()
            local win = vim.fn.bufwinid(buf)
            if win == -1 then return end
            vim.wo[win].conceallevel = 2
            vim.wo[win].concealcursor = "nc"
            vim.wo[win].wrap = true
            vim.wo[win].linebreak = true
        end)
        -- Attach input translation for CSF buffers
        local ok, csf_input = pcall(require, 'atlassian.csf.input')
        if ok then
            csf_input.setup_buffer(buf)
        end
        -- Image hover (CursorHold) + K keymap
        local img_ok, csf_image = pcall(require, 'atlassian.csf.image')
        if img_ok then
            csf_image.setup_hover(buf)
            vim.keymap.set("n", "K", function()
                csf_image.show_at_cursor(buf)
            end, { buffer = buf, desc = "Show image at cursor" })
        end
        -- Math rendering (LaTeX → unicode via latex2text)
        local math_ok, csf_math = pcall(require, 'atlassian.csf.math')
        if math_ok then
            csf_math.setup(buf)
        end
        -- Slash command interactive keymap
        local int_ok, interactive = pcall(require, 'atlassian.slash_commands.interactive')
        if int_ok then
            interactive.setup_keymap(buf)
        end
    end,
})
