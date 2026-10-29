# Nothing OS (Glyph) Rice for Hyprland

A custom, high-performance, minimalist Nothing OS (Glyph) desktop environment built on **Hyprland** and **Quickshell** for Linux.

> [!NOTE]
> **Upstream & Attribution**: This configuration is copied, expanded, and customized from the upstream repository [Nebelung-cloud/glyph-rice](https://github.com/Nebelung-cloud/glyph-rice). Special thanks to the original authors for the Glyph shell foundations.

---

## Highlights & Features

- **Nothing OS Aesthetics**:
  - Doto dot-matrix typography, monochrome widget palette, and red accent cues.
  - Active window borders styled in pure white (`#ffffff`).
  - Snappy, fluid animation profiles (`smoothGlide` bezier curve).

- **Dual-Mode Application Overview**:
  1. **Runtime Floating Overview (`app_overview.py`)**:
     - **Current Workspace (`Super` alone / 3-Finger Swipe)**: Arranges running applications on the active workspace into a balanced, floating preview grid without touching other workspaces.
     - **All Workspaces (`Super + Shift + Tab`)**: Floats running applications across all workspaces into a unified multi-window board with dynamic scaling.
     - **Click to Navigate**: Left-clicking (`mouse:272`) on any floating window card immediately selects that window, smoothly restores all windows to normal tiled state, and switches to its workspace.
     - **Interactive Navigation Submap**: Navigate between previews using **`←` `→` `↑` `↓`** arrow keys or **Tab** / **Shift + Tab**, press **Enter** / **Space** to select, or **Escape** / **Super** to cancel.
     - **YouTube Fullscreen Protection**: Leverages Hyprland's `fullscreen_state` preserving `client` fullscreen (`client = orig_fullscreenClient`), ensuring YouTube HTML5 video playback never drops out of full-screen player mode during overview.
  2. **Zoomed-Out Graphical Overview (`Super + Tab`)**:
     - Built with Quickshell, replicating the authentic Nothing OS design (`uploaded_media_1793202205441.png`).
     - Centered search bar with live filtering.
     - Workspace filter pills defaulting to `ALL (N)` with active workspace indicators.
     - Live application window thumbnails, application icon badges, real CPU% & RAM usage from `/proc/<pid>/status`, and functional window controls (Minimize, Maximize, Close).
     - Minimal bottom keyboard cheatsheet bar.

- **Dynamic Video Lock Screen**:
  - High-definition video background (`RB22.mp4`) with smooth aspect-crop and subtle darkening.
  - Circular anti-aliased profile picture inside an animated Nothing OS LED dot ring.
  - **Auto-Login**: Typing a 6-digit PIN authenticates immediately with 0ms delay; typing a 4–5 digit PIN auto-submits after 350ms.
  - **Session Gear Menu (⚙)**: Switch sessions across users, drop to GDM greeter, log out, restart, or power off directly from the lock screen.
  - PAM watchdog and active focus retention to ensure keyboard inputs never freeze.

- **Precise Window Termination (`Super + Q`)**:
  - Automatically identifies the exact window located under the mouse cursor.
  - **Multi-Terminal Safe**: If multiple terminal windows share a single PID (e.g. Kitty in single-instance mode), only the targeted window under the cursor closes. The parent terminal daemon and other open windows remain untouched.
  - Graceful `SIGTERM` $\rightarrow$ 250ms grace $\rightarrow$ `SIGKILL` for solitary application windows.

- **Workspace Cleanup Shortcut (`Super + Shift + S` / `Super + Shift + Q`)**:
  - Safely terminates all client windows belonging exclusively to the currently active workspace.
  - Windows on other workspaces remain completely unaffected.

---

## Keyboard Shortcuts & Gestures

### Overview & Window Management

| Keybind / Gesture | Action |
| :--- | :--- |
| `Super (tap alone)` | Current workspace runtime floating overview |
| `3-Finger Swipe Up / Down` | Current workspace runtime floating overview |
| `Super + Shift + Tab` | All workspaces runtime floating overview |
| `Super + Tab` | Zoomed-Out Graphical Overview (Quickshell) |
| `Left Click` (in overview) | Select clicked window, untile, and restore to normal |
| `←` `→` `↑` `↓` (in overview) | Navigate focus spatially between floating previews |
| `Tab` / `Shift + Tab` (in overview) | Cycle focus between floating previews |
| `Enter` / `Space` (in overview) | Select focused window and restore to normal |
| `Escape` / `Super (tap)` (in overview) | Cancel overview and restore all windows to normal |

### General Shortcuts

| Keybind | Action |
| :--- | :--- |
| `Super + Q` | Close window under mouse cursor (multi-terminal safe) |
| `Super + Shift + S` / `Super + Shift + Q` | Safely close all applications on active workspace |
| `Super + W` | Open wallpaper selector |
| `Super + B` | Launch Microsoft Edge browser |
| `Super + Return` / `Super + T` | Launch Kitty terminal |
| `Super + D` | Open Nothing OS Application Launcher (Rofi) |
| `Super + L` | Lock screen (Nothing OS video lock screen) |
| `Print` | Instant full-screen screenshot |
| `Super + Print` | Interactive region screenshot snipping tool |

---

## Repository Structure

```
nothing-os-rice/
├── config/
│   ├── hypr/             # Hyprland Lua configurations, animations, keybinds
│   │   ├── hyprland/     # animations.lua, keybinds.lua, rules.lua, execs.lua
│   │   └── scripts/      # app_overview.py (runtime floating overview engine)
│   ├── quickshell/       # Quickshell glyph desktop shell, widgets, and lock screen
│   │   └── glyph/overview/ # Overview.qml (graphical overview with previews)
│   ├── rofi/             # Custom Nothing launcher themes and scripts
│   └── kitty/            # Kitty terminal configuration
├── bin/
│   ├── app-kill-clean    # Cursor-targeted window closer script
│   ├── workspace-kill-clean # Active workspace application terminator
│   ├── rice              # Rice shell daemon and lock manager
│   └── start-nothing-os  # GDM session launcher
├── assets/
│   └── avatar.png        # Circular anti-aliased profile picture
├── system/
│   ├── rules.json        # Hardware, palette, and behavior rules
│   ├── hypridle.conf     # Idle management and sleep hooks
│   └── nothing-os-rice.desktop # Wayland display manager desktop file
├── install.sh            # Automated deployment script
└── README.md
```

---

## Installation & Deployment

To apply or update configurations on the current machine:

```bash
cd ~/REPOS/nothing-os-rice
./install.sh
hyprctl reload
```

### System & Battery Optimization (NVIDIA RTD3, ZRAM & Daemons)

To eliminate the ~10.7W NVIDIA idle drain, speed up app launches with compressed ZRAM swap, and disable redundant daemons:

```bash
sudo ./bin/optimize-system.sh
```

---

## Upstream & Customizations

This rice was originally branched and modified from [https://github.com/Nebelung-cloud/glyph-rice](https://github.com/Nebelung-cloud/glyph-rice).

Key enhancements built on top of the original repository:
- **Dual-Mode Overview Engine**:
  - Implemented runtime floating application overview (`app_overview.py`) supporting both current workspace (`Super` alone / 3-finger swipe) and all workspaces (`Super + Shift + Tab`).
  - Added dedicated navigation submap with arrow keys, Tab, Enter, and mouse click hit-testing (`cursorpos`).
  - Implemented client-side fullscreen preservation (`fullscreen_state` with `internal = 0, client = orig_fullscreenClient`) to protect YouTube HTML5 video player full-screen states.
  - Replicated authentic Nothing OS reference UI in Quickshell Overview with live window previews, real-time CPU/RAM stats from `/proc`, and workspace filtering.
- **Lock Screen Re-architecture**: Added 4K H.264 video background playback via QtMultimedia, circular anti-aliased profile pictures, auto-PIN verification, PAM watchdog, and an integrated session management gear menu (switch session, logout, reboot, poweroff).
- **Process Management**: Custom hit-testing scripts (`app-kill-clean` and `workspace-kill-clean`) allowing precise, multi-terminal safe cursor window termination and workspace cleanup.
- **Visual & Performance Tuning**: Switched to native 1080p 144Hz scale 1:1, crisp pure white window borders (`#ffffff`), and fluid `smoothGlide` bezier curves.
- **Rofi & Launcher Integration**: Embedded Nothing OS application search and styling.
