local api = vim.api

local M = {}

M.config = {
    cmd = "claude",
    model = "haiku",
    effort = "low",
    -- every completion stays in the session context; restart before it grows slow
    max_turns = 8,
    lines_before = 80,
    lines_after = 30,
    hl = "Comment",
    keys = { trigger = "<M-c>", accept = "<M-y>" },
}

local SYSTEM =
    [[You are a code completion engine inside an editor. The user message is an excerpt of a file with the cursor marked <HOLE>. Write the code that belongs at <HOLE>: continue the current statement, finish the block, or implement what a nearby comment describes. Match the indentation and style of the surrounding code; text before <HOLE> on its line is already typed, so do not repeat it or start with a newline. Never explain, ask, or refuse; always attempt a completion. Reply with exactly <fill>CODE</fill> and nothing else. Use <fill></fill> only when the code is already complete at that point.]]

local ns = api.nvim_create_namespace("claudefill")
local proc, pending, shown

local function clear()
    if shown and api.nvim_buf_is_valid(shown.buf) then
        api.nvim_buf_clear_namespace(shown.buf, ns, 0, -1)
    end
    shown = nil
end

local function progress(req, message)
    if req.handle then
        req.handle:report({ message = message })
        return
    end
    local ok, fidget = pcall(require, "fidget.progress")
    if ok then
        req.handle = fidget.handle.create({ title = "Infill", message = message, lsp_client = { name = "claude" } })
    end
end

local function done(req, message)
    if req.handle then
        req.handle:finish(message)
        req.handle = nil
    end
end

local function fresh(req)
    if api.nvim_get_current_buf() ~= req.buf or api.nvim_buf_get_changedtick(req.buf) ~= req.tick then
        return false
    end
    local pos = api.nvim_win_get_cursor(0)
    return pos[1] - 1 == req.row and pos[2] == req.col and api.nvim_get_mode().mode:sub(1, 1) == "i"
end

local function show(req, text)
    clear()
    -- anything outside <fill> is the model talking, not code
    text = text:match("<fill>(.-)</fill>")
    if not text then
        return false
    end
    text = text:gsub("^```[%w_+-]*\n", ""):gsub("\n?```%s*$", ""):gsub("%s+$", "")
    if req.at_indent then
        text = text:gsub("^%s+", "")
    end
    if text == "" then
        return false
    end
    local lines = vim.split(text, "\n", { plain = true })
    local opts = { virt_text = { { lines[1], M.config.hl } }, virt_text_pos = "inline" }
    if #lines > 1 then
        opts.virt_lines = vim.tbl_map(function(l)
            return { { l, M.config.hl } }
        end, vim.list_slice(lines, 2))
    end
    api.nvim_buf_set_extmark(req.buf, ns, req.row, req.col, opts)
    shown = { buf = req.buf, row = req.row, col = req.col, lines = lines }
    return true
end

local spawn, dispatch

local function retire(p)
    p.retired = true
    p.job:write(nil)
    if proc == p then
        proc = spawn()
    end
end

local function on_result(p, msg)
    local req = p.inflight
    p.inflight = nil
    p.turns = p.turns + 1
    if msg.is_error then
        vim.notify("claudefill: " .. tostring(msg.result), vim.log.levels.WARN)
        done(req, "error")
    elseif not fresh(req) then
        done(req, "discarded (buffer or cursor changed)")
    elseif type(msg.result) == "string" and show(req, msg.result) then
        done(req, ("%.1fs"):format((vim.uv.hrtime() - req.started) / 1e9))
    else
        done(req, "no suggestion")
    end
    if p.turns >= M.config.max_turns then
        retire(p)
    end
    dispatch()
end

local function on_stdout(p, data)
    local chunks = vim.split(p.partial .. data, "\n", { plain = true })
    p.partial = table.remove(chunks)
    for _, line in ipairs(chunks) do
        local ok, msg = pcall(vim.json.decode, line)
        if ok and type(msg) == "table" and msg.type == "result" then
            on_result(p, msg)
        end
    end
