local M = {}

local types = require('blink.cmp.types')

local unicode_items = {
    { label = "∞", insertText = "∞", kind = types.CompletionItemKind.Text, filterText = "infinity" },
    { label = "∀", insertText = "∀", kind = types.CompletionItemKind.Text, filterText = "for_all" },
    { label = "∃", insertText = "∃", kind = types.CompletionItemKind.Text, filterText = "exists" },
    { label = "⟹", insertText = "⇒", kind = types.CompletionItemKind.Text, filterText = "implies" },
    { label = "⊨", insertText = "⊨", kind = types.CompletionItemKind.Text, filterText = "entails" },
    { label = "⊢", insertText = "⊢", kind = types.CompletionItemKind.Text, filterText = "provable" },
    { label = "⇔", insertText = "⇔", kind = types.CompletionItemKind.Text, filterText = "equivalent" },
    { label = "≈", insertText = "≈", kind = types.CompletionItemKind.Text, filterText = "approximate" },
    { label = "≠", insertText = "≠", kind = types.CompletionItemKind.Text, filterText = "not_equal" },
}

function M.new(opts)
    local self = setmetatable({}, { __index = M })
    self.opts = opts
    self.opts.name = "unicode"
    self.opts.items = unicode_items
    return self
end

function M:enabled() return vim.bo.filetype == "lean" end

function M:get_completions(ctx, callback)
    callback({
        items = unicode_items,
        is_incomplete_backward = true,
        is_incomplete_forward = true,
    })
    return function() end
end

return M
