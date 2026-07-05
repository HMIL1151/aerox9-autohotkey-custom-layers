#Requires AutoHotkey v2.0
#SingleInstance Force

; ==========================================================
; Aerox 9 Layer Manager - AutoHotkey v2
;
; SteelSeries GG suggested bindings:
; CPI button  -> Ctrl + Alt + Shift + F12
; Side 1-12   -> F13 to F24
;
; Editor hotkey:
; Ctrl + Alt + Shift + F11
;
; Behaviour:
; CPI short press       -> switch layer on release
; CPI hold > 1 second   -> hold current overlay on screen, no layer switch
; ==========================================================

global ConfigFile := A_ScriptDir "\Aerox9Layers.ini"
global CurrentLayer := 1
global Layers := []
global ButtonPressed := Map()

global OverlayGui := ""
global EditorGui := ""
global LayerDropDown := ""
global NameEdit := ""
global ThumbnailEdit := ""
global EnabledCheck := ""
global LabelEdits := []
global ActionEdits := []

global CpiIsDown := false
global CpiDownTick := 0
global CpiLongPressActive := false
global OverlayHoldMode := false

global PickGui := ""
global PickTargetIndex := 0
global PickTypeDDL := ""
global PickKeyDDL := ""
global PickFreeTextEdit := ""

global ThumbnailCacheDir := A_ScriptDir "\ThumbnailCache"
global OverlayBackColour := "202020"

; ----------------------------------------------------------
; Overlay position  (pixels from top-left of primary screen)
; ----------------------------------------------------------
global OverlayX := A_ScreenWidth - 500   ; distance from left edge
global OverlayY := 80                    ; distance from top edge

; ----------------------------------------------------------
; CPI long-press threshold (milliseconds)
; ----------------------------------------------------------
global CpiLongPressMs := 250

; ----------------------------------------------------------
; Start-up
; ----------------------------------------------------------

LoadConfig()
ShowOverlay()

; CPI button
^!+F12::CpiDown()
^!+F12 Up::CpiUp()

; Open editor
^!+F11::OpenEditor()

; Side button down/up mappings
F13::ButtonDown(1)
F13 Up::ButtonUp(1)

F14::ButtonDown(2)
F14 Up::ButtonUp(2)

F15::ButtonDown(3)
F15 Up::ButtonUp(3)

F16::ButtonDown(4)
F16 Up::ButtonUp(4)

F17::ButtonDown(5)
F17 Up::ButtonUp(5)

F18::ButtonDown(6)
F18 Up::ButtonUp(6)

F19::ButtonDown(7)
F19 Up::ButtonUp(7)

F20::ButtonDown(8)
F20 Up::ButtonUp(8)

F21::ButtonDown(9)
F21 Up::ButtonUp(9)

F22::ButtonDown(10)
F22 Up::ButtonUp(10)

F23::ButtonDown(11)
F23 Up::ButtonUp(11)

F24::ButtonDown(12)
F24 Up::ButtonUp(12)

; ----------------------------------------------------------
; CPI handling
; ----------------------------------------------------------

CpiDown() {
    global CpiIsDown, CpiDownTick, CpiLongPressActive

    ; Prevent key repeat from restarting the timer
    if CpiIsDown {
        return
    }

    CpiIsDown := true
    CpiLongPressActive := false
    CpiDownTick := A_TickCount

    ; After CpiLongPressMs, check if CPI is still held
    SetTimer(CheckCpiLongPress, -CpiLongPressMs)
}

CheckCpiLongPress() {
    global CpiIsDown, CpiLongPressActive, OverlayHoldMode

    if !CpiIsDown {
        return
    }

    CpiLongPressActive := true
    OverlayHoldMode := true

    ShowOverlay()
}

CpiUp() {
    global CpiIsDown, CpiDownTick, CpiLongPressActive, OverlayHoldMode, OverlayGui

    if !CpiIsDown {
        return
    }

    heldMs := A_TickCount - CpiDownTick
    CpiIsDown := false

    if CpiLongPressActive || heldMs >= CpiLongPressMs {
        ; Long press:
        ; Do not switch layer.
        ; Do not rebuild overlay because that causes a visible flash.
        ; Just release hold mode and fade the existing overlay.
        OverlayHoldMode := false

        if IsObject(OverlayGui) {
            SetTimer(() => FadeOverlay(OverlayGui), -200)
        }

        return
    }

    ; Short press:
    ; Switch layer only on release.
    CycleLayer()
}

