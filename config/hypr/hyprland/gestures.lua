local vars = require("variables")

hl.config({
    gestures = {
        workspace_swipe_distance                 = 400,
        workspace_swipe_invert                   = true,
        workspace_swipe_min_speed_to_force       = 30,
        workspace_swipe_cancel_ratio             = 0.5,
        workspace_swipe_direction_lock           = true,
        workspace_swipe_direction_lock_threshold = 10,
        workspace_swipe_create_new               = true,
        workspace_swipe_forever                  = true,
    },
})

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

-- Debounced 3-finger swipe gestures for smooth application overview
local last_gesture_time = 0
local overview_script = "/home/marudhu/REPOS/nothing-os-rice/config/hypr/scripts/app_overview.py"

hl.gesture({
    fingers   = 3,
    direction = "up",
    action    = function()
        local now = os.clock()
        if now - last_gesture_time < 0.35 then return end
        last_gesture_time = now
        hl.exec_cmd(overview_script .. " activate --current")
    end,
})

hl.gesture({
    fingers   = 3,
    direction = "down",
    action    = function()
        local now = os.clock()
        if now - last_gesture_time < 0.35 then return end
        last_gesture_time = now
        hl.exec_cmd(overview_script .. " restore")
    end,
})

hl.gesture({
    fingers   = 4,
    direction = "up",
    action    = function()
        hl.dispatch(hl.dsp.global("shell:launcher"))
    end,
})
hl.gesture({
    fingers   = 4,
    direction = "down",
    action    = function()
        hl.dispatch(hl.dsp.global("shell:launcher"))
    end,
})
