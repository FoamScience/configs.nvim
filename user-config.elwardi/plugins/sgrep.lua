local min_live_words = 3
local repo = "https://github.com/context-dot-dev/sgrep"
local installing = false

local function bin()
    local b = vim.fn.exepath("sgrep")
    if b ~= "" then
        return b
    end
    b = (vim.env.CARGO_HOME or vim.fn.expand("~/.cargo")) .. "/bin/sgrep"
    if vim.fn.executable(b) == 1 then
        return b
    end
end

if not bin() and vim.fn.executable("cargo") == 0 then
    return {}
end

local function ensure(cb)
    if bin() then
        return cb()
    end
    if installing then
        return vim.notify("sgrep is still building", vim.log.levels.INFO, { title = "sgrep" })
    end
    installing = true
    vim.notify("sgrep not found, building from " .. repo, vim.log.levels.INFO, { title = "sgrep" })
    vim.system({ "cargo", "install", "--git", repo }, { text = true }, vim.schedule_wrap(function(res)
        installing = false
        if res.code ~= 0 or not bin() then
            return vim.notify("sgrep build failed:\n" .. res.stderr, vim.log.levels.ERROR, { title = "sgrep" })
        end
        vim.notify("sgrep installed", vim.log.levels.INFO, { title = "sgrep" })
        cb()
    end))
end

local function cmd(query, cwd)
    return { bin(), "--json", "-n", "30", query, cwd }
end

local test_patterns = { "^tests?/", "/tests?/", "^spec/", "/spec/", "test_[^/]*$", "_test%.[^/]*$", "%.test%.[^/]*$", "%.spec%.[^/]*$" }

local function is_test(path)
    for _, pat in ipairs(test_patterns) do
        if path:find(pat) then
            return true
        end
    end
    return false
end

local function to_items(stdout, query)
    local keep_tests = query:lower():find("test") or query:lower():find("spec")
    local items = {}
    for _, hit in ipairs(vim.json.decode(stdout)) do
        if keep_tests or not is_test(hit.path) then
            table.insert(items, {
                file = hit.path,
                pos = { hit.start, 0 },
                end_pos = { hit["end"], 0 },
                text = hit.path .. " " .. vim.split(hit.content, "\n")[1],
            })
        end
    end
    return items
end

local function sgrep(query)
    vim.system(cmd(query, vim.fn.getcwd()), { text = true }, vim.schedule_wrap(function(res)
        if res.code ~= 0 then
            return vim.notify(res.stderr, vim.log.levels.ERROR, { title = "sgrep" })
        end
        require("snacks").picker({ title = "sgrep: " .. query, items = to_items(res.stdout, query), format = "file" })
    end))
end

local function sgrep_live()
    require("snacks").picker({
        title = "sgrep (live)",
        live = true,
        supports_live = true,
        format = "file",
        finder = function(_, ctx)
            local query = vim.trim(ctx.filter.search)
            if #vim.split(query, "%s+") < min_live_words then
                return {}
            end
            return function(cb)
                local res
                local proc = vim.system(cmd(query, ctx.filter.cwd), { text = true }, function(r)
                    res = r
                    ctx.async:resume()
                end)
                ctx.async:on("abort", function()
                    proc:kill(15)
                end)
                ctx.async:suspend()
                if res and res.code == 0 then
                    for _, item in ipairs(to_items(res.stdout, query)) do
                        cb(item)
                    end
                end
            end
        end,
    })
end

return {
    "folke/snacks.nvim",
    optional = true,
    lazy = false,
    keys = {
        {
            "<leader>fS",
            function()
                ensure(function()
                    require("snacks").input({ prompt = "Semantic search" }, function(q)
                        if q and q ~= "" then
                            sgrep(q)
                        end
                    end)
                end)
            end,
            desc = "Semantic grep (sgrep)",
        },
        {
            "<leader>fL",
            function()
                ensure(sgrep_live)
            end,
            desc = "Semantic grep live (sgrep)",
        },
    },
}
