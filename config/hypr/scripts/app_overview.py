#!/usr/bin/env python3
"""
Nothing OS Runtime Application Overview for Hyprland
Floats and arranges running applications on the active workspace into a clean
overview layout at runtime without any popup overlays or cancellation buttons.
Pressing Super again restores all windows to their previous tiled/floating state.
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

def batch_eval_lua(lua_codes):
    if not lua_codes:
        return
    full_script = " ".join(lua_codes)
    eval_lua(full_script)

def restore_overview():
    if not os.path.exists(STATE_FILE):
        return False
    try:
        with open(STATE_FILE, "r") as f:
            state = json.load(f)
    except Exception:
        if os.path.exists(STATE_FILE):
            os.remove(STATE_FILE)
        return False

    lua_cmds = []
    for win in state.get("windows", []):
        addr = win["address"]
        target = f"address:{addr}"
        if not win.get("floating", False):
            # Was tiled, restore to tiled
            lua_cmds.append(f'hl.dispatch(hl.dsp.window.float({{ action = "off", window = "{target}" }}))')
        else:
            # Was floating, restore original size and position
            orig_w, orig_h = win["size"]
            orig_x, orig_y = win["at"]
            lua_cmds.append(f'hl.dispatch(hl.dsp.window.resize({{ x = {int(orig_w)}, y = {int(orig_h)}, window = "{target}" }}))')
            lua_cmds.append(f'hl.dispatch(hl.dsp.window.move({{ x = {int(orig_x)}, y = {int(orig_y)}, relative = false, window = "{target}" }}))')

    batch_eval_lua(lua_cmds)
    
    try:
        os.remove(STATE_FILE)
    except Exception:
        pass
    return True

def activate_overview():
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
    # Windows on active workspace that are visible/mapped
    ws_clients = [
        c for c in clients 
        if c.get("workspace", {}).get("id") == active_ws_id 
        and c.get("mapped") 
        and not c.get("hidden")
    ]

    if not ws_clients:
        return

    # Save previous state
    saved_state = {
        "workspace_id": active_ws_id,
        "windows": [
            {
                "address": c["address"],
                "floating": c.get("floating", False),
                "size": c.get("size", [800, 600]),
                "at": c.get("at", [0, 0])
            }
            for c in ws_clients
        ]
    }

    try:
        with open(STATE_FILE, "w") as f:
            json.dump(saved_state, f)
    except Exception:
        return

    # Calculate layout
    count = len(ws_clients)
    margin_x = 80
    margin_y = 120
    gap = 36

    avail_w = mon_w - (2 * margin_x)
    avail_h = mon_h - (2 * margin_y)

    layout_slots = []

    if count == 1:
        # Centered card with ~70% screen footprint
        card_w = min(1400, int(mon_w * 0.72))
        card_h = min(800, int(mon_h * 0.72))
        card_x = mon_x + (mon_w - card_w) // 2
        card_y = mon_y + (mon_h - card_h) // 2
        layout_slots.append((card_x, card_y, card_w, card_h))

    elif count == 2:
        # 2 windows side-by-side floating (matches GNOME screenshot)
        card_w = (avail_w - gap) // 2
        card_h = min(int(card_w * 0.65), avail_h)
        card_y = mon_y + (mon_h - card_h) // 2
        card_x1 = mon_x + margin_x
        card_x2 = card_x1 + card_w + gap
        layout_slots.append((card_x1, card_y, card_w, card_h))
        layout_slots.append((card_x2, card_y, card_w, card_h))

    elif count in (3, 4):
        # 2x2 grid
        cols = 2
        rows = 2
        card_w = (avail_w - gap) // cols
        card_h = (avail_h - gap) // rows
        for i in range(count):
            r = i // cols
            c = i % cols
            # If 3 windows, center the 3rd window on the second row
            if count == 3 and i == 2:
                x = mon_x + (mon_w - card_w) // 2
            else:
                x = mon_x + margin_x + c * (card_w + gap)
            y = mon_y + margin_y + r * (card_h + gap)
            layout_slots.append((x, y, card_w, card_h))

    else:
        # Multi-column grid (up to 3 columns)
        cols = 3
        rows = math.ceil(count / cols)
        card_w = (avail_w - (cols - 1) * gap) // cols
        card_h = (avail_h - (rows - 1) * gap) // rows
        for i in range(count):
            r = i // cols
            c = i % cols
            x = mon_x + margin_x + c * (card_w + gap)
            y = mon_y + margin_y + r * (card_h + gap)
            layout_slots.append((x, y, card_w, card_h))

    lua_cmds = []
    for idx, client in enumerate(ws_clients):
        if idx >= len(layout_slots):
            break
        target = f"address:{client['address']}"
        tx, ty, tw, th = layout_slots[idx]

        # Float window if not already floating
        if not client.get("floating", False):
            lua_cmds.append(f'hl.dispatch(hl.dsp.window.float({{ action = "on", window = "{target}" }}))')

        # Resize and move
        lua_cmds.append(f'hl.dispatch(hl.dsp.window.resize({{ x = {int(tw)}, y = {int(th)}, window = "{target}" }}))')
        lua_cmds.append(f'hl.dispatch(hl.dsp.window.move({{ x = {int(tx)}, y = {int(ty)}, relative = false, window = "{target}" }}))')

    batch_eval_lua(lua_cmds)

def main():
    # If state file exists, restore
    if os.path.exists(STATE_FILE):
        restore_overview()
    else:
        activate_overview()

if __name__ == "__main__":
    main()
