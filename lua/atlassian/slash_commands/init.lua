local M = {}

---@class SlashCommand
---@field name string Display name (e.g., "Heading 1")
---@field keywords string[] Extra search terms for fuzzy matching
---@field icon string Icon for completion menu
---@field description string Short description
---@field category string Category: Formatting, Code, Panels, Structure, Media, Inline
---@field filetypes string[] Applicable filetypes
---@field interactive boolean Whether post-insertion picker is needed

-- All filetypes that use CSF
local csf_ft = { "atlassian_confluence", "atlassian_jira", "csf" }

---@type SlashCommand[]
M.commands = {
    -- Formatting
    { name = "Heading 1",      keywords = { "h1", "title" },           icon = "󰉫", description = "Top-level heading",                category = "Formatting", filetypes = csf_ft, interactive = false },
    { name = "Heading 2",      keywords = { "h2", "subtitle" },        icon = "󰉬", description = "Second-level heading",              category = "Formatting", filetypes = csf_ft, interactive = false },
    { name = "Heading 3",      keywords = { "h3" },                    icon = "󰉭", description = "Third-level heading",               category = "Formatting", filetypes = csf_ft, interactive = false },
    { name = "Heading 4",      keywords = { "h4" },                    icon = "󰉮", description = "Fourth-level heading",              category = "Formatting", filetypes = csf_ft, interactive = false },
    { name = "Heading 5",      keywords = { "h5" },                    icon = "󰉯", description = "Fifth-level heading",               category = "Formatting", filetypes = csf_ft, interactive = false },
    { name = "Heading 6",      keywords = { "h6" },                    icon = "󰉰", description = "Sixth-level heading",               category = "Formatting", filetypes = csf_ft, interactive = false },
    { name = "Divider",        keywords = { "hr", "rule", "line" },    icon = "─", description = "Horizontal rule",                   category = "Formatting", filetypes = csf_ft, interactive = false },
    { name = "Quote",          keywords = { "blockquote", "cite" },    icon = "", description = "Block quote",                       category = "Formatting", filetypes = csf_ft, interactive = false },

    -- Code
    { name = "Code block",     keywords = { "code", "snippet", "pre" }, icon = "", description = "Fenced code block with language",   category = "Code",       filetypes = csf_ft, interactive = false },

    -- Panels (CSF — bridge handles ADF conversion for Jira)
    { name = "Info panel",     keywords = { "info", "note blue" },     icon = "", description = "Blue information panel",             category = "Panels",     filetypes = csf_ft, interactive = false },
    { name = "Note panel",     keywords = { "note", "yellow" },        icon = "", description = "Yellow note panel",                  category = "Panels",     filetypes = csf_ft, interactive = false },
    { name = "Warning panel",  keywords = { "warning", "caution" },    icon = "", description = "Red warning panel",                  category = "Panels",     filetypes = csf_ft, interactive = false },
    { name = "Tip panel",      keywords = { "tip", "success", "green" }, icon = "", description = "Green tip/success panel",          category = "Panels",     filetypes = csf_ft, interactive = false },

    -- Structure
    { name = "Table",          keywords = { "grid", "matrix" },        icon = "", description = "Insert table",                       category = "Structure",  filetypes = csf_ft, interactive = false },
    { name = "Expand",         keywords = { "collapse", "accordion" }, icon = "", description = "Expandable section",                 category = "Structure",  filetypes = csf_ft, interactive = false },
    { name = "Task list",      keywords = { "todo", "checklist" },     icon = "", description = "Task/checkbox list",                 category = "Structure",  filetypes = csf_ft, interactive = false },
    { name = "Bullet list",    keywords = { "ul", "unordered" },       icon = "", description = "Bulleted list",                      category = "Structure",  filetypes = csf_ft, interactive = false },
    { name = "Numbered list",  keywords = { "ol", "ordered" },         icon = "", description = "Numbered list",                      category = "Structure",  filetypes = csf_ft, interactive = false },

    -- Media
    { name = "Mention",        keywords = { "user", "at", "person" },  icon = "", description = "Mention a user",                     category = "Media",      filetypes = csf_ft, interactive = true },
    { name = "Page link",      keywords = { "link", "page", "wiki" },  icon = "", description = "Link to Confluence page",            category = "Media",      filetypes = csf_ft, interactive = true },
    { name = "Jira issue",     keywords = { "issue", "ticket" },       icon = "", description = "Link to Jira issue",                 category = "Media",      filetypes = csf_ft, interactive = true },
    { name = "External link",  keywords = { "url", "href", "web" },    icon = "", description = "External hyperlink",                 category = "Media",      filetypes = csf_ft, interactive = false },

    -- Inline
    { name = "Date",           keywords = { "calendar", "today" },     icon = "", description = "Insert date",                        category = "Inline",     filetypes = csf_ft, interactive = false },
    { name = "Status",         keywords = { "badge", "label", "lozenge" }, icon = "", description = "Colored status lozenge",         category = "Inline",     filetypes = csf_ft, interactive = true },

    -- Math
    { name = "Math block",     keywords = { "math", "latex", "equation" }, icon = "∑", description = "Block LaTeX equation",          category = "Math",       filetypes = csf_ft, interactive = false },
    { name = "Math inline",    keywords = { "math", "latex", "inline" },   icon = "∫", description = "Inline LaTeX equation",         category = "Math",       filetypes = csf_ft, interactive = false },

    -- Media (actions)
    { name = "Upload",         keywords = { "attach", "file", "image", "upload" }, icon = "", description = "Upload file attachment", category = "Media",      filetypes = csf_ft, interactive = true },
}

---@param ft string Filetype
---@return SlashCommand[]
function M.get_commands_for_filetype(ft)
    local result = {}
    for _, cmd in ipairs(M.commands) do
        if vim.tbl_contains(cmd.filetypes, ft) then
            table.insert(result, cmd)
        end
    end
    return result
end

return M
