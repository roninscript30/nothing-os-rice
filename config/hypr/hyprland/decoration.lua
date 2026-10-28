local vars = require("variables")

hl.config({
    decoration = {
        rounding = 0,

        blur = {
            enabled           = true,
            xray              = false,
            special           = false,
            ignore_opacity    = true,
            new_optimizations = true,
            popups            = false,
            size              = 4,
            passes            = 1,
        },

        shadow = {
            enabled      = false,
            range        = 4,
            render_power = 1,
        },
    },
})
