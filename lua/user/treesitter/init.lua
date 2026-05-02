-- Replaces the archived nvim-treesitter plugin with a thin local installer.
-- Loaded as a module (NOT a lazy spec) from init.lua via `require "user.treesitter"`.
local install = require('user.treesitter.install')

-- Built-in nvim ftplugins (e.g. runtime/ftplugin/lua.lua) call
-- vim.treesitter.start() unconditionally and throw if the parser isn't
-- installed yet. Since our installer is async, that race produces a noisy
-- BufReadPost error on first open. Wrap start() so a missing parser is a
-- silent no-op; install_one() retroactively starts ts on open buffers
-- once the parser becomes available.
do
    local orig_start = vim.treesitter.start
    vim.treesitter.start = function(buf, lang)
        local ok, err = pcall(orig_start, buf, lang)
        if not ok and not tostring(err):match('Parser could not be created') then
            error(err)
        end
    end
end

local ensure_installed = {
    "lua", "vim", "vimdoc", "regex",
    "markdown", "markdown_inline", "html", "typst", "yaml", "latex",
    "bash",
    "python",
    "foam", "cpp", "c",
    "rust", "glsl",
    "xonsh",
    "json",
}

local function complete_langs()
    return install.parser_names()
end

vim.api.nvim_create_user_command('TSInstall', function(args)
    install.install(args.fargs, true)
end, { nargs = '+', complete = complete_langs })

vim.api.nvim_create_user_command('TSUpdate', function(args)
    local langs = #args.fargs > 0 and args.fargs or ensure_installed
    install.install(langs, true)
end, { nargs = '*', complete = complete_langs })

vim.api.nvim_create_user_command('TSUninstall', function(args)
    install.uninstall(args.fargs)
end, { nargs = '+', complete = complete_langs })

vim.api.nvim_create_user_command('TSHealth', function()
    local ok = install.recheck_prereqs()
    local lines = { 'treesitter prereqs: ' .. (ok and 'OK' or 'FAIL') }
    table.insert(lines, 'install dir: ' .. vim.fs.joinpath(vim.fn.stdpath('data'), 'site', 'parser'))
    table.insert(lines, 'ABI: ' .. tostring(vim.treesitter.language_version))
    local installed = vim.fn.glob(vim.fs.joinpath(vim.fn.stdpath('data'), 'site', 'parser', '*.so'), false, true)
    table.insert(lines, ('installed parsers: %d'):format(#installed))
    for _, p in ipairs(installed) do table.insert(lines, '  ' .. vim.fs.basename(p)) end
    vim.notify(table.concat(lines, '\n'), vim.log.levels.INFO)
end, {})

-- On every FileType: if our registry knows this lang, either start TS
-- (parser installed) or kick off a background install (the installer's
-- retro-start hook will attach TS to this buffer once the build finishes).
local known = {}
for _, lang in ipairs(install.parser_names()) do known[lang] = true end

vim.api.nvim_create_autocmd('FileType', {
    callback = function(args)
        local ft = args.match
        if not known[ft] then return end
        if install.is_installed(ft) then
            vim.defer_fn(function()
                if vim.api.nvim_buf_is_valid(args.buf) then
                    pcall(vim.treesitter.start, args.buf)
                end
            end, 1)
        else
            install.install({ ft }, false)
        end
    end,
})

vim.opt.foldexpr = 'v:lua.vim.treesitter.foldexpr()'

-- Install missing parsers asynchronously after startup.
vim.schedule(function()
    install.install(ensure_installed, false)
end)
