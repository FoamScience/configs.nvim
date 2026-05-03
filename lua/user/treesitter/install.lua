-- Tree-sitter parser installer (replaces archived nvim-treesitter).
-- Async via coroutines + vim.system callbacks. Installs run in parallel,
-- bounded by MAX_JOBS, and never block the main loop.
--
-- Pipeline per parser:
--   curl <repo>/archive/<rev>.tar.gz → tar -xz → (optional) tree-sitter generate
--   → tree-sitter build -o parser.so → cp into <stdpath:data>/site/parser/<lang>.so
--   queries: prefer parser-repo `queries/`, fall back to archived nvim-treesitter
--   `runtime/queries/<lang>/` for languages where that repo shipped curated overrides.

local M = {}
local fs = vim.fs
local uv = vim.uv
local parsers = require('user.treesitter.parsers')

local MAX_JOBS = 8
local TS_MIN_VERSION = { 0, 26, 1 }

-- Archived nvim-treesitter SHA used purely to harvest curated queries.
local NVIMTS_QUERIES_SHA = 'main'

local _prereqs_checked = false
local _prereqs_ok = false

local function ver_ge(a, b)
    for i = 1, 3 do
        if (a[i] or 0) ~= (b[i] or 0) then return (a[i] or 0) > (b[i] or 0) end
    end
    return true
end

local function parse_ts_version(s)
    local maj, min, pat = s:match('(%d+)%.(%d+)%.(%d+)')
    if not maj then return nil end
    return { tonumber(maj), tonumber(min), tonumber(pat) }
end

local function which(cmd)
    local r = vim.system({ 'sh', '-c', 'command -v ' .. cmd }):wait()
    return r.code == 0 and (r.stdout or ''):gsub('\n$', '') or nil
end

---Synchronous one-time check. Notifies once with a single error listing all
---missing or out-of-date tools. Returns true if everything is OK.
function M.check_prereqs()
    if _prereqs_checked then return _prereqs_ok end
    _prereqs_checked = true

    local missing = {}

    if not which('curl') then table.insert(missing, 'curl') end
    if not which('tar') then table.insert(missing, 'tar') end
    if not (which('cc') or which('gcc') or which('clang')) then
        table.insert(missing, 'a C compiler (cc/gcc/clang)')
    end

    local ts_path = which('tree-sitter')
    if not ts_path then
        table.insert(missing, ('tree-sitter CLI (>= %d.%d.%d, NOT the npm one)')
            :format(TS_MIN_VERSION[1], TS_MIN_VERSION[2], TS_MIN_VERSION[3]))
    else
        local r = vim.system({ 'tree-sitter', '--version' }):wait()
        local v = r.code == 0 and parse_ts_version(r.stdout or '') or nil
        if not v then
            table.insert(missing, 'tree-sitter --version output unparseable: ' .. (r.stdout or '<nil>'))
        elseif not ver_ge(v, TS_MIN_VERSION) then
            table.insert(missing, ('tree-sitter %d.%d.%d (need >= %d.%d.%d)')
                :format(v[1], v[2], v[3], TS_MIN_VERSION[1], TS_MIN_VERSION[2], TS_MIN_VERSION[3]))
        end
    end

    if #missing > 0 then
        vim.notify(
            'treesitter installer prerequisites missing:\n  - ' .. table.concat(missing, '\n  - '),
            vim.log.levels.ERROR
        )
        _prereqs_ok = false
    else
        _prereqs_ok = true
    end
    return _prereqs_ok
end

local function install_dir() return fs.joinpath(vim.fn.stdpath('data'), 'site') end
local function state_dir() return fs.joinpath(vim.fn.stdpath('data'), 'user-treesitter', 'state') end
local function parser_so(lang) return fs.joinpath(install_dir(), 'parser', lang .. '.so') end
local function rev_file(lang) return fs.joinpath(state_dir(), lang .. '.revision') end
local function query_dir(lang) return fs.joinpath(install_dir(), 'queries', lang) end

local function read_revision(lang)
    local f = io.open(rev_file(lang), 'r')
    if not f then return nil end
    local r = f:read('*l')
    f:close()
    return r
end

local function write_revision(lang, rev)
    local f = io.open(rev_file(lang), 'w')
    if not f then return end
    f:write(rev)
    f:close()
end

