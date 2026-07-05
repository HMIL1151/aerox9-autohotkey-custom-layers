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
  - linking thumbnail images to layers
- Optional action picker to avoid remembering AutoHotkey key codes.
- Support for tap actions, hold actions, text output, launching programs, and disabled buttons.
- Config saved to an `.ini` file beside the script.
- Designed for AutoHotkey v2.

---

## Requirements

- Windows 10 or Windows 11.
- AutoHotkey v2.
- SteelSeries GG.
- SteelSeries Aerox 9 mouse.

---

## Recommended Folder Structure

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

## Adding a New Layer

1. Open the editor with `Ctrl + Alt + Shift + F11`.
2. Select **Add Layer**.
3. Rename the layer using the **Layer name** field.
4. Optionally select a thumbnail using **Browse...**.
5. Edit the 12 display labels.
6. Edit the 12 actions, or use **Pick...** if the action picker is included in your script version.
7. Select **Save** or **Save & Close**.

---

## Editing an Existing Layer

1. Open the editor with `Ctrl + Alt + Shift + F11`.
2. Select the layer from the dropdown.
3. Change the layer name, thumbnail, labels, or actions.
4. Optionally set wheel-tilt left/right actions for the layer.
5. Select **Save** or **Save & Close**.

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

The recommended method is to place a shortcut to the `.ahk` script in the Windows Startup folder.

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
- The tool does not currently auto-switch layers based on active application.
- The tool does not currently include a full macro recorder unless added separately.
- Thumbnail images are displayed in a fixed-size box and may appear squashed if not square.

---

## Future Improvement Ideas

Possible future additions:

- Active-application layer switching.
- Manual override per application.
- Full macro recorder.
- Import/export layer profiles.
- Tray menu for opening the editor.
- Overlay positioning options.
- Per-layer colours.
- Per-layer icon packs.
- Better support for chorded hold actions.
- Compiled `.exe` release for easier startup and sharing.

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