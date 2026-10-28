#!/usr/bin/env python3
"""
Nothing OS Runtime Application Floating Overview for Hyprland

Modes:
- --current (default, Super tap or 3-finger swipe):
    Floats and arranges running applications on the CURRENT ACTIVE WORKSPACE only.
- --all (Super + Shift + Tab):
    Floats and arranges running applications across ALL WORKSPACES.

Navigation while in Overview (submap 'overview'):
- Left-Click (mouse:272): click ANY floating window to immediately select it and restore to normal
- Left / Right / Up / Down arrow keys: spatial navigation between floating window previews
- Tab / Shift+Tab: cycle through floating previews
- Enter / Space: select currently focused window and smoothly restore to normal (tiled)
- Escape / Super tap / Super+Shift+Tab: exit overview and smoothly restore to normal

YouTube / Browser Full Screen Protection:
- Uses Hyprland's `fullscreen_state` with `internal = 0` and preserving `client`
- YouTube HTML5 video player is NEVER forced out of fullscreen mode
"""

import sys
import os
import json
import subprocess
import math

STATE_FILE = "/tmp/hypr_overview_state.json"

def run_hyprctl_json(cmd):
    try:
        out = subprocess.check_output(["hyprctl", "-j"] + cmd, stderr=subprocess.DEVNULL)
        return json.loads(out)
    except Exception:
        return None

def eval_lua(lua_code):
    try:
        subprocess.check_output(["hyprctl", "eval", lua_code], stderr=subprocess.DEVNULL)
    except Exception:
        pass

def batch_eval_lua(lua_cmds):
    if not lua_cmds:
        return
    full_script = " ".join(lua_cmds)
    eval_lua(full_script)

def calculate_layout(count, mon_x, mon_y, mon_w, mon_h):
    margin_x = 60
    margin_y = 70
    gap = 28

    avail_w = mon_w - 2 * margin_x
    avail_h = mon_h - 2 * margin_y

    layout_slots = []

    if count == 1:
        # Centered generous preview (~78% width, ~84% height)
        card_w = min(1400, int(avail_w * 0.78))
        card_h = min(840, int(avail_h * 0.84))
        card_x = mon_x + (mon_w - card_w) // 2
        card_y = mon_y + (mon_h - card_h) // 2
        layout_slots.append((card_x, card_y, card_w, card_h))

    elif count == 2:
        # 2 windows side-by-side with balanced 16:10 aspect ratio
        card_w = (avail_w - gap) // 2
        card_h = min(int(card_w * 0.65), avail_h - 40)
        card_y = mon_y + (mon_h - card_h) // 2
        card_x0 = mon_x + margin_x
        card_x1 = card_x0 + card_w + gap
        layout_slots.append((card_x0, card_y, card_w, card_h))
        layout_slots.append((card_x1, card_y, card_w, card_h))

    elif count == 3:
        # 3 windows side-by-side (matching reference overview UI)
        card_w = (avail_w - 2 * gap) // 3
        card_h = min(int(card_w * 0.72), avail_h - 40)
        card_y = mon_y + (mon_h - card_h) // 2
        for i in range(3):
            x = mon_x + margin_x + i * (card_w + gap)
            layout_slots.append((x, card_y, card_w, card_h))

    elif count == 4:
        # 2x2 grid
        cols = 2
        rows = 2
        card_w = (avail_w - gap) // cols
        card_h = (avail_h - gap) // rows
        for i in range(4):
            r = i // cols
            c = i % cols
            x = mon_x + margin_x + c * (card_w + gap)
            y = mon_y + margin_y + r * (card_h + gap)
            layout_slots.append((x, y, card_w, card_h))

    elif count in (5, 6):
        # 3 columns, 2 rows
        cols = 3
        rows = 2
        card_w = (avail_w - 2 * gap) // cols
        card_h = (avail_h - gap) // rows
        for i in range(count):
            r = i // cols
            c = i % cols
            if count == 5 and r == 1:
                bottom_offset = (avail_w - (2 * card_w + gap)) // 2
                x = mon_x + margin_x + bottom_offset + c * (card_w + gap)
            else:
                x = mon_x + margin_x + c * (card_w + gap)
            y = mon_y + margin_y + r * (card_h + gap)
            layout_slots.append((x, y, card_w, card_h))

    else:
        # Multi-column grid
        cols = 4 if count <= 8 else math.ceil(math.sqrt(count * (16 / 9)))
        rows = math.ceil(count / cols)
        card_w = (avail_w - (cols - 1) * gap) // cols
        card_h = (avail_h - (rows - 1) * gap) // rows
        for i in range(count):
            r = i // cols
            c = i % cols
            x = mon_x + margin_x + c * (card_w + gap)
            y = mon_y + margin_y + r * (card_h + gap)
            layout_slots.append((x, y, card_w, card_h))

    return layout_slots

