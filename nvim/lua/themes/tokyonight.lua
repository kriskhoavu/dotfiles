return {
    "folke/tokyonight.nvim",
    lazy = true,
    priority = 1000,
    config = function()
        require("tokyonight").setup({
            style = "storm",
            transparent = true,
            styles = {
                sidebars = "transparent",
                floats = "transparent",
            },
        })
    end,
}
