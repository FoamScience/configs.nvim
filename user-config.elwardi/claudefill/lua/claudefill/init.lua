local api = vim.api
local context = require("claudefill.context")

local M = {}

M.config = {
    cmd = "claude",
    model = "haiku",
    effort = "low",
    -- every completion stays in the session context; restart before it grows slow
    max_turns = 8,
    lines_before = 80,
    lines_after = 30,
    -- rows around the cursor the model may rewrite in insert mode
    region = { before = 2, after = 8 },
    header_lines = 20,
    max_file_bytes = 512 * 1024,
    defs = { timeout_ms = 300, max_idents = 30, max = 8, max_lines = 40 },
    imports = { max = 6, max_lines = 40 },
    -- semantic search hits via m2v; false disables
    search = {
        n = 8,
        max = 4,
        max_lines = 40,
        max_query = 500,
        timeout_ms = 400,
    },
    -- accepting and cycling are the vim.lsp.inline_completion keys
    keys = { trigger = "<M-c>" },
}

local SYSTEM =
    [[You are a code completion and editing engine inside an editor. The user message ends with an excerpt of a file in which the editable part sits between a <REGION> line and a </REGION> line. The region contains <CURSOR>, where the user is typing: write the code that belongs at <CURSOR> (continue the statement, finish the block, implement what a nearby comment describes) and adjust later lines of the region when they must change to stay consistent. Everything outside the region is read-only and stays in the file: code after </REGION> directly follows your rewrite, so never repeat it; <context> and <outline> blocks show related code from this and other files. Match the indentation and style of the surrounding code and keep lines that need no change exactly as they are, blank lines included. Never explain, ask, or refuse. Reply with exactly <region>, a newline, the full rewritten region without <CURSOR>, a newline, </region>, and nothing else. Return the region unchanged when nothing needs doing.]]

local proc, pending
-- last finished suggestion; served while buffer and cursor are unchanged
local ready

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

local function position(row, col)
    return { line = row, character = col }
end

