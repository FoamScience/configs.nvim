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
            log_level = "DEBUG",
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
