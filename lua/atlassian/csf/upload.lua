local M = {}

local image_extensions = {
    png = true, jpg = true, jpeg = true, gif = true,
    svg = true, webp = true, bmp = true, ico = true,
}

---@param buf number Buffer handle
function M.upload_attachment(buf)
    local csf = require("atlassian.csf")
    local notify = require("atlassian.notify")

    local first_line = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] or ""
    local meta = csf.parse_metadata(first_line)
    if not meta then
        notify.error("Not a CSF buffer")
        return
    end

    local entity_id
    if meta.type == "jira" then
        entity_id = meta.key
    elseif meta.type == "confluence" then
        entity_id = meta.id
    end

    if not entity_id or entity_id == "NEW" then
        notify.error("Save the issue/page first before uploading attachments")
        return
    end

    vim.ui.input({
        prompt = "File to upload: ",
        completion = "file",
    }, function(file_path)
        if not file_path or file_path == "" then return end

        file_path = vim.fn.expand(file_path)
        if vim.fn.filereadable(file_path) ~= 1 then
            notify.error("File not found: " .. file_path)
            return
        end

        local filename = vim.fn.fnamemodify(file_path, ":t")
        notify.progress_start("upload", "Uploading " .. filename)

        local function on_done(err, data)
            if err then
                notify.progress_error("upload", "Upload failed: " .. tostring(err))
                return
            end
            notify.progress_finish("upload", "Uploaded: " .. filename)
            -- Extract attachment ID from response (Jira returns an array)
            local attachment_id
            if type(data) == "table" then
                local attachment = data[1] or data
                attachment_id = attachment and tostring(attachment.id)
            end
            M.insert_tag(buf, filename, attachment_id)
        end

        if meta.type == "jira" then
            require("jira-interface.api").upload_attachment(entity_id, file_path, on_done)
        else
            require("confluence-interface.api").upload_attachment(entity_id, file_path, on_done)
        end
    end)
end

---@param buf number Buffer handle
---@param filename string Uploaded filename
---@param attachment_id? string Attachment ID from the upload response
function M.insert_tag(buf, filename, attachment_id)
    local ext = (filename:match("%.(%w+)$") or ""):lower()
    local tag
    if image_extensions[ext] then
        local id_attr = attachment_id and (' ri:id="' .. attachment_id .. '"') or ""
        tag = '<ac:image><ri:attachment ri:filename="' .. filename .. '"' .. id_attr .. ' /></ac:image>'
    else
        tag = '<a href="attachment:' .. filename .. '">' .. filename .. '</a>'
    end

    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    local line = vim.api.nvim_buf_get_lines(buf, row - 1, row, false)[1] or ""
    local new_line = line:sub(1, col) .. tag .. line:sub(col + 1)
    vim.api.nvim_buf_set_lines(buf, row - 1, row, false, { new_line })
end

return M
