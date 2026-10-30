-- Splits a file into retrieval units: top-level treesitter nodes, descending into
-- nodes that are too big, then merging small neighbours. Rows are 0-based inclusive.
local M = {}

local function windows(s, e, size, out)
    for a = s, e, size do
        out[#out + 1] = { a, math.min(a + size - 1, e) }
    end
end

local function units(node, max_lines, out)
    for child in node:iter_children() do
        if child:named() then
            local s, _, e, ecol = child:range()
            if ecol == 0 and e > s then
                e = e - 1
            end
            if e - s + 1 <= max_lines then
                out[#out + 1] = { s, e }
            elseif child:named_child_count() > 0 then
                units(child, max_lines, out)
            else
                windows(s, e, max_lines, out)
            end
        end
    end
end

local function root(lines, lang)
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

function M.split(lines, lang, opts)
    local parsed, found = root(lines, lang), {}
    if parsed then
        units(parsed, opts.max_lines, found)
        table.sort(found, function(a, b)
            return a[1] < b[1]
        end)
    end
    if #found == 0 then
        windows(0, #lines - 1, opts.max_lines, found)
        return found
    end
    local out, cur = {}, nil
    for _, u in ipairs(found) do
        if cur and u[1] <= cur[2] + 2 and math.max(u[2], cur[2]) - cur[1] + 1 <= opts.target_lines then
            cur[2] = math.max(cur[2], u[2])
        else
            cur = { u[1], u[2] }
            out[#out + 1] = cur
        end
    end
    return out
end

return M
