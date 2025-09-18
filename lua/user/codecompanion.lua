local M = {
    "olimorris/codecompanion.nvim",
    event = "VeryLazy",
    enable = not vim.env.GROQ_API_KEY == "",
}

local function fetch_groq_models()
    if not vim.env.GROQ_API_KEY then
        return {}
    end
    local models = {}
    local handle = io.popen("curl -s -H 'Authorization: Bearer " .. vim.env.GROQ_API_KEY .. "' https://api.groq.com/openai/v1/models")
    if handle then
        local result = handle:read("*a")
        handle:close()
        local ok, decoded = pcall(vim.fn.json_decode, result)
        if ok and decoded and decoded.data then
            for _, model in ipairs(decoded.data) do
                models[model.id] = model.id .. " [Groq]"
            end
        end
    end
    return models
end

M.config = function()
    local ok, settings = pcall(require, vim.loop.os_getenv("USER") .. ".user-settings")
    if not ok then
        settings = {}
    end
    local ai_settings = settings.ai or {}
    require("codecompanion").setup({
        opts = {
            language = ai_settings.language or "English",
            send_code = ai_settings.send_code or true,
        },
        adapters = {
            http = {
                groq = function()
                    return require("codecompanion.adapters").extend("openai", {
                        env = {
                            api_key = vim.env.GROQ_API_KEY,
                        },
                        name = "Groq",
                        url = "https://api.groq.com/openai/v1/chat/completions",
                        schema = {
                            model = {
                                default = ai_settings.model or "openai/gpt-oss-20b",
                                choices = fetch_groq_models(),
                            },
                        },
                        max_tokens = {
                            default = 32768,
                        },
                        temperature = {
                            default = 1,
                        },
                    })
                end,
            },
        },
        strategies = {
            chat = { adapter = "groq" },
            inline = { adapter = "groq" },
        },
        prompt_library = {
            ["Review code"] = {
                strategy = "chat",
                description = "Review the selected code",
                opts = {
                    index = 11,
                    is_default = true,
                    is_slash_cmd = false,
                    modes = { "v" },
                    short_name = "review",
                    auto_submit = true,
                    user_prompt = false,
                    stop_context_insertion = true,
                },
            },
            ["Regex explainer"] = {
                strategy = "chat",
                opts = {
                    modes = { "n" },
                    short_name = "regexp",
                    auto_submit = true,
                },
                prompts = {
                    {
                        role = "system",
                        content = "You are an expert in " .. vim.bo.filetype .. " regular expressions."
                    },
                    {
                        role = "user",
                        content = function(ctx)
                            local parser = vim.treesitter.get_parser(ctx.bufnr)
                            local tree = parser:parse()[1]
                            local root = tree:root()
                            local row = ctx.cursor_pos[1]-1
                            local col = ctx.cursor_pos[2]
                            local node = root:named_descendant_for_range(row, col, row, col)
                            if not node then
                                return nil
                            end
                            local start_row, start_col, end_row, end_col = node:range()
                            local lines = vim.api.nvim_buf_get_text(ctx.bufnr, start_row, start_col, end_row, end_col, {})
                            local pattern = table.concat(lines, "\n")
                            return "Draw a detailed railroad regexp diagram for the following " .. vim.bo.filetype .. " pattern:\n`" .. pattern .. "`"
                        end
                    },
                }
            },
        },
        display = {
            diff = {
                provider = "mini_diff",
            },
            chat = {
                render_headers = false,
            },
            action_palette = {
                provider = "telescope",
            },
        }
    })
end

return M