; ----------------------------------------------------------
; Layer functions
; ----------------------------------------------------------

CycleLayer() {
    global CurrentLayer, Layers

    Loop Layers.Length {
        CurrentLayer += 1

        if CurrentLayer > Layers.Length {
            CurrentLayer := 1
        }

        if Layers[CurrentLayer].Enabled {
            break
        }
    }

    ShowOverlay()
}

; ----------------------------------------------------------
; Button handling
; ----------------------------------------------------------

ButtonDown(buttonNumber) {
    global ButtonPressed, Layers, CurrentLayer

    ; Prevent Windows/key-repeat from repeatedly triggering held actions
    if ButtonPressed.Has(buttonNumber) && ButtonPressed[buttonNumber] {
        return
    }

    ButtonPressed[buttonNumber] := true

    action := Layers[CurrentLayer].Actions[buttonNumber]
    ExecuteActionDown(action)
}

ButtonUp(buttonNumber) {
    global ButtonPressed, Layers, CurrentLayer

    ButtonPressed[buttonNumber] := false

    action := Layers[CurrentLayer].Actions[buttonNumber]
    ExecuteActionUp(action)
}

ExecuteActionDown(action) {
    parsed := ParseAction(action)
    type := parsed.Type
    value := parsed.Value

    switch type {
        case "tap":
            if value != "" {
                Send(value)
            }

        case "hold":
            if value != "" {
                Send(HoldDownString(value))
            }

        case "text":
            if value != "" {
                SendText(value)
            }

        case "run":
            if value != "" {
                Run(value)
            }
        
        case "lock":
            DllCall("LockWorkStation")


        case "none":
            return

        default:
            if action != "" {
                Send(action)
            }
    }
}

ExecuteActionUp(action) {
    parsed := ParseAction(action)
    type := parsed.Type
    value := parsed.Value

    if type = "hold" && value != "" {
        Send(HoldUpString(value))
    }
}

ParseAction(action) {
    action := Trim(action)

    if action = "" {
        return { Type: "none", Value: "" }
    }

    colonPos := InStr(action, ":")

    if !colonPos {
        return { Type: "tap", Value: action }
    }

    type := StrLower(Trim(SubStr(action, 1, colonPos - 1)))
    value := Trim(SubStr(action, colonPos + 1))

    return { Type: type, Value: value }
}

HoldDownString(value) {
    value := Trim(value)

    ; {MButton} -> {MButton Down}
    if RegExMatch(value, "^\{(.+?)\}$", &m) {
        return "{" m[1] " Down}"
    }

    ; Shift -> {Shift Down}
    return "{" value " Down}"
}

HoldUpString(value) {
    value := Trim(value)

    ; {MButton} -> {MButton Up}
    if RegExMatch(value, "^\{(.+?)\}$", &m) {
        return "{" m[1] " Up}"
    }

    ; Shift -> {Shift Up}
    return "{" value " Up}"
}

; ----------------------------------------------------------
; Overlay
; ----------------------------------------------------------

