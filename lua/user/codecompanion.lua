local M = {
    "olimorris/codecompanion.nvim",
    event = "VeryLazy",
    enable = not vim.env.GROQ_API_KEY == "",
}

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
            groq = function()
                return require("codecompanion.adapters").extend("openai", {
                    env = {
                        api_key = vim.env.GROQ_API_KEY,
                    },
                    name = "Groq",
                    url = "https://api.groq.com/openai/v1/chat/completions",
                    schema = {
                        model = {
                            default = ai_settings.model or "mixtral-8x7b-32768",
                            choices = {
                                ["mixtral-8x7b-32768"] = "Mixtral 8x7B from Mistral",
                                ["llama-3.1-8b-instant"] = "LLAMA 3.1 instant from Meta",
                                ["llama-3.1-70b-versatile"] = "LLAMA 3.1 70B from Meta",
                                ["whisper-large-v3-turbo"] = "Whisper large from OpenAI",
                                ["gemma2-9b-it"] = "Gemma 2 9B from Google",
                            },
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
