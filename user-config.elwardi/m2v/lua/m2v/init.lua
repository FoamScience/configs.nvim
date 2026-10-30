local ffi = require("ffi")
local index = require("m2v.index")

local M = {}

M.config = {
    model = "minishlab/potion-code-16M-v2",
    max_tokens = 512,
    max_file_bytes = 256 * 1024,
    chunk = { max_lines = 60, target_lines = 30 },
    root_markers = { ".git" },
    -- reciprocal rank fusion constant
    rrf_k = 60,
    -- candidates taken from each ranking before fusion
    depth = 100,
    lexical = { max_terms = 16, min_len = 3, max_count = 20 },
    rebuild_delay_ms = 2000,
}

local MODEL_FILES = { "tokenizer.json", "model.safetensors" }

-- words too common to help ripgrep rank anything
local STOPWORDS = {}
for w in
    ("the and for are but not you all any can her was one our out has have this that with from they will what when where which who how why into than then them there these those does did use uses used get set new"):gmatch(
        "%S+"
    )
do
    STOPWORDS[w] = true
end

local roots = {}
local model, model_dir, downloading
local script = vim.fs.joinpath(vim.fs.dirname(debug.getinfo(1, "S").source:sub(2)), "..", "..", "indexer.lua")

local function has_files(dir)
    for _, f in ipairs(MODEL_FILES) do
        if not vim.uv.fs_stat(vim.fs.joinpath(dir, f)) then
            return false
        end
    end
    return true
end

local function find_model()
    local hub = vim.env.HF_HUB_CACHE or vim.fs.joinpath(vim.env.HF_HOME or vim.fn.expand("~/.cache/huggingface"), "hub")
    local snaps =
        vim.fn.glob(vim.fs.joinpath(hub, "models--" .. M.config.model:gsub("/", "--"), "snapshots", "*"), true, true)
    for _, dir in ipairs(snaps) do
        if has_files(dir) then
            return dir
        end
    end
    local own = vim.fs.joinpath(vim.fn.stdpath("cache"), "m2v", "models", (M.config.model:gsub("/", "--")))
    return has_files(own) and own or nil, own
end

local function with_model_dir(cb)
    if model_dir then
        return cb(model_dir)
    end
    local found, own = find_model()
    if found then
        model_dir = found
        return cb(found)
    end
    if downloading then
        return table.insert(downloading, cb)
    end
    downloading = { cb }
    vim.fn.mkdir(own, "p")
    vim.notify("m2v: downloading " .. M.config.model, vim.log.levels.INFO)
    local left, failed = #MODEL_FILES, nil
    for _, f in ipairs(MODEL_FILES) do
        local url = ("https://huggingface.co/%s/resolve/main/%s"):format(M.config.model, f)
        local dest = vim.fs.joinpath(own, f)
        vim.system(
            { "curl", "-fsSL", "-o", dest .. ".part", url },
            {},
            vim.schedule_wrap(function(res)
                if res.code ~= 0 then
                    failed = (res.stderr or ""):gsub("%s+$", "")
                else
                    vim.uv.fs_rename(dest .. ".part", dest)
                end
                left = left - 1
                if left == 0 then
                    local waiting = downloading
                    downloading = nil
                    if failed then
                        return vim.notify("m2v: model download failed: " .. failed, vim.log.levels.ERROR)
                    end
                    model_dir = own
                    for _, w in ipairs(waiting) do
                        w(own)
                    end
                end
            end)
        )
    end
end

local function index_dir(root)
    local key = vim.fn.sha256(root .. "\0" .. M.config.model):sub(1, 16)
    return vim.fs.joinpath(vim.fn.stdpath("cache"), "m2v", "index", key)
end

local function progress(state, message, finish)
    local ok, fidget = pcall(require, "fidget.progress")
    if not ok then
        return
    end
    if not state.handle then
        state.handle = fidget.handle.create({ title = "Indexing", message = message, lsp_client = { name = "m2v" } })
    elseif finish then
        state.handle:finish(message)
        state.handle = nil
    else
        state.handle:report({ message = message })
    end