ShowOverlay() {
    global OverlayGui, Layers, CurrentLayer, OverlayHoldMode

    layer := Layers[CurrentLayer]

    ; Prepare thumbnail before creating/replacing the GUI.
    ; This avoids old fade timers destroying the GUI while thumbnail processing is happening.
    thumbnailPath := ""

    try {
        thumbnailPath := ResolveThumbnailPath(layer.Thumbnail)
    }

    displayThumbnail := ""

    if thumbnailPath != "" && FileExist(thumbnailPath) {
        displayThumbnail := PrepareThumbnailForOverlay(thumbnailPath, 54)
    }

    ; Destroy the previous overlay, if it still exists.
    if IsObject(OverlayGui) {
        try OverlayGui.Destroy()
    }

    ; IMPORTANT:
    ; Do not name this variable "gui".
    ; In AutoHotkey v2 that can shadow the built-in Gui() constructor.
    newOverlay := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20")
    newOverlay.BackColor := "202020"
    newOverlay.MarginX := 14
    newOverlay.MarginY := 12

    if displayThumbnail != "" && FileExist(displayThumbnail) {
        try {
            newOverlay.Add("Picture", "xm ym w54 h54", displayThumbnail)

            newOverlay.SetFont("s14 cFFFFFF Bold", "Segoe UI")
            newOverlay.AddText("x+10 yp+2 w220", layer.Name)

            newOverlay.SetFont("s8 cAFAFAF", "Segoe UI")
            newOverlay.AddText("xp y+2 w220", "Hold CPI to keep this open")
        } catch {
            ; If image loading fails for any reason, fall back to text-only overlay.
            newOverlay.SetFont("s14 cFFFFFF Bold", "Segoe UI")
            newOverlay.AddText("xm ym w280", layer.Name)

            newOverlay.SetFont("s8 cAFAFAF", "Segoe UI")
            newOverlay.AddText("xm y+2 w280", "Hold CPI to keep this open")
        }
    } else {
        newOverlay.SetFont("s14 cFFFFFF Bold", "Segoe UI")
        newOverlay.AddText("xm ym w280", layer.Name)

        newOverlay.SetFont("s8 cAFAFAF", "Segoe UI")
        newOverlay.AddText("xm y+2 w280", "Hold CPI to keep this open")
    }

    newOverlay.SetFont("s8 c808080", "Segoe UI")
    newOverlay.AddText("xm y+6 w280", "Edit layers: Ctrl + Alt + Shift + F11")

    newOverlay.SetFont("s9 cFFFFFF", "Consolas")

    text := ""

    Loop 12 {
        label := layer.Labels[A_Index]
        buttonText := Format("{:02}", A_Index)

        text .= buttonText ": " label "`n"
    }

    newOverlay.AddText("xm y+8 w280", text)

    newOverlay.Show("x" OverlayX " y" OverlayY " NoActivate")
    WinSetTransparent(235, "ahk_id " newOverlay.Hwnd)

    ; Now that the GUI is fully built and shown, make it the current overlay.
    OverlayGui := newOverlay

    if !OverlayHoldMode {
        overlayToFade := newOverlay
        SetTimer(() => FadeOverlay(overlayToFade), -2200)
    }
}

FadeOverlay(overlayToFade) {
    global OverlayGui

    ; If this timer belongs to an older overlay, ignore it.
    ; This prevents old fade timers from destroying a newer overlay.
    if !IsObject(overlayToFade) {
        return
    }

    if !IsObject(OverlayGui) {
        return
    }

    try {
        if overlayToFade.Hwnd != OverlayGui.Hwnd {
            return
        }
    } catch {
        return
    }

    alpha := 235

    while alpha > 0 {
        ; Stop fading if a newer overlay has replaced this one.
        try {
            if !IsObject(OverlayGui) || overlayToFade.Hwnd != OverlayGui.Hwnd {
                return
            }
        } catch {
            return
        }

        alpha -= 15
        if alpha < 0 {
            alpha := 0
        }

        try {
            WinSetTransparent(alpha, "ahk_id " overlayToFade.Hwnd)
        } catch {
            return
        }

        Sleep(25)
    }

    ; Only destroy if this is still the current overlay.
    try {
        if IsObject(OverlayGui) && overlayToFade.Hwnd = OverlayGui.Hwnd {
            overlayToFade.Destroy()
            OverlayGui := ""
        }
    }
}

; ----------------------------------------------------------
; Editor GUI
; ----------------------------------------------------------

