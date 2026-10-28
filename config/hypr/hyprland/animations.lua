hl.config({
    animations = {
        enabled = true,
    },
})

-- Snappy, fluid Nothing OS physics curves
hl.curve("fastDecel", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.0 } } })
hl.curve("fastLinear", { type = "bezier", points = { { 0.25, 1.0 }, { 0.5, 1.0 } } })
-- Fast, fluid sigmoid: starts smoothly, accelerates swiftly, decelerates cleanly (zero jolt, snappy ~270ms)
hl.curve("fluidSigmoid", { type = "bezier", points = { { 0.3, 0.0 }, { 0.2, 1.0 } } })
hl.curve("smoothGlide", { type = "bezier", points = { { 0.16, 1.0 }, { 0.3, 1.0 } } })

-- UI elements
hl.animation({ leaf = "layersIn", enabled = true, speed = 1.8, bezier = "fastDecel", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 1.8, bezier = "fastLinear", style = "fade" })
hl.animation({ leaf = "fadeLayers", enabled = true, speed = 1.8, bezier = "fastDecel" })

-- Snappy, fluid window movement and scaling (ultra responsive 2.7 = 270ms motion)
hl.animation({ leaf = "windows", enabled = true, speed = 2.7, bezier = "fluidSigmoid", style = "popin 90%" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 2.5, bezier = "fluidSigmoid", style = "popin 90%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.8, bezier = "fastLinear", style = "popin 90%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 2.7, bezier = "fluidSigmoid" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 2.5, bezier = "fluidSigmoid", style = "slide" })

hl.animation({
    leaf    = "specialWorkspace",
    enabled = true,
    speed   = 1.8,
    bezier  = "fluidSigmoid",
    style   = "slidefade"
})
hl.animation({ leaf = "fade", enabled = true, speed = 1.8, bezier = "fluidSigmoid" })
hl.animation({ leaf = "fadeDim", enabled = true, speed = 1.8, bezier = "fluidSigmoid" })
hl.animation({ leaf = "border", enabled = true, speed = 1.8, bezier = "fluidSigmoid" })