def activate_overview(mode="current"):
    monitors = run_hyprctl_json(["monitors"]) or []
    active_mon = next((m for m in monitors if m.get("focused")), monitors[0] if monitors else None)
    if not active_mon:
        return

    mon_x = active_mon.get("x", 0)
    mon_y = active_mon.get("y", 0)
    scale = active_mon.get("scale", 1.0)
    mon_w = int(active_mon.get("width", 1920) / scale)
    mon_h = int(active_mon.get("height", 1080) / scale)

    active_ws = run_hyprctl_json(["activeworkspace"]) or {}
    active_ws_id = active_ws.get("id", 1)

    clients = run_hyprctl_json(["clients"]) or []

    if mode == "all":
        # All normal workspaces (id > 0, ignore special workspaces like sysmon)
        target_clients = [
            c for c in clients
            if c.get("workspace", {}).get("id", -99) > 0
            and c.get("mapped")
            and not c.get("hidden")
        ]
    else:
        # STRICTLY ONLY windows on the CURRENT ACTIVE WORKSPACE
        target_clients = [
            c for c in clients
            if c.get("workspace", {}).get("id") == active_ws_id
            and c.get("mapped")
            and not c.get("hidden")
        ]

    if not target_clients:
        return

    count = len(target_clients)
    layout_slots = calculate_layout(count, mon_x, mon_y, mon_w, mon_h)

    # Save state of all affected windows
    saved_windows = []
    for idx, c in enumerate(target_clients):
        slot = layout_slots[idx] if idx < len(layout_slots) else (0, 0, 800, 600)
        saved_windows.append({
            "address": c["address"],
            "orig_workspace": c.get("workspace", {}).get("id", active_ws_id),
            "orig_floating": c.get("floating", False),
            "orig_size": c.get("size", [800, 600]),
            "orig_at": c.get("at", [0, 0]),
            "orig_fullscreen": c.get("fullscreen", 0),
            "orig_fullscreenClient": c.get("fullscreenClient", 0),
            "slot_x": slot[0],
            "slot_y": slot[1],
            "slot_w": slot[2],
            "slot_h": slot[3]
        })

    saved_state = {
        "mode": mode,
        "active_ws_id": active_ws_id,
        "windows": saved_windows
    }

    try:
        with open(STATE_FILE, "w") as f:
            json.dump(saved_state, f)
    except Exception:
        return

    lua_cmds = []

    # Activate overview submap for dedicated navigation
    lua_cmds.append('hl.dispatch(hl.dsp.submap("overview"))')

    for idx, client in enumerate(target_clients):
        if idx >= len(layout_slots):
            break
        target = f"address:{client['address']}"
        tx, ty, tw, th = layout_slots[idx]

        # In "all" mode, temporarily move windows from other workspaces to active workspace
        orig_ws = client.get("workspace", {}).get("id", active_ws_id)
        if mode == "all" and orig_ws != active_ws_id:
            lua_cmds.append(f'hl.dispatch(hl.dsp.window.move({{ workspace = "{active_ws_id}", silent = true, window = "{target}" }}))')

        # Preserve client-side fullscreen (e.g. YouTube HTML5 video player)
        # Setting internal = 0 allows Hyprland to float/scale, while preserving client state
        orig_fs = client.get("fullscreen", 0)
        orig_fc = client.get("fullscreenClient", 0)
        if orig_fs > 0:
            cstate = orig_fc if orig_fc > 0 else 2
            lua_cmds.append(f'hl.dispatch(hl.dsp.window.fullscreen_state({{ internal = 0, client = {cstate}, window = "{target}" }}))')

        # Float window
        lua_cmds.append(f'hl.dispatch(hl.dsp.window.float({{ action = "on", window = "{target}" }}))')

        # Resize and position into slot (absolute)
        lua_cmds.append(f'hl.dispatch(hl.dsp.window.resize({{ x = {int(tw)}, y = {int(th)}, relative = false, window = "{target}" }}))')
        lua_cmds.append(f'hl.dispatch(hl.dsp.window.move({{ x = {int(tx)}, y = {int(ty)}, relative = false, window = "{target}" }}))')

    batch_eval_lua(lua_cmds)

