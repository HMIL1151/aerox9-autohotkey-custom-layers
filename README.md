# Aerox 9 Layer Manager

A lightweight AutoHotkey v2 tool for turning the SteelSeries Aerox 9 mouse into a configurable, multi-layer productivity controller.

The tool lets you use the Aerox 9’s 12 side buttons as programmable actions, with different button mappings grouped into layers. Layers can be switched using the CPI button, and an on-screen overlay shows the active layer and button labels.

This was built as a Windows-side software layer rather than a firmware modification. SteelSeries GG is used only to map the physical mouse buttons to neutral key outputs, while AutoHotkey handles the layer logic, overlay, editor, and actions.

---

## Features

- Multiple configurable button layers.
- CPI button short press switches to the next layer.
- CPI button long press shows and holds the overlay without switching layer.
- Narrow on-screen overlay showing:
  - active layer name
  - optional layer thumbnail
  - 12 button labels
  - editor shortcut reminder
- GUI editor for:
  - adding layers
  - deleting layers
  - renaming layers
  - editing button labels
  - editing button actions
  - editing wheel-tilt left and right actions per layer
  - assigning per-layer auto-switch app rules by process name
  - linking thumbnail images to layers
- Optional action picker to avoid remembering AutoHotkey key codes.
- Built-in macro editor with line-by-line step editing and test run.
- Context-sensitive action rules by active process.
- Multi-trigger actions (short, double-tap, long-press) per button via action syntax.
- Profile import/export from the editor.
- Automatic timestamped config backups on save.
- Support for tap actions, hold actions, text output, launching programs, and disabled buttons.
- Config saved to an `.ini` file beside the script.
- Designed for AutoHotkey v2.

---

## Requirements

- Windows 10 or Windows 11.
- AutoHotkey v2 (only if running the `.ahk` script directly - not needed if you install via the packaged installer, see below).
- SteelSeries GG.
- SteelSeries Aerox 9 mouse.

---

## Installing (Colleagues / Non-Developers)

If you just want to run the tool - no Git, no AutoHotkey install, no manual Startup folder setup - use the packaged installer:

