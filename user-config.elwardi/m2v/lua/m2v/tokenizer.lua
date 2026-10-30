-- BERT-style WordPiece, the subset of HF tokenizers that potion models use:
-- BertNormalizer (lowercase) + BertPreTokenizer + WordPiece
local ffi = require("ffi")

ffi.cdef([[
    typedef ptrdiff_t utf8proc_ssize_t;
    utf8proc_ssize_t utf8proc_map(const uint8_t *str, utf8proc_ssize_t strlen, uint8_t **dstptr, int options);
    void free(void *ptr);
]])

-- utf8proc ships inside nvim; NULLTERM | STABLE | DECOMPOSE | STRIPMARK
local STRIP_ACCENTS = bit.bor(1, 2, 16, 8192)

local M = {}
M.__index = M

-- HF strips accents whenever it lowercases: NFD, then drop marks
local function lower_ascii_or_unicode(text)
    if not text:find("[\128-\255]") then
        return text:lower()
    end
    local dst = ffi.new("uint8_t*[1]")
    local n = ffi.C.utf8proc_map(vim.fn.tolower(text), 0, dst, STRIP_ACCENTS)
    if n < 0 then
        return vim.fn.tolower(text)
    end
    local out = ffi.string(dst[0], n)
    ffi.C.free(dst[0])
    return out
end

function M.load(path)
    local f = assert(io.open(path, "rb"))
    local spec = vim.json.decode(f:read("*a"))
    f:close()
    local model = spec.model
    assert(model.type == "WordPiece", "m2v: unsupported tokenizer model " .. tostring(model.type))
    local norm = spec.normalizer or {}
    local longest = 0
    for token in pairs(model.vocab) do
        longest = math.max(longest, #token)
    end
    return setmetatable({
        vocab = model.vocab,
        longest = longest,
        memo = {},
        memo_size = 0,
        unk = model.vocab[model.unk_token],
        prefix = model.continuing_subword_prefix or "##",
        max_word = model.max_input_chars_per_word or 100,
        lowercase = norm.lowercase ~= false,
    }, M)
end

function M:pieces(word)
    if #word > self.max_word then
        return false
    end
    local vocab, start, pieces = self.vocab, 1, {}
    while start <= #word do
        local id, stop
        for e = math.min(#word, start + self.longest - 1), start, -1 do
            local piece = word:sub(start, e)
            id = vocab[start > 1 and self.prefix .. piece or piece]
            if id then
                stop = e
                break
            end
        end
        -- HF maps the whole word to [UNK] when any part fails
        if not id then
            return false
        end
        pieces[#pieces + 1] = id
        start = stop + 1
    end
    return pieces
end

function M:wordpiece(word, out)
    local pieces = self.memo[word]
    if pieces == nil then
        if self.memo_size >= 200000 then
            self.memo, self.memo_size = {}, 0
        end
        pieces = self:pieces(word)
        self.memo[word], self.memo_size = pieces, self.memo_size + 1
    end
    if pieces then
        local n = #out
        for i = 1, #pieces do
            out[n + i] = pieces[i]
        end
    end
end

-- ids without [UNK], as model2vec drops them before pooling
function M:encode(text, max_tokens)
    text = text:gsub("%c", " ")
    if self.lowercase then
        text = lower_ascii_or_unicode(text)
    end
    -- every ASCII punctuation char is its own word; non-ASCII bytes count as word chars
    text = text:gsub("%p", " %0 ")
    local out = {}
    for word in text:gmatch("%S+") do
        self:wordpiece(word, out)
        if max_tokens and #out >= max_tokens then
            break
        end
    end
    return max_tokens and vim.list_slice(out, 1, max_tokens) or out
end

return M