def restore_overview(selected_address=None):
    if not os.path.exists(STATE_FILE):
        eval_lua('hl.dispatch(hl.dsp.submap("reset"))')
        return False

    try:
        with open(STATE_FILE, "r") as f:
            state = json.load(f)
    except Exception:
        if os.path.exists(STATE_FILE):
            os.remove(STATE_FILE)
        eval_lua('hl.dispatch(hl.dsp.submap("reset"))')
        return False

    lua_cmds = []

    # Exit overview submap immediately
    lua_cmds.append('hl.dispatch(hl.dsp.submap("reset"))')

    active_ws_id = state.get("active_ws_id", 1)
    mode = state.get("mode", "current")
    windows = state.get("windows", [])

    # Restore all windows
    for win in windows:
        addr = win["address"]
        target = f"address:{addr}"

        # If window was moved from another workspace in "all" mode, return it
        orig_ws = win.get("orig_workspace", active_ws_id)
        if mode == "all" and orig_ws != active_ws_id:
            lua_cmds.append(f'hl.dispatch(hl.dsp.window.move({{ workspace = "{orig_ws}", silent = true, window = "{target}" }}))')

        if not win.get("orig_floating", False):
            # Restore tiled state
            lua_cmds.append(f'hl.dispatch(hl.dsp.window.float({{ action = "off", window = "{target}" }}))')
        else:
            # Restore original floating geometry
            orig_w, orig_h = win.get("orig_size", [800, 600])
            orig_x, orig_y = win.get("orig_at", [0, 0])
            lua_cmds.append(f'hl.dispatch(hl.dsp.window.resize({{ x = {int(orig_w)}, y = {int(orig_h)}, relative = false, window = "{target}" }}))')
            lua_cmds.append(f'hl.dispatch(hl.dsp.window.move({{ x = {int(orig_x)}, y = {int(orig_y)}, relative = false, window = "{target}" }}))')

        # Restore fullscreen state (including YouTube client fullscreen)
        orig_fs = win.get("orig_fullscreen", 0)
        orig_fc = win.get("orig_fullscreenClient", 0)
        if orig_fs > 0:
            cstate = orig_fc if orig_fc > 0 else 2
            lua_cmds.append(f'hl.dispatch(hl.dsp.window.fullscreen_state({{ internal = {orig_fs}, client = {cstate}, window = "{target}" }}))')

    # If a specific window was selected on Enter or click:
    if selected_address:
        sel_win = next((w for w in windows if w["address"] == selected_address), None)
        if sel_win:
            sel_ws = sel_win.get("orig_workspace", active_ws_id)
            if mode == "all" and sel_ws != active_ws_id:
                lua_cmds.append(f'hl.dispatch(hl.dsp.focus({{ workspace = "{sel_ws}" }}))')
            lua_cmds.append(f'hl.dispatch(hl.dsp.focus({{ window = "address:{selected_address}" }}))')
            lua_cmds.append(f'hl.dispatch(hl.dsp.window.bring_to_top({{ window = "address:{selected_address}" }}))')

    batch_eval_lua(lua_cmds)

    try:
        os.remove(STATE_FILE)
    except Exception:
        pass
    return True

