-- Generate treesitter conceal queries for CSF buffers
-- Icons sourced from user.lspicons for single-source-of-truth
local M = {}

---@return string Treesitter query string for CSF concealing
function M.conceal()
    local icons = require("user.lspicons")
    local function ic(s) return vim.trim(s) end

    -- Heading icons (from lspicons)
    local heading = {
        ic(icons.ui.Heading1), ic(icons.ui.Heading2), ic(icons.ui.Heading3),
        ic(icons.ui.Heading4), ic(icons.ui.Heading5), ic(icons.ui.Heading6),
    }

    -- XHTML element icons (from lspicons)
    local bullet     = ic(icons.ui.Circle)
    local quote_ic   = ic(icons.ui.BoldLineLeft)
    local link_ic    = ic(icons.kind.Reference)
    local file_ic    = ic(icons.kind.File)
    local check_no   = ic(icons.ui.Circle)
    local check_yes  = ic(icons.ui.BoxChecked)
    local ellipsis   = ic(icons.ui.Ellipsis)
    local tbl_cell   = ic(icons.ui.LineMiddle)

    -- AC structured-macro icons (from lspicons)
    local info_ic    = ic(icons.diagnostics.Information)
    local warn_ic    = ic(icons.diagnostics.Warning)
    local note_ic    = ic(icons.ui.Pencil)
    local hint_ic    = ic(icons.diagnostics.Hint)
    local code_ic    = ic(icons.ui.Code)
    local expand_ic  = ic(icons.ui.Triangle)
    local bmark_ic   = ic(icons.ui.BookMark)
    local list_ic    = ic(icons.ui.List)
    local target_ic  = ic(icons.ui.Target)
    local table_ic   = ic(icons.ui.Table)

    local q = {}
    local function add(s) table.insert(q, s) end

    -- ── XHTML Headings: split-tag conceal for icon + space ──
    for lvl = 1, 6 do
        local h = "h" .. lvl
        add(('(element (STag "<" @markup.heading.%d (Name) @_n) (#eq? @_n "%s") (#set! conceal "%s"))'):format(lvl, h, heading[lvl]))
        add(('(element (STag (Name) @conceal) (#eq? @conceal "%s") (#set! conceal ""))'):format(h))
        add(('(element (STag (Name) @_n ">" @punctuation.bracket) (#eq? @_n "%s") (#set! conceal " "))'):format(h))
        add(('(element (ETag (Name) @_n) @conceal (#eq? @_n "%s") (#set! conceal ""))'):format(h))
    end

    -- ── Inline formatting: hidden tags, content styled via highlights.scm ──
    for _, t in ipairs({
        { "strong", "@markup.strong" },
        { "em",     "@markup.italic" },
        { "code",   "@markup.raw" },
        { "s",      "@markup.strikethrough" },
    }) do
        add(('(element (STag (Name) @_n) %s (#eq? @_n "%s") (#set! conceal ""))'):format(t[2], t[1]))
        add(('(element (ETag (Name) @_n) %s (#eq? @_n "%s") (#set! conceal ""))'):format(t[2], t[1]))
    end

    -- ── Invisible tags ──
    add('(element (STag (Name) @_n) @conceal'
        .. ' (#any-of? @_n "p" "u" "ul" "ol" "table" "tr" "tbody" "thead" "span" "div" "pre" "sup" "sub")'
        .. ' (#set! conceal ""))')
    add('(element (ETag (Name) @_n) @conceal'
        .. ' (#any-of? @_n "p" "u" "ul" "ol" "table" "tr" "tbody" "thead" "span" "div" "pre" "sup" "sub")'
        .. ' (#set! conceal ""))')

    -- ── List items ──
    add(('(element (STag (Name) @_n) @markup.list (#eq? @_n "li") (#set! conceal "%s"))'):format(bullet))
    add( '(element (ETag (Name) @_n) @conceal (#eq? @_n "li") (#set! conceal ""))')

    -- ── Block elements ──
    add(('(element (STag (Name) @_n) @markup.quote (#eq? @_n "blockquote") (#set! conceal "%s"))'):format(quote_ic))
    add( '(element (ETag (Name) @_n) @conceal (#eq? @_n "blockquote") (#set! conceal ""))')
    local hr_ic      = ic(icons.ui.HorizontalRule)
    add(('(element (EmptyElemTag (Name) @_n) @punctuation.special (#eq? @_n "hr") (#set! conceal "%s"))'):format(hr_ic))
    add( '(element (EmptyElemTag (Name) @_n) @conceal (#eq? @_n "br") (#set! conceal ""))')

    -- ── Links & images ──
    add(('(element (STag (Name) @_n) @markup.link (#eq? @_n "a") (#set! conceal "%s"))'):format(link_ic))
    add( '(element (ETag (Name) @_n) @conceal (#eq? @_n "a") (#set! conceal ""))')
    add(('(element (EmptyElemTag (Name) @_n) @markup.link (#eq? @_n "img") (#set! conceal "%s"))'):format(file_ic))

    -- ── Table cells ──
    add(('(element (STag (Name) @_n) @punctuation.delimiter (#eq? @_n "td") (#set! conceal "%s"))'):format(tbl_cell))
    add( '(element (ETag (Name) @_n) @conceal (#eq? @_n "td") (#set! conceal ""))')
    local th_ic      = ic(icons.ui.LineBold)
    add(('(element (STag (Name) @_n) @markup.heading (#eq? @_n "th") (#set! conceal "%s"))'):format(th_ic))
    add( '(element (ETag (Name) @_n) @conceal (#eq? @_n "th") (#set! conceal ""))')

    -- ── Metadata comment ──
    add(('(Comment) @comment (#set! conceal "%s")'):format(ellipsis))

    -- ── AC: Task elements ──
    -- Capture entire ac_start_tag / ac_end_tag (not just tag name) to hide `<` and `>`
    -- Task internals stay on one line: <ac:task><ac:task-status>X</ac:task-status><ac:task-body>text</ac:task-body></ac:task>
    -- Renders as: ☐ text  (or ☑ text for complete)

    -- ac:task-list wrapper → hidden
    add('(ac_element (ac_start_tag (ac_tag_name) @_t) @conceal (#eq? @_t "ac:task-list") (#set! conceal ""))')
    add('(ac_element (ac_end_tag   (ac_tag_name) @_t) @conceal (#eq? @_t "ac:task-list") (#set! conceal ""))')
    -- ac:task → hidden (checkbox comes from status text below)
    add('(ac_element (ac_start_tag (ac_tag_name) @_t) @conceal (#eq? @_t "ac:task") (#set! conceal ""))')
    add('(ac_element (ac_end_tag   (ac_tag_name) @_t) @conceal (#eq? @_t "ac:task") (#set! conceal ""))')
    -- ac:task-id → hidden (start tag, content, end tag)
    add('(ac_element (ac_start_tag (ac_tag_name) @_t) @conceal (#eq? @_t "ac:task-id") (#set! conceal ""))')
    add('(ac_element (ac_end_tag   (ac_tag_name) @_t) @conceal (#eq? @_t "ac:task-id") (#set! conceal ""))')
    add('(ac_element (ac_start_tag (ac_tag_name) @_t) (content (CharData) @conceal) (#eq? @_t "ac:task-id") (#set! conceal ""))')
    -- ac:task-status → checkbox icon based on status text
    add('(ac_element (ac_start_tag (ac_tag_name) @_t) @conceal (#eq? @_t "ac:task-status") (#set! conceal ""))')
    add('(ac_element (ac_end_tag   (ac_tag_name) @_t) @conceal (#eq? @_t "ac:task-status") (#set! conceal ""))')
    add(('(ac_element (ac_start_tag (ac_tag_name) @_t) (content (CharData) @markup.list.unchecked) (#eq? @_t "ac:task-status") (#eq? @markup.list.unchecked "incomplete") (#set! conceal "%s"))'):format(check_no))
    add(('(ac_element (ac_start_tag (ac_tag_name) @_t) (content (CharData) @markup.list.checked)   (#eq? @_t "ac:task-status") (#eq? @markup.list.checked "complete")     (#set! conceal "%s"))'):format(check_yes))
    -- ac:task-body → space before content (creates gap between checkbox and text)
    add('(ac_element (ac_start_tag (ac_tag_name) @_t) @punctuation.special (#eq? @_t "ac:task-body") (#set! conceal " "))')
    add('(ac_element (ac_end_tag   (ac_tag_name) @_t) @conceal (#eq? @_t "ac:task-body") (#set! conceal ""))')

    -- ── AC: Math macros — conceal everything except the equation content ──
    -- Two-part conceal: parent ac_start_tag → "" hides delimiters/attrs,
    -- then child "<" token → icon overrides parent for that single char.
    -- This avoids conceal fragmentation from parser highlight extmarks on
    -- child nodes (ac_tag_name, Attribute, etc.) breaking the parent conceal
    -- into multiple visible icon segments.
    local math_block_ic  = ic(icons.ui.MathBlock)
    local math_inline_ic = ic(icons.ui.MathInline)

    -- mathblock: hide entire start tag, then show "<" as icon
    add('(ac_element (ac_start_tag (ac_tag_name) @_tag (Attribute (Name) @_attr (AttValue) @_val))'
        .. ' @conceal'
        .. ' (#eq? @_tag "ac:structured-macro") (#eq? @_attr "ac:name") (#match? @_val "mathblock")'
        .. ' (#set! conceal ""))')
    add(('(ac_element (ac_start_tag "<" @punctuation.special (ac_tag_name) @_tag (Attribute (Name) @_attr (AttValue) @_val))'
        .. ' (#eq? @_tag "ac:structured-macro") (#eq? @_attr "ac:name") (#match? @_val "mathblock")'
        .. ' (#set! conceal "%s"))'):format(math_block_ic))

    -- mathinline: same split approach
    add('(ac_element (ac_start_tag (ac_tag_name) @_tag (Attribute (Name) @_attr (AttValue) @_val))'
        .. ' @conceal'
        .. ' (#eq? @_tag "ac:structured-macro") (#eq? @_attr "ac:name") (#match? @_val "mathinline")'
        .. ' (#set! conceal ""))')
    add(('(ac_element (ac_start_tag "<" @punctuation.special (ac_tag_name) @_tag (Attribute (Name) @_attr (AttValue) @_val))'
        .. ' (#eq? @_tag "ac:structured-macro") (#eq? @_attr "ac:name") (#match? @_val "mathinline")'
        .. ' (#set! conceal "%s"))'):format(math_inline_ic))

    -- ac:plain-text-body and ac:parameter tags → hidden (wrap around math content)
    for _, inner_tag in ipairs({ "ac:plain-text-body", "ac:parameter" }) do
        add(('(ac_element (ac_start_tag (ac_tag_name) @_t) @conceal (#eq? @_t "%s") (#set! conceal ""))'):format(inner_tag))
        add(('(ac_element (ac_end_tag   (ac_tag_name) @_t) @conceal (#eq? @_t "%s") (#set! conceal ""))'):format(inner_tag))
    end

    -- ac:rich-text-body → hidden
    add('(ac_element (ac_start_tag (ac_tag_name) @_t) @conceal (#eq? @_t "ac:rich-text-body") (#set! conceal ""))')
    add('(ac_element (ac_end_tag   (ac_tag_name) @_t) @conceal (#eq? @_t "ac:rich-text-body") (#set! conceal ""))')

    -- CDATA delimiters → hidden (show only the content)
    add('(CDSect (CDStart) @conceal (#set! conceal ""))')
    add('(CDSect (CDEnd) @conceal (#set! conceal ""))')

    -- ── AC: Structured macro icons (override parser defaults with lspicons) ──
    -- Same two-part conceal as math: parent → "", child "<" → icon
    local macros = {
        { "info",    info_ic },
        { "warning", warn_ic },
        { "note",    note_ic },
        { "tip",     hint_ic },
        { "code",    code_ic },
        { "status",  target_ic },
        { "expand",  expand_ic },
        { "panel",   table_ic },
        { "anchor",  bmark_ic },
        { "toc",     list_ic },
    }
    for _, m in ipairs(macros) do
        add(('(ac_element (ac_start_tag (ac_tag_name) @_tag (Attribute (Name) @_attr (AttValue) @_val))'
            .. ' @conceal'
            .. ' (#eq? @_tag "ac:structured-macro") (#eq? @_attr "ac:name") (#match? @_val "%s")'
            .. ' (#set! conceal ""))'):format(m[1]))
        add(('(ac_element (ac_start_tag "<" @punctuation.special (ac_tag_name) @_tag (Attribute (Name) @_attr (AttValue) @_val))'
            .. ' (#eq? @_tag "ac:structured-macro") (#eq? @_attr "ac:name") (#match? @_val "%s")'
            .. ' (#set! conceal "%s"))'):format(m[1], m[2]))
    end
    -- All structured-macro closing tags → hidden (entire ac_end_tag, not just tag name)
    add('(ac_element (ac_end_tag (ac_tag_name) @_t) @conceal (#eq? @_t "ac:structured-macro") (#set! conceal ""))')

    -- ── AC: Link and image tags (ac:link, ac:image) ──
    add(('(ac_element (ac_start_tag (ac_tag_name) @_t) @conceal (#eq? @_t "ac:link") (#set! conceal "%s"))'):format(link_ic))
    add( '(ac_element (ac_end_tag   (ac_tag_name) @_t) @conceal (#eq? @_t "ac:link") (#set! conceal ""))')
    add(('(ac_element (ac_start_tag (ac_tag_name) @_t) @conceal (#eq? @_t "ac:image") (#set! conceal "%s"))'):format(file_ic))
    add( '(ac_element (ac_end_tag   (ac_tag_name) @_t) @conceal (#eq? @_t "ac:image") (#set! conceal ""))')

    -- ── AC: Emoticon → smiley ──
    local smiley_ic = ic(icons.misc.Smiley)
    add(('(ac_empty_tag (ac_tag_name) @conceal (#eq? @conceal "ac:emoticon") (#set! conceal "%s"))'):format(smiley_ic))

    -- ── ri: namespace elements → hidden (resource identifiers are metadata) ──
    add('(ri_empty_tag (ri_tag_name) @conceal (#set! conceal ""))')
    add('(ri_start_tag (ri_tag_name) @conceal (#set! conceal ""))')
    add('(ri_end_tag   (ri_tag_name) @conceal (#set! conceal ""))')

    return table.concat(q, "\n")
end

return M
