-- On-disk index per root: meta.json (files and chunk rows) + vectors.bin (float32 rows)
local ffi = require("ffi")
local chunk = require("m2v.chunk")

local M = {}

local VERSION = 1

local function read(path)
    local f = io.open(path, "rb")
    if not f then
        return
    end
    local data = f:read("*a")
    f:close()
    return data
end

local function list_files(root)
    for _, cmd in ipairs({ { "rg", "--files", "--no-messages" }, { "git", "ls-files" } }) do
        if vim.fn.executable(cmd[1]) == 1 then
            local res = vim.system(cmd, { cwd = root, text = true }):wait()
            if res.code == 0 then
                local files = vim.split(vim.trim(res.stdout), "\n", { trimempty = true })
                table.sort(files)
                return files
            end
        end
    end
    return {}
end

local function stamp(stat)
    return ("%d.%09d:%d"):format(stat.mtime.sec, stat.mtime.nsec, stat.size)
end

-- meta.chunks is flat: file index, first row, last row per chunk
function M.load(dir)
    local meta_raw, vectors = read(dir .. "/meta.json"), read(dir .. "/vectors.bin")
    if not meta_raw or not vectors then
        return
    end
    local ok, meta = pcall(vim.json.decode, meta_raw)
    if not ok or meta.version ~= VERSION or #vectors ~= #meta.chunks / 3 * meta.dim * 4 then
        return
    end
    local by_path = {}
    for i, f in ipairs(meta.files) do
        by_path[f.path] = i
    end
    return {
        meta = meta,
        dim = meta.dim,
        n = #meta.chunks / 3,
        data = vectors,
        vectors = ffi.cast("const float*", vectors),
        by_path = by_path,
    }
end

-- 0-based chunk indices of a file, in row order
function M.file_chunks(idx, rel)
    local i = idx.by_path[rel]
    local f = i and idx.meta.files[i]
    return f and f.first or 0, f and f.count or 0
end

function M.chunk(idx, c)
    local ch = idx.meta.chunks
    return idx.meta.files[ch[c * 3 + 1]].path, ch[c * 3 + 2], ch[c * 3 + 3]
end

local function binary(data)
    return data:sub(1, 8000):find("\0", 1, true) ~= nil
end

function M.build(root, dir, model, opts, progress)
    vim.fn.mkdir(dir, "p")
    local old = M.load(dir)
    if old and old.meta.model ~= opts.model then
        old = nil
    end
    local dim = model.dim
    local meta = { version = VERSION, model = opts.model, dim = dim, files = {}, chunks = {} }
    local tmp = dir .. "/vectors.bin.tmp"
    local out = assert(io.open(tmp, "wb"))
    local vec = ffi.new("float[?]", dim)
    local files = list_files(root)
    local n = 0
    for i, rel in ipairs(files) do
        local abs = root .. "/" .. rel
        local stat = vim.uv.fs_stat(abs)
        if stat and stat.type == "file" and stat.size <= opts.max_file_bytes then
            local entry = { path = rel, stamp = stamp(stat), first = n, count = 0 }
            local prev = old and old.by_path[rel] and old.meta.files[old.by_path[rel]]
            if prev and prev.stamp == entry.stamp then
                out:write(ffi.string(old.vectors + prev.first * dim, prev.count * dim * 4))
                for c = prev.first, prev.first + prev.count - 1 do
                    local _, s, e = M.chunk(old, c)
                    vim.list_extend(meta.chunks, { #meta.files + 1, s, e })
                end
                entry.count = prev.count
            else
                local data = read(abs)
                if data and not binary(data) then
                    local lines = vim.split(data, "\n", { plain = true })
                    -- content sniffing is slow; only shebang scripts need it
                    local ft = vim.filetype.match({ filename = abs })
                        or lines[1]:find("^#!") and vim.filetype.match({ filename = abs, contents = lines })
                        or nil
                    local lang = ft and vim.treesitter.language.get_lang(ft)
                    for _, r in ipairs(chunk.split(lines, lang, opts.chunk)) do
                        local text = rel .. "\n" .. table.concat(lines, "\n", r[1] + 1, r[2] + 1)
                        if model:embed(text, vec) then
                            out:write(ffi.string(vec, dim * 4))
                            vim.list_extend(meta.chunks, { #meta.files + 1, r[1], r[2] })
                            entry.count = entry.count + 1
                        end
                    end
                end
            end
            if entry.count > 0 then
                meta.files[#meta.files + 1] = entry
                n = n + entry.count
            end
        end
        if progress and (i % 200 == 0 or i == #files) then
            progress(i, #files)
        end
    end
    out:close()
    local f = assert(io.open(dir .. "/meta.json.tmp", "wb"))
    f:write(vim.json.encode(meta))
    f:close()
    assert(vim.uv.fs_rename(tmp, dir .. "/vectors.bin"))
    assert(vim.uv.fs_rename(dir .. "/meta.json.tmp", dir .. "/meta.json"))
end

return M