OpenEditor() {
    global EditorGui, LayerDropDown, NameEdit, ThumbnailEdit, EnabledCheck, LabelEdits, ActionEdits
    global Layers, CurrentLayer

    if IsObject(EditorGui) {
        try EditorGui.Destroy()
    }

    LabelEdits := []
    ActionEdits := []

    EditorGui := Gui("+Resize", "Aerox 9 Layer Manager")
    EditorGui.SetFont("s10", "Segoe UI")
    EditorGui.MarginX := 14
    EditorGui.MarginY := 14

    EditorGui.AddText("xm ym", "Layer:")

    LayerDropDown := EditorGui.Add("DropDownList", "x+8 yp-3 w280", GetLayerNames())
    LayerDropDown.Value := CurrentLayer
    LayerDropDown.OnEvent("Change", (*) => SelectLayerFromEditor())

    EditorGui.AddButton("x+8 yp-1 w90", "Add Layer").OnEvent("Click", (*) => AddLayerFromEditor())
    EditorGui.AddButton("x+8 yp w100", "Delete Layer").OnEvent("Click", (*) => DeleteLayerFromEditor())

    EditorGui.AddText("xm y+18", "Layer name:")
    NameEdit := EditorGui.AddEdit("x+8 yp-3 w420", Layers[CurrentLayer].Name)

    EnabledCheck := EditorGui.AddCheckbox("xm y+8", "Layer enabled (active in CPI cycle)")
    EnabledCheck.Value := Layers[CurrentLayer].Enabled ? 1 : 0

    EditorGui.AddText("xm y+12", "Thumbnail:")
    ThumbnailEdit := EditorGui.AddEdit("x+8 yp-3 w420", GetLayerThumbnail(CurrentLayer))
    EditorGui.AddButton("x+8 yp-1 w80", "Browse...").OnEvent("Click", (*) => BrowseThumbnail())
    EditorGui.AddButton("x+8 yp w80", "Clear").OnEvent("Click", (*) => ClearThumbnail())

    EditorGui.AddText("xm y+18 w40", "Btn")
    EditorGui.AddText("x+8 yp w200", "Display label")
    EditorGui.AddText("x+8 yp w300", "Action")
    EditorGui.AddText("x+8 yp w60", "Picker")

    Loop 12 {
        yPos := A_Index = 1 ? "y+6" : "y+4"

        EditorGui.AddText("xm " yPos " w40", A_Index)

        labelEdit := EditorGui.AddEdit("x+8 yp-3 w200", Layers[CurrentLayer].Labels[A_Index])
        actionEdit := EditorGui.AddEdit("x+8 yp w300", Layers[CurrentLayer].Actions[A_Index])

        pickButton := EditorGui.AddButton("x+8 yp-1 w60", "Pick...")
        pickButton.OnEvent("Click", PickAction.Bind(A_Index))

        LabelEdits.Push(labelEdit)
        ActionEdits.Push(actionEdit)
    }

    EditorGui.AddText(
        "xm y+18 w760 c555555",
        "Use Pick... to build actions without remembering AHK codes. Manual examples: tap:^c    hold:{MButton}    text:Hello    run:notepad.exe    none:"
    )

    EditorGui.AddButton("xm y+16 w100", "Save").OnEvent("Click", (*) => SaveFromEditor(true))
    EditorGui.AddButton("x+8 yp w130", "Save && Close").OnEvent("Click", (*) => SaveCloseEditor())
    EditorGui.AddButton("x+8 yp w120", "Reload File").OnEvent("Click", (*) => ReloadEditor())
    EditorGui.AddButton("x+8 yp w120", "Show Overlay").OnEvent("Click", (*) => ShowOverlay())

    EditorGui.OnEvent("Close", (*) => EditorGui.Destroy())

    EditorGui.Show("w860")
}

SelectLayerFromEditor() {
    global CurrentLayer, LayerDropDown

    SaveFromEditor(false)
    CurrentLayer := LayerDropDown.Value
    OpenEditor()
    ShowOverlay()
}

SaveFromEditor(showMessage := true) {
    global Layers, CurrentLayer, NameEdit, ThumbnailEdit, LabelEdits, ActionEdits

    if !IsObject(NameEdit) {
        return
    }

    Layers[CurrentLayer].Name := NameEdit.Value
    Layers[CurrentLayer].Enabled := EnabledCheck.Value = 1
    Layers[CurrentLayer].Thumbnail := ThumbnailEdit.Value

    Loop 12 {
        Layers[CurrentLayer].Labels[A_Index] := LabelEdits[A_Index].Value
        Layers[CurrentLayer].Actions[A_Index] := ActionEdits[A_Index].Value
    }

    SaveConfig()

    if showMessage {
        MsgBox("Saved.")
    }
}

SaveCloseEditor() {
    global EditorGui

    SaveFromEditor(false)

    if IsObject(EditorGui) {
        EditorGui.Destroy()
    }

    ShowOverlay()
}

AddLayerFromEditor() {
    global Layers, CurrentLayer

    SaveFromEditor(false)

    newIndex := Layers.Length + 1
    Layers.Push(CreateBlankLayer("New Layer " newIndex))
    CurrentLayer := newIndex

    SaveConfig()
    OpenEditor()
    ShowOverlay()
}

DeleteLayerFromEditor() {
    global Layers, CurrentLayer

    if Layers.Length <= 1 {
        MsgBox("You need at least one layer.")
        return
    }

    result := MsgBox("Delete current layer?", "Confirm delete", "YesNo Icon?")

    if result != "Yes" {
        return
    }

    Layers.RemoveAt(CurrentLayer)

    if CurrentLayer > Layers.Length {
        CurrentLayer := Layers.Length
    }

    SaveConfig()
    OpenEditor()
    ShowOverlay()
}

