local M = {
    "nvim-lualine/lualine.nvim",
    dependencies = { "SmiteshP/nvim-navic" },
}

local filetypes_to_ignore = {
    nil,
    "help",
    "qf",
    "nofile",
    "NvimTree",
    "terminal",
    "fugitiveblame",
    "fugitive",
    "fzf",
    "lazy",
    "mason",
    "trouble",
}

local clients_lsp = function()
    local clients = vim.lsp.get_clients({ bufnr = 0 })
    if next(clients) == nil then
        return ""
    end

    local c = {}
    for _, client in pairs(clients) do
        if not (client.name == "null-ls") then
            table.insert(c, client.name)
        end
    end
    return "\u{f085}  " .. table.concat(c, "|")
end

function M.config()
    local sl_hl = vim.api.nvim_get_hl_by_name("StatusLine", true)
    vim.api.nvim_set_hl(0, "Copilot", { fg = "#6CC644", bg = sl_hl.background })
    local icons = require("user.lspicons")
    local diff = {
        "diff",
        colored = true,
        symbols = { added = icons.git.LineAdded, modified = icons.git.LineModified, removed = icons.git.LineRemoved },
    }

    local codecompanion = require("lualine.component"):extend()
    codecompanion.processing = false
    codecompanion.spinner_index = 1
    local spinner_symbols = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏", }
    local spinner_symbols_len = 10
    function codecompanion:init(options)
        codecompanion.super.init(self, options)
        local group = vim.api.nvim_create_augroup("CodeCompanionHooks", {})
        vim.api.nvim_create_autocmd({ "User" }, {
            pattern = "CodeCompanionRequest*",
            group = group,
            callback = function(request)
                if request.match == "CodeCompanionRequestStarted" then
                    self.processing = true
                elseif request.match == "CodeCompanionRequestFinished" then
                    self.processing = false
                end
            end,
        })
    end
    function codecompanion:update_status()
        if self.processing then
            self.spinner_index = (self.spinner_index % spinner_symbols_len) + 1
            return spinner_symbols[self.spinner_index]
        else
            return nil
        end
    end

    local navic_ok, navic = pcall(require, "nvim-navic")
    local git_blame_ok, git_blame = pcall(require, "gitblame")
    local arrow_ok, arrow = pcall(require, "arrow.statusline")
    require("lualine").setup({
        options = {
            theme = "auto",
            component_separators = { left = "", right = "" },
            section_separators = { left = "", right = "" },
            ignore_focus = { "NvimTree", "noice", "qf" },
            globalstatus = true,
            globalwinbar = true,
            always_show_tabline = false,
            disabled_filetypes = {
                statusline = filetypes_to_ignore,
                winbar = filetypes_to_ignore,
            },
        },
        sections = {
            lualine_a = {
                "mode",
                {
                    function()
                        if not arrow_ok then return nil end
                        return arrow.text_for_statusline_with_icons()
                    end,
                    cond = function()
                        if not arrow_ok then return nil end
                        return arrow.is_on_arrow_file() ~= nil
                    end,
                },
                {
                    function()
                        local rec = vim.fn.reg_recording()
                        if rec == "" then
                            return ""
                        else
                            return "Recording @" .. rec
                        end
                    end,
                },
            },
            lualine_b = { { "branch", icon = icons.git.Branch }, diff },
            lualine_c = {},
            lualine_x = {
                {
                    function()
                        if not git_blame_ok then return nil end
                        return git_blame.get_current_blame_text()
                    end,
                    cond = function()
                        if not git_blame_ok then return false end
                        return git_blame.is_blame_text_available
                    end
                },
                "overseer",
                codecompanion,
                "diagnostics",
                clients_lsp,
                --copilot,
            },
            lualine_y = {
                {
                    "fileformat",
                    icons_enabled = true,
                    symbols = {
                        unix = icons.misc.Unix,
                        dos = icons.misc.Dos,
                        mac = icons.misc.Mac,
                    },
                },
                "filetype",
            },
        },
        inactive_sections = {
            lualine_a = {},
            lualine_b = { "filename" },
            lualine_x = { "filetype" },
        },
        extensions = { "quickfix", "man", "fugitive", "fzf", "lazy", "mason" },
        disabled_filetypes = {
            statusline = { "NvimTree", "terminal", "glow" },
            winbar = { "NvimTree", "terminal", "glow" },
        },

        tabline = {
            lualine_a = {},
            lualine_b = {
                {
                    'buffers',
                    show_filename_only = true,
                    hide_filename_extension = false,
                    show_modified_status = true,
                    mode = 2,
                    buffers_color = {
                        active = 'lualine_a_normal',
                        inactive = 'lualine_a_inactive',
                    },
                    symbols = {
                        alternate_file = icons.git.FileRenamed,
                    },
                    fmt = function(out, _)
                        if out == "[No Name]" then
                            return ""
                        end
                        return out
                    end,
                }
            },
            lualine_c = {},
            lualine_x = {},
            lualine_y = {},
            lualine_z = {
            }
        },
        winbar = {
            lualine_a = {
                {
                    function()
                        if not navic_ok then return nil end
                        return navic.get_location()
                    end,
                    cond = function()
                        if not navic_ok then return false end
                        return navic.is_available()
                    end,
                    color = "WarningMsg",
                },
            },
        },
        inactive_winbar = {},
    })
end

return M
