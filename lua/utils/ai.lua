local M = {}

local user = vim.loop.os_getenv("USER")
local settings_path = vim.fn.stdpath("config") .. "/lua/" .. user .. "/user-settings.lua"

local function serialize(tbl, indent)
  indent = indent or 0
  local lines = {}
  local pad = string.rep("    ", indent)
  table.insert(lines, "{")
  for k, v in pairs(tbl) do
    local key = (type(k) == "string" and k:match("^[%a_][%w_]*$")) and k or string.format("[%q]", k)
    local val
    if type(v) == "table" then
      val = serialize(v, indent + 1)
    elseif type(v) == "string" then
      val = string.format("%q", v)
    elseif type(v) == "function" then
      val = "function() return true end"
    else
      val = tostring(v)
    end
    table.insert(lines, string.format("%s    %s = %s,", pad, key, val))
  end
  table.insert(lines, pad .. "}")
  return table.concat(lines, "\n")
end

local function save_settings(tbl)
  local f = io.open(settings_path, "w")
  if not f then
    vim.notify("Could not write to " .. settings_path, vim.log.levels.ERROR)
    return
  end
  f:write("local M = " .. serialize(tbl) .. "\nreturn M\n")
  f:close()
end

function M.set_language(lang)
  package.loaded[user .. ".user-settings"] = nil
  local ok, settings = pcall(require, user .. ".user-settings")
  if not ok then
    vim.notify("Could not load user-settings", vim.log.levels.ERROR)
    return
  end

  settings.ai = settings.ai or {}
  settings.ai.language = lang
  save_settings(settings)
  vim.notify("AI language set to " .. lang .. " (persisted)", vim.log.levels.INFO)
end

function M.pick_language()
  local languages = {
    "Arabic",
    "Chinese",
    "Dutch",
    "English",
    "French",
    "German",
    "Italian",
    "Japanese",
    "Korean",
    "Portuguese",
    "Russian",
    "Spanish",
  }

  -- Convert to items format
  local items = {}
  for _, lang in ipairs(languages) do
    table.insert(items, {
      text = lang,
      value = lang,
    })
  end

  require("snacks").picker.pick({
    title = "Set AI Response Language (persisted in user-settings.lua)",
    items = items,
    confirm = function(picker, item)
      if item then
        M.set_language(item.value)
      end
    end,
  })
end

return M
