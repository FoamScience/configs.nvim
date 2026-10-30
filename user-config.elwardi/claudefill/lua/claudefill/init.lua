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
    hl = "Comment",
    hl_add = "DiffAdd",
    hl_delete = "DiffDelete",
    keys = { trigger = "<M-c>", accept = "<M-y>" },
}

local SYSTEM =
    [[You are a code completion and editing engine inside an editor. The user message ends with an excerpt of a file in which the editable part sits between a <REGION> line and a </REGION> line. If the region contains <CURSOR>, the user is typing there: write the code that belongs at <CURSOR> (continue the statement, finish the block, implement what a nearby comment describes) and adjust later lines of the region when they must change to stay consistent. Without <CURSOR>, the user selected the region for you to complete or correct: finish unfinished code, implement comments and TODOs, fix bugs. Everything outside the region is read-only and stays in the file: code after </REGION> directly follows your rewrite, so never repeat it; <context> and <outline> blocks show related code from this and other files. Match the indentation and style of the surrounding code and keep lines that need no change exactly as they are, blank lines included. Never explain, ask, or refuse. Reply with exactly <region>, a newline, the full rewritten region without <CURSOR>, a newline, </region>, and nothing else. Return the region unchanged when nothing needs doing.]]

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
    local mode = api.nvim_get_mode().mode:sub(1, 1)
    if req.mode == "n" then
        return mode == "n"
    end
    local pos = api.nvim_win_get_cursor(0)
    return pos[1] - 1 == req.row and pos[2] == req.col and mode == "i"
end

local function virt_line(buf, line, hl)
    return { { (line:gsub("\t", (" "):rep(vim.bo[buf].tabstop))), hl } }
end

local function show_insert(req, text)
    local lines = vim.split(text, "\n", { plain = true })
    local opts = { virt_text = { { lines[1], M.config.hl } }, virt_text_pos = "inline" }
    if #lines > 1 then
        opts.virt_lines = vim.tbl_map(function(l)
            return virt_line(req.buf, l, M.config.hl)
        end, vim.list_slice(lines, 2))
    end
    api.nvim_buf_set_extmark(req.buf, ns, req.row, req.col, opts)
    shown = { kind = "insert", mode = req.mode, buf = req.buf, row = req.row, col = req.col, lines = lines }
end

