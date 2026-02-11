-- Unified CSF snippet templates for both Confluence and Jira
-- Uses LSP snippet format: ${1:placeholder}, $0 for final cursor
local M = {}

---@type table<string, string>
M.templates = {
    ["Heading 1"] = "<h1>${1:Heading}</h1>\n$0",
    ["Heading 2"] = "<h2>${1:Heading}</h2>\n$0",
    ["Heading 3"] = "<h3>${1:Heading}</h3>\n$0",
    ["Heading 4"] = "<h4>${1:Heading}</h4>\n$0",
    ["Heading 5"] = "<h5>${1:Heading}</h5>\n$0",
    ["Heading 6"] = "<h6>${1:Heading}</h6>\n$0",

    ["Divider"] = "<hr />\n$0",

    ["Quote"] = table.concat({
        "<blockquote>",
        "  <p>${1:Quote text}</p>",
        "</blockquote>",
        "$0",
    }, "\n"),

    ["Code block"] = table.concat({
        '<ac:structured-macro ac:name="code"><ac:parameter ac:name="language">',
        "${1:java}",
        "</ac:parameter><ac:plain-text-body><![CDATA[",
        "${2:code}",
        "]]></ac:plain-text-body></ac:structured-macro>",
        "$0",
    }, "\n"),

    ["Info panel"] = table.concat({
        '<ac:structured-macro ac:name="info">',
        "  <ac:rich-text-body>",
        "    <p>${1:Information text}</p>",
        "  </ac:rich-text-body>",
        "</ac:structured-macro>",
        "$0",
    }, "\n"),

    ["Note panel"] = table.concat({
        '<ac:structured-macro ac:name="note">',
        "  <ac:rich-text-body>",
        "    <p>${1:Note text}</p>",
        "  </ac:rich-text-body>",
        "</ac:structured-macro>",
        "$0",
    }, "\n"),

    ["Warning panel"] = table.concat({
        '<ac:structured-macro ac:name="warning">',
        "  <ac:rich-text-body>",
        "    <p>${1:Warning text}</p>",
        "  </ac:rich-text-body>",
        "</ac:structured-macro>",
        "$0",
    }, "\n"),

    ["Tip panel"] = table.concat({
        '<ac:structured-macro ac:name="tip">',
        "  <ac:rich-text-body>",
        "    <p>${1:Tip text}</p>",
        "  </ac:rich-text-body>",
        "</ac:structured-macro>",
        "$0",
    }, "\n"),

    ["Table"] = table.concat({
        "<table>",
        "  <tbody>",
        "    <tr>",
        "      <th><p>${1:Header 1}</p></th>",
        "      <th><p>${2:Header 2}</p></th>",
        "    </tr>",
        "    <tr>",
        "      <td><p>${3:Cell 1}</p></td>",
        "      <td><p>${4:Cell 2}</p></td>",
        "    </tr>",
        "  </tbody>",
        "</table>",
        "$0",
    }, "\n"),

    ["Expand"] = table.concat({
        '<ac:structured-macro ac:name="expand">',
        '  <ac:parameter ac:name="title">${1:Click to expand}</ac:parameter>',
        "  <ac:rich-text-body>",
        "    <p>${2:Content}</p>",
        "  </ac:rich-text-body>",
        "</ac:structured-macro>",
        "$0",
    }, "\n"),

    ["Task list"] = table.concat({
        "<ac:task-list>",
        "  <ac:task>",
        "    <ac:task-status>incomplete</ac:task-status>",
        "    <ac:task-body>${1:Task item}</ac:task-body>",
        "  </ac:task>",
        "</ac:task-list>",
        "$0",
    }, "\n"),

    ["Bullet list"] = table.concat({
        "<ul>",
        "  <li><p>${1:Item 1}</p></li>",
        "  <li><p>${2:Item 2}</p></li>",
        "  <li><p>${3:Item 3}</p></li>",
        "</ul>",
        "$0",
    }, "\n"),

    ["Numbered list"] = table.concat({
        "<ol>",
        "  <li><p>${1:Item 1}</p></li>",
        "  <li><p>${2:Item 2}</p></li>",
        "  <li><p>${3:Item 3}</p></li>",
        "</ol>",
        "$0",
    }, "\n"),

    ["Mention"] = table.concat({
        "<ac:link>",
        '  <ri:user ri:account-id="${1:account-id}" />',
        "</ac:link>$0",
    }, "\n"),

    ["Page link"] = table.concat({
        "<ac:link>",
        '  <ri:page ri:content-title="${1:Page Title}" ri:space-key="${2:SPACE}" />',
        "</ac:link>$0",
    }, "\n"),

    ["Jira issue"] = table.concat({
        '<ac:structured-macro ac:name="jira">',
        '  <ac:parameter ac:name="key">${1:PROJ-123}</ac:parameter>',
        "</ac:structured-macro>$0",
    }, "\n"),

    ["External link"] = '<a href="${1:https://example.com}">${2:Link text}</a>$0',

    ["Date"] = '<time datetime="${1:' .. os.date("%Y-%m-%d") .. '}" />$0',

    ["Status"] = table.concat({
        '<ac:structured-macro ac:name="status">',
        '  <ac:parameter ac:name="title">${1:Status}</ac:parameter>',
        '  <ac:parameter ac:name="colour">${2:Green}</ac:parameter>',
        "</ac:structured-macro>$0",
    }, "\n"),

    -- Math commands
    ["Math block"] = table.concat({
        '<ac:structured-macro ac:name="mathblock">',
        "  <ac:plain-text-body><![CDATA[${1:\\\\frac{a}{b}}]]></ac:plain-text-body>",
        "</ac:structured-macro>",
        "$0",
    }, "\n"),

    ["Math inline"] = table.concat({
        '<ac:structured-macro ac:name="mathinline">',
        '  <ac:parameter ac:name="body">${1:\\\\alpha}</ac:parameter>',
        "</ac:structured-macro>$0",
    }, "\n"),

    -- Upload inserts nothing — the execute handler triggers the file picker
    ["Upload"] = "$0",
}

---@param name string Command name
---@return string|nil
function M.get(name)
    return M.templates[name]
end

return M
