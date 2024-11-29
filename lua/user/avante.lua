local M = {
    "yetone/avante.nvim",
    event = "VeryLazy",
    build = "make",
    lazy = false,
    enable = not vim.env.GROQ_API_KEY == "",
    dependencies = {
        "nvim-treesitter/nvim-treesitter",
        "stevearc/dressing.nvim",
        "nvim-lua/plenary.nvim",
        "MunifTanjim/nui.nvim",
        --- The below dependencies are optional,
        "nvim-tree/nvim-web-devicons", -- or echasnovski/mini.icons
        --"zbirenbaum/copilot.lua",      -- for providers='copilot'
        {
            -- support for image pasting
            "HakonHarnes/img-clip.nvim",
            event = "VeryLazy",
            opts = {
                -- recommended settings
                default = {
                    embed_image_as_base64 = false,
                    prompt_for_file_name = false,
                    drag_and_drop = {
                        insert_mode = true,
                    },
                    -- required for Windows users
                    use_absolute_path = true,
                },
            },
        },
        {
            -- Make sure to set this up properly if you have lazy=true
            'MeanderingProgrammer/render-markdown.nvim',
            opts = {
                file_types = { "markdown", "Avante" },
            },
            ft = { "markdown", "Avante" },
        },
    },
}

function M.config()
    require("avante").setup {
        provider = "groq",
        vendors = {
            ["groq"] = {
                endpoint = "https://api.groq.com/openai/v1/chat/completions",
                model = "mixtral-8x7b-32768",
                api_key_name = "GROQ_API_KEY",
                parse_curl_args = function(opts, code_opts)
                    local msg = table.concat(vim.tbl_map(function(message) return message.content end, code_opts.messages),
                        "\n")
                    return {
                        url = opts.endpoint,
                        headers = {
["Accept"] = "application/json",
                            ["Content-Type"] = "application/json",
                            ["Authorization"] = "Bearer " .. os.getenv(opts.api_key_name),
                        },
                        body = {
                            model = opts.model,
                            messages = { -- you can make your own message, but this is very advanced
                                { role = "system", content = code_opts.system_prompt },
                                { role = "user",   content = msg },
                            },
                            temperature = 0,
                            max_tokens = 32768,
                            stream = true,
                        },
                    }
                end,
                parse_response_data = function(data_stream, event_state, opts)
                    require("avante.providers").openai.parse_response(data_stream, event_state, opts)
                end,
            }
        }
    }
end

return M