end

local function state_of(root)
    roots[root] = roots[root] or { dir = index_dir(root) }
    local state = roots[root]
    if not state.idx then
        state.idx = index.load(state.dir)
    end
    return state
end

function M.build(root)
    local state = state_of(root)
    if state.job then
        state.dirty = true
        return
    end
    state.dirty = false
    state.job = true
    with_model_dir(function(dir)
        local opts = vim.json.encode({
            model = M.config.model,
            max_tokens = M.config.max_tokens,
            max_file_bytes = M.config.max_file_bytes,
            chunk = M.config.chunk,
        })
        local partial = ""
        progress(state, vim.fn.fnamemodify(root, ":~"))
        state.job = vim.system(
            { vim.v.progpath, "-l", script, root, state.dir, dir, opts },
            {
                stdout = vim.schedule_wrap(function(_, data)
                    local lines = vim.split(partial .. (data or ""), "\n", { plain = true })
                    partial = table.remove(lines)
                    local last = lines[#lines]
                    if last then
                        local done, total = last:match("(%d+) (%d+)")
                        progress(state, ("%s/%s files"):format(done, total))
                    end
                end),
            },
            vim.schedule_wrap(function(res)
                state.job = nil
                if res.code ~= 0 then
                    progress(state, "failed", true)
                    vim.notify("m2v: indexing failed\n" .. (res.stderr or ""), vim.log.levels.ERROR)
                    return
                end
                state.idx = index.load(state.dir)
                progress(state, ("%d chunks"):format(state.idx and state.idx.n or 0), true)
                if state.dirty then
                    M.build(root)
                end
            end)
        )
    end)
end

local function semantic(idx, query, depth)
    if not model then
        model = require("m2v.model").load(model_dir, M.config.max_tokens)
    end
    local q = ffi.new("float[?]", model.dim)
    if idx.dim ~= model.dim or not model:embed(query, q) then
        return {}
    end
    local v, dim, top = idx.vectors, idx.dim, {}
    for c = 0, idx.n - 1 do
        local s, base = 0, c * dim
        for j = 0, dim - 1 do
            s = s + v[base + j] * q[j]
        end
        if #top < depth or s > top[#top][2] then
            local lo, hi = 1, #top + 1
            while lo < hi do
                local mid = math.floor((lo + hi) / 2)
                if top[mid][2] >= s then
                    lo = mid + 1
                else
                    hi = mid
                end
            end
            table.insert(top, lo, { c, s })
            top[depth + 1] = nil
        end
    end
    return vim.tbl_map(function(t)
        return t[1]
    end, top)
end

local function terms(query)
    local opts, seen, out = M.config.lexical, {}, {}
    for w in query:gmatch("[%w_]+") do
        local lw = w:lower()
        if #w >= opts.min_len and not STOPWORDS[lw] and not seen[lw] then
            seen[lw] = true
            out[#out + 1] = w
        end
    end
    -- longer identifiers are rarer and more telling
    table.sort(out, function(a, b)
        return #a > #b
    end)
    return vim.list_slice(out, 1, opts.max_terms)
end

-- chunk holding a match line, or a window bucket when the file is not indexed
local function locate(idx, rel, row)
    local first, count = 0, 0
    if idx then
        first, count = index.file_chunks(idx, rel)
    end
    local lo, hi = first, first + count - 1
    while lo <= hi do
        local mid = math.floor((lo + hi) / 2)
        local _, s, e = index.chunk(idx, mid)
        if row < s then
            hi = mid - 1
        elseif row > e then
            lo = mid + 1
        else
            return mid
        end
    end
    return rel .. ":" .. math.floor(row / M.config.chunk.target_lines)
end

local function lexical(root, idx, query, cb)
    local words = terms(query)
    if #words == 0 or vim.fn.executable("rg") == 0 then
        return cb({})
    end
    local cmd = { "rg", "--json", "-i", "-F", "--max-count", tostring(M.config.lexical.max_count) }
    for _, w in ipairs(words) do
        vim.list_extend(cmd, { "-e", w })
    end
    return vim.system(
        cmd,
        { cwd = root, text = true },
        vim.schedule_wrap(function(res)
            local hits, df = {}, {}
            for line in vim.gsplit(res.stdout or "", "\n", { plain = true, trimempty = true }) do
                local ok, msg = pcall(vim.json.decode, line)
                if ok and msg.type == "match" and msg.data.path.text then
                    local rel = msg.data.path.text:gsub("^%./", "")
                    local key = locate(idx, rel, msg.data.line_number - 1)
                    local hit = hits[key] or { key = key, rel = rel, row = msg.data.line_number - 1, found = {} }
                    hit.row = math.min(hit.row, msg.data.line_number - 1)
                    hits[key] = hit
                    for _, sub in ipairs(msg.data.submatches) do
                        local t = sub.match.text and sub.match.text:lower()
                        if t and not hit.found[t] then
                            hit.found[t] = true
                            df[t] = (df[t] or 0) + 1
                        end
                    end
                end
            end
            local ranked = {}
            for _, hit in pairs(hits) do
                hit.score = 0
                for t in pairs(hit.found) do
                    hit.score = hit.score + 1 / math.log(1 + df[t])
                end
                ranked[#ranked + 1] = hit
            end
            table.sort(ranked, function(a, b)
                return a.score > b.score
            end)
            cb(vim.list_slice(ranked, 1, M.config.depth))
        end)
    )
end

function M.root(path)
    return vim.fs.root(path, M.config.root_markers)
end

-- cb gets { path, start, end, score } with 1-based inclusive lines, best first.
-- Returns a handle with :kill() for the ripgrep half.
function M.search(root, query, n, cb)
    local state = state_of(root)
    if not state.checked then
        state.checked = true
        M.build(root)
    end
    local idx = state.idx
    return lexical(root, idx, query, function(lex)
        local fused, keys = {}, {}
        local function add(key, rank, fill)
            if not fused[key] then
                fused[key] = fill()
                fused[key].score = 0
                keys[#keys + 1] = key
            end
            fused[key].score = fused[key].score + 1 / (M.config.rrf_k + rank)
        end
        local function from_chunk(c)
            return function()
                local rel, s, e = index.chunk(idx, c)
                return { path = vim.fs.joinpath(root, rel), start = s + 1, ["end"] = e + 1 }
            end
        end
        if idx and model_dir then
            for rank, c in ipairs(semantic(idx, query, M.config.depth)) do
                add(c, rank, from_chunk(c))
            end
        end
        for rank, hit in ipairs(lex) do
            add(hit.key, rank, type(hit.key) == "number" and from_chunk(hit.key) or function()
                local s = hit.row - hit.row % M.config.chunk.target_lines
                return {
                    path = vim.fs.joinpath(root, hit.rel),
                    start = s + 1,
                    ["end"] = s + M.config.chunk.target_lines,
                }
            end)
        end
        local out = vim.tbl_map(function(k)
            return fused[k]
        end, keys)
        table.sort(out, function(a, b)
            return a.score > b.score
        end)
        cb(vim.list_slice(out, 1, n))
    end)
end

function M.setup(opts)
    M.config = vim.tbl_deep_extend("force", M.config, opts or {})
    local timers = {}
    vim.api.nvim_create_autocmd("BufWritePost", {
        group = vim.api.nvim_create_augroup("m2v", { clear = true }),
        callback = function(ev)
            local root = M.root(ev.buf)
            if not root or not roots[root] then
                return
            end
            timers[root] = timers[root] or vim.uv.new_timer()
            timers[root]:start(
                M.config.rebuild_delay_ms,
                0,
                vim.schedule_wrap(function()
                    M.build(root)
                end)
            )
        end,
    })
end

return M
