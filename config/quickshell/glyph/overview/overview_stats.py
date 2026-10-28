#!/usr/bin/env python3
"""
Overview Statistics & Preview Collector for Nothing OS Rice
Gathers real CPU% (ps), VmRSS RAM (/proc/<pid>/status), window state,
and captures fast lightweight window thumbnails via grim.
Cleans up preview files upon overview exit to preserve memory.
"""

import sys
import os
import glob
import json
import subprocess

def clean_previews():
    for f in glob.glob("/tmp/qs-preview-*.png"):
        try:
            os.remove(f)
        except Exception:
            pass

def collect():
    try:
        clients_raw = subprocess.check_output(["hyprctl", "-j", "clients"], stderr=subprocess.DEVNULL)
        clients = json.loads(clients_raw)
    except Exception:
        clients = []

    try:
        active_ws_raw = subprocess.check_output(["hyprctl", "-j", "activeworkspace"], stderr=subprocess.DEVNULL)
        active_ws = json.loads(active_ws_raw).get("id", 1)
    except Exception:
        active_ws = 1

    pids = [str(c["pid"]) for c in clients if c.get("pid")]
    cpu_map = {}
    if pids:
        try:
            out = subprocess.check_output(["ps", "-p", ",".join(pids), "-o", "pid,%cpu", "--no-headers"], stderr=subprocess.DEVNULL).decode()
            for line in out.strip().split("\n"):
                parts = line.split()
                if len(parts) >= 2:
                    try:
                        cpu_map[int(parts[0])] = f"{float(parts[1]):.1f}%"
                    except Exception:
                        pass
        except Exception:
            pass

    stats = {}
    for c in clients:
        addr = c.get("address", "")
        if not addr:
            continue
        pid = c.get("pid", 0)
        ws = c.get("workspace", {}).get("id", 1)

        # Read actual resident memory directly from /proc/<pid>/status
        rss_mb = 0
        if pid > 0:
            try:
                with open(f"/proc/{pid}/status", "r") as f:
                    for line in f:
                        if line.startswith("VmRSS:"):
                            rss_kb = int(line.split()[1])
                            rss_mb = int(rss_kb / 1024)
                            break
            except Exception:
                pass

        cpu_str = cpu_map.get(pid, "0.0%")
        mem_str = f"{rss_mb} MB" if rss_mb > 0 else "N/A"

        # Window state
        if c.get("fullscreen"):
            status = "Fullscreen"
        elif c.get("floating"):
            status = "Floating"
        else:
            status = "Tiled"
        if c.get("pinned"):
            status += " (Pin)"

        preview_file = f"/tmp/qs-preview-{addr}.png"
        at = c.get("at", [0, 0])
        size = c.get("size", [0, 0])

        # Capture thumbnail for visible window on current workspace if not captured yet
        if ws == active_ws and c.get("mapped") and size[0] > 10 and size[1] > 10:
            if not os.path.exists(preview_file):
                try:
                    subprocess.run(
                        ["grim", "-s", "0.25", "-t", "png", "-l", "1", "-g", f"{at[0]},{at[1]} {size[0]}x{size[1]}", preview_file],
                        timeout=0.25,
                        stdout=subprocess.DEVNULL,
                        stderr=subprocess.DEVNULL
                    )
                except Exception:
                    pass

        has_preview = os.path.exists(preview_file)
        stats[addr] = {
            "cpu": cpu_str,
            "mem": mem_str,
            "status": status,
            "preview": preview_file if has_preview else ""
        }

    return stats

def main():
    if len(sys.argv) > 1 and sys.argv[1] == "--clean":
        clean_previews()
        print(json.dumps({"cleaned": True}))
        return

    data = collect()
    print(json.dumps(data))

if __name__ == "__main__":
    main()
