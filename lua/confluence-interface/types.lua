local M = {}

---@class ConfluenceSpace
---@field id string Space ID
---@field key string Space key
---@field name string Space name
---@field type string Space type (global, personal)
---@field status string Space status
---@field description string|nil Space description
---@field homepage_id string|nil Homepage ID
---@field web_url string Web URL

---@class ConfluencePage
---@field id string Page ID
---@field title string Page title
---@field space_id string|nil Space ID
---@field space_key string|nil Space key
---@field parent_id string|nil Parent page ID
---@field status string Page status
---@field version number Version number
---@field body string|nil Page body (storage format)
---@field created string Created timestamp
---@field updated string Updated timestamp
---@field created_by string|nil Creator display name
---@field updated_by string|nil Last updater display name
---@field web_url string Web URL

-- Helper to check if value is a valid table (not nil/vim.NIL)
local function is_table(value)
    return type(value) == "table"
end

---@param raw table
---@return ConfluenceSpace
function M.parse_space(raw)
    local desc = nil
    if is_table(raw.description) and is_table(raw.description.plain) then
        desc = raw.description.plain.value
    end

    return {
        id = raw.id or "",
        key = raw.key or "",
        name = raw.name or "",
        type = raw.type or "global",
        status = raw.status or "current",
        description = desc,
        homepage_id = raw.homepageId or nil,
        web_url = is_table(raw._links) and raw._links.webui or "",
    }
end

---@param raw table
---@return ConfluencePage
function M.parse_page(raw)
    local body = nil
    if is_table(raw.body) then
        if is_table(raw.body.storage) then
            body = raw.body.storage.value
        elseif is_table(raw.body.atlas_doc_format) then
            body = raw.body.atlas_doc_format.value
        end
    end

    local version_num = 1
    local updated = ""
    local author_id = nil
    if is_table(raw.version) then
        version_num = raw.version.number or 1
        updated = raw.version.createdAt or ""
        author_id = raw.version.authorId
    end

    return {
        id = raw.id or "",
        title = raw.title or "",
        space_id = raw.spaceId or nil,
        space_key = nil,
        parent_id = raw.parentId or nil,
        status = raw.status or "current",
        version = version_num,
        body = body,
        created = raw.createdAt or "",
        updated = updated,
        created_by = author_id,
        updated_by = author_id,
        web_url = is_table(raw._links) and raw._links.webui or "",
    }
end

---@param raw table
---@return ConfluencePage
function M.parse_page_v1(raw)
    local body = nil
    if is_table(raw.body) then
        if is_table(raw.body.storage) then
            body = raw.body.storage.value
        elseif is_table(raw.body.view) then
            body = raw.body.view.value
        end
    end

    local version_num = 1
    local updated = ""
    local updated_by = nil
    if is_table(raw.version) then
        version_num = raw.version.number or 1
        updated = raw.version.when or ""
        if is_table(raw.version.by) then
            updated_by = raw.version.by.displayName
        end
    end

    local created = ""
    local created_by = nil
    if is_table(raw.history) then
        created = raw.history.createdDate or ""
        if is_table(raw.history.createdBy) then
            created_by = raw.history.createdBy.displayName
        end
    end

    return {
        id = raw.id or "",
        title = raw.title or "",
        space_id = nil,
        space_key = is_table(raw.space) and raw.space.key or nil,
        parent_id = nil,
        status = raw.status or "current",
        version = version_num,
        body = body,
        created = created,
        updated = updated,
        created_by = created_by,
        updated_by = updated_by,
        web_url = is_table(raw._links) and raw._links.webui or "",
    }
end

return M
