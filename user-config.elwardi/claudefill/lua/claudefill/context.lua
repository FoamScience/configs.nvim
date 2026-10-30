local api = vim.api

local M = {}

local function readable(path)
    local stat = vim.uv.fs_stat(path)
    return stat and stat.type == "file"
end

local function first_readable(candidates)
    for _, path in ipairs(candidates) do
        if readable(path) then
            return vim.uv.fs_realpath(path)
        end
    end
end

local function parse(lines, path)
    local ft = vim.filetype.match({ filename = path, contents = lines })
    local lang = ft and vim.treesitter.language.get_lang(ft)
    if not lang then
        return
    end
    local ok, parser = pcall(vim.treesitter.get_string_parser, table.concat(lines, "\n"), lang)
    if not ok or not parser then
        return
    end
    local ok_parse, trees = pcall(parser.parse, parser)
    return ok_parse and trees[1] and trees[1]:root() or nil
end

-- loaded buffers win over disk so unsaved edits are seen
local function loader(cfg)
    local bufs, cache = {}, {}
    for _, b in ipairs(api.nvim_list_bufs()) do
        local name = api.nvim_buf_is_loaded(b) and vim.uv.fs_realpath(api.nvim_buf_get_name(b))
        if name then
            bufs[name] = b
        end
    end
    return function(path)
        if cache[path] == nil then
            local lines = bufs[path] and api.nvim_buf_get_lines(bufs[path], 0, -1, false)
            if not lines and readable(path) and vim.fn.getfsize(path) <= cfg.max_file_bytes then
                lines = vim.fn.readfile(path)
            end
            cache[path] = lines and { lines = lines, root = parse(lines, path) } or false
        end
        return cache[path] or nil
    end
end

-- widest node that still starts on the definition's line: the whole function
-- or assignment, but not the enclosing class or module
local function extent(root, row, col)
    local node = root and root:named_descendant_for_range(row, col, row, col)
    if not node or not node:parent() then
        return row, row
    end
    while true do
        local parent = node:parent()
        if not parent or not parent:parent() or parent:start() ~= row then
            break
        end
        node = parent
    end
    local s, _, e, ecol = node:range()
    if ecol == 0 and e > s then
        e = e - 1
    end
    return s, e
end