local function show_diff(req, new)
    local hunks =
        vim.text.diff(table.concat(req.old, "\n") .. "\n", table.concat(new, "\n") .. "\n", { result_type = "indices" })
    if #hunks == 0 then
        return false
    end
    for _, h in ipairs(hunks) do
        local sa, ca, sb, cb = unpack(h)
        local added = vim.tbl_map(function(l)
            return virt_line(req.buf, l, M.config.hl_add)
        end, vim.list_slice(new, sb, sb + cb - 1))
        if ca > 0 then
            local first = req.first + sa - 1
            api.nvim_buf_set_extmark(req.buf, ns, first, 0, {
                end_row = first + ca,
                hl_group = M.config.hl_delete,
                hl_eol = true,
            })
            if cb > 0 then
                api.nvim_buf_set_extmark(req.buf, ns, first + ca - 1, 0, { virt_lines = added })
            end
        elseif sa == 0 then
            api.nvim_buf_set_extmark(req.buf, ns, req.first, 0, { virt_lines = added, virt_lines_above = true })
        else
            api.nvim_buf_set_extmark(req.buf, ns, req.first + sa - 1, 0, { virt_lines = added })
        end
    end
    local sb, cb = hunks[#hunks][3], hunks[#hunks][4]
    shown = {
        kind = "replace",
        mode = req.mode,
        buf = req.buf,
        first = req.first,
        last = req.last,
        lines = new,
        -- offset of the last changed line inside the new region
        land = math.max(sb + math.max(cb, 1) - 1, 1),
    }
    return true
end

local function show(req, text)
    clear()
    -- anything outside <region> is the model talking, not code
    text = text:match("<region>\n?(.-)\n?</region>")
    if not text then
        return false
    end
    text = text:gsub("^```[%w_+-]*\n", ""):gsub("\n?```%s*$", ""):gsub("<CURSOR>", "")
    local new = vim.split(text, "\n", { plain = true })
    if req.mode == "i" then
        -- text around the cursor survived untouched: plain insertion, show as ghost text
        local old, before = table.concat(req.old, "\n"), req.before
        local after = old:sub(#before + 1)
        if #text > #old and text:sub(1, #before) == before and text:sub(#text - #after + 1) == after then
            show_insert(req, text:sub(#before + 1, #text - #after))
            return true
        end
    end
    return show_diff(req, new)
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

local seq = 0

local function prompt(req, snippets, win)
    local name = vim.fn.fnamemodify(api.nvim_buf_get_name(req.buf), ":~:.")
    local lines = api.nvim_buf_get_lines(req.buf, win[1], win[2], false)
    local rel = req.first - win[1]
    if req.mode == "i" then
        local cur = lines[req.row - win[1] + 1]
        lines[req.row - win[1] + 1] = cur:sub(1, req.col) .. "<CURSOR>" .. cur:sub(req.col + 1)
    end
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
local function request(buf, first, last, cursor)
    clear()
    seq = seq + 1
    local req = {
        seq = seq,
        started = vim.uv.hrtime(),
        buf = buf,
        first = first,
        last = last,
        mode = cursor and "i" or "n",
        tick = api.nvim_buf_get_changedtick(buf),
        old = api.nvim_buf_get_lines(buf, first, last, false),
    }
    if cursor then
        req.row, req.col = cursor[1], cursor[2]
        local before = api.nvim_buf_get_lines(buf, first, req.row + 1, false)
        before[#before] = before[#before]:sub(1, req.col)
        req.before = table.concat(before, "\n")
    end
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
    request(buf, first, last, { row - 1, col })
end

function M.trigger_visual()
    local a, b = vim.fn.line("v"), vim.fn.line(".")
    api.nvim_feedkeys(api.nvim_replace_termcodes("<Esc>", true, false, true), "nx", false)
    request(api.nvim_get_current_buf(), math.min(a, b) - 1, math.max(a, b))
end

function M.accept()
    local s = shown
    if not s then
        return
    end
    clear()
    if s.kind == "insert" then
        api.nvim_buf_set_text(s.buf, s.row, s.col, s.row, s.col, s.lines)
        local last = s.lines[#s.lines]
        api.nvim_win_set_cursor(0, { s.row + #s.lines, (#s.lines == 1 and s.col or 0) + #last })
        return
    end
    api.nvim_buf_set_lines(s.buf, s.first, s.last, false, s.lines)
    local row = math.min(s.first + s.land, api.nvim_buf_line_count(s.buf))
    local line = api.nvim_buf_get_lines(s.buf, row - 1, row, false)[1]
    api.nvim_win_set_cursor(0, { row, #line })
end

function M.setup(opts)
    M.config = vim.tbl_deep_extend("force", M.config, opts or {})
    vim.keymap.set("i", M.config.keys.trigger, M.trigger, { desc = "Claude: request infill" })
    vim.keymap.set("x", M.config.keys.trigger, M.trigger_visual, { desc = "Claude: rewrite selection" })
    vim.keymap.set({ "i", "n" }, M.config.keys.accept, M.accept, { desc = "Claude: accept infill" })
    local group = api.nvim_create_augroup("claudefill", { clear = true })
    api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "BufLeave" }, { group = group, callback = clear })
    api.nvim_create_autocmd({ "CursorMovedI", "InsertLeave" }, {
        group = group,
        callback = function()
            if shown and shown.mode == "i" then
                clear()
            end
        end,
    })
    -- normal-mode previews survive moving around inside the region to read them
    api.nvim_create_autocmd({ "CursorMoved", "InsertEnter" }, {
        group = group,
        callback = function(ev)
            if not (shown and shown.mode == "n") then
                return
            end
            local row = api.nvim_win_get_cursor(0)[1] - 1
            if ev.event == "InsertEnter" or row < shown.first or row >= shown.last then
                clear()
            end
        end,
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
