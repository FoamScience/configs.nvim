-- Semantic code search on model2vec static embeddings, run in LuaJIT: treesitter
-- chunks indexed by a background `nvim -l`, fused with ripgrep matches.
local min_live_words = 3
local n = 30

local test_patterns =
    { "^tests?/", "/tests?/", "^spec/", "/spec/", "test_[^/]*$", "_test%.[^/]*$", "%.test%.[^/]*$", "%.spec%.[^/]*$" }

local function is_test(path)
    for _, pat in ipairs(test_patterns) do
        if path:find(pat) then
            return true
        end
    end
    return false
end

-- never index a directory without a project marker, like ~
local function root(cwd)
    local r = require("m2v").root(cwd)
    if not r then
        vim.notify("m2v: no project root above " .. cwd, vim.log.levels.WARN)
    end
    return r
end

local function to_items(hits, query, cwd)
    local keep_tests = query:lower():find("test") or query:lower():find("spec")
    local items = {}
    for _, hit in ipairs(hits) do
        local rel = vim.fs.relpath(cwd, hit.path) or hit.path
        if keep_tests or not is_test(rel) then
            local line = vim.fn.readfile(hit.path, "", hit.start)[hit.start] or ""
            table.insert(items, {
                file = hit.path,
                pos = { hit.start, 0 },
                end_pos = { hit["end"], 0 },
                text = rel .. " " .. vim.trim(line),
            })
        end
    end
    return items
end

local function search(query)
    local cwd = vim.fn.getcwd()
    local r = root(cwd)
    if not r then
        return
    end
    require("m2v").search(r, query, n, function(hits)
        require("snacks").picker({ title = "m2v: " .. query, items = to_items(hits, query, cwd), format = "file" })
    end)
end

local function search_live()
    require("snacks").picker({
        title = "m2v (live)",
        live = true,
        supports_live = true,
        format = "file",
        finder = function(_, ctx)
            local query = vim.trim(ctx.filter.search)
            local r = #vim.split(query, "%s+") >= min_live_words and root(ctx.filter.cwd)
            if not r then
                return {}
            end
            return function(cb)
                local items
                vim.schedule(function()
                    local job = require("m2v").search(r, query, n, function(h)
                        items = to_items(h, query, ctx.filter.cwd)
                        ctx.async:resume()
                    end)
                    ctx.async:on("abort", function()
                        if job then
                            job:kill(15)
                        end
                    end)
                end)
                ctx.async:suspend()
                for _, item in ipairs(items or {}) do
                    cb(item)
                end
            end
        end,
    })
end

return {
    dir = vim.fn.stdpath("config") .. "/user-config/m2v",
    name = "m2v",
    main = "m2v",
    opts = {},
    keys = {
        {
            "<leader>fS",
            function()
                require("snacks").input({ prompt = "Semantic search" }, function(q)
                    if q and q ~= "" then
                        search(q)
                    end
                end)
            end,
            desc = "Semantic search (m2v)",
        },
        { "<leader>fL", search_live, desc = "Semantic search live (m2v)" },
    },
}