ReloadEditor() {
    global CurrentLayer, Layers

    LoadConfig()

    if CurrentLayer > Layers.Length {
        CurrentLayer := 1
    }

    OpenEditor()
    ShowOverlay()
}

BrowseThumbnail() {
    global ThumbnailEdit

    selectedFile := FileSelect(
        1,
        "",
        "Select layer thumbnail",
        "Image Files (*.png; *.jpg; *.jpeg; *.bmp; *.gif)"
    )

    if selectedFile != "" {
        ThumbnailEdit.Value := ToStoredThumbnailPath(selectedFile)
    }
}

PickAction(buttonIndex, *) {
    global PickGui, PickTargetIndex, PickTypeDDL, PickKeyDDL, PickFreeTextEdit
    global ActionEdits

    PickTargetIndex := buttonIndex

    if IsObject(PickGui) {
        try PickGui.Destroy()
    }

    PickGui := Gui("+AlwaysOnTop", "Pick action for button " buttonIndex)
    PickGui.SetFont("s10", "Segoe UI")
    PickGui.MarginX := 14
    PickGui.MarginY := 14

    PickGui.AddText("xm ym", "Action type:")
    PickTypeDDL := PickGui.AddDropDownList("xm y+4 w220", [
        "tap",
        "hold",
        "text",
        "run",
        "none"
    ])
    PickTypeDDL.Value := 1
    PickTypeDDL.OnEvent("Change", (*) => UpdatePickHelp())

    PickGui.AddText("xm y+14", "Key / mouse button:")
    PickKeyDDL := PickGui.AddDropDownList("xm y+4 w360", GetCommonKeyDisplayList())
    PickKeyDDL.Value := 1

    PickGui.AddText("xm y+14", "Text or program path, only used for text/run:")
    PickFreeTextEdit := PickGui.AddEdit("xm y+4 w360", "")

    PickGui.AddText(
        "xm y+12 w380 c555555",
        "Examples:`n" .
        "tap + Middle mouse button = tap:{MButton}`n" .
        "hold + Middle mouse button = hold:{MButton}`n" .
        "text = type literal text`n" .
        "run = launch a program or file"
    )

    PickGui.AddButton("xm y+16 w90", "Apply").OnEvent("Click", (*) => ApplyPickedAction())
    PickGui.AddButton("x+8 yp w90", "Cancel").OnEvent("Click", (*) => PickGui.Destroy())

    PickGui.Show()
}

ApplyPickedAction() {
    global PickGui, PickTargetIndex, PickTypeDDL, PickKeyDDL, PickFreeTextEdit, ActionEdits

    actionType := PickTypeDDL.Text
    action := ""

    switch actionType {
        case "tap":
            action := "tap:" ExtractPickedCode(PickKeyDDL.Text)

        case "hold":
            action := "hold:" ExtractPickedCode(PickKeyDDL.Text)

        case "text":
            action := "text:" PickFreeTextEdit.Value

        case "run":
            action := "run:" PickFreeTextEdit.Value

        case "none":
            action := "none:"

        default:
            action := "none:"
    }

    ActionEdits[PickTargetIndex].Value := action

    if IsObject(PickGui) {
        PickGui.Destroy()
    }
}

ExtractPickedCode(displayText) {
    arrowPos := InStr(displayText, "=>")

    if !arrowPos {
        return displayText
    }

    return Trim(SubStr(displayText, arrowPos + 2))
}

UpdatePickHelp() {
    ; Placeholder for future UI behaviour.
    ; Could be used later to disable key dropdown for text/run.
}

