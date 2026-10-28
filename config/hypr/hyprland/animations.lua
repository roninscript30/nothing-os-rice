hl.config({
    animations = {
        enabled = true,
    },
})

-- Fluid Nothing OS physics curves
hl.curve("fastDecel", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.0 } } })
hl.curve("fastLinear", { type = "bezier", points = { { 0.25, 1.0 }, { 0.5, 1.0 } } })
-- Smooth sigmoid curve: gentle initial acceleration with silky deceleration (zero sudden jolt)
hl.curve("fluidSigmoid", { type = "bezier", points = { { 0.35, 0.0 }, { 0.25, 1.0 } } })
hl.curve("smoothGlide", { type = "bezier", points = { { 0.16, 1.0 }, { 0.3, 1.0 } } })

-- UI elements
hl.animation({ leaf = "layersIn", enabled = true, speed = 2, bezier = "fastDecel", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 2, bezier = "fastLinear", style = "fade" })
hl.animation({ leaf = "fadeLayers", enabled = true, speed = 2, bezier = "fastDecel" })

-- Enhanced window movement and scaling physics (responsive 420-450ms smooth travel)
hl.animation({ leaf = "windows", enabled = true, speed = 4.2, bezier = "fluidSigmoid", style = "popin 85%" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 3.8, bezier = "fluidSigmoid", style = "popin 85%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 2.8, bezier = "fastLinear", style = "popin 85%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 4.5, bezier = "fluidSigmoid" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 3.5, bezier = "fluidSigmoid", style = "slide" })

hl.animation({
    leaf    = "specialWorkspace",
    enabled = true,
    speed   = 2.2,
    bezier  = "fluidSigmoid",
    style   = "slidefade"
})
hl.animation({ leaf = "fade", enabled = true, speed = 2.5, bezier = "fluidSigmoid" })
hl.animation({ leaf = "fadeDim", enabled = true, speed = 2.5, bezier = "fluidSigmoid" })
hl.animation({ leaf = "border", enabled = true, speed = 2.5, bezier = "fluidSigmoid" })