def navigate_direction(direction):
    if not os.path.exists(STATE_FILE):
        return
    try:
        with open(STATE_FILE, "r") as f:
            state = json.load(f)
    except Exception:
        return

    windows = state.get("windows", [])
    if not windows:
        return

    active_win = run_hyprctl_json(["activewindow"]) or {}
    curr_addr = active_win.get("address")

    curr = next((w for w in windows if w["address"] == curr_addr), windows[0])
    curr_cx = curr["slot_x"] + curr["slot_w"] / 2.0
    curr_cy = curr["slot_y"] + curr["slot_h"] / 2.0

    candidates = []
    for w in windows:
        if w["address"] == curr["address"]:
            continue
        cx = w["slot_x"] + w["slot_w"] / 2.0
        cy = w["slot_y"] + w["slot_h"] / 2.0
        dx = cx - curr_cx
        dy = cy - curr_cy

        if direction == "right" and dx > 15:
            dist = dx + abs(dy) * 2.0
            candidates.append((dist, w["address"]))
        elif direction == "left" and dx < -15:
            dist = -dx + abs(dy) * 2.0
            candidates.append((dist, w["address"]))
        elif direction == "down" and dy > 15:
            dist = dy + abs(dx) * 2.0
            candidates.append((dist, w["address"]))
        elif direction == "up" and dy < -15:
            dist = -dy + abs(dx) * 2.0
            candidates.append((dist, w["address"]))

    if candidates:
        candidates.sort(key=lambda c: c[0])
        target_addr = candidates[0][1]
    else:
        # Cyclic fallback
        curr_idx = next((i for i, w in enumerate(windows) if w["address"] == curr["address"]), 0)
        if direction in ("right", "down"):
            target_addr = windows[(curr_idx + 1) % len(windows)]["address"]
        else:
            target_addr = windows[(curr_idx - 1) % len(windows)]["address"]

    lua_cmds = [
        f'hl.dispatch(hl.dsp.focus({{ window = "address:{target_addr}" }}))',
        f'hl.dispatch(hl.dsp.window.bring_to_top({{ window = "address:{target_addr}" }}))'
    ]
    batch_eval_lua(lua_cmds)

def select_current():
    if not os.path.exists(STATE_FILE):
        return

    try:
        with open(STATE_FILE, "r") as f:
            state = json.load(f)
    except Exception:
        return

    windows = state.get("windows", [])
    if not windows:
        return

    # Check cursor position first to detect if user clicked on a specific floating window preview
    target_addr = None
    cpos = run_hyprctl_json(["cursorpos"])
    if cpos and "x" in cpos and "y" in cpos:
        cx, cy = cpos["x"], cpos["y"]
        for w in windows:
            sx = w.get("slot_x", 0)
            sy = w.get("slot_y", 0)
            sw = w.get("slot_w", 0)
            sh = w.get("slot_h", 0)
            if sx <= cx <= sx + sw and sy <= cy <= sy + sh:
                target_addr = w["address"]
                break

    # If cursor was not inside a card (e.g. keyboard navigation), use currently active window
    if not target_addr:
        active_win = run_hyprctl_json(["activewindow"]) or {}
        target_addr = active_win.get("address")

    if not target_addr and windows:
        target_addr = windows[0]["address"]

    restore_overview(selected_address=target_addr)

def main():
    args = sys.argv[1:]
    cmd = args[0] if args else "toggle"

    if cmd == "toggle":
        mode = "all" if "--all" in args else "current"
        if os.path.exists(STATE_FILE):
            restore_overview()
        else:
            activate_overview(mode=mode)
    elif cmd == "next":
        navigate_direction("right")
    elif cmd == "prev":
        navigate_direction("left")
    elif cmd == "up":
        navigate_direction("up")
    elif cmd == "down":
        navigate_direction("down")
    elif cmd == "select":
        select_current()
    elif cmd == "restore":
        restore_overview()
    else:
        # Fallback toggle
        if os.path.exists(STATE_FILE):
            restore_overview()
        else:
            activate_overview(mode="current")

if __name__ == "__main__":
    main()
