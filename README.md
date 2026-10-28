# Nothing OS (Glyph) Rice for Hyprland

A custom, high-performance, minimalist Nothing OS (Glyph) desktop environment built on **Hyprland** and **Quickshell** for Linux.

> [!NOTE]
> **Upstream & Attribution**: This configuration is copied, expanded, and customized from the upstream repository [Nebelung-cloud/glyph-rice](https://github.com/Nebelung-cloud/glyph-rice). Special thanks to the original authors for the Glyph shell foundations.

---

## Highlights & Features

- **Nothing OS Aesthetics**:
  - Doto dot-matrix typography, monochrome widget palette, and red accent cues.
  - Active window borders styled in pure white (`#ffffff`).
  - Snappy, instantaneous animation profiles (speed 2).

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

- **Keyboard Shortcuts**:
  | Keybind | Action |
  | :--- | :--- |
  | `Super + Tab` / `Super (tap)` | Open Zoomed-Out Overview (running apps & workspaces) |
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
│   ├── quickshell/       # Quickshell glyph desktop shell, widgets, and lock screen
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

---

## Upstream & Customizations

This rice was originally branched and modified from [https://github.com/Nebelung-cloud/glyph-rice](https://github.com/Nebelung-cloud/glyph-rice).

Key enhancements built on top of the original repository:
- **Lock Screen Re-architecture**: Added 4K H.264 video background playback via QtMultimedia, circular anti-aliased profile pictures, auto-PIN verification, PAM watchdog, and an integrated session management gear menu (switch session, logout, reboot, poweroff).
- **Process Management**: Custom hit-testing scripts (`app-kill-clean` and `workspace-kill-clean`) allowing precise, multi-terminal safe cursor window termination and workspace cleanup.
- **Visual & Performance Tuning**: Switched to native 1080p 144Hz scale 1:1, crisp pure white window borders (`#ffffff`), and snappy animation curves.
- **Rofi & Launcher Integration**: Embedded Nothing OS application search and styling.
