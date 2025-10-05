local M = {
    "3rd/image.nvim",
    build = false,
    enable = vim.env.TERM == "xterm-kitty" and vim.fn.executable("mogrify") == 1,
}

M.config = function()
    require("image").setup({
        backend = "kitty",
        processor = "magick_cli",
        integrations = {
            markdown = {
                resolve_image_path = function(doc_path, image_path, fallback)
                    return fallback(doc_path, image_path)
                end,
                enabled = true,
                clear_in_insert_mode = false,
                download_remote_images = true,
                only_render_image_at_cursor = true,
                floating_windows = true,
                filetypes = { "markdown", "vimwiki" },
            },
            neorg = {
                enabled = true,
                floating_windows = true,
                only_render_image_at_cursor = true,
                filetypes = { "norg" },
            },
            typst = {
                enabled = true,
                floating_windows = true,
                only_render_image_at_cursor = true,
                filetypes = { "typst" },
            },
            html = {
                enabled = false,
                floating_windows = true,
                only_render_image_at_cursor = true,
            },
            css = {
                enabled = false,
                floating_windows = true,
                only_render_image_at_cursor = true,
            },
        },
        max_width = nil,
        max_height = nil,
        max_width_window_percentage = nil,
        max_height_window_percentage = 50,
        window_overlap_clear_enabled = false,
        window_overlap_clear_ft_ignore = { "cmp_menu", "cmp_docs", "scrollview", "scrollview_sign", "" },
        editor_only_render_when_focused = false,
        tmux_show_only_in_active_window = false,
        hijack_file_patterns = { "*.png", "*.jpg", "*.jpeg", "*.gif", "*.webp", "*.avif" },
    })
end

return M