GetCommonKeyDisplayList() {
    return [
        "Middle mouse button => {MButton}",
        "Right mouse button => {RButton}",
        "Left mouse button => {LButton}",
        "Mouse button 4 / Back => {XButton1}",
        "Mouse button 5 / Forward => {XButton2}",
        "Mouse wheel up => {WheelUp}",
        "Mouse wheel down => {WheelDown}",

        "Shift => {Shift}",
        "Ctrl => {Ctrl}",
        "Alt => {Alt}",
        "Windows key => {LWin}",
        "Space => {Space}",
        "Enter => {Enter}",
        "Escape => {Esc}",
        "Tab => {Tab}",
        "Backspace => {Backspace}",
        "Delete => {Delete}",

        "Up arrow => {Up}",
        "Down arrow => {Down}",
        "Left arrow => {Left}",
        "Right arrow => {Right}",
        "Home => {Home}",
        "End => {End}",
        "Page Up => {PgUp}",
        "Page Down => {PgDn}",

        "A => a",
        "B => b",
        "C => c",
        "D => d",
        "E => e",
        "F => f",
        "G => g",
        "H => h",
        "I => i",
        "J => j",
        "K => k",
        "L => l",
        "M => m",
        "N => n",
        "O => o",
        "P => p",
        "Q => q",
        "R => r",
        "S => s",
        "T => t",
        "U => u",
        "V => v",
        "W => w",
        "X => x",
        "Y => y",
        "Z => z",

        "0 => 0",
        "1 => 1",
        "2 => 2",
        "3 => 3",
        "4 => 4",
        "5 => 5",
        "6 => 6",
        "7 => 7",
        "8 => 8",
        "9 => 9",

        "F1 => {F1}",
        "F2 => {F2}",
        "F3 => {F3}",
        "F4 => {F4}",
        "F5 => {F5}",
        "F6 => {F6}",
        "F7 => {F7}",
        "F8 => {F8}",
        "F9 => {F9}",
        "F10 => {F10}",
        "F11 => {F11}",
        "F12 => {F12}",

        "Copy / Ctrl+C => ^c",
        "Paste / Ctrl+V => ^v",
        "Cut / Ctrl+X => ^x",
        "Undo / Ctrl+Z => ^z",
        "Redo / Ctrl+Y => ^y",
        "Save / Ctrl+S => ^s",
        "Find / Ctrl+F => ^f",
        "Select all / Ctrl+A => ^a",
        "Alt+Tab => !{Tab}",
        "Task view / Win+Tab => #{Tab}",
        "Command palette / Ctrl+Shift+P => ^+p",
        "VS Code terminal / Ctrl+Backtick => ^``"
    ]
}

ClearThumbnail() {
    global ThumbnailEdit

    ThumbnailEdit.Value := ""
}

GetLayerNames() {
    global Layers

    names := []

    for layer in Layers {
        names.Push(layer.Name)
    }

    return names
}

GetLayerThumbnail(layerIndex) {
    global Layers

    try {
        return Layers[layerIndex].Thumbnail
    }

    return ""
}

; ----------------------------------------------------------
; Config handling using INI
; ----------------------------------------------------------

LoadConfig() {
    global ConfigFile, Layers

    Layers := []

    if !FileExist(ConfigFile) {
        Layers := CreateDefaultLayers()
        SaveConfig()
        return
    }

    count := Integer(IniRead(ConfigFile, "General", "LayerCount", "0"))

    if count < 1 {
        Layers := CreateDefaultLayers()
        SaveConfig()
        return
    }

    Loop count {
        section := "Layer" A_Index
        name := IniRead(ConfigFile, section, "Name", "Layer " A_Index)
        thumbnail := IniRead(ConfigFile, section, "Thumbnail", "")
        enabled := IniRead(ConfigFile, section, "Enabled", "1")

        labels := []
        actions := []

        Loop 12 {
            labelKey := "Button" A_Index "Label"
            actionKey := "Button" A_Index "Action"

            labels.Push(IniRead(ConfigFile, section, labelKey, "Button " A_Index))
            actions.Push(IniRead(ConfigFile, section, actionKey, "none:"))
        }

        Layers.Push({
            Name: name,
            Thumbnail: NormalizeThumbnailFromConfig(thumbnail),
            Enabled: (enabled != "0"),
            Labels: labels,
            Actions: actions
        })
    }
}

SaveConfig() {
    global ConfigFile, Layers

    if FileExist(ConfigFile) {
        FileDelete(ConfigFile)
    }

    IniWrite(Layers.Length, ConfigFile, "General", "LayerCount")

    for layerIndex, layer in Layers {
        section := "Layer" layerIndex

        IniWrite(layer.Name, ConfigFile, section, "Name")
        IniWrite(GetSafeThumbnail(layer), ConfigFile, section, "Thumbnail")
        IniWrite(layer.Enabled ? "1" : "0", ConfigFile, section, "Enabled")

        Loop 12 {
            labelKey := "Button" A_Index "Label"
            actionKey := "Button" A_Index "Action"

            IniWrite(layer.Labels[A_Index], ConfigFile, section, labelKey)
            IniWrite(layer.Actions[A_Index], ConfigFile, section, actionKey)
        }
    }
}

GetSafeThumbnail(layer) {
    try {
        return ToStoredThumbnailPath(layer.Thumbnail)
    }

    return ""
}

