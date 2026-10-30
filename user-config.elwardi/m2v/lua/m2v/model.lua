-- model2vec static embeddings: mean of token rows, L2-normalized
local ffi = require("ffi")
local tokenizer = require("m2v.tokenizer")

local M = {}
M.__index = M

local half_table

-- LuaJIT has no half type; decode all 65536 bit patterns once
local function halves()
    if half_table then
        return half_table
    end
    half_table = ffi.new("float[65536]")
    for h = 0, 65535 do
        local sign = bit.band(h, 0x8000) ~= 0 and -1 or 1
        local exp = bit.band(bit.rshift(h, 10), 0x1f)
        local mant = bit.band(h, 0x3ff)
        local v
        if exp == 0 then
            v = mant * 2 ^ -24
        elseif exp == 31 then
            v = mant == 0 and math.huge or 0 / 0
        else
            v = (1 + mant / 1024) * 2 ^ (exp - 15)
        end
        half_table[h] = sign * v
    end
    return half_table
end

local function read(path)
    local f = assert(io.open(path, "rb"))
    local data = f:read("*a")
    f:close()
    return data
end

-- dir holds tokenizer.json and model.safetensors
function M.load(dir, max_tokens)
    local data = read(dir .. "/model.safetensors")
    local header_len = tonumber(ffi.cast("const uint64_t*", data)[0])
    local header = vim.json.decode(data:sub(9, 8 + header_len))
    local t = assert(header.embeddings, "m2v: safetensors has no embeddings tensor")
    assert(t.dtype == "F16" or t.dtype == "F32", "m2v: unsupported dtype " .. t.dtype)
    local base = ffi.cast("const uint8_t*", data) + 8 + header_len + t.data_offsets[1]
    return setmetatable({
        -- keeps the string alive under the casted pointers
        data = data,
        dim = t.shape[2],
        f16 = t.dtype == "F16" and ffi.cast("const uint16_t*", base) or nil,
        f32 = t.dtype == "F32" and ffi.cast("const float*", base) or nil,
        half = t.dtype == "F16" and halves() or nil,
        tok = tokenizer.load(dir .. "/tokenizer.json"),
        max_tokens = max_tokens or 512,
    }, M)
end

-- writes the embedding of text into out (float[dim]); false when no token is known
function M:embed(text, out)
    local dim, ids = self.dim, self.tok:encode(text, self.max_tokens)
    ffi.fill(out, dim * 4)
    if #ids == 0 then
        return false
    end
    local f16, f32, half = self.f16, self.f32, self.half
    for _, id in ipairs(ids) do
        local row = id * dim
        if f16 then
            for j = 0, dim - 1 do
                out[j] = out[j] + half[f16[row + j]]
            end
        else
            for j = 0, dim - 1 do
                out[j] = out[j] + f32[row + j]
            end
        end
    end
    local norm = 0
    for j = 0, dim - 1 do
        norm = norm + out[j] * out[j]
    end
    norm = math.sqrt(norm)
    if norm == 0 then
        return false
    end
    for j = 0, dim - 1 do
        out[j] = out[j] / norm
    end
    return true
end

return M