local function ensure_dir(p) vim.fn.mkdir(p, 'p') end
local function rmrf(p) vim.fn.delete(p, 'rf') end

-- Yields the running coroutine until vim.system completes.
local function arun(cmd, opts)
    local co = assert(coroutine.running(), 'arun must run inside a coroutine')
    vim.system(cmd, opts or {}, function(r)
        vim.schedule(function() coroutine.resume(co, r) end)
    end)
    local r = coroutine.yield()
    if r.code ~= 0 then
        error(string.format('[%s] exit %d: %s', cmd[1], r.code,
            (r.stderr or '') .. (r.stdout or '')))
    end
    return r
end

local function copy_scm(src_dir, dst_dir)
    if vim.fn.isdirectory(src_dir) ~= 1 then return 0 end
    ensure_dir(dst_dir)
    local n = 0
    for _, scm in ipairs(vim.fn.glob(fs.joinpath(src_dir, '*.scm'), false, true)) do
        local dst = fs.joinpath(dst_dir, vim.fs.basename(scm))
        uv.fs_copyfile(scm, dst)
        n = n + 1
    end
    return n
end

-- Curated nvim-treesitter query bundle: downloaded & extracted once, reused for
-- all standard parsers. Parser-repo `queries/` is used only as fallback (or for
-- custom parsers that set `info.queries` explicitly).
local function nvimts_queries_root()
    return fs.joinpath(state_dir(), 'nvimts-queries')
end

---@async
local function ensure_nvimts_queries()
    local root = nvimts_queries_root()
    -- Detect "ready": runtime/queries exists with content
    local rt = fs.joinpath(root, 'runtime', 'queries')
    if vim.fn.isdirectory(rt) == 1 and #vim.fn.glob(fs.joinpath(rt, '*'), false, true) > 0 then
        return rt
    end
    rmrf(root)
    ensure_dir(root)
    local tar_url = string.format(
        'https://codeload.github.com/nvim-treesitter/nvim-treesitter/tar.gz/%s',
        NVIMTS_QUERIES_SHA
    )
    local tarball = fs.joinpath(state_dir(), 'nvimts.tar.gz')
    local ok = pcall(arun, { 'curl', '--silent', '--fail', '--show-error', '-L', tar_url, '-o', tarball })
    if not ok then return nil end
    -- Extract only runtime/queries (much smaller than full repo)
    pcall(arun, { 'tar', '-xzf', tarball, '-C', root, '--strip-components=1',
        ('nvim-treesitter-%s/runtime'):format(NVIMTS_QUERIES_SHA) })
    vim.fn.delete(tarball)
    if vim.fn.isdirectory(rt) == 1 then return rt end
    return nil
end

