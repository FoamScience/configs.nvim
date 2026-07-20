-- CAESES scripting languages (FPL, FSC, FDF) — tree-sitter integration.
-- Sources from a local checkout at ~/repo/tree-sitter-caeses; this plugin
-- only activates on machines where that path exists, so the user-config
-- stays portable.

local src_root = vim.fn.expand('~/repo/tree-sitter-caeses')
if vim.fn.isdirectory(src_root) ~= 1 then
    return nil -- skip the spec entirely on machines without the source
end

local LANGS = { 'fpl', 'fsc', 'fdf' }

local function paths()
    local site = vim.fs.joinpath(vim.fn.stdpath('data'), 'site')
    return {
        site = site,
        parser_dir = vim.fs.joinpath(site, 'parser'),
        queries_dir = vim.fs.joinpath(site, 'queries'),
    }
end

local function parser_so(lang)
    return vim.fs.joinpath(paths().parser_dir, lang .. '.so')
end

local function build_one(lang)
    local grammar_dir = vim.fs.joinpath(src_root, 'grammars', lang)
    if vim.fn.isdirectory(grammar_dir) ~= 1 then
        vim.notify('[caeses] grammar dir missing: ' .. grammar_dir, vim.log.levels.WARN)
        return false
    end
    local p = paths()
    vim.fn.mkdir(p.parser_dir, 'p')
    local qdst = vim.fs.joinpath(p.queries_dir, lang)
    vim.fn.mkdir(qdst, 'p')

    local r = vim.system(
        { 'tree-sitter', 'build', '-o', 'parser.so' },
        { cwd = grammar_dir, text = true }
    ):wait()
    if r.code ~= 0 then
        vim.notify(('[caeses] build %s failed: %s'):format(lang,
            (r.stderr or '') .. (r.stdout or '')), vim.log.levels.ERROR)
        return false
    end

    local src_so = vim.fs.joinpath(grammar_dir, 'parser.so')
    local ok, err = vim.uv.fs_copyfile(src_so, parser_so(lang))
    if not ok then
        vim.notify(('[caeses] copy parser.so failed (%s): %s'):format(lang, err),
            vim.log.levels.ERROR)
        return false
    end

    local qsrc = vim.fs.joinpath(grammar_dir, 'queries')
    if vim.fn.isdirectory(qsrc) == 1 then
        for _, scm in ipairs(vim.fn.glob(vim.fs.joinpath(qsrc, '*.scm'), false, true)) do
            vim.uv.fs_copyfile(scm, vim.fs.joinpath(qdst, vim.fs.basename(scm)))
        end
    end

    vim.notify('[caeses] installed ' .. lang)
    return true
end

local function build_all()
    for _, lang in ipairs(LANGS) do build_one(lang) end
end

-- Eagerly register filetypes and treesitter language bindings at spec-load
-- time so they're active before lazy decides whether/when to load the plugin.
vim.filetype.add({
    extension = {
        fpl = 'fpl',
        fsc = 'fsc',
        fdf = 'fdf',
    },
})

for _, lang in ipairs(LANGS) do
    local so = parser_so(lang)
    if vim.uv.fs_stat(so) then
        pcall(vim.treesitter.language.add, lang, { path = so })
    end
end

vim.api.nvim_create_autocmd('FileType', {
    pattern = LANGS,
    callback = function(args)
        local lang = args.match
        if vim.uv.fs_stat(parser_so(lang)) then
            pcall(vim.treesitter.start, args.buf, lang)
        else
            vim.notify(
                ('[caeses] parser %s not built — run :CaesesRebuild'):format(lang),
                vim.log.levels.WARN
            )
        end
    end,
})

vim.api.nvim_create_user_command('CaesesRebuild', function()
    build_all()
    -- Re-register and (re)start treesitter on existing buffers.
    for _, lang in ipairs(LANGS) do
        local so = parser_so(lang)
        if vim.uv.fs_stat(so) then
            pcall(vim.treesitter.language.add, lang, { path = so })
        end
    end
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(buf) then
            local ft = vim.bo[buf].filetype
            if vim.tbl_contains(LANGS, ft) then
                pcall(vim.treesitter.start, buf, ft)
            end
        end
    end
end, { desc = 'Rebuild and install fpl/fsc/fdf tree-sitter parsers' })

-- Return a lazy.nvim spec so :Lazy build caeses works. Pointing `dir` at
-- the real source path avoids the silent-drop you get with `dir = '.'`.
return {
    dir = src_root,
    name = 'caeses',
    lazy = false,
    build = build_all,
}