1. Get `Aerox9LayerManagerSetup.exe` from whoever built the latest release (see [Building a Release](#building-a-release) below for maintainers).
2. Run it and step through the wizard.
3. Leave **"Start Aerox 9 Layer Manager automatically when Windows starts"** checked (default) so it launches every time you sign in.
4. Finish the wizard. The app launches automatically on completion unless you untick that option.
5. On first launch (and every launch after), Windows will prompt for administrator approval (UAC). This is expected - the tool self-elevates for reliable input handling. Accept it.
6. Complete the one remaining manual step: [SteelSeries GG Setup](#steelseries-gg-setup) below, mapping the mouse buttons to the key outputs the tool listens for.

The installer ships with a default set of example layers and thumbnails already configured, so you can try it immediately, then customize with the editor (`Ctrl + Alt + Shift + F11`).

Re-running the installer later (to upgrade to a newer build) will not overwrite your existing `Aerox9Layers.ini`, config backups, or thumbnails - only the app itself is replaced.

Uninstalling (via **Settings > Apps** or the Start Menu shortcut) removes the app and its startup entry. You'll be asked whether to also delete your saved layer profile, backups, and thumbnails, or keep them in place for a future reinstall.

---

## Recommended Folder Structure

This section applies if you are running the `.ahk` script directly (development workflow). If you used the installer, skip this - it already places files in a stable Program Files location for you.

For reliability, keep the script in a stable local folder rather than a cloud-only or temporary folder.

Recommended example:

```text
C:\AHK\Aerox9_LayerOverlay.ahk
C:\AHK\Aerox9Layers.ini
C:\AHK\Thumbnails\
```

The `.ini` file is created automatically when the script first runs.

If you store the script in OneDrive, make sure the file is kept available offline. If OneDrive has not fully initialised when Windows starts, the script may not launch correctly.

---

## SteelSeries GG Setup

In SteelSeries GG, create a base Aerox 9 configuration and map the mouse controls as follows:

| Aerox 9 control | SteelSeries GG binding |
|---|---|
| CPI button | `Ctrl + Alt + Shift + F12` |
| Side button 1 | `F13` |
| Side button 2 | `F14` |
| Side button 3 | `F15` |
| Side button 4 | `F16` |
| Side button 5 | `F17` |
| Side button 6 | `F18` |
| Side button 7 | `F19` |
| Side button 8 | `F20` |
| Side button 9 | `F21` |
| Side button 10 | `F22` |
| Side button 11 | `F23` |
| Side button 12 | `F24` |
| Wheel tilt left | `WheelLeft` (default mouse event) |
| Wheel tilt right | `WheelRight` (default mouse event) |

The script listens for these key outputs and converts them into layer-specific actions.

If F13–F24 do not work reliably, you can instead use unusual key combinations such as `Ctrl + Alt + Shift + 1`, but the script hotkeys would need to be updated to match.

---

## Basic Controls

| Control | Behaviour |
|---|---|
| CPI short press | Switch to the next layer |
| CPI hold for more than 1 second | Hold the overlay on screen without changing layer |
| Release CPI after long hold | Fade the overlay away |
| `Ctrl + Alt + Shift + F11` | Open the layer editor |
| `Ctrl + Alt + Shift + F10` | Reload the script (fast edit/test loop) |
| Side buttons 1–12 | Run the configured action for the active layer |
| Wheel tilt left | Run layer wheel-tilt-left action (default `tap:^z`) |
| Wheel tilt right | Run layer wheel-tilt-right action (default `tap:^y`) |

---

## Overlay Behaviour

The overlay appears when:

- the script starts,
- the CPI button is pressed,
- the active layer changes,
- the editor requests a preview.

The overlay displays:

- the current layer name,
- optional thumbnail image,
- the 12 button labels,
- a reminder that the editor shortcut is `Ctrl + Alt + Shift + F11`.

The overlay does not show the underlying shortcut/action codes by design. It is intended to show only the human-readable button labels.

---

## Opening the Editor

Press:

```text
Ctrl + Alt + Shift + F11
```

The editor allows you to configure layers without editing the `.ini` file manually.

---

## Faster Iteration Workflow

For day-to-day editing/testing, use this loop:

1. Keep the script running.
2. Save your changes in VS Code.
3. Press `Ctrl + Alt + Shift + F10` to reload instantly.
4. Re-test on the mouse.

The script now self-elevates on launch if it is not already running as administrator, so you can usually launch it normally and accept UAC once.

---

## Adding a New Layer

1. Open the editor with `Ctrl + Alt + Shift + F11`.
2. Select **Add Layer**.
3. Rename the layer using the **Layer name** field.
4. Optionally select a thumbnail using **Browse...**.
5. Edit the 12 display labels.
6. Edit the 12 actions using each row's **Edit...** button.
7. Select **Save** or **Save & Close**.

Tip: you can click directly into an action field and press a key or key combo to auto-capture it as a `tap:` action.

In the **Buttons** tab, action cells are read-only summaries (for example `CTRL+SHIFT+A`, `SHIFT (hold)`, `Save (macro)`).

Use **Edit...** on a button row to configure its action.

In the button action editor, action text is read-only.
You can update it only by:

- **Capture Key**
- selecting a macro from the macro list (auto-applies)

For key capture:

1. Click **Capture Key**.
2. Press the key/combo to store.

In the button action editor, **Capture Key** auto-focuses the current action field.

Wheel tilt left/right actions are configured from the **Buttons** tab using the same **Edit...** workflow as button actions.

Wheel up/down actions are no longer exposed in the General tab.

---

## Editing an Existing Layer

1. Open the editor with `Ctrl + Alt + Shift + F11`.
2. Select the layer from the dropdown.
3. Change the layer name, thumbnail, labels, or actions.
4. Optionally set wheel-tilt left/right actions for the layer.
5. Optionally set wheel up/down actions (leave `none:` to keep normal scrolling).
6. Optionally set **Auto-switch apps** (for example: `Code.exe, devenv.exe`).
7. Select **Save** or **Save & Close**.

The editor is organized into tabs to keep it usable at normal window sizes:

- **General**
- **Buttons 1-6**
- **Buttons 7-12**
- **Help**

---

## Auto Layer Switching (Process-Based)

Each layer can define a list of process names in the editor field:

```text
Auto-switch apps (process names, comma-separated)
```

You can also click **Pick...** beside this field to see currently open apps and select from a checklist.

When the active window process matches one of these names, the script automatically switches to that layer.

Examples:

```text
Code.exe, devenv.exe
Inventor.exe
chrome
```

Notes:

- Matching is case-insensitive.
- You can use names with or without `.exe`.
- Separate multiple entries with commas, semicolons, or new lines.

---

## Advanced Action Syntax

You can still use regular actions like `tap:^c` and `hold:{Shift}`. Advanced options are:

### Multi-trigger action

```text
multi:shortAction||doubleTapAction||longPressAction
```

Example:

```text
multi:tap:^c||tap:^v||tap:^x
```

### Context-sensitive action

```text
code.exe,devenv.exe=>tap:^c;;default=>tap:^v
```

Rules are checked left-to-right. `default` is optional fallback.

### Macro action

```text
macro:MyMacroName
```

### Toggle action (stateful)

```text
toggle:StateName|onAction|offAction
```

Example:

```text
toggle:MicMute|tap:{Volume_Mute}|none:
```

---

## Macro Editor

Open the layer editor, then click **Macros...**.

The macro editor is arranged in two columns:

- Left: macro list and create/save/delete controls
- Right: macro name, step editor, quick-insert buttons, test run

Macro recording buttons are available in the macro editor:

- **Start Rec** begins capturing key presses into macro steps.
- **Stop Rec** ends capture.

Recorded steps are added as `tap:` and `sleep:` lines.

Macros are edited as one step per line, for example:

```text
tap:^c
sleep:120
tap:^v
```

Supported step styles include:

- `tap:...`
- `hold:...` (executed as press+release in macro playback)
- `text:...`
- `run:...`
- `sleep:<milliseconds>`
- `macro:<OtherMacro>` (nested macro)

---

## Profile Import/Export

In the layer editor:

- **Export...** writes your current config to an `.ini` profile file.
- **Import...** replaces current settings from an exported profile file.

---

## Config Backups

Every save creates a timestamped backup in:

```text
ConfigBackups\Aerox9Layers_YYYYMMDD-HHMMSS.ini
```

This gives a rollback path when experimenting with large mapping changes.

---

## Alternative Presses

Use multi-trigger actions for alternative presses on the same button:

```text
multi:shortAction||doubleTapAction||longPressAction
```

Example:

```text
multi:tap:^c||tap:^v||tap:^x
```

This gives one physical button three behaviors (single, double, long press).

---

## Deleting a Layer

1. Open the editor.
2. Select the layer from the dropdown.
3. Select **Delete Layer**.
4. Confirm the prompt.

At least one layer must remain.

---

## Layer Thumbnails

Each layer can optionally have a thumbnail image.

Supported image types in the picker:

```text
.png
.jpg
.jpeg
.bmp
.gif
```

The thumbnail path is saved in `Aerox9Layers.ini`.

If the image is moved, renamed, or deleted, the overlay will simply skip the thumbnail for that layer.

For best results, use square images. The overlay displays thumbnails in a small fixed-size box, so very wide or tall images may appear squashed.

---

## Action Syntax

Each button has two fields:

| Field | Purpose |
|---|---|
| Display label | The friendly name shown in the overlay |
| Action | The AutoHotkey action executed by the script |

Example label/action pair:

```text
Display label: Orbit
Action: hold:{MButton}
```

This means the overlay shows `Orbit`, while the actual action holds the middle mouse button.

---

## Supported Action Types

### Tap

Runs a shortcut once.

```text
tap:^c
tap:{Esc}
tap:^+p
```

Examples:

| Action | Meaning |
|---|---|
| `tap:^c` | Ctrl+C |
| `tap:^v` | Ctrl+V |
| `tap:{Esc}` | Escape |
| `tap:^+p` | Ctrl+Shift+P |
| `tap:!{Tab}` | Alt+Tab |
| `tap:#{Tab}` | Windows+Tab |

---

### Hold

Holds a key or mouse button while the Aerox side button is physically held.

```text
hold:{MButton}
hold:{Shift}
hold:{Ctrl}
hold:{RButton}
```

Examples:

| Action | Meaning |
|---|---|
| `hold:{MButton}` | Hold middle mouse button |
| `hold:{RButton}` | Hold right mouse button |
| `hold:{Shift}` | Hold Shift |
| `hold:{Ctrl}` | Hold Ctrl |
| `hold:{Space}` | Hold Space |

Hold actions are intended for single keys or single mouse buttons.

Avoid using complex combinations with `hold:` unless the script has explicitly been extended to support them.

---

### Text

Types literal text.

```text
text:Hello world
```

This is useful for short snippets, repeated phrases, or simple text entry.

---

### Run

Launches a program, file, or path.

```text
run:notepad.exe
run:C:\Path\To\App.exe
```

If the path contains spaces and does not work, try wrapping it in quotation marks inside the action field if needed.

---

### None

Disables the button for that layer.

```text
none:
```

---

## Common AutoHotkey Key Codes

If the action picker is not available, these are useful codes to know.

### Modifiers

| Code | Key |
|---|---|
| `^` | Ctrl |
| `+` | Shift |
| `!` | Alt |
| `#` | Windows key |

### Mouse Buttons

| Code | Button |
|---|---|
| `{LButton}` | Left mouse button |
| `{RButton}` | Right mouse button |
| `{MButton}` | Middle mouse button |
| `{XButton1}` | Mouse back button |
| `{XButton2}` | Mouse forward button |
| `{WheelUp}` | Mouse wheel up |
| `{WheelDown}` | Mouse wheel down |

### Common Keys

| Code | Key |
|---|---|
| `{Esc}` | Escape |
| `{Enter}` | Enter |
| `{Tab}` | Tab |
| `{Space}` | Space |
| `{Backspace}` | Backspace |
| `{Delete}` | Delete |
| `{Home}` | Home |
| `{End}` | End |
| `{PgUp}` | Page Up |
| `{PgDn}` | Page Down |
| `{Up}` | Up arrow |
| `{Down}` | Down arrow |
| `{Left}` | Left arrow |
| `{Right}` | Right arrow |

---

## Suggested Example Layers

### Default / Windows

| Button | Label | Action |
|---|---|---|
| 1 | Copy | `tap:^c` |
| 2 | Paste | `tap:^v` |
| 3 | Cut | `tap:^x` |
| 4 | Undo | `tap:^z` |
| 5 | Redo | `tap:^y` |
| 6 | Enter | `tap:{Enter}` |
| 7 | Escape | `tap:{Esc}` |
| 8 | Alt Tab | `tap:!{Tab}` |
| 9 | Task View | `tap:#{Tab}` |
| 10 | Screenshot | `tap:#{PrintScreen}` |
| 11 | Mute | `tap:{Volume_Mute}` |
| 12 | Play/Pause | `tap:{Media_Play_Pause}` |

---

### Autodesk Inventor

These are starting points and may need tuning depending on your Inventor navigation settings.

| Button | Label | Action |
|---|---|---|
| 1 | Orbit | `hold:{MButton}` |
| 2 | Pan | `hold:{Shift}` |
| 3 | Zoom Fit | `tap:{Home}` |
| 4 | Measure | `tap:m` |
| 5 | Sketch | `tap:s` |
| 6 | Extrude | `tap:e` |
| 7 | Constraint | `tap:c` |
| 8 | Project Geo | `tap:p` |
| 9 | Finish/Esc | `tap:{Esc}` |
| 10 | Save | `tap:^s` |
| 11 | Undo | `tap:^z` |
| 12 | Escape | `tap:{Esc}` |

---

### VS Code

| Button | Label | Action |
|---|---|---|
| 1 | Command Pal | `tap:^+p` |
| 2 | Quick Open | `tap:^p` |
| 3 | Find | `tap:^f` |
| 4 | Find Files | `tap:^+f` |
| 5 | Terminal | `tap:^``` |
| 6 | Build | `tap:^+b` |
| 7 | Format | `tap:+!f` |
| 8 | Comment | `tap:^/` |
| 9 | Definition | `tap:{F12}` |
| 10 | Problems | `tap:^+m` |
| 11 | Git | `tap:^+g` |
| 12 | Save | `tap:^s` |

---

## Starting Automatically with Windows

If you installed via `Aerox9LayerManagerSetup.exe`, this is already handled: the installer creates the Startup entry for you as long as the startup task was checked during setup (re-run the installer and adjust the task if you want to change this).

If you are running the `.ahk` script directly instead, the recommended method is to place a shortcut to the `.ahk` script in the Windows Startup folder.

1. Find the `.ahk` script file.
2. Create a shortcut to it.
3. Press `Windows + R`.
4. Type:

```text
shell:startup
```

5. Press Enter.
6. Copy the shortcut into the Startup folder.

The script should then run automatically when you sign in to Windows.

To stop it running at startup, remove the shortcut from the Startup folder.

---

## Troubleshooting

### The script does not start

Check that:

- AutoHotkey v2 is installed.
- The script file still exists at the shortcut target location.
- The script is not stored as an online-only OneDrive file.
- The shortcut exists in the Startup folder if you expect it to run automatically.

---

### CPI short press does not switch layers

Check that the CPI button in SteelSeries GG is mapped to:

```text
Ctrl + Alt + Shift + F12
```

Also check that the script is running by looking for the AutoHotkey tray icon.

---

### CPI long press does not hold the overlay

This depends on SteelSeries GG sending a true key-down and key-up event for the CPI button mapping.

If SteelSeries only sends a quick tap, the script cannot detect a long press.

---

### Side button hold actions do not work

Check that the side buttons are mapped to real key outputs in SteelSeries GG, preferably F13–F24.

If SteelSeries emits only tap events rather than key-down/key-up events, hold actions such as `hold:{MButton}` may not behave correctly.

---

### The overlay appears but the actions do not work

Check the action syntax.

Examples of valid actions:

```text
tap:^c
tap:{Esc}
hold:{MButton}
hold:{Shift}
text:Hello
run:notepad.exe
none:
```

---

### The thumbnail does not show

Check that:

- the file path is correct,
- the file still exists,
- the file is an image format supported by AutoHotkey’s picture control,
- the file is available locally if stored in OneDrive.

---

### The wrong layer is active

Press the CPI button to cycle through layers.

If needed, open the editor with:

```text
Ctrl + Alt + Shift + F11
```

Then check the layer order in the dropdown.

---

## Configuration File

The tool stores configuration in:

```text
Aerox9Layers.ini
```

This file is created beside the `.ahk` script.

It stores:

- layer count,
- layer names,
- layer thumbnail paths,
- button display labels,
- button actions.

You can back this file up or edit it manually if needed, but using the GUI editor is recommended.

---

## Design Notes

This tool deliberately avoids modifying the mouse firmware.

The intended setup is:

```text
Aerox 9 hardware
    ↓
SteelSeries GG neutral key bindings
    ↓
AutoHotkey layer manager
    ↓
Application-specific shortcuts/actions
```

This keeps the setup reversible, easier to debug, and safer than attempting to directly modify the mouse or SteelSeries configuration internals.

---

## Known Limitations

- Long-press CPI behaviour depends on SteelSeries GG emitting real key-down/key-up events.
- Hold actions are designed for single keys or single mouse buttons.
- The overlay is click-through and cannot currently be interacted with directly.
- Thumbnail images are displayed in a fixed-size box and may appear squashed if not square.

---

## Future Improvement Ideas

Possible future additions:

- Tray menu for opening the editor.
- Overlay positioning options.
- Per-layer colours.
- Per-layer icon packs.
- Macro recorder (currently macro editor is step-based, not recorder-based).
- Scheduled Task-based autostart (run with highest privileges) to remove the per-login UAC prompt entirely.

---

## Building a Release

This produces `dist\Aerox9LayerManagerSetup.exe`, the single installer file colleagues need (see [Installing (Colleagues / Non-Developers)](#installing-colleagues--non-developers) above). Only maintainers need this section.

### One-time tool setup

Install these once on the build machine:

- **AutoHotkey v2** - <https://www.autohotkey.com/>. Provides the runtime used as the compiled EXE's base file.
- **Ahk2Exe compiler** - the AutoHotkey v2 install includes `UX\install-ahk2exe.ahk`, which downloads and installs it; or grab a release directly from <https://github.com/AutoHotkey/Ahk2Exe/releases>.
- **Inno Setup 6** - <https://jrsoftware.org/isinfo.php> (or the GitHub releases at <https://github.com/jrsoftware/issrc/releases>). Provides `ISCC.exe`, the command-line installer compiler.

`build-release.ps1` looks for these tools in the standard Program Files locations, in `%LOCALAPPDATA%\Aerox9BuildTools\...` (a convenient non-admin install target if you don't want to touch Program Files), and finally on `PATH`. If none of those match, it fails with the paths it checked.

### Building

From the repo root:

```powershell
.\build-release.ps1
```

Optionally pass a version number (embedded in the installer's version metadata):

```powershell
.\build-release.ps1 -Version 1.1.0
```

This will:

1. Compile `Aerox9_LayerOverlay.ahk` into a standalone `Aerox9_LayerOverlay.exe` (no AutoHotkey install required on the target machine).
2. Stage the EXE, `README.md`, the default profile (`Aerox9Layers.default.ini`), and `Thumbnails\` into `dist\stage\`.
3. Build `dist\Aerox9LayerManagerSetup.exe` from `installer\installer.iss`.

### Notes for maintainers

- `Aerox9Layers.default.ini` is a curated fixture - a copy of a working profile with thumbnail paths made relative to `Thumbnails\` - shipped as the default profile for fresh installs. It is intentionally separate from your local working `Aerox9Layers.ini` (which stays in `.gitignore`-able developer/runtime state). Update `Aerox9Layers.default.ini` deliberately when you want to change what new installs start with.
- The installer only writes `Aerox9Layers.ini` and `Thumbnails\` if they don't already exist at the target (`onlyifdoesntexist`), so upgrades never clobber a colleague's live configuration or config backups.
- The installer requires administrator privileges to install (matching the app's own self-elevation behavior). It registers a Startup-folder shortcut rather than a Scheduled Task, so each login still shows one UAC prompt when the app self-elevates - a Scheduled Task with "highest privileges" is a possible future improvement to remove that prompt.
- Version metadata (name, description, file version) is embedded via `;@Ahk2Exe-Set...` compiler directives near the top of `Aerox9_LayerOverlay.ahk`. Bump the version there when cutting a new release.

---

## Licence

Personal/internal tool. Add a formal licence if this is published or shared more widely.

---

## Version Notes

This README describes the AutoHotkey v2 version of the Aerox 9 Layer Manager using:

- INI configuration,
- GUI layer editor,
- CPI short/long press behaviour,
- optional layer thumbnails,
- on-screen overlay,
- F13–F24 side-button bindings.