---@async
local function install_one_async(lang)
    local info = parsers[lang]
    if not info then
        vim.notify('treesitter: unknown parser ' .. lang, vim.log.levels.WARN)
        return false
    end

    ensure_dir(fs.joinpath(install_dir(), 'parser'))
    ensure_dir(fs.joinpath(install_dir(), 'queries'))
    ensure_dir(state_dir())

    local cache = fs.joinpath(vim.fn.stdpath('cache'), 'user-treesitter', lang)
    rmrf(cache)
    ensure_dir(cache)

    local url = (info.url or ''):gsub('%.git$', '')
    local rev = info.revision or 'HEAD'
    local target = string.format('%s/archive/%s.tar.gz', url, rev)
    local tarball = fs.joinpath(cache, lang .. '.tar.gz')

    vim.notify('treesitter: installing ' .. lang)

    arun({ 'curl', '--silent', '--fail', '--show-error', '--retry', '7', '-L', target, '-o', tarball })

    local extract = fs.joinpath(cache, 'src')
    ensure_dir(extract)
    arun({ 'tar', '-xzf', tarball, '-C', extract, '--strip-components=1' })

    local compile_dir = info.location and fs.joinpath(extract, info.location) or extract

    if info.generate then
        arun({ 'tree-sitter', 'generate', '--abi', tostring(vim.treesitter.language_version) },
            { cwd = compile_dir, env = { TREE_SITTER_JS_RUNTIME = 'native' } })
    end

    arun({ 'tree-sitter', 'build', '-o', 'parser.so' }, { cwd = compile_dir })

    local target_so = parser_so(lang)
    local ok, err = uv.fs_copyfile(fs.joinpath(compile_dir, 'parser.so'), target_so)
    if not ok then error('copy parser.so failed: ' .. tostring(err)) end

    -- Queries: prefer nvim-treesitter curated set (the source of the rich
    -- highlighting users expect). Fall back to parser-repo `queries/`.
    -- Custom parsers (info.queries explicitly set) skip the curated path.
    local qdst = query_dir(lang)
    rmrf(qdst)
    local copied = 0
    if info.queries == nil then
        local rt = ensure_nvimts_queries()
        if rt then
            copied = copy_scm(fs.joinpath(rt, lang), qdst)
        end
    end
    if copied == 0 then
        local qsrc = fs.joinpath(compile_dir, info.queries or 'queries')
        copied = copy_scm(qsrc, qdst)
    end

    write_revision(lang, rev)
    rmrf(cache)
    vim.notify(string.format('treesitter: installed %s (%d query files)', lang, copied))

    -- Retroactively start treesitter on any already-open buffers of this filetype.
    vim.schedule(function()
        local started = {}
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
            if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].filetype == lang then
                local ok, err = pcall(vim.treesitter.start, buf, lang)
                if ok then
                    table.insert(started, buf)
                else
                    vim.notify(('treesitter retro-start %s buf %d failed: %s'):format(lang, buf, err),
                        vim.log.levels.WARN)
                end
            end
        end
        if #started > 0 then
            vim.notify(('treesitter: started %s on %d buffer(s)'):format(lang, #started))
        end
    end)

    return true
end

-- Bounded parallel runner. Tasks are zero-arg functions; each runs in its own
-- coroutine so it can call arun(), which yields/resumes via vim.system callbacks.
-- A task signals completion by reaching the end of its body — we wrap it so the
-- last act before the coroutine dies is to schedule the next pending task.
local function run_pool(tasks, max_jobs, on_done)
    if #tasks == 0 then if on_done then on_done() end return end
    max_jobs = math.min(max_jobs or MAX_JOBS, #tasks)
    local idx = 0
    local total = #tasks
    local finished = 0
    local spawn_next

    local function task_done()
        finished = finished + 1
        if finished == total then
            if on_done then on_done() end
        elseif idx < total then
            spawn_next()
        end
    end

    spawn_next = function()
        idx = idx + 1
        if idx > total then return end
        local fn = tasks[idx]
        local co
        co = coroutine.create(function()
            local ok, err = pcall(fn)
            if not ok then
                vim.notify('treesitter task: ' .. tostring(err), vim.log.levels.ERROR)
            end
            -- defer signalling so we don't recurse into spawn_next from within
            -- the same coroutine resume frame
            vim.schedule(task_done)
        end)
        local ok, err = coroutine.resume(co)
        if not ok then
            vim.notify('treesitter resume: ' .. tostring(err), vim.log.levels.ERROR)
            vim.schedule(task_done)
        end
    end

    for _ = 1, max_jobs do spawn_next() end
end

---@param langs? string[]
---@param force? boolean
function M.install(langs, force)
    if not M.check_prereqs() then return end
    langs = langs or vim.tbl_keys(parsers)
    local tasks = {}
    for _, lang in ipairs(langs) do
        local info = parsers[lang]
        if info then
            local up_to_date = read_revision(lang) == info.revision and uv.fs_stat(parser_so(lang))
            if force or not up_to_date then
                table.insert(tasks, function() install_one_async(lang) end)
            end
        end
    end
    if #tasks == 0 then return end
    run_pool(tasks, MAX_JOBS)
end

function M.install_one(lang)
    M.install({ lang }, true)
end

function M.uninstall(langs)
    for _, lang in ipairs(langs) do
        vim.fn.delete(parser_so(lang))
        vim.fn.delete(rev_file(lang))
        rmrf(query_dir(lang))
    end
end

function M.is_installed(lang)
    return uv.fs_stat(parser_so(lang)) ~= nil
end

function M.parser_names()
    return vim.tbl_keys(parsers)
end

function M.recheck_prereqs()
    _prereqs_checked = false
    return M.check_prereqs()
end

function M.nvimts_queries_runtime()
    local rt = fs.joinpath(nvimts_queries_root(), 'runtime')
    if vim.fn.isdirectory(rt) == 1 then return rt end
    return nil
end

return M