end

local function on_exit(p, obj)
    if proc == p then
        proc = nil
    end
    if p.inflight then
        done(p.inflight, "claude exited")
    end
    if not p.retired and obj.code ~= 0 then
        vim.notify(("claudefill: claude exited %d\n%s"):format(obj.code, obj.stderr or ""), vim.log.levels.ERROR)
    end
end

spawn = function()
    local p = { turns = 0, partial = "" }
    p.job = vim.system({
        M.config.cmd,
        "-p",
        "--input-format",
        "stream-json",
        "--output-format",
        "stream-json",
        "--verbose",
        "--model",
        M.config.model,
        "--effort",
        M.config.effort,
        "--system-prompt",
        SYSTEM,
        "--tools",
        "",
        "--strict-mcp-config",
        "--setting-sources",
        "",
        "--disable-slash-commands",
        "--no-session-persistence",
    }, {
        -- neutral cwd so no project CLAUDE.md gets pulled into the prompt
        cwd = vim.fn.stdpath("cache"),
        env = { CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1" },
        stdin = true,
        stdout = function(_, data)
            if data then
                vim.schedule(function()
                    on_stdout(p, data)
                end)
            end
        end,
    }, function(obj)
        vim.schedule(function()
            on_exit(p, obj)
        end)
    end)
    return p
end

-- one turn in flight at a time: stream-json merges messages queued mid-turn
dispatch = function()
    if not pending then
        return
    end
    proc = proc or spawn()
    if proc.inflight then
        return
    end
    proc.inflight, pending = pending, nil
    progress(proc.inflight, proc.turns == 0 and "starting session…" or "thinking…")
    local msg = { type = "user", message = { role = "user", content = proc.inflight.prompt } }
    proc.job:write(vim.json.encode(msg) .. "\n")
end

function M.trigger()
    clear()
    local buf = api.nvim_get_current_buf()
    local row, col = unpack(api.nvim_win_get_cursor(0))
    local first = math.max(0, row - 1 - M.config.lines_before)
    local lines = api.nvim_buf_get_lines(buf, first, row + M.config.lines_after, false)
    local cur = lines[row - first]
    lines[row - first] = cur:sub(1, col) .. "<HOLE>" .. cur:sub(col + 1)
    local name = vim.fn.fnamemodify(api.nvim_buf_get_name(buf), ":~:.")
    if pending then
        done(pending, "superseded")
    end
    pending = {
        started = vim.uv.hrtime(),
        buf = buf,
        row = row - 1,
        col = col,
        tick = api.nvim_buf_get_changedtick(buf),
        at_indent = cur:sub(1, col):match("^%s*$") ~= nil,
        prompt = ("File: %s (filetype: %s)\n\n%s"):format(name, vim.bo[buf].filetype, table.concat(lines, "\n")),
    }
    dispatch()
    if pending then
        progress(pending, "queued…")
    end
end

function M.accept()
    local s = shown
    if not s then
        return
    end
    clear()
    api.nvim_buf_set_text(s.buf, s.row, s.col, s.row, s.col, s.lines)
    local last = s.lines[#s.lines]
    api.nvim_win_set_cursor(0, { s.row + #s.lines, (#s.lines == 1 and s.col or 0) + #last })
end

function M.setup(opts)
    M.config = vim.tbl_deep_extend("force", M.config, opts or {})
    vim.keymap.set("i", M.config.keys.trigger, M.trigger, { desc = "Claude: request infill" })
    vim.keymap.set("i", M.config.keys.accept, M.accept, { desc = "Claude: accept infill" })
    api.nvim_create_autocmd({ "CursorMovedI", "TextChangedI", "InsertLeave", "BufLeave" }, {
        group = api.nvim_create_augroup("claudefill", { clear = true }),
        callback = clear,
    })
    api.nvim_create_autocmd("VimLeavePre", {
        callback = function()
            if proc then
                proc.job:kill(15)
            end
        end,
    })
    proc = spawn()
end

return M