local function outline(file, max_lines)
    local out, last = {}, -1
    if file.root then
        for node in file.root:iter_children() do
            local row = node:start()
            if node:named() and not node:type():find("comment") and row ~= last then
                out[#out + 1] = file.lines[row + 1]
                last = row
            end
            if #out >= max_lines then
                break
            end
        end
    end
    return #out > 0 and out or vim.list_slice(file.lines, 1, max_lines)
end

local function identifiers(buf, first, last, max)
    local seen, out = {}, {}
    for i, line in ipairs(api.nvim_buf_get_lines(buf, first, last, false)) do
        for col, word in line:gmatch("()([%a_][%w_]*)") do
            if #word > 1 and not seen[word] then
                seen[word] = true
                out[#out + 1] = { row = first + i - 1, col = col - 1, line = line }
                if #out >= max then
                    return out
                end
            end
        end
    end
    return out
end

local function js_candidates(dir, spec)
    local base = vim.fs.joinpath(dir, spec)
    return vim.tbl_map(function(ext)
        return base .. ext
    end, { "", ".ts", ".tsx", ".js", ".jsx", ".mjs", "/index.ts", "/index.tsx", "/index.js" })
end

local js = {
    patterns = {
        [=[from%s+["'](%.[^"']+)["']]=],
        [=[import%s+["'](%.[^"']+)["']]=],
        [[require%(%s*["'](%.[^"']+)["']%s*%)]],
    },
    resolve = function(spec, dir)
        return first_readable(js_candidates(dir, spec))
    end,
}

local resolvers = {
    lua = {
        patterns = { [=[require%s*%(?%s*["']([^"']+)["']]=] },
        resolve = function(mod, _, root)
            local rel = mod:gsub("%.", "/")
            return api.nvim_get_runtime_file("lua/" .. rel .. ".lua", false)[1]
                or api.nvim_get_runtime_file("lua/" .. rel .. "/init.lua", false)[1]
                or first_readable({ root .. "/lua/" .. rel .. ".lua", root .. "/" .. rel .. ".lua" })
                or package.searchpath(mod, package.path)
        end,
    },
    python = {
        patterns = { "^%s*from%s+([%w%._]+)%s+import", "^%s*import%s+([%w%._]+)" },
        resolve = function(mod, dir, root)
            local dots, rest = mod:match("^(%.*)(.*)$")
            local bases = { dir, root, root .. "/src" }
            if #dots > 0 then
                local base = dir
                for _ = 2, #dots do
                    base = vim.fs.dirname(base)
                end
                bases = { base }
            end
            local rel = rest:gsub("%.", "/")
            local candidates = {}
            for _, base in ipairs(bases) do
                vim.list_extend(candidates, { base .. "/" .. rel .. ".py", base .. "/" .. rel .. "/__init__.py" })
            end
            return first_readable(candidates)
        end,
    },
    c = {
        patterns = { [[^%s*#%s*include%s*"([^"]+)"]] },
        resolve = function(header, dir, root)
            return first_readable({ dir .. "/" .. header, root .. "/" .. header, root .. "/include/" .. header })
        end,
    },
}
resolvers.cpp, resolvers.objc, resolvers.cuda = resolvers.c, resolvers.c, resolvers.c
for _, ft in ipairs({ "javascript", "typescript", "javascriptreact", "typescriptreact" }) do
    resolvers[ft] = js
end

local function imports(buf, path, cfg, load)
    local r = resolvers[vim.bo[buf].filetype]
    if not r or path == "" then
        return {}
    end
    local dir = vim.fs.dirname(path)
    local root = vim.fs.root(buf, { ".git", "pyproject.toml", "package.json", "Makefile", "CMakeLists.txt" }) or dir
    local seen, out = {}, {}
    for _, line in ipairs(api.nvim_buf_get_lines(buf, 0, -1, false)) do
        for _, pat in ipairs(r.patterns) do
            -- gmatch never matches an anchored pattern
            for spec in pat:sub(1, 1) == "^" and vim.iter({ line:match(pat) }) or line:gmatch(pat) do
                local target = r.resolve(spec, dir, root)
                target = target and vim.uv.fs_realpath(target)
                local file = target and target ~= path and not seen[target] and load(target)
                if file then
                    seen[target] = true
                    local lines = outline(file, cfg.imports.max_lines)
                    out[#out + 1] = #lines > 0 and { path = target, lines = lines } or nil
                    if #out >= cfg.imports.max then
                        return out
                    end
                end
            end
        end
    end
    return out
end

local function covered(out, path, win, p, s, e)
    if p == path and s < win[2] and e >= win[1] then
        return true
    end
    for _, o in ipairs(out) do
        if o.first and o.path == p and s <= o.last and e >= o.first then
            return true
        end
    end
end

local function definitions(results, path, win, cfg, load, out)
    local added = 0
    for _, locs in ipairs(results) do
        for _, item in ipairs(locs) do
            local loc = item.loc
            local uri = loc.targetUri or loc.uri
            local range = loc.targetSelectionRange or loc.range
            local target = uri and range and uri:match("^file:") and vim.uv.fs_realpath(vim.uri_to_fname(uri))
            local file = target and load(target)
            local line = file and file.lines[range.start.line + 1]
            if line then
                local col = vim.str_byteindex(line, item.enc, range.start.character, false)
                local s, e = extent(file.root, range.start.line, col)
                e = math.min(e, s + cfg.defs.max_lines - 1)
                if not covered(out, path, win, target, s, e) then
                    out[#out + 1] =
                        { path = target, first = s, last = e, lines = vim.list_slice(file.lines, s + 1, e + 1) }
                    added = added + 1
                    if added >= cfg.defs.max then
                        return added
                    end
                end
            end
        end
    end
    return added
end

local function search_hits(hits, path, win, cfg, load, out)
    local added = 0
    for _, hit in ipairs(hits) do
        local target = vim.uv.fs_realpath(hit.path)
        local s = hit.start - 1
        local e = math.min(hit["end"] - 1, s + cfg.search.max_lines - 1)
        local file = target and load(target)
        if file and s < #file.lines and not covered(out, path, win, target, s, e) then
            local lines = vim.list_slice(file.lines, s + 1, e + 1)
            out[#out + 1] = { path = target, first = s, last = s + #lines - 1, lines = lines }
            added = added + 1
            if added >= cfg.search.max then
                return
            end
        end
    end
end

-- calls cb with definition locations per identifier, in identifier order
local function lsp_locations(buf, region, cfg, cb)
    local clients = vim.lsp.get_clients({ bufnr = buf, method = "textDocument/definition" })
    local idents = identifiers(buf, region[1], region[2], cfg.defs.max_idents)
    local results, left, finished = {}, #clients * #idents, false
    local function finish()
        if not finished then
            finished = true
            local keys = vim.tbl_keys(results)
            table.sort(keys)
            cb(vim.tbl_map(function(k)
                return results[k]
            end, keys))
        end
    end
    local function settle()
        left = left - 1
        if left == 0 then
            finish()
        end
    end
    if left == 0 then
        return finish()
    end
    vim.defer_fn(finish, cfg.defs.timeout_ms)

    local uri = vim.uri_from_bufnr(buf)
    for _, client in ipairs(clients) do
        local enc = client.offset_encoding
        for i, id in ipairs(idents) do
            local params = {
                textDocument = { uri = uri },
                position = { line = id.row, character = vim.str_utfindex(id.line, enc, id.col, false) },
            }
            local sent = client:request("textDocument/definition", params, function(err, result)
                if not err and result then
                    results[i] = results[i] or {}
                    for _, loc in ipairs(result.uri and { result } or result) do
                        table.insert(results[i], { loc = loc, enc = enc })
                    end
                end
                settle()
            end, buf)
            if not sent then
                settle()
            end
        end
    end
end

local function search(buf, region, cfg, cb)
    local opts = cfg.search
    local ok, m2v = pcall(require, "m2v")
    local root = opts and ok and m2v.root(buf)
    local query = table.concat(vim.tbl_map(vim.trim, api.nvim_buf_get_lines(buf, region[1], region[2], false)), " ")
    query = vim.trim(query):sub(1, opts and opts.max_query or 0)
    if not root or query == "" then
        return cb({})
    end
    local finished, job = false, nil
    local function finish(hits)
        if not finished then
            finished = true
            cb(hits)
        end
    end
    job = m2v.search(root, query, opts.n, finish)
    vim.defer_fn(function()
        if not finished and job then
            job:kill(15)
        end
        finish({})
    end, opts.timeout_ms)
end

-- win and region are 0-based, end-exclusive row ranges. Calls cb with a list of
-- { path, lines, first?, last? }: snippets carry a line range, outlines do not.
function M.gather(buf, win, region, cfg, cb)
    local path = vim.uv.fs_realpath(api.nvim_buf_get_name(buf)) or ""
    local load = loader(cfg)
    local out = {}
    if win[1] > 0 then
        local last = math.min(cfg.header_lines, win[1]) - 1
        out[1] = { path = path, first = 0, last = last, lines = api.nvim_buf_get_lines(buf, 0, last + 1, false) }
    end

    local locs, hits
    local function join()
        if not (locs and hits) then
            return
        end
        if definitions(locs, path, win, cfg, load, out) == 0 then
            vim.list_extend(out, imports(buf, path, cfg, load))
        end
        search_hits(hits, path, win, cfg, load, out)
        cb(out)
    end
    lsp_locations(buf, region, cfg, function(r)
        locs = r
        join()
    end)
    search(buf, region, cfg, function(h)
        hits = h
        join()
    end)
end

return M
