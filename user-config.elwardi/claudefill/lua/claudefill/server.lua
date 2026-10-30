-- In-process language server: `cmd` for vim.lsp.start. Serves only
-- textDocument/inlineCompletion; buffers are read directly, so no text sync.
return function(dispatchers)
    local closing, last_id = false, 0
    local srv = {}

    -- replies go through the loop: the client registers the request after request() returns
    local function reply(callback, notify_reply_callback, id, err, result)
        vim.schedule(function()
            callback(err, result, id)
            if notify_reply_callback then
                notify_reply_callback(id)
            end
        end)
    end

    function srv.request(method, params, callback, notify_reply_callback)
        last_id = last_id + 1
        local id = last_id
        if method == "initialize" then
            reply(callback, notify_reply_callback, id, nil, {
                capabilities = { positionEncoding = "utf-8", inlineCompletionProvider = true, textDocumentSync = 0 },
                serverInfo = { name = "claudefill" },
            })
        elseif method == "shutdown" then
            reply(callback, notify_reply_callback, id, nil, nil)
        elseif method == "textDocument/inlineCompletion" then
            reply(callback, notify_reply_callback, id, nil, require("claudefill").complete(params))
        else
            reply(callback, notify_reply_callback, id, { code = -32601, message = "unsupported: " .. method })
        end
        return true, id
    end

    function srv.notify(method)
        if method == "exit" then
            closing = true
            dispatchers.on_exit(0, 0)
        end
        return true
    end

    function srv.is_closing()
        return closing
    end

    function srv.terminate()
        closing = true
    end

    return srv
end