ResolveThumbnailPath(storedPath) {
    if storedPath = "" {
        return ""
    }

    path := Trim(storedPath)

    if !IsAbsoluteWindowsPath(path) {
        path := TrimLeadingDotPath(path)
        return A_ScriptDir "\" path
    }

    ; Legacy absolute path fallback: if missing on this machine, try local Thumbnails\ by filename.
    if FileExist(path) {
        return path
    }

    SplitPath(path, &fileName)

    if fileName != "" {
        candidate := A_ScriptDir "\Thumbnails\" fileName

        if FileExist(candidate) {
            return candidate
        }

        candidate := A_ScriptDir "\" fileName

        if FileExist(candidate) {
            return candidate
        }
    }

    return path
}

ToStoredThumbnailPath(pathValue) {
    if pathValue = "" {
        return ""
    }

    original := Trim(pathValue)
    resolved := ResolveThumbnailPath(original)

    ; Keep relative values relative (for portability in repo).
    if !IsAbsoluteWindowsPath(original) {
        return TrimLeadingDotPath(original)
    }

    scriptPrefix := RTrim(A_ScriptDir, "\\") "\\"

    if InStr(StrLower(resolved), StrLower(scriptPrefix)) = 1 {
        return SubStr(resolved, StrLen(scriptPrefix) + 1)
    }

    ; Absolute but outside this repo: keep absolute.
    return resolved
}

NormalizeThumbnailFromConfig(storedPath) {
    if storedPath = "" {
        return ""
    }

    path := Trim(storedPath)

    ; Canonicalize relative paths to a stable saved form.
    if !IsAbsoluteWindowsPath(path) {
        return TrimLeadingDotPath(path)
    }

    ; Convert absolute paths inside this repo to relative.
    return ToStoredThumbnailPath(path)
}

IsAbsoluteWindowsPath(pathValue) {
    return RegExMatch(pathValue, "i)^[A-Z]:\\|^\\\\")
}

TrimLeadingDotPath(pathValue) {
    path := StrReplace(pathValue, "/", "\\")

    if SubStr(path, 1, 2) = ".\\" {
        path := SubStr(path, 3)
    }

    while SubStr(path, 1, 1) = "\\" {
        path := SubStr(path, 2)
    }

    return path
}

PrepareThumbnailForOverlay(sourcePath, size := 54) {
    global ThumbnailCacheDir, OverlayBackColour

    if sourcePath = "" || !FileExist(sourcePath) {
        return ""
    }

    if !DirExist(ThumbnailCacheDir) {
        DirCreate(ThumbnailCacheDir)
    }

    ; Include modified time in the cache name so the cache refreshes if the image changes.
    modTime := ""

    try {
        modTime := FileGetTime(sourcePath, "M")
    } catch {
        modTime := A_Now
    }

    safeName := RegExReplace(sourcePath, "[^\w]", "_")
    cachePath := ThumbnailCacheDir "\" safeName "_" modTime "_" size ".png"

    if FileExist(cachePath) {
        return cachePath
    }

    success := CreateFlattenedThumbnail(sourcePath, cachePath, size, OverlayBackColour)

    if success && FileExist(cachePath) {
        return cachePath
    }

    ; Fallback to the original image if thumbnail generation fails.
    return sourcePath
}

