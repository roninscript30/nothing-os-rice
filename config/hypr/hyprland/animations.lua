hl.config({
    animations = {
        enabled = true,
    },
})

-- Snappy Animation curves
hl.curve("fastDecel", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.0 } } })
hl.curve("fastLinear", { type = "bezier", points = { { 0.25, 1.0 }, { 0.5, 1.0 } } })

-- Snappy Animation configs (speed 2 = 200ms instantaneous response)
hl.animation({ leaf = "layersIn", enabled = true, speed = 2, bezier = "fastDecel", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 2, bezier = "fastLinear", style = "fade" })
hl.animation({ leaf = "fadeLayers", enabled = true, speed = 2, bezier = "fastDecel" })

hl.animation({ leaf = "windowsIn", enabled = true, speed = 2, bezier = "fastDecel" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 2, bezier = "fastLinear" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 2, bezier = "fastDecel" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 2, bezier = "fastDecel", style = "slide" })

hl.animation({
    leaf    = "specialWorkspace",
    enabled = true,
    speed   = 2,
    bezier  = "fastDecel",
    style   = "slidefade"
})
hl.animation({ leaf = "fade", enabled = true, speed = 2, bezier = "fastDecel" })
hl.animation({ leaf = "fadeDim", enabled = true, speed = 2, bezier = "fastDecel" })
hl.animation({ leaf = "border", enabled = true, speed = 2, bezier = "fastDecel" })
