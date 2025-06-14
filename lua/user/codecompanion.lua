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
                            default = ai_settings.model or "distil-whisper-large-v3-en",
                            choices = {
                                ["distil-whisper-large-v3-en"] = "Whisper Large v3 English from HuggingFace [Prod]",
                                ["gemma2-9b-it"] = "Gemma 2 9B from Google [Prod]",
                                ["llama-3.3-70b-versatile"] = "LLAMA 3.3 70B from Meta [Prod]",
                                ["whisper-large-v3-turbo"] = "Whisper large from OpenAI [Prod]",
                                ["mistral-saba-24b"] = "SABA 24B from Mistral [Preview]",
                                ["compound-beta"] = "Llama 4 Scout for reasoning; Llama 3.3 70B for routing and tool usage [Preview]",
                                ["compound-beta-mini"] = "Llama 4 Scout for reasoning; Llama 3.3 70B for routing and tool usage; 1 tool at a time [Preview]",
                                ["deepseek-r1-distill-llama-70b"] = "Deepseek R1 70B from DeepSeek [Preview]",
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