-- lsp.InlineCompletionItem for the rewritten region, positions in utf-8 bytes
local function to_item(req, text)
    -- anything outside <region> is the model talking, not code
    text = text:match("<region>\n?(.-)\n?</region>")
    if not text then
        return
    end
    text = text:gsub("^```[%w_+-]*\n", ""):gsub("\n?```%s*$", ""):gsub("<CURSOR>", "")
    -- text around the cursor survived untouched: plain insertion at the cursor
    local old, before = table.concat(req.old, "\n"), req.before
    local after = old:sub(#before + 1)
    if #text > #old and text:sub(1, #before) == before and text:sub(#text - #after + 1) == after then
        local at = position(req.row, req.col)
        return { insertText = text:sub(#before + 1, #text - #after), range = { start = at, ["end"] = at } }
    end

    local new = vim.split(text, "\n", { plain = true })
    local hunks = vim.text.diff(old .. "\n", table.concat(new, "\n") .. "\n", { result_type = "indices" })
    if #hunks == 0 then
        return
    end
    -- one item has one range: span every hunk, carrying unchanged lines in between
    local a_lo, a_hi, b_lo, b_hi = math.huge, -1, math.huge, -1
    for _, h in ipairs(hunks) do
        local sa, ca, sb, cb = unpack(h)
        a_lo, a_hi = math.min(a_lo, ca > 0 and sa or sa + 1), math.max(a_hi, ca > 0 and sa + ca - 1 or sa)
        b_lo, b_hi = math.min(b_lo, cb > 0 and sb or sb + 1), math.max(b_hi, cb > 0 and sb + cb - 1 or sb)
    end
    local added = table.concat(vim.list_slice(new, b_lo, b_hi), "\n")
    if a_lo > a_hi then
        -- pure addition after old line a_hi (0 = before the region)
        if a_hi == 0 then
            local at = position(req.first, 0)
            return { insertText = added .. "\n", range = { start = at, ["end"] = at } }
        end
        local at = position(req.first + a_hi - 1, #req.old[a_hi])
        return { insertText = "\n" .. added, range = { start = at, ["end"] = at } }
    end
    return {
        insertText = added,
        range = {
            start = position(req.first + a_lo - 1, 0),
            ["end"] = position(req.first + a_hi - 1, #req.old[a_hi]),
        },
    }
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
    else
        req.item = type(msg.result) == "string" and to_item(req, msg.result) or nil
        if req.item then
            ready = req
            done(req, ("%.1fs"):format((vim.uv.hrtime() - req.started) / 1e9))
            -- nvim requests inline completions on cursor events; ask it to come and get this one
            api.nvim_exec_autocmds("CursorMovedI", { buffer = req.buf })
        else
            done(req, "no suggestion")
        end
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

local seq = 0

local function prompt(req, snippets, win)
    local name = vim.fn.fnamemodify(api.nvim_buf_get_name(req.buf), ":~:.")
    local lines = api.nvim_buf_get_lines(req.buf, win[1], win[2], false)
    local rel = req.first - win[1]
    local cur = lines[req.row - win[1] + 1]
    lines[req.row - win[1] + 1] = cur:sub(1, req.col) .. "<CURSOR>" .. cur:sub(req.col + 1)
    table.insert(lines, rel + 1 + (req.last - req.first), "</REGION>")
    table.insert(lines, rel + 1, "<REGION>")
    local parts = {}
    for _, sn in ipairs(snippets) do
        local path = vim.fn.fnamemodify(sn.path, ":~:.")
        local body = table.concat(sn.lines, "\n")
        if sn.first then
            parts[#parts + 1] = ('<context path="%s" lines="%d-%d">\n%s\n</context>'):format(
                path,
                sn.first + 1,
                sn.last + 1,
                body
            )
        else
            parts[#parts + 1] = ('<outline path="%s">\n%s\n</outline>'):format(path, body)
        end
    end
    parts[#parts + 1] = ("File: %s (filetype: %s)\n\n%s"):format(
        name,
        vim.bo[req.buf].filetype,
        table.concat(lines, "\n")
    )
    return table.concat(parts, "\n\n")
end

-- first/last: 0-based end-exclusive rows the model may rewrite
local function request(buf, first, last, row, col)
    seq = seq + 1
    ready = nil
    local before = api.nvim_buf_get_lines(buf, first, row + 1, false)
    before[#before] = before[#before]:sub(1, col)
    local req = {
        seq = seq,
        started = vim.uv.hrtime(),
        buf = buf,
        first = first,
        last = last,
        row = row,
        col = col,
        tick = api.nvim_buf_get_changedtick(buf),
        old = api.nvim_buf_get_lines(buf, first, last, false),
        before = table.concat(before, "\n"),
    }
    local win = {
        math.max(0, first - M.config.lines_before),
        math.min(api.nvim_buf_line_count(buf), last + M.config.lines_after),
    }
    progress(req, "gathering context…")
    context.gather(buf, win, { first, last }, M.config, function(snippets)
        if req.seq ~= seq then
            return done(req, "superseded")
        end
        if not fresh(req) then
            return done(req, "discarded (buffer or cursor changed)")
        end
        req.prompt = prompt(req, snippets, win)
        if pending then
            done(pending, "superseded")
        end
        pending = req
        dispatch()
        if pending then
            progress(pending, "queued…")
        end
    end)
end

function M.trigger()
    local buf = api.nvim_get_current_buf()
    local row, col = unpack(api.nvim_win_get_cursor(0))
    local first = math.max(0, row - 1 - M.config.region.before)
    local last = math.min(api.nvim_buf_line_count(buf), row + M.config.region.after)
    -- models tend to drop blank lines at the region edges
    local function blank(r)
        return api.nvim_buf_get_lines(buf, r, r + 1, false)[1]:match("^%s*$")
    end
    while first < row - 1 and blank(first) do
        first = first + 1
    end
    while last > row and blank(last - 1) do
        last = last - 1
    end
    request(buf, first, last, row - 1, col)
end

-- answers textDocument/inlineCompletion with the ready suggestion, if it still fits
function M.complete(params)
    local req = ready
    if
        not req
        or vim.uri_to_bufnr(params.textDocument.uri) ~= req.buf
        or params.position.line ~= req.row
        or params.position.character ~= req.col
        or not fresh(req)
    then
        return { items = {} }
    end
    return { items = { req.item } }
end

local client_id

local function attach(buf)
    if vim.bo[buf].buftype == "" and api.nvim_buf_get_name(buf) ~= "" then
        vim.lsp.buf_attach_client(buf, client_id)
    end
end

function M.setup(opts)
    M.config = vim.tbl_deep_extend("force", M.config, opts or {})
    vim.keymap.set("i", M.config.keys.trigger, M.trigger, { desc = "Claude: request infill" })
    -- started before other servers so its item sorts first among inline completions
    client_id = vim.lsp.start({ name = "claudefill", cmd = require("claudefill.server") }, { attach = false })
    api.nvim_create_autocmd("BufEnter", {
        group = api.nvim_create_augroup("claudefill", { clear = true }),
        callback = function(ev)
            attach(ev.buf)
        end,
    })
    for _, buf in ipairs(api.nvim_list_bufs()) do
        if api.nvim_buf_is_loaded(buf) then
            attach(buf)
        end
    end
    api.nvim_create_autocmd("VimLeavePre", {
        callback = function()
            if proc then
                proc.job:kill(15)
            end
        end,
    })
    -- warm the session before the first trigger, not for every nvim started
    api.nvim_create_autocmd("InsertEnter", {
        once = true,
        callback = function()
            proc = proc or spawn()
        end,
    })
end

return M
