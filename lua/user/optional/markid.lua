local M = {
	"David-Kunz/markid",
	event = "VeryLazy",
    ft = {"lua", "cpp", "python", "rust", "c", "java", "javascript", "typescript", "sh"},
}

M.colors = {
    dark = { "#619e9d", "#9E6162", "#81A35C", "#7E5CA3", "#9E9261", "#616D9E", "#97687B", "#689784", "#999C63", "#66639C" },
    bright = {"#f5c0c0", "#f5d3c0", "#f5eac0", "#dff5c0", "#c0f5c8", "#c0f5f1", "#c0dbf5", "#ccc0f5", "#f2c0f5", "#98fc03" },
    medium = { "#c99d9d", "#c9a99d", "#c9b79d", "#c9c39d", "#bdc99d", "#a9c99d", "#9dc9b6", "#9dc2c9", "#9da9c9", "#b29dc9" },
    catppuccin = {
        "#f5e0dc", "#f2cdcd",
        "#f5c2e7", "#cba6f7",
        "#f38ba8", "#eba0ac",
        "#fab387", "#f9e2af",
        "#a6e3a1", "#94e2d5",
        "#89dceb", "#74c7ec",
        "#89b4fa", "#b4befe",
        "#cdd6f4", "#bac2de",
        "#a6adc8", "#9399b2",
    },
    ayu = {
        "#ACB6BF", "#F07178",
        "#39BAE6", "#E6B673",
        "#59C2FF", "#FFB454",
        "#AAD94C", "#FF8F40",
        "#7FD962", "#D2A6FF",
        "#73B8FF", "#F26D78",
        "#F29668", "#D95757",
        "#E6B450", "#95E6CB",
    }
}

function M.config()
    require'nvim-treesitter.configs'.setup {
        markid = {
            enable = true,
            colors = M.colors.catppuccin,
        },
    }
end

return M
