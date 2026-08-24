-- Renders mermaid fences to PNG so image.nvim can display them; image.nvim has
-- no mermaid support of its own (snacks.image did this before the swap, see
-- lua/user/image.lua for why we swapped).
--
-- Requires mermaid-cli (`mmdc`). mmdc drives a puppeteer-managed chrome and
-- pins one exact build, which breaks whenever the shared puppeteer cache holds
-- a different one; find_chrome() below is the fallback for that case.
local M = {}

local cache_dir = vim.fn.stdpath("cache") .. "/mermaid"
local pending = {}
local chrome = nil

local function theme()
    return vim.o.background == "light" and "neutral" or "dark"
end

local function find_chrome()
    local cached = vim.fn.glob(vim.fn.expand("~/.cache/puppeteer/chrome/*/chrome-linux64/chrome"), false, true)
    table.sort(cached)
    local newest = cached[#cached]
    if newest and vim.fn.executable(newest) == 1 then
        return newest
    end
    for _, exe in ipairs({ "chromium", "chromium-browser", "google-chrome", "google-chrome-stable" }) do
        local path = vim.fn.exepath(exe)
        if path ~= "" then
            return path
        end
    end
end

-- Content- and theme-addressed, so edits and `set background` both invalidate.
M.path_for = function(code)
    return ("%s/%s-%s.png"):format(cache_dir, vim.fn.sha256(code), theme())
end

local function is_rendered(path)
    return vim.fn.filereadable(path) == 1 and vim.fn.getfsize(path) > 0
end

-- Returns the PNG path if it is already on disk, otherwise starts a render and
-- returns nil; on_ready(path) fires once the render lands.
M.ensure = function(code, on_ready)
    local out = M.path_for(code)
    if is_rendered(out) then
        return out
    end
    if pending[out] or vim.fn.executable("mmdc") == 0 then
        return nil
    end

    pending[out] = true
    vim.fn.mkdir(cache_dir, "p")
    local src = vim.fn.tempname() .. ".mmd"
    vim.fn.writefile(vim.split(code, "\n"), src)

    local function attempt(env, may_retry)
        local cmd = { "mmdc", "-i", src, "-o", out, "-b", "transparent", "-t", theme(), "-s", "2" }
        vim.system(cmd, { env = env, text = true }, function(res)
            vim.schedule(function()
                if res.code == 0 and is_rendered(out) then
                    pending[out] = nil
                    vim.fn.delete(src)
                    on_ready(out)
                    return
                end
                local stderr = res.stderr or ""
                if may_retry and stderr:match("Could not find Chrome") then
                    chrome = chrome or find_chrome()
                    if chrome then
                        return attempt({ PUPPETEER_EXECUTABLE_PATH = chrome }, false)
                    end
                end
                pending[out] = nil
                vim.fn.delete(src)
                vim.notify("mermaid render failed:\n" .. stderr, vim.log.levels.WARN)
            end)
        end)
    end

    attempt(chrome and { PUPPETEER_EXECUTABLE_PATH = chrome } or nil, chrome == nil)
    return nil
end

return M
