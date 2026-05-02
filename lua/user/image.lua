-- 3rd/image.nvim — replaces snacks.image for inline/float image rendering.
-- Reason: snacks.image emits kitty graphics escapes at the cursor position,
-- which on wezterm decouples from the float window's location (frame on
-- right, image on left). image.nvim positions images at the float's window
-- coords explicitly and works on both kitty and wezterm.
--
-- Requirements (user-mode):
--   - imagemagick CLI on PATH (`magick` or `convert`). Install via your
--     system pm; image.nvim uses it through `processor = "magick_cli"`,
--     which avoids the luarocks magick binding and its build deps.
--   - kitty or wezterm with kitty graphics protocol enabled (we run wezterm
--     with `enable_kitty_graphics = true` already).

return {
    -- Disable snacks.image and strip its leftover style entry so the two
    -- don't fight over the same buffers and the snacks config doesn't
    -- advertise an image module that's been turned off.
    {
        "folke/snacks.nvim",
        opts = function(_, opts)
            opts.image = { enabled = false }
            if opts.styles then opts.styles.snacks_image = nil end
            return opts
        end,
    },

    {
        "3rd/image.nvim",
        dependencies = { "leafo/magick" },
        ft = { "markdown", "norg", "vimwiki", "html", "css", "tex", "typst" },
        cmd = { "Image" },
        opts = {
            backend = "kitty",      -- works on kitty and (with caveats) wezterm
            processor = "magick_cli",

            integrations = {
                markdown = {
                    enabled = true,
                    clear_in_insert_mode = false,
                    download_remote_images = true,
                    only_render_image_at_cursor = false,
                    floating_windows = true,           -- mirror the snacks float behavior
                    filetypes = { "markdown", "vimwiki" },
                },
                neorg = {
                    enabled = true,
                    filetypes = { "norg" },
                },
                typst = {
                    enabled = true,
                    filetypes = { "typst" },
                },
                html = { enabled = true },
                css = { enabled = true },
            },

            max_width = nil,
            max_height = nil,
            max_width_window_percentage = 60,    -- right-side float should not eat main text
            max_height_window_percentage = 70,
            window_overlap_clear_enabled = true,
            window_overlap_clear_ft_ignore = { "cmp_menu", "cmp_docs", "snacks_notif", "scrollview", "scrollview_sign" },

            editor_only_render_when_focused = false,
            tmux_show_only_in_active_window = false,

            hijack_file_patterns = { "*.png", "*.jpg", "*.jpeg", "*.gif", "*.webp", "*.avif" },
        },

        -- Some users prefer to drive image previews from a keymap. Bind one
        -- here that mirrors the snacks.image idea (open image float for the
        -- thing under the cursor / the file).
        keys = {
            {
                "<leader>vi",
                function()
                    local image = require("image")
                    if image and image.from_file then
                        local path = vim.fn.expand("<cfile>")
                        if path == "" or vim.fn.filereadable(path) == 0 then
                            vim.notify("no image under cursor: " .. path, vim.log.levels.WARN)
                            return
                        end
                        local img = image.from_file(path, {
                            window = vim.api.nvim_get_current_win(),
                            with_virtual_padding = true,
                        })
                        if img then img:render() end
                    end
                end,
                desc = "image: render under cursor",
            },
        },
    },
}