CreateFlattenedThumbnail(sourcePath, outputPath, size, bgColour) {
    psPath := A_Temp "\Aerox9_CreateThumbnail.ps1"

    psLines := [
        "param(",
        "    [string]$Source,",
        "    [string]$Output,",
        "    [int]$Size,",
        "    [string]$BackgroundHex",
        ")",
        "",
        "Add-Type -AssemblyName System.Drawing",
        "",
        "$src = [System.Drawing.Image]::FromFile($Source)",
        "",
        "try {",
        "    $bmp = New-Object System.Drawing.Bitmap $Size, $Size, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)",
        "    $g = [System.Drawing.Graphics]::FromImage($bmp)",
        "",
        "    try {",
        "        $bg = [System.Drawing.ColorTranslator]::FromHtml('#' + $BackgroundHex)",
        "",
        "        $g.Clear($bg)",
        "        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic",
        "        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality",
        "        $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality",
        "        $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality",
        "",
        "        $ratioX = $Size / $src.Width",
        "        $ratioY = $Size / $src.Height",
        "        $ratio = [Math]::Min($ratioX, $ratioY)",
        "",
        "        $newW = [int]($src.Width * $ratio)",
        "        $newH = [int]($src.Height * $ratio)",
        "",
        "        $x = [int](($Size - $newW) / 2)",
        "        $y = [int](($Size - $newH) / 2)",
        "",
        "        $g.DrawImage($src, $x, $y, $newW, $newH)",
        "",
        "        $bmp.Save($Output, [System.Drawing.Imaging.ImageFormat]::Png)",
        "    }",
        "    finally {",
        "        if ($g -ne $null) {",
        "            $g.Dispose()",
        "        }",
        "",
        "        if ($bmp -ne $null) {",
        "            $bmp.Dispose()",
        "        }",
        "    }",
        "}",
        "finally {",
        "    if ($src -ne $null) {",
        "        $src.Dispose()",
        "    }",
        "}"
    ]

    psScript := JoinLines(psLines)

    try {
        if FileExist(psPath) {
            FileDelete(psPath)
        }

        FileAppend(psScript, psPath, "UTF-8")

        command := "powershell.exe -NoProfile -ExecutionPolicy Bypass -File "
            . QuoteArg(psPath)
            . " -Source " . QuoteArg(sourcePath)
            . " -Output " . QuoteArg(outputPath)
            . " -Size " . size
            . " -BackgroundHex " . QuoteArg(bgColour)

        RunWait(command, , "Hide")

        return FileExist(outputPath)
    } catch as err {
        return false
    }
}

QuoteArg(value) {
    return "`"" value "`""
}

JoinLines(lines) {
    output := ""

    for _, line in lines {
        output .= line "`r`n"
    }

    return output
}


CreateDefaultLayers() {
    return [
        {
            Name: "Default / Windows",
            Thumbnail: "",
            Enabled: true,
            Labels: [
                "Copy",
                "Paste",
                "Cut",
                "Undo",
                "Redo",
                "Enter",
                "Escape",
                "Alt Tab",
                "Task View",
                "Screenshot",
                "Mute",
                "Play/Pause"
            ],
            Actions: [
                "tap:^c",
                "tap:^v",
                "tap:^x",
                "tap:^z",
                "tap:^y",
                "tap:{Enter}",
                "tap:{Esc}",
                "tap:!{Tab}",
                "tap:#{Tab}",
                "tap:#{PrintScreen}",
                "tap:{Volume_Mute}",
                "tap:{Media_Play_Pause}"
            ]
        },
        {
            Name: "Autodesk Inventor",
            Thumbnail: "",
            Enabled: true,
            Labels: [
                "Orbit",
                "Pan",
                "Zoom Fit",
                "Measure",
                "Sketch",
                "Extrude",
                "Constraint",
                "Project Geo",
                "Finish/Esc",
                "Save",
                "Undo",
                "Escape"
            ],
            Actions: [
                "hold:{MButton}",
                "hold:{Shift}",
                "tap:{Home}",
                "tap:m",
                "tap:s",
                "tap:e",
                "tap:c",
                "tap:p",
                "tap:{Esc}",
                "tap:^s",
                "tap:^z",
                "tap:{Esc}"
            ]
        },
        {
            Name: "VS Code",
            Thumbnail: "",
            Enabled: true,
            Labels: [
                "Command Pal",
                "Quick Open",
                "Find",
                "Find Files",
                "Terminal",
                "Build",
                "Format",
                "Comment",
                "Definition",
                "Problems",
                "Git",
                "Save"
            ],
            Actions: [
                "tap:^+p",
                "tap:^p",
                "tap:^f",
                "tap:^+f",
                "tap:^``",
                "tap:^+b",
                "tap:+!f",
                "tap:^/",
                "tap:{F12}",
                "tap:^+m",
                "tap:^+g",
                "tap:^s"
            ]
        }
    ]
}

CreateBlankLayer(name) {
    return {
        Name: name,
        Thumbnail: "",
        Enabled: true,
        Labels: [
            "Button 1",
            "Button 2",
            "Button 3",
            "Button 4",
            "Button 5",
            "Button 6",
            "Button 7",
            "Button 8",
            "Button 9",
            "Button 10",
            "Button 11",
            "Button 12"
        ],
        Actions: [
            "none:",
            "none:",
            "none:",
            "none:",
            "none:",
            "none:",
            "none:",
            "none:",
            "none:",
            "none:",
            "none:",
            "none:"
        ]
    }
}