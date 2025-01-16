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
            send_code = ai_settings.send_code() or true,
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
--                prompts = {
--                    {
--                        role = "system",
--                        content = [[When asked to perform a code review or identify code smells, follow these steps:
--1. **Understand the Context**: Review the purpose and functionality of the code.
--
--2. **Identify Code Smells**: Look for common code smells, such as
--   - Duplicated code
--   - Large functions or classes (violating Single Responsibility Principle)
--   - Poor naming conventions
--   - Overly complex or deeply nested logic
--   - Unnecessary comments (indicating unclear code)
--   - Hardcoded values or magic numbers
--   - Lack of error handling
--   - Violations of best practices in the language/framework.
--
--3. **Assess Best Practices**: Ensure the code adheres to
--   - Clean code principles
--   - DRY (Don't Repeat Yourself)
--   - Proper modularization and abstraction
--   - Consistent formatting and style guides.
--
--4. **Suggest Improvements**:
--   - Provide constructive feedback with specific examples.
--   - Highlight areas of improvement with suggestions, not just criticisms.
--
--5. **Document Findings**:
--   - Summarize key points in a clear, actionable manner.
--   - Categorize issues by severity (e.g., critical, moderate, minor).
--
--When presenting feedback:
--- Use clear, concise language.
--- Provide code examples when suggesting improvements.
--- Focus on improving readability, maintainability, and performance.
--
--Example format for findings:
--- **Issue**: [Brief description of the problem]
--  - **Evidence**: [Relevant code snippet or explanation]
--  - **Suggestion**: [Detailed improvement recommendation]
--
--Use Markdown formatting and include the programming language name at the start of the code block.]],
--                        opts = {
--                            visible = false,
--                        },
--                    },
--                    {
--                        role = "user",
--                        content = function(context)
--                            local code = require("codecompanion.helpers.actions").get_code(context.start_line,
--                                context.end_line)
--
--                            return string.format(
--                                [[Please review and discover code smells for this code from buffer %d:
--
--```%s
--%s
--```
--]],
--                                context.bufnr,
--                                context.filetype,
--                                code
--                            )
--                        end,
--                        opts = {
--                            contains_code = true,
--                        },
--                    },
--                },
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
