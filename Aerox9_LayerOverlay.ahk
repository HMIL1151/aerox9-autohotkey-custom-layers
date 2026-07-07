#Requires AutoHotkey v2.0
#SingleInstance Force

EnsureAdmin()

; ==========================================================
; Aerox 9 Layer Manager - AutoHotkey v2
;
; SteelSeries GG suggested bindings:
; CPI button  -> Ctrl + Alt + Shift + F12
; Side 1-12   -> F13 to F24
;
; Editor hotkey:
; Ctrl + Alt + Shift + F11
; Reload script hotkey:
; Ctrl + Alt + Shift + F10
;
; Behaviour:
; CPI short press       -> switch layer on release
; CPI hold > 1 second   -> hold current overlay on screen, no layer switch
; ==========================================================

;@Ahk2Exe-SetName Aerox 9 Layer Manager
;@Ahk2Exe-SetDescription Aerox 9 Layer Manager - mouse layer overlay
;@Ahk2Exe-SetProductName Aerox 9 Layer Manager
;@Ahk2Exe-SetVersion 1.0.0.0
;@Ahk2Exe-SetCopyright Aerox 9 Layer Manager contributors

global ConfigFile := A_ScriptDir "\Aerox9Layers.ini"
global CurrentLayer := 1
global Layers := []
global ButtonPressed := Map()
global ButtonDownTick := Map()
global ButtonActionCtx := Map()
global PendingDoubleTap := Map()
global ButtonLongPressMs := 360
global ButtonDoubleTapMs := 260

global OverlayGui := ""
global EditorGui := ""
global LayerDropDown := ""
global NameEdit := ""
global ThumbnailEdit := ""
global EnabledCheck := ""
global TiltLeftActionEdit := ""
global TiltRightActionEdit := ""
global WheelUpActionEdit := ""
global WheelDownActionEdit := ""
global AutoSwitchAppsEdit := ""
global LabelEdits := []
global ActionDisplayEdits := []
global ActionValues := []
global TiltLeftActionValue := ""
global TiltRightActionValue := ""
global WheelUpActionValue := ""
global WheelDownActionValue := ""
global TiltLeftActionDisplayEdit := ""
global TiltRightActionDisplayEdit := ""
global CapturableActionTargetMap := Map()
global ActionCaptureArmed := false
global ActionCaptureTargetHwnd := 0

global CpiIsDown := false
global CpiDownTick := 0
global CpiLongPressActive := false
global OverlayHoldMode := false

global PickGui := ""
global PickTargetIndex := 0
global PickTypeDDL := ""
global PickKeyDDL := ""
global PickFreeTextEdit := ""
global PickMacroDDL := ""

global AppPickerGui := ""
global AppPickerListView := ""

global MacroLibrary := []
global ToggleState := Map()
global MacroGui := ""
global MacroListBox := ""
global MacroNameEdit := ""
global MacroStepsEdit := ""
global MacroRecording := false
global MacroRecordLastTick := 0
global MacroActionEditorWasHidden := false

global ButtonActionEditGui := ""
global ButtonActionEditIndex := 0
global ButtonActionEditTargetKind := "button"
global ButtonActionRawEdit := ""
global ButtonActionMacroDDL := ""
global ButtonActionLayerDDL := ""

global ThumbnailCacheDir := A_ScriptDir "\ThumbnailCache"
global OverlayBackColour := "202020"
global LastActionText := ""

; ----------------------------------------------------------
; Overlay position  (pixels from top-left of primary screen)
; ----------------------------------------------------------
global OverlayX := A_ScreenWidth - 500   ; distance from left edge
global OverlayY := 80                    ; distance from top edge

; ----------------------------------------------------------
; CPI long-press threshold (milliseconds)
; ----------------------------------------------------------
global CpiLongPressMs := 250
global AutoLayerEnabled := true
global AutoLayerCheckMs := 450
global AutoSwitchOverrideProcess := ""

; Windows message constants used for action capture in the editor
global WM_KEYDOWN := 0x100
global WM_SYSKEYDOWN := 0x104

; ----------------------------------------------------------
; Start-up
; ----------------------------------------------------------

LoadConfig()
ShowOverlay()
StartAutoLayerMonitor()
OnMessage(WM_KEYDOWN, HandleEditorKeyCapture)
OnMessage(WM_SYSKEYDOWN, HandleEditorKeyCapture)

; CPI button
^!+F12::CpiDown()
^!+F12 Up::CpiUp()

; Open editor
^!+F11::OpenEditor()

; Reload script (quick iteration while editing)
^!+F10::ReloadScript()

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

; Wheel tilt left/right
WheelLeft::WheelTilt("Left")
WheelRight::WheelTilt("Right")
WheelUp::HandleWheelScroll("Up")
WheelDown::HandleWheelScroll("Down")

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

EnsureAdmin() {
    if A_IsAdmin {
        return
    }

    try {
        if A_IsCompiled {
            Run('*RunAs "' A_ScriptFullPath '"')
        } else {
            Run('*RunAs "' A_AhkPath '" "' A_ScriptFullPath '"')
        }

        ExitApp()
    } catch {
        MsgBox("This script should run as administrator for reliable input handling.")
    }
}

ReloadScript() {
    try {
        Reload()
    } catch {
        ; Fallback if reload fails for any reason.
        Run('*RunAs "' A_AhkPath '" "' A_ScriptFullPath '"')
        ExitApp()
    }
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
    global CurrentLayer, Layers, AutoSwitchOverrideProcess

    Loop Layers.Length {
        CurrentLayer += 1

        if CurrentLayer > Layers.Length {
            CurrentLayer := 1
        }

        if Layers[CurrentLayer].Enabled {
            break
        }
    }

    ; Manual CPI cycling should win while staying in the current app.
    ; Auto-switch resumes after focus changes to a different process.
    AutoSwitchOverrideProcess := GetActiveProcessName()

    ShowOverlay()
}

StartAutoLayerMonitor() {
    global AutoLayerEnabled, AutoLayerCheckMs

    if !AutoLayerEnabled {
        return
    }

    if AutoLayerCheckMs < 100 {
        AutoLayerCheckMs := 100
    }

    SetTimer(CheckAutoLayerSwitch, AutoLayerCheckMs)
}

CheckAutoLayerSwitch() {
    global Layers, CurrentLayer, EditorGui, LastActionText, AutoSwitchOverrideProcess

    if IsObject(EditorGui) {
        ; If the editor object exists and still has a live hwnd, pause auto-switch.
        ; If the hwnd is gone, clear the stale object so switching can continue.
        try {
            if EditorGui.Hwnd {
                return
            }
        } catch {
            EditorGui := ""
        }
    }

    if Layers.Length < 1 {
        return
    }

    activeHwnd := WinExist("A")

    if !activeHwnd {
        return
    }

    processName := ""

    try {
        processName := WinGetProcessName("ahk_id " activeHwnd)
    }

    if processName = "" {
        return
    }

    ; Respect manual CPI override while the same process remains focused.
    if AutoSwitchOverrideProcess != "" {
        if StrLower(AutoSwitchOverrideProcess) = StrLower(processName) {
            return
        }

        ; Focus moved to another app, so clear the temporary override.
        AutoSwitchOverrideProcess := ""
    }

    targetLayer := FindLayerForProcess(processName)

    if targetLayer < 1 || targetLayer > Layers.Length {
        return
    }

    if !Layers[targetLayer].Enabled {
        return
    }

    if targetLayer = CurrentLayer {
        return
    }

    CurrentLayer := targetLayer
    LastActionText := "Auto switch: " Layers[targetLayer].Name
    ShowAutoSwitchOverlay()
}

ShowAutoSwitchOverlay() {
    global OverlayHoldMode

    ; App-based switches should always show and then fade.
    OverlayHoldMode := false
    ShowOverlay()
}

FindLayerForProcess(processName) {
    global Layers

    for layerIndex, layer in Layers {
        appList := ""

        try {
            appList := layer.AutoSwitchApps
        }

        if LayerMatchesProcess(appList, processName) {
            return layerIndex
        }
    }

    return 0
}

LayerMatchesProcess(appList, processName) {
    if appList = "" || processName = "" {
        return false
    }

    processNorm := StrLower(Trim(processName))
    processBase := RegExReplace(processNorm, "\.exe$")

    normalizedList := StrReplace(appList, "`r", "")
    normalizedList := StrReplace(normalizedList, ";", ",")
    normalizedList := StrReplace(normalizedList, "`n", ",")

    for _, item in StrSplit(normalizedList, ",") {
        candidate := StrLower(Trim(item))

        if candidate = "" {
            continue
        }

        if candidate = processNorm || candidate = processBase {
            return true
        }

        if !RegExMatch(candidate, "\.exe$") && candidate ".exe" = processNorm {
            return true
        }
    }

    return false
}

; ----------------------------------------------------------
; Button handling
; ----------------------------------------------------------

ButtonDown(buttonNumber) {
    global ButtonPressed, ButtonDownTick, ButtonActionCtx

    ; Prevent Windows/key-repeat from repeatedly triggering held actions
    if ButtonPressed.Has(buttonNumber) && ButtonPressed[buttonNumber] {
        return
    }

    ButtonPressed[buttonNumber] := true
    ButtonDownTick[buttonNumber] := A_TickCount

    action := GetActionForButton(buttonNumber)
    resolvedAction := ResolveActionByContext(action)
    profile := ParseButtonActionProfile(resolvedAction)

    ButtonActionCtx[buttonNumber] := profile

    if profile.IsMulti {
        if profile.Long != "" {
            expectedTick := ButtonDownTick[buttonNumber]
            SetTimer(() => TryTriggerLongAction(buttonNumber, expectedTick), -ButtonLongPressMs)
        }

        return
    }

    ExecuteActionDown(resolvedAction)
}

ButtonUp(buttonNumber) {
    global ButtonPressed, ButtonActionCtx

    ButtonPressed[buttonNumber] := false

    if !ButtonActionCtx.Has(buttonNumber) {
        action := GetActionForButton(buttonNumber)
        action := ResolveActionByContext(action)
        ExecuteActionUp(action)
        return
    }

    profile := ButtonActionCtx[buttonNumber]

    if profile.IsMulti {
        HandleMultiActionOnRelease(buttonNumber, profile)
    } else {
        ExecuteActionUp(profile.Short)
    }

    ButtonActionCtx.Delete(buttonNumber)
}

WheelTilt(direction) {
    layer := GetEffectiveLayerObject()
    action := ""

    if direction = "Left" {
        action := layer.TiltLeftAction
    } else {
        action := layer.TiltRightAction
    }

    ; Wheel tilt does not provide a reliable up event in this workflow,
    ; so execute down+up immediately to keep hold actions from sticking.
    ExecuteActionDown(action)
    ExecuteActionUp(action)
}

HandleWheelScroll(direction) {
    layer := GetEffectiveLayerObject()
    action := ""

    if direction = "Up" {
        action := layer.WheelUpAction
        if action = "" || StrLower(Trim(action)) = "none:" {
            Send("{WheelUp}")
            return
        }
    } else {
        action := layer.WheelDownAction
        if action = "" || StrLower(Trim(action)) = "none:" {
            Send("{WheelDown}")
            return
        }
    }

    ExecuteActionDown(action)
    ExecuteActionUp(action)
}

GetActionForButton(buttonNumber) {
    layer := GetEffectiveLayerObject()
    return layer.Actions[buttonNumber]
}

GetEffectiveLayerIndex() {
    global CurrentLayer
    return CurrentLayer
}

GetEffectiveLayerObject() {
    global Layers
    return Layers[GetEffectiveLayerIndex()]
}

SwitchToLayer(layerInput) {
    global Layers, CurrentLayer, LastActionText, AutoSwitchOverrideProcess

    layerIndex := Integer(Trim(layerInput))

    if layerIndex < 1 || layerIndex > Layers.Length {
        return
    }

    CurrentLayer := layerIndex
    LastActionText := "Switch to: " Layers[layerIndex].Name
    
    ; Prevent auto-switch from overriding manual layer switch temporarily
    activeHwnd := WinExist("A")
    if activeHwnd {
        try {
            AutoSwitchOverrideProcess := WinGetProcessName("ahk_id " activeHwnd)
        }
    }
    
    ShowOverlay()
}

TryTriggerLongAction(buttonNumber, expectedTick) {
    global ButtonPressed, ButtonDownTick, ButtonActionCtx

    if !ButtonPressed.Has(buttonNumber) || !ButtonPressed[buttonNumber] {
        return
    }

    if !ButtonDownTick.Has(buttonNumber) || ButtonDownTick[buttonNumber] != expectedTick {
        return
    }

    if !ButtonActionCtx.Has(buttonNumber) {
        return
    }

    profile := ButtonActionCtx[buttonNumber]

    if !profile.IsMulti || profile.Long = "" || profile.LongTriggered {
        return
    }

    profile.LongTriggered := true
    ButtonActionCtx[buttonNumber] := profile

    ExecuteActionDown(profile.Long)
}

HandleMultiActionOnRelease(buttonNumber, profile) {
    global PendingDoubleTap, ButtonDownTick

    if profile.LongTriggered {
        ExecuteActionUp(profile.Long)
        return
    }

    if profile.Double != "" {
        if PendingDoubleTap.Has(buttonNumber) {
            pending := PendingDoubleTap[buttonNumber]

            if A_TickCount - pending.Tick <= ButtonDoubleTapMs {
                PendingDoubleTap.Delete(buttonNumber)
                ExecuteActionDown(profile.Double)
                ExecuteActionUp(profile.Double)
                return
            }

            PendingDoubleTap.Delete(buttonNumber)
        }

        pendingShort := profile.Short
        PendingDoubleTap[buttonNumber] := { Tick: A_TickCount, Action: pendingShort }

        SetTimer(() => FlushPendingDoubleTap(buttonNumber), -ButtonDoubleTapMs)
        return
    }

    ExecuteActionDown(profile.Short)
    ExecuteActionUp(profile.Short)
}

FlushPendingDoubleTap(buttonNumber) {
    global PendingDoubleTap

    if !PendingDoubleTap.Has(buttonNumber) {
        return
    }

    pending := PendingDoubleTap[buttonNumber]
    PendingDoubleTap.Delete(buttonNumber)

    if pending.Action != "" {
        ExecuteActionDown(pending.Action)
        ExecuteActionUp(pending.Action)
    }
}

ParseButtonActionProfile(action) {
    clean := Trim(action)

    if InStr(StrLower(clean), "multi:") != 1 {
        return { IsMulti: false, Short: clean, Double: "", Long: "", LongTriggered: false }
    }

    payload := SubStr(clean, 7)
    parts := StrSplit(payload, "||")

    shortAction := parts.Length >= 1 ? Trim(parts[1]) : "none:"
    doubleAction := parts.Length >= 2 ? Trim(parts[2]) : ""
    longAction := parts.Length >= 3 ? Trim(parts[3]) : ""

    if shortAction = "" {
        shortAction := "none:"
    }

    return {
        IsMulti: true,
        Short: shortAction,
        Double: doubleAction,
        Long: longAction,
        LongTriggered: false
    }
}

ExecuteActionDown(action) {
    global LastActionText

    action := ResolveActionByContext(action)
    parsed := ParseAction(action)
    type := parsed.Type
    value := parsed.Value

    switch type {
        case "tap":
            if value != "" {
                Send(value)
                LastActionText := value
            }

        case "hold":
            if value != "" {
                Send(HoldDownString(value))
                LastActionText := "Hold " value
            }

        case "text":
            if value != "" {
                SendText(value)
                LastActionText := "Text"
            }

        case "run":
            if value != "" {
                Run(value)
                LastActionText := "Run " value
            }

        case "macro":
            if value != "" {
                ExecuteMacroByName(value)
                LastActionText := "Macro " value
            }

        case "toggle":
            ExecuteToggleAction(value)
        
        case "lock":
            DllCall("LockWorkStation")
            LastActionText := "Lock workstation"

        case "layer":
            SwitchToLayer(value)

        case "none":
            return

        default:
            if action != "" {
                Send(action)
            }
    }
}

ExecuteActionUp(action) {
    action := ResolveActionByContext(action)
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

ResolveActionByContext(action) {
    raw := Trim(action)

    if !InStr(raw, "=>") {
        return raw
    }

    activeProcess := GetActiveProcessName()
    fallback := ""

    for _, rule in StrSplit(raw, ";;") {
        pair := StrSplit(rule, "=>")

        if pair.Length < 2 {
            continue
        }

        condition := StrLower(Trim(pair[1]))
        mappedAction := Trim(pair[2])

        if condition = "default" || condition = "*" {
            fallback := mappedAction
            continue
        }

        if LayerMatchesProcess(condition, activeProcess) {
            return mappedAction
        }
    }

    return fallback != "" ? fallback : "none:"
}

GetActiveProcessName() {
    activeHwnd := WinExist("A")

    if !activeHwnd {
        return ""
    }

    processName := ""

    try {
        processName := WinGetProcessName("ahk_id " activeHwnd)
    }

    return processName
}

ExecuteMacroByName(name) {
    macro := FindMacroByName(name)

    if !IsObject(macro) {
        return
    }

    steps := ParseMacroSteps(macro.Steps)

    for _, step in steps {
        parsed := ParseAction(step)

        if parsed.Type = "sleep" {
            delayMs := Integer(parsed.Value)

            if delayMs < 0 {
                delayMs := 0
            }

            Sleep(delayMs)
            continue
        }

        ExecuteActionDown(step)
        ExecuteActionUp(step)
    }
}

FindMacroByName(name) {
    global MacroLibrary

    target := StrLower(Trim(name))

    for _, macro in MacroLibrary {
        if StrLower(macro.Name) = target {
            return macro
        }
    }

    return ""
}

ParseMacroSteps(stepsText) {
    normalized := StrReplace(stepsText, "`r", "")
    normalized := StrReplace(normalized, "||", "`n")

    steps := []

    for _, line in StrSplit(normalized, "`n") {
        step := Trim(line)

        if step = "" {
            continue
        }

        steps.Push(step)
    }

    return steps
}

ExecuteToggleAction(value) {
    global ToggleState, LastActionText

    parts := StrSplit(value, "|")

    if parts.Length < 3 {
        return
    }

    stateName := Trim(parts[1])
    onAction := Trim(parts[2])
    offAction := Trim(parts[3])

    if stateName = "" {
        return
    }

    current := false

    if ToggleState.Has(stateName) {
        current := ToggleState[stateName]
    }

    nextState := !current
    ToggleState[stateName] := nextState

    selectedAction := nextState ? onAction : offAction

    if selectedAction != "" {
        ExecuteActionDown(selectedAction)
        ExecuteActionUp(selectedAction)
    }

    LastActionText := stateName ": " (nextState ? "ON" : "OFF")
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
    global OverlayGui, Layers, CurrentLayer, OverlayHoldMode, LastActionText

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

    statusLine := LastActionText

    if statusLine != "" {
        newOverlay.SetFont("s8 c66BBDD", "Segoe UI")
        newOverlay.AddText("xm y+2 w280", statusLine)
    }

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
    global EditorGui, LayerDropDown, NameEdit, ThumbnailEdit, EnabledCheck, AutoSwitchAppsEdit
    global LabelEdits, ActionDisplayEdits, ActionValues
    global TiltLeftActionValue, TiltRightActionValue, WheelUpActionValue, WheelDownActionValue
    global TiltLeftActionDisplayEdit, TiltRightActionDisplayEdit
    global CapturableActionTargetMap, ActionCaptureArmed, ActionCaptureTargetHwnd
    global Layers, CurrentLayer

    if IsObject(EditorGui) {
        try EditorGui.Destroy()
    }

    LabelEdits := []
    ActionDisplayEdits := []
    ActionValues := []
    CapturableActionTargetMap := Map()
    ActionCaptureArmed := false
    ActionCaptureTargetHwnd := 0

    Loop 12 {
        ActionValues.Push(Layers[CurrentLayer].Actions[A_Index])
    }

    TiltLeftActionValue := Layers[CurrentLayer].TiltLeftAction
    TiltRightActionValue := Layers[CurrentLayer].TiltRightAction
    WheelUpActionValue := Layers[CurrentLayer].WheelUpAction
    WheelDownActionValue := Layers[CurrentLayer].WheelDownAction

    EditorGui := Gui("+Resize", "Aerox 9 Layer Manager")
    EditorGui.SetFont("s10", "Segoe UI")
    EditorGui.MarginX := 14
    EditorGui.MarginY := 14

    EditorGui.AddText("xm ym+2", "Layer:")

    LayerDropDown := EditorGui.Add("DropDownList", "x+8 yp-3 w260", GetLayerNames())
    LayerDropDown.Value := CurrentLayer
    LayerDropDown.OnEvent("Change", (*) => SelectLayerFromEditor())

    EditorGui.AddButton("x+8 yp-1 w88", "Add Layer").OnEvent("Click", (*) => AddLayerFromEditor())
    EditorGui.AddButton("x+8 yp w96", "Delete Layer").OnEvent("Click", (*) => DeleteLayerFromEditor())

    tabs := EditorGui.AddTab3("xm y+16 w910 h560", ["General", "Buttons", "Help"])

    tabs.UseTab(1)

    EditorGui.AddText("x34 y104", "Layer name:")
    NameEdit := EditorGui.AddEdit("x150 y100 w340", Layers[CurrentLayer].Name)

    EnabledCheck := EditorGui.AddCheckbox("x34 y136 w360", "Layer enabled (active in CPI cycle)")
    EnabledCheck.Value := Layers[CurrentLayer].Enabled ? 1 : 0

    EditorGui.AddText("x34 y170", "Thumbnail:")
    ThumbnailEdit := EditorGui.AddEdit("x150 y166 w440 r1", GetLayerThumbnail(CurrentLayer))
    EditorGui.AddButton("x602 y164 w78", "Browse...").OnEvent("Click", (*) => BrowseThumbnail())
    EditorGui.AddButton("x686 y164 w60", "Clear").OnEvent("Click", (*) => ClearThumbnail())

    EditorGui.AddText("x34 y208", "Auto-switch apps:")
    AutoSwitchAppsEdit := EditorGui.AddEdit("x150 y204 w520 r3", GetLayerAutoSwitchApps(CurrentLayer))
    EditorGui.AddButton("x680 y202 w66", "Pick...").OnEvent("Click", (*) => OpenAutoSwitchAppPicker())

    tabs.UseTab(2)
    EditorGui.AddText("x34 y102 w560 c555555", "Alternative press actions are supported with: multi:short||double||long")

    EditorGui.AddText("x30 y130 w28", "Btn")
    EditorGui.AddText("x62 y130 w145", "Label")
    EditorGui.AddText("x214 y130 w180", "Action")
    EditorGui.AddText("x400 y130 w60", "Edit")

    EditorGui.AddText("x476 y130 w28", "Btn")
    EditorGui.AddText("x508 y130 w145", "Label")
    EditorGui.AddText("x660 y130 w180", "Action")
    EditorGui.AddText("x846 y130 w60", "Edit")

    Loop 12 {
        idx := A_Index

        if idx <= 6 {
            row := idx
            xBtn := 30
            xLabel := 62
            xAction := 214
            xPick := 400
        } else {
            row := idx - 6
            xBtn := 476
            xLabel := 508
            xAction := 660
            xPick := 846
        }

        y := 158 + ((row - 1) * 52)

        EditorGui.AddText("x" xBtn " y" y " w28", idx)
        labelEdit := EditorGui.AddEdit("x" xLabel " y" (y - 4) " w145", Layers[CurrentLayer].Labels[idx])
        actionDisplay := EditorGui.AddEdit("x" xAction " y" (y - 4) " w180 +ReadOnly +Disabled BackgroundE8E8E8", ActionToDisplayText(ActionValues[idx]))
        editButton := EditorGui.AddButton("x" xPick " y" (y - 5) " w60", "Edit...")
        editButton.OnEvent("Click", OpenButtonActionEditor.Bind(idx))

        LabelEdits.Push(labelEdit)
        ActionDisplayEdits.Push(actionDisplay)
    }

    EditorGui.AddText("x30 y494 w110", "Tilt Left")
    TiltLeftActionDisplayEdit := EditorGui.AddEdit("x140 y490 w250 +ReadOnly +Disabled BackgroundE8E8E8", ActionToDisplayText(TiltLeftActionValue))
    EditorGui.AddButton("x400 y489 w70", "Edit...").OnEvent("Click", (*) => OpenNamedActionEditor("tilt-left"))

    EditorGui.AddText("x476 y494 w110", "Tilt Right")
    TiltRightActionDisplayEdit := EditorGui.AddEdit("x590 y490 w250 +ReadOnly +Disabled BackgroundE8E8E8", ActionToDisplayText(TiltRightActionValue))
    EditorGui.AddButton("x850 y489 w70", "Edit...").OnEvent("Click", (*) => OpenNamedActionEditor("tilt-right"))

    tabs.UseTab(3)
    EditorGui.SetFont("s10", "Segoe UI")
    EditorGui.AddText("x34 y108 w840", "Tips")
    EditorGui.SetFont("s9", "Segoe UI")
    EditorGui.AddText(
        "x34 y138 w840 c555555",
        "Use Edit... on each button row for action setup. Advanced syntax supported: multi:short||double||long, process.exe=>action;;default=>action, macro:Name, toggle:State|On|Off."
    )
    EditorGui.AddText(
        "x34 y198 w840 c555555",
        "Because native AHK GUI scrolling is limited, this editor is split into tabs so all controls are reachable without resizing."
    )

    tabs.UseTab()

    EditorGui.AddButton("x24 y626 w96", "Save").OnEvent("Click", (*) => SaveFromEditor(true))
    EditorGui.AddButton("x128 y626 w120", "Save && Close").OnEvent("Click", (*) => SaveCloseEditor())
    EditorGui.AddButton("x256 y626 w110", "Reload File").OnEvent("Click", (*) => ReloadEditor())
    EditorGui.AddButton("x374 y626 w110", "Show Overlay").OnEvent("Click", (*) => ShowOverlay())
    EditorGui.AddButton("x596 y626 w90", "Export...").OnEvent("Click", (*) => ExportProfileConfig())
    EditorGui.AddButton("x694 y626 w90", "Import...").OnEvent("Click", (*) => ImportProfileConfig())

    EditorGui.OnEvent("Close", (*) => CloseEditorGui())

    EditorGui.Show("w940 h700")
}

SelectLayerFromEditor() {
    global CurrentLayer, LayerDropDown

    SaveFromEditor(false)
    CurrentLayer := LayerDropDown.Value
    OpenEditor()
    ShowOverlay()
}

SaveFromEditor(showMessage := true) {
    global Layers, CurrentLayer, NameEdit, ThumbnailEdit, EnabledCheck, AutoSwitchAppsEdit, LabelEdits, ActionValues
    global TiltLeftActionValue, TiltRightActionValue, WheelUpActionValue, WheelDownActionValue

    if !IsObject(NameEdit) {
        return
    }

    Layers[CurrentLayer].Name := NameEdit.Value
    Layers[CurrentLayer].Enabled := EnabledCheck.Value = 1
    Layers[CurrentLayer].Thumbnail := ThumbnailEdit.Value
    Layers[CurrentLayer].TiltLeftAction := TiltLeftActionValue
    Layers[CurrentLayer].TiltRightAction := TiltRightActionValue
    Layers[CurrentLayer].WheelUpAction := WheelUpActionValue
    Layers[CurrentLayer].WheelDownAction := WheelDownActionValue
    Layers[CurrentLayer].AutoSwitchApps := AutoSwitchAppsEdit.Value

    Loop 12 {
        Layers[CurrentLayer].Labels[A_Index] := LabelEdits[A_Index].Value
        Layers[CurrentLayer].Actions[A_Index] := ActionValues[A_Index]
    }

    SaveConfig()

    if showMessage {
        MsgBox("Saved.")
    }
}

SaveCloseEditor() {
    global EditorGui

    SaveFromEditor(false)

    CloseEditorGui()

    ShowOverlay()
}

CloseEditorGui() {
    global EditorGui, CapturableActionTargetMap, ActionCaptureArmed, ActionCaptureTargetHwnd

    if IsObject(EditorGui) {
        try EditorGui.Destroy()
    }

    CapturableActionTargetMap := Map()
    ActionCaptureArmed := false
    ActionCaptureTargetHwnd := 0
    EditorGui := ""
}

ActionToDisplayText(action) {
    raw := Trim(action)

    if raw = "" || StrLower(raw) = "none:" {
        return "Disabled"
    }

    parsed := ParseAction(raw)
    type := parsed.Type
    value := parsed.Value

    switch type {
        case "tap":
            return HumanizeTapToken(value)

        case "hold":
            return HumanizeTapToken(value) " (hold)"

        case "macro":
            return value " (macro)"

        case "layer":
            layerIndex := Integer(value)
            global Layers
            if layerIndex >= 1 && layerIndex <= Layers.Length {
                return "Switch to " Layers[layerIndex].Name
            }
            return "Layer " value

        case "lock":
            return "Lock workstation"

        case "multi":
            return "Single/Double/Long"

        case "text":
            return "Text"

        case "run":
            return "Run"

        case "toggle":
            return "Toggle"

        default:
            return raw
    }
}

HumanizeTapToken(token) {
    value := Trim(token)

    if value = "" {
        return "(empty)"
    }

    mods := ""

    if InStr(value, "^") {
        mods .= "CTRL+"
    }
    if InStr(value, "!") {
        mods .= "ALT+"
    }
    if InStr(value, "+") {
        mods .= "SHIFT+"
    }
    if InStr(value, "#") {
        mods .= "WIN+"
    }

    key := RegExReplace(value, "[\^!\+#]")

    if RegExMatch(key, "^\{(.+?)\}$", &m) {
        key := m[1]
    }

    key := StrUpper(key)
    return mods key
}

OpenButtonActionEditor(buttonIndex, *) {
    global ButtonActionEditGui, ButtonActionEditIndex, ButtonActionEditTargetKind, ButtonActionRawEdit, ButtonActionMacroDDL, ButtonActionLayerDDL
    global ActionValues, Layers

    ButtonActionEditTargetKind := "button"

    ButtonActionEditIndex := buttonIndex

    if IsObject(ButtonActionEditGui) {
        try ButtonActionEditGui.Destroy()
    }

    ButtonActionEditGui := Gui("+AlwaysOnTop", "Edit Action - Button " buttonIndex)
    ButtonActionEditGui.SetFont("s10", "Segoe UI")
    ButtonActionEditGui.MarginX := 12
    ButtonActionEditGui.MarginY := 12

    ButtonActionEditGui.AddText("xm ym", "Current action:")
    ButtonActionEditGui.AddButton("xm y+4 w110", "Capture Key").OnEvent("Click", (*) => ArmActionCapture())
    ButtonActionEditGui.AddButton("x+8 yp w70", "Disable").OnEvent("Click", (*) => DisableButtonAction())
    ButtonActionRawEdit := ButtonActionEditGui.AddEdit("x+8 yp-1 w410 +ReadOnly", ActionValues[buttonIndex])
    RegisterCapturableActionTarget(ButtonActionRawEdit, "edit", 0)

    macroNames := ["(none)"]

    for _, macroName in GetMacroNameList() {
        macroNames.Push(macroName)
    }

    ButtonActionEditGui.AddText("xm y+14", "Select macro (auto-apply):")
    ButtonActionMacroDDL := ButtonActionEditGui.AddDropDownList("xm y+4 w320", macroNames)
    ButtonActionMacroDDL.OnEvent("Change", (*) => OnButtonActionMacroChanged())
    ButtonActionEditGui.AddButton("x+10 yp-1 w130", "Open Macro Editor").OnEvent("Click", (*) => RequestOpenMacroEditor())

    layerNames := ["(none)"]
    for i, layer in Layers {
        layerNames.Push(i ": " layer.Name)
    }

    ButtonActionEditGui.AddText("xm y+12", "Select layer (auto-apply):")
    ButtonActionLayerDDL := ButtonActionEditGui.AddDropDownList("xm y+4 w320", layerNames)
    ButtonActionLayerDDL.OnEvent("Change", (*) => OnButtonActionLayerChanged())

    ButtonActionEditGui.AddText("xm y+12 w620 c777777", "Choose one: Capture Key, Macro, Layer, or Disable. Then click Save.")

    ButtonActionEditGui.AddButton("xm y+14 w90", "Save").OnEvent("Click", (*) => SaveButtonActionEdit())
    ButtonActionEditGui.AddButton("x+8 yp w90", "Cancel").OnEvent("Click", (*) => ButtonActionEditGui.Destroy())

    ButtonActionEditGui.OnEvent("Close", (*) => ButtonActionEditGui.Destroy())
    ButtonActionEditGui.Show("w660 h310")
}

OpenNamedActionEditor(targetKind) {
    global ButtonActionEditGui, ButtonActionEditIndex, ButtonActionEditTargetKind, ButtonActionRawEdit, ButtonActionMacroDDL, ButtonActionLayerDDL
    global TiltLeftActionValue, TiltRightActionValue, Layers

    ButtonActionEditIndex := 0
    ButtonActionEditTargetKind := targetKind

    if IsObject(ButtonActionEditGui) {
        try ButtonActionEditGui.Destroy()
    }

    ButtonActionEditGui := Gui("+AlwaysOnTop", "Edit Action - " (targetKind = "tilt-left" ? "Tilt Left" : "Tilt Right"))
    ButtonActionEditGui.SetFont("s10", "Segoe UI")
    ButtonActionEditGui.MarginX := 12
    ButtonActionEditGui.MarginY := 12

    currentAction := targetKind = "tilt-left" ? TiltLeftActionValue : TiltRightActionValue

    ButtonActionEditGui.AddText("xm ym", "Current action:")
    ButtonActionEditGui.AddButton("xm y+4 w110", "Capture Key").OnEvent("Click", (*) => ArmActionCapture())
    ButtonActionEditGui.AddButton("x+8 yp w70", "Disable").OnEvent("Click", (*) => DisableButtonAction())
    ButtonActionRawEdit := ButtonActionEditGui.AddEdit("x+8 yp-1 w410 +ReadOnly", currentAction)
    RegisterCapturableActionTarget(ButtonActionRawEdit, "edit", 0)

    macroNames := ["(none)"]

    for _, macroName in GetMacroNameList() {
        macroNames.Push(macroName)
    }

    ButtonActionEditGui.AddText("xm y+14", "Select macro (auto-apply):")
    ButtonActionMacroDDL := ButtonActionEditGui.AddDropDownList("xm y+4 w320", macroNames)
    ButtonActionMacroDDL.OnEvent("Change", (*) => OnButtonActionMacroChanged())
    ButtonActionEditGui.AddButton("x+10 yp-1 w130", "Open Macro Editor").OnEvent("Click", (*) => RequestOpenMacroEditor())

    layerNames := ["(none)"]
    for i, layer in Layers {
        layerNames.Push(i ": " layer.Name)
    }

    ButtonActionEditGui.AddText("xm y+12", "Select layer (auto-apply):")
    ButtonActionLayerDDL := ButtonActionEditGui.AddDropDownList("xm y+4 w320", layerNames)
    ButtonActionLayerDDL.OnEvent("Change", (*) => OnButtonActionLayerChanged())

    ButtonActionEditGui.AddText("xm y+12 w620 c777777", "Choose one: Capture Key, Macro, Layer, or Disable. Then click Save.")

    ButtonActionEditGui.AddButton("xm y+14 w90", "Save").OnEvent("Click", (*) => SaveButtonActionEdit())
    ButtonActionEditGui.AddButton("x+8 yp w90", "Cancel").OnEvent("Click", (*) => ButtonActionEditGui.Destroy())

    ButtonActionEditGui.OnEvent("Close", (*) => ButtonActionEditGui.Destroy())
    ButtonActionEditGui.Show("w660 h310")
}

OnButtonActionMacroChanged() {
    global ButtonActionRawEdit, ButtonActionMacroDDL

    name := Trim(ButtonActionMacroDDL.Text)

    if name = "" || name = "(none)" {
        ButtonActionRawEdit.Value := "none:"
    } else {
        ButtonActionRawEdit.Value := "macro:" name
    }
}

OnButtonActionLayerChanged() {
    global ButtonActionRawEdit, ButtonActionLayerDDL

    text := Trim(ButtonActionLayerDDL.Text)

    if text = "" || text = "(none)" {
        ButtonActionRawEdit.Value := "none:"
    } else {
        ; Extract the layer number from "1: Layer Name" format
        colonPos := InStr(text, ":")
        if colonPos > 0 {
            layerNum := Trim(SubStr(text, 1, colonPos - 1))
            ButtonActionRawEdit.Value := "layer:" layerNum
        } else {
            ButtonActionRawEdit.Value := "none:"
        }
    }
}

DisableButtonAction() {
    global ButtonActionRawEdit

    ButtonActionRawEdit.Value := "none:"
}

SaveButtonActionEdit() {
    global ButtonActionEditGui, ButtonActionEditIndex, ButtonActionEditTargetKind, ButtonActionRawEdit
    global ActionValues, ActionDisplayEdits
    global TiltLeftActionValue, TiltRightActionValue, TiltLeftActionDisplayEdit, TiltRightActionDisplayEdit

    if ButtonActionEditTargetKind = "button" && (ButtonActionEditIndex < 1 || ButtonActionEditIndex > ActionValues.Length) {
        return
    }

    raw := Trim(ButtonActionRawEdit.Value)

    if raw = "" {
        raw := "none:"
    }

    switch ButtonActionEditTargetKind {
        case "button":
            ActionValues[ButtonActionEditIndex] := raw
            ActionDisplayEdits[ButtonActionEditIndex].Value := ActionToDisplayText(raw)

        case "tilt-left":
            TiltLeftActionValue := raw
            if IsObject(TiltLeftActionDisplayEdit) {
                TiltLeftActionDisplayEdit.Value := ActionToDisplayText(raw)
            }

        case "tilt-right":
            TiltRightActionValue := raw
            if IsObject(TiltRightActionDisplayEdit) {
                TiltRightActionDisplayEdit.Value := ActionToDisplayText(raw)
            }
    }

    if IsObject(ButtonActionEditGui) {
        ButtonActionEditGui.Destroy()
    }
}

RegisterCapturableActionEdit(editControl) {
    RegisterCapturableActionTarget(editControl, "edit", 0)
}

RegisterCapturableActionTarget(control, targetType, targetIndex := 0) {
    global CapturableActionTargetMap

    if !IsObject(control) {
        return
    }

    CapturableActionTargetMap[control.Hwnd] := {
        Control: control,
        Type: targetType,
        Index: targetIndex
    }

    control.OnEvent("Focus", CapturableActionEditFocused)
}

CapturableActionEditFocused(editControl, *) {
    global ActionCaptureTargetHwnd

    if IsObject(editControl) {
        ActionCaptureTargetHwnd := editControl.Hwnd
    }
}

ArmActionCapture() {
    global ActionCaptureArmed, ActionCaptureTargetHwnd
    global ButtonActionEditGui, ButtonActionRawEdit, CapturableActionTargetMap

    targetHwnd := 0

    ; In button action editor, always capture into the current action field.
    if IsObject(ButtonActionEditGui) && IsObject(ButtonActionRawEdit) {
        targetHwnd := ButtonActionRawEdit.Hwnd
    }

    ; Otherwise use last known capture target when available.
    if !targetHwnd && ActionCaptureTargetHwnd && CapturableActionTargetMap.Has(ActionCaptureTargetHwnd) {
        targetHwnd := ActionCaptureTargetHwnd
    }

    ; Fallback to current focus if it is a capturable target.
    if !targetHwnd {
        focused := DllCall("GetFocus", "ptr")

        if focused && CapturableActionTargetMap.Has(focused) {
            targetHwnd := focused
        }
    }

    ActionCaptureTargetHwnd := targetHwnd

    if targetHwnd {
        try DllCall("SetFocus", "ptr", targetHwnd)
    }

    ActionCaptureArmed := true
    ToolTip("Capture armed: press key/combo")
    SetTimer(() => ToolTip(), -1200)
}

HandleEditorKeyCapture(wParam, lParam, msg, hwnd) {
    global EditorGui, CapturableActionTargetMap, ActionCaptureArmed, ActionCaptureTargetHwnd
    global MacroGui, MacroRecording, MacroRecordLastTick, MacroStepsEdit
    global ActionValues, ActionDisplayEdits

    ; Macro recording capture inside Macro Editor.
    if MacroRecording && IsObject(MacroGui) {
        try {
            if WinActive("ahk_id " MacroGui.Hwnd) {
                action := BuildCapturedTapAction(wParam)

                if action != "" {
                    nowTick := A_TickCount

                    if MacroRecordLastTick > 0 {
                        delay := nowTick - MacroRecordLastTick

                        if delay > 0 {
                            AppendMacroStep("sleep:" delay)
                        }
                    }

                    AppendMacroStep(action)
                    MacroRecordLastTick := nowTick
                    return 0
                }

                ; While recording, swallow non-capturable keys to avoid edit-control beep noise.
                return 0
            }
        }
    }

    if !ActionCaptureArmed {
        return
    }

    if !IsObject(EditorGui) {
        ActionCaptureArmed := false
        ActionCaptureTargetHwnd := 0
        return
    }

    ; Ignore autorepeat keydown events.
    if (lParam & 0x40000000) {
        return
    }

    focusedHwnd := DllCall("GetFocus", "ptr")

    if !focusedHwnd || !CapturableActionTargetMap.Has(focusedHwnd) {
        ; Capture was armed, but focus is not in a capturable field.
        ; Swallow the key to avoid system ding and keep capture armed.
        return 0
    }

    target := CapturableActionTargetMap[focusedHwnd]

    if ActionCaptureTargetHwnd && focusedHwnd != ActionCaptureTargetHwnd {
        ActionCaptureTargetHwnd := focusedHwnd
    }

    action := BuildCapturedTapAction(wParam)

    if action = "" {
        ; Ignore modifier-only presses without producing noise.
        return 0
    }

    if target.Type = "button" {
        ActionValues[target.Index] := action
        ActionDisplayEdits[target.Index].Value := ActionToDisplayText(action)
    } else {
        target.Control.Value := action
    }

    ActionCaptureArmed := false
    ActionCaptureTargetHwnd := focusedHwnd

    ToolTip("Captured: " action)
    SetTimer(() => ToolTip(), -900)

    ; Consume the key so the raw character doesn't get typed into the edit box.
    return 0
}

BuildCapturedTapAction(vkCode) {
    keyName := GetKeyName(Format("vk{:X}", vkCode))

    if keyName = "" {
        return
    }

    ; Normalize keys that often arrive as left/right variants.
    if keyName = "LControl" || keyName = "RControl" {
        keyName := "Control"
    } else if keyName = "LShift" || keyName = "RShift" {
        keyName := "Shift"
    } else if keyName = "LAlt" || keyName = "RAlt" {
        keyName := "Alt"
    }

    ; Ignore standalone modifier keys.
    if keyName = "Shift" || keyName = "Control" || keyName = "Alt" || keyName = "LWin" || keyName = "RWin" {
        return ""
    }

    prefix := ""

    if GetKeyState("Ctrl", "P") {
        prefix .= "^"
    }
    if GetKeyState("Alt", "P") {
        prefix .= "!"
    }
    if GetKeyState("Shift", "P") {
        prefix .= "+"
    }
    if GetKeyState("LWin", "P") || GetKeyState("RWin", "P") {
        prefix .= "#"
    }

    keyToken := KeyNameToActionToken(keyName)

    if keyToken = "" {
        return ""
    }

    return "tap:" prefix keyToken
}

KeyNameToActionToken(keyName) {
    ; Single alphanumeric keys can stay plain.
    if RegExMatch(keyName, "^[A-Za-z0-9]$") {
        return StrLower(keyName)
    }

    ; Named keys should use brace syntax.
    return "{" keyName "}"
}

ExportProfileConfig() {
    global ConfigFile

    targetPath := FileSelect(
        "S",
        A_ScriptDir "\Aerox9Layers-export.ini",
        "Export profile config",
        "INI Files (*.ini)"
    )

    if targetPath = "" {
        return
    }

    SaveConfig()

    try {
        FileCopy(ConfigFile, targetPath, true)
        MsgBox("Profile exported.")
    } catch {
        MsgBox("Could not export profile.")
    }
}

ImportProfileConfig() {
    global ConfigFile

    sourcePath := FileSelect(
        1,
        A_ScriptDir,
        "Import profile config",
        "INI Files (*.ini)"
    )

    if sourcePath = "" {
        return
    }

    result := MsgBox("Importing will replace current settings. Continue?", "Import profile", "YesNo Icon?")

    if result != "Yes" {
        return
    }

    try {
        FileCopy(sourcePath, ConfigFile, true)
        ReloadEditor()
        MsgBox("Profile imported.")
    } catch {
        MsgBox("Could not import profile.")
    }
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
    global PickGui, PickTargetIndex, PickTypeDDL, PickKeyDDL, PickFreeTextEdit, PickMacroDDL
    global ActionValues, ActionDisplayEdits

    macroNames := GetMacroNameList()

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
        "macro",
        "none"
    ])
    PickTypeDDL.Value := 1
    PickTypeDDL.OnEvent("Change", (*) => UpdatePickHelp())

    PickGui.AddText("xm y+14", "Key / mouse button:")
    PickKeyDDL := PickGui.AddDropDownList("xm y+4 w360", GetCommonKeyDisplayList())
    PickKeyDDL.Value := 1

    PickGui.AddText("xm y+14", "Text or program path, only used for text/run:")
    PickFreeTextEdit := PickGui.AddEdit("xm y+4 w360", "")

    PickGui.AddText("xm y+14", "Macro name, only used for macro:")
    PickMacroDDL := PickGui.AddDropDownList("xm y+4 w360", macroNames)

    if macroNames.Length > 0 {
        PickMacroDDL.Value := 1
    }

    PickGui.AddText(
        "xm y+12 w380 c555555",
        "Examples:`n" .
        "tap + Middle mouse button = tap:{MButton}`n" .
        "hold + Middle mouse button = hold:{MButton}`n" .
        "text = type literal text`n" .
        "run = launch a program or file`n" .
        "macro = run saved macro steps`n" .
        "multi syntax: multi:short||double||long`n" .
        "context syntax: code.exe=>tap:^c;;default=>tap:^v"
    )

    PickGui.AddButton("xm y+16 w90", "Apply").OnEvent("Click", (*) => ApplyPickedAction())
    PickGui.AddButton("x+8 yp w90", "Cancel").OnEvent("Click", (*) => PickGui.Destroy())

    PickGui.Show()
}

ApplyPickedAction() {
    global PickGui, PickTargetIndex, PickTypeDDL, PickKeyDDL, PickFreeTextEdit, PickMacroDDL
    global ActionValues, ActionDisplayEdits

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

        case "macro":
            macroName := PickMacroDDL.Text

            if macroName = "" {
                action := "none:"
            } else {
                action := "macro:" macroName
            }

        case "none":
            action := "none:"

        default:
            action := "none:"
    }

    if PickTargetIndex >= 1 && PickTargetIndex <= ActionValues.Length {
        ActionValues[PickTargetIndex] := action

        if PickTargetIndex <= ActionDisplayEdits.Length {
            ActionDisplayEdits[PickTargetIndex].Value := ActionToDisplayText(action)
        }
    }

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

GetLayerTiltLeftAction(layerIndex) {
    global Layers

    try {
        return Layers[layerIndex].TiltLeftAction
    }

    return "tap:^z"
}

GetLayerTiltRightAction(layerIndex) {
    global Layers

    try {
        return Layers[layerIndex].TiltRightAction
    }

    return "tap:^y"
}

GetLayerWheelUpAction(layerIndex) {
    global Layers

    try {
        return Layers[layerIndex].WheelUpAction
    }

    return "none:"
}

GetLayerWheelDownAction(layerIndex) {
    global Layers

    try {
        return Layers[layerIndex].WheelDownAction
    }

    return "none:"
}

GetLayerAutoSwitchApps(layerIndex) {
    global Layers

    try {
        return Layers[layerIndex].AutoSwitchApps
    }

    return ""
}

GetMacroNameList() {
    global MacroLibrary

    names := []

    for _, macro in MacroLibrary {
        names.Push(macro.Name)
    }

    return names
}

OpenMacroEditor() {
    global MacroGui, MacroListBox, MacroNameEdit, MacroStepsEdit, MacroRecording, MacroRecordLastTick, ButtonActionEditGui, MacroActionEditorWasHidden

    macroNames := GetMacroNameList()

    if IsObject(MacroGui) {
        try MacroGui.Destroy()
    }

    MacroRecording := false
    MacroRecordLastTick := 0
    MacroActionEditorWasHidden := false

    MacroGui := Gui("+Resize +AlwaysOnTop", "Aerox 9 Macro Editor")
    if IsObject(ButtonActionEditGui) {
        try {
            ButtonActionEditGui.Hide()
            MacroActionEditorWasHidden := true
        }
    }
    MacroGui.SetFont("s10", "Segoe UI")
    MacroGui.MarginX := 14
    MacroGui.MarginY := 14

    MacroGui.AddText("xm ym", "Macro list")
    MacroListBox := MacroGui.AddListBox("xm y+4 w190 h285", macroNames)
    MacroListBox.OnEvent("Change", (*) => LoadSelectedMacroIntoEditor())

    ; Fixed-position controls avoid overlap on different DPI/font scales.
    MacroGui.AddButton("x14 y342 w58", "New").OnEvent("Click", (*) => NewMacroInEditor())
    MacroGui.AddButton("x78 y342 w58", "Save").OnEvent("Click", (*) => SaveMacroFromEditor())
    MacroGui.AddButton("x142 y342 w62", "Delete").OnEvent("Click", (*) => DeleteSelectedMacro())
    MacroGui.AddButton("x14 y376 w92", "Start Rec").OnEvent("Click", (*) => StartMacroRecording())
    MacroGui.AddButton("x112 y376 w92", "Stop Rec").OnEvent("Click", (*) => StopMacroRecording())

    MacroGui.AddText("x224 y14", "Macro name")
    MacroNameEdit := MacroGui.AddEdit("x224 y34 w380", "")

    MacroGui.AddText("x224 y70", "Steps (one per line)")
    MacroStepsEdit := MacroGui.AddEdit("x224 y90 w380 h250", "")

    MacroGui.AddText(
        "x224 y348 w380 c555555",
        "Use one action per line. Examples: tap:^c, hold:{Shift}, text:Hello, run:notepad.exe, sleep:120, macro:Build"
    )

    MacroGui.AddText("x224 y390", "Quick insert")
    MacroGui.AddButton("x224 y410 w82", "Tap").OnEvent("Click", (*) => InsertMacroTemplate("tap:"))
    MacroGui.AddButton("x+6 yp w82", "Hold").OnEvent("Click", (*) => InsertMacroTemplate("hold:{Shift}"))
    MacroGui.AddButton("x+6 yp w82", "Text").OnEvent("Click", (*) => InsertMacroTemplate("text:"))
    MacroGui.AddButton("x+6 yp w82", "Run").OnEvent("Click", (*) => InsertMacroTemplate("run:"))

    MacroGui.AddButton("x224 y446 w82", "Sleep").OnEvent("Click", (*) => InsertMacroTemplate("sleep:120"))
    MacroGui.AddButton("x+6 yp w82", "Macro").OnEvent("Click", (*) => InsertMacroTemplate("macro:"))
    MacroGui.AddButton("x+6 yp w110", "Test Run").OnEvent("Click", (*) => TestRunMacro())
    MacroGui.AddButton("x+6 yp w110", "Close").OnEvent("Click", (*) => MacroGui.Destroy())

    ; Cheatsheet panel
    MacroGui.AddText("x14 y482", "AHK Action Codes")
    cheatsheetText := "Keyboard: tap:{Enter}, tap:a, tap:^c (Ctrl+C), tap:!c (Alt+C), tap:+c (Shift+C), tap:#{Tab} (Win+Tab)`n"
    cheatsheetText .= "Mouse: tap:{MButton}, tap:{RButton}, tap:{LButton}, tap:{XButton1}, tap:{WheelUp}`n"
    cheatsheetText .= "Hold: hold:{Shift}, hold:^c`n"
    cheatsheetText .= "Text: text:Hello World`n"
    cheatsheetText .= "Run: run:notepad.exe, run:C:\\path\\to\\app.exe`n"
    cheatsheetText .= "Delay: sleep:500 (milliseconds)`n"
    cheatsheetText .= "Macro: macro:MacroName (recursively call other macro)`n"
    cheatsheetText .= "Navigation: {Up}, {Down}, {Left}, {Right}, {Home}, {End}, {PgUp}, {PgDn}`n"
    cheatsheetText .= "Functions: {F1} to {F12}, {Esc}, {Tab}, {Backspace}, {Delete}, {Ins}, {Pause}`n"
    cheatsheetText .= "Combos: ^+a (Ctrl+Shift+A), !{F4} (Alt+F4), #e (Win+E)"
    MacroGui.AddEdit("x14 y502 w590 h120 +ReadOnly BackgroundE8E8E8 -VScroll", cheatsheetText)

    MacroGui.OnEvent("Close", (*) => CloseMacroGui())
    MacroGui.Show("w630 h650")
    ActivateMacroGui()
    SetTimer(ActivateMacroGui, -40)

    if macroNames.Length > 0 {
        MacroListBox.Value := 1
        LoadSelectedMacroIntoEditor()
    }
}

RequestOpenMacroEditor() {
    ; Open after the current click event settles to avoid owner focus rebound.
    SetTimer(OpenMacroEditor, -10)
}

ActivateMacroGui() {
    global MacroGui

    if IsObject(MacroGui) {
        try WinActivate("ahk_id " MacroGui.Hwnd)
    }
}

LoadSelectedMacroIntoEditor() {
    global MacroListBox, MacroNameEdit, MacroStepsEdit

    selected := MacroListBox.Text

    if selected = "" {
        return
    }

    macro := FindMacroByName(selected)

    if !IsObject(macro) {
        return
    }

    MacroNameEdit.Value := macro.Name
    MacroStepsEdit.Value := macro.Steps
}

RefreshMacroListBox() {
    global MacroListBox

    if !IsObject(MacroListBox) {
        return
    }

    try {
        MacroListBox.Delete()

        for _, name in GetMacroNameList() {
            MacroListBox.Add([name])
        }
    } catch {
        ; ListBox control is destroyed, silently return
        return
    }
}

NewMacroInEditor() {
    global MacroNameEdit, MacroStepsEdit, MacroListBox

    MacroNameEdit.Value := "NewMacro"
    MacroStepsEdit.Value := "tap:^c`nsleep:120`ntap:^v"
    
    ; Add to list and select it to make it obvious a new macro was created
    newIndex := MacroListBox.Add(["NewMacro"])
    MacroListBox.Value := newIndex
    
    ; Focus on the name edit so user can immediately rename it
    try MacroNameEdit.Focus()
    
    ToolTip("New macro created - edit name and steps")
    SetTimer(() => ToolTip(), -1200)
}

SaveMacroFromEditor() {
    global MacroLibrary, MacroNameEdit, MacroStepsEdit

    name := Trim(MacroNameEdit.Value)
    steps := Trim(MacroStepsEdit.Value)

    if name = "" {
        MsgBox("Macro name is required.", "Macro Editor", 48)
        return
    }

    updated := false

    for idx, macro in MacroLibrary {
        if StrLower(macro.Name) = StrLower(name) {
            MacroLibrary[idx].Steps := steps
            MacroLibrary[idx].Name := name
            updated := true
            break
        }
    }

    if !updated {
        MacroLibrary.Push({ Name: name, Steps: steps })
    }

    SaveConfig()
    RefreshMacroListBox()
    
    ; Use tooltip instead of MsgBox to ensure it appears on top of macro editor
    ToolTip("✓ Macro saved")
    SetTimer(() => ToolTip(), -1200)
}

DeleteSelectedMacro() {
    global MacroLibrary, MacroListBox, MacroNameEdit, MacroStepsEdit

    selected := MacroListBox.Text

    if selected = "" {
        return
    }

    for idx, macro in MacroLibrary {
        if StrLower(macro.Name) = StrLower(selected) {
            MacroLibrary.RemoveAt(idx)
            break
        }
    }

    SaveConfig()
    RefreshMacroListBox()
    MacroNameEdit.Value := ""
    MacroStepsEdit.Value := ""
}

TestRunMacro() {
    global MacroNameEdit

    name := Trim(MacroNameEdit.Value)

    if name = "" {
        return
    }

    ExecuteMacroByName(name)
}

InsertMacroTemplate(templateLine) {
    global MacroStepsEdit

    line := Trim(templateLine)

    if MacroStepsEdit.Value = "" {
        MacroStepsEdit.Value := line
    } else {
        MacroStepsEdit.Value .= "`n" line
    }
}

OpenAutoSwitchAppPicker() {
    global AppPickerGui, AppPickerListView, AutoSwitchAppsEdit

    if !IsObject(AutoSwitchAppsEdit) {
        return
    }

    if IsObject(AppPickerGui) {
        try AppPickerGui.Destroy()
    }

    AppPickerGui := Gui("+AlwaysOnTop +Resize", "Pick Open Apps For Auto-Switch")
    AppPickerGui.SetFont("s10", "Segoe UI")
    AppPickerGui.MarginX := 12
    AppPickerGui.MarginY := 12

    AppPickerGui.AddText("xm ym w520", "Select running app processes to auto-switch this layer:")
    AppPickerListView := AppPickerGui.AddListView("xm y+6 w560 h300 Checked", ["Process", "Window title"])

    FillOpenAppsListView(AutoSwitchAppsEdit.Value)

    AppPickerGui.AddButton("xm y+10 w90", "Refresh").OnEvent("Click", (*) => FillOpenAppsListView(AutoSwitchAppsEdit.Value))
    AppPickerGui.AddButton("x+8 yp w90", "Apply").OnEvent("Click", (*) => ApplyPickedAutoSwitchApps())
    AppPickerGui.AddButton("x+8 yp w90", "Cancel").OnEvent("Click", (*) => AppPickerGui.Destroy())

    AppPickerGui.OnEvent("Close", (*) => AppPickerGui.Destroy())
    AppPickerGui.Show("w590 h390")
}

FillOpenAppsListView(existingList := "") {
    global AppPickerListView

    if !IsObject(AppPickerListView) {
        return
    }

    selectedSet := ParseProcessSelectionSet(existingList)
    appMap := GetOpenAppProcessMap()

    AppPickerListView.Delete()

    for processName, title in appMap {
        row := AppPickerListView.Add("", processName, title)

        normalized := StrLower(Trim(processName))
        normalizedBase := RegExReplace(normalized, "\.exe$")

        if selectedSet.Has(normalized) || selectedSet.Has(normalizedBase) {
            AppPickerListView.Modify(row, "Check")
        }
    }

    AppPickerListView.ModifyCol(1, 180)
    AppPickerListView.ModifyCol(2, 350)
}

ParseProcessSelectionSet(appList) {
    set := Map()

    normalizedList := StrReplace(appList, "`r", "")
    normalizedList := StrReplace(normalizedList, ";", ",")
    normalizedList := StrReplace(normalizedList, "`n", ",")

    for _, item in StrSplit(normalizedList, ",") {
        name := StrLower(Trim(item))

        if name = "" {
            continue
        }

        set[name] := true
        set[RegExReplace(name, "\.exe$")] := true
    }

    return set
}

GetOpenAppProcessMap() {
    processMap := Map()

    for hwnd in WinGetList() {
        title := ""
        processName := ""

        try title := Trim(WinGetTitle("ahk_id " hwnd))
        try processName := Trim(WinGetProcessName("ahk_id " hwnd))

        if processName = "" {
            continue
        }

        if StrLower(processName) = StrLower(A_ScriptName) {
            continue
        }

        if title = "" {
            title := "(no window title)"
        }

        if !processMap.Has(processName) {
            processMap[processName] := title
        }
    }

    return processMap
}

ApplyPickedAutoSwitchApps() {
    global AppPickerGui, AppPickerListView, AutoSwitchAppsEdit

    if !IsObject(AppPickerListView) || !IsObject(AutoSwitchAppsEdit) {
        return
    }

    selected := []
    row := 0

    Loop {
        row := AppPickerListView.GetNext(row, "C")

        if row = 0 {
            break
        }

        processName := Trim(AppPickerListView.GetText(row, 1))

        if processName != "" {
            selected.Push(processName)
        }
    }

    AutoSwitchAppsEdit.Value := JoinWithComma(selected)

    if IsObject(AppPickerGui) {
        AppPickerGui.Destroy()
    }
}

JoinWithComma(values) {
    output := ""

    for idx, value in values {
        output .= (idx = 1 ? "" : ", ") value
    }

    return output
}

; ----------------------------------------------------------
; Config handling using INI
; ----------------------------------------------------------

LoadConfig() {
    global ConfigFile, Layers, AutoLayerEnabled, AutoLayerCheckMs, MacroLibrary

    Layers := []
    MacroLibrary := []

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

    AutoLayerEnabled := IniRead(ConfigFile, "General", "AutoLayerEnabled", "1") != "0"
    AutoLayerCheckMs := Integer(IniRead(ConfigFile, "General", "AutoLayerCheckMs", "450"))

    if AutoLayerCheckMs < 100 {
        AutoLayerCheckMs := 100
    }

    Loop count {
        section := "Layer" A_Index
        name := IniRead(ConfigFile, section, "Name", "Layer " A_Index)
        thumbnail := IniRead(ConfigFile, section, "Thumbnail", "")
        enabled := IniRead(ConfigFile, section, "Enabled", "1")
        tiltLeftAction := IniRead(ConfigFile, section, "TiltLeftAction", "tap:^z")
        tiltRightAction := IniRead(ConfigFile, section, "TiltRightAction", "tap:^y")
        wheelUpAction := IniRead(ConfigFile, section, "WheelUpAction", "none:")
        wheelDownAction := IniRead(ConfigFile, section, "WheelDownAction", "none:")
        autoSwitchApps := IniRead(ConfigFile, section, "AutoSwitchApps", "")

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
            TiltLeftAction: tiltLeftAction,
            TiltRightAction: tiltRightAction,
            WheelUpAction: wheelUpAction,
            WheelDownAction: wheelDownAction,
            AutoSwitchApps: autoSwitchApps,
            Labels: labels,
            Actions: actions
        })
    }

    LoadMacrosFromConfig()
}

SaveConfig() {
    global ConfigFile, Layers, AutoLayerEnabled, AutoLayerCheckMs, MacroLibrary

    CreateConfigBackup()

    if FileExist(ConfigFile) {
        FileDelete(ConfigFile)
    }

    IniWrite(Layers.Length, ConfigFile, "General", "LayerCount")
    IniWrite(AutoLayerEnabled ? "1" : "0", ConfigFile, "General", "AutoLayerEnabled")
    IniWrite(AutoLayerCheckMs, ConfigFile, "General", "AutoLayerCheckMs")

    for layerIndex, layer in Layers {
        section := "Layer" layerIndex

        IniWrite(layer.Name, ConfigFile, section, "Name")
        IniWrite(GetSafeThumbnail(layer), ConfigFile, section, "Thumbnail")
        IniWrite(layer.Enabled ? "1" : "0", ConfigFile, section, "Enabled")
        IniWrite(layer.TiltLeftAction, ConfigFile, section, "TiltLeftAction")
        IniWrite(layer.TiltRightAction, ConfigFile, section, "TiltRightAction")
        IniWrite(layer.WheelUpAction, ConfigFile, section, "WheelUpAction")
        IniWrite(layer.WheelDownAction, ConfigFile, section, "WheelDownAction")
        IniWrite(layer.AutoSwitchApps, ConfigFile, section, "AutoSwitchApps")

        Loop 12 {
            labelKey := "Button" A_Index "Label"
            actionKey := "Button" A_Index "Action"

            IniWrite(layer.Labels[A_Index], ConfigFile, section, labelKey)
            IniWrite(layer.Actions[A_Index], ConfigFile, section, actionKey)
        }
    }

    IniWrite(MacroLibrary.Length, ConfigFile, "Macros", "Count")

    for macroIndex, macro in MacroLibrary {
        section := "Macro" macroIndex
        normalizedSteps := StrReplace(macro.Steps, "`r", "")
        normalizedSteps := StrReplace(normalizedSteps, "`n", "||")

        IniWrite(macro.Name, ConfigFile, section, "Name")
        IniWrite(normalizedSteps, ConfigFile, section, "Steps")
    }
}

LoadMacrosFromConfig() {
    global ConfigFile, MacroLibrary

    macroCount := Integer(IniRead(ConfigFile, "Macros", "Count", "0"))

    if macroCount < 1 {
        return
    }

    Loop macroCount {
        section := "Macro" A_Index
        name := Trim(IniRead(ConfigFile, section, "Name", ""))
        steps := IniRead(ConfigFile, section, "Steps", "")

        if name = "" {
            continue
        }

        steps := StrReplace(steps, "||", "`n")
        MacroLibrary.Push({ Name: name, Steps: steps })
    }
}

CreateConfigBackup() {
    global ConfigFile

    if !FileExist(ConfigFile) {
        return
    }

    backupDir := A_ScriptDir "\ConfigBackups"

    if !DirExist(backupDir) {
        DirCreate(backupDir)
    }

    timestamp := FormatTime(, "yyyyMMdd-HHmmss")
    backupPath := backupDir "\Aerox9Layers_" timestamp ".ini"

    try {
        FileCopy(ConfigFile, backupPath, true)
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
            TiltLeftAction: "tap:^z",
            TiltRightAction: "tap:^y",
            WheelUpAction: "none:",
            WheelDownAction: "none:",
            AutoSwitchApps: "",
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
            TiltLeftAction: "tap:^z",
            TiltRightAction: "tap:^y",
            WheelUpAction: "none:",
            WheelDownAction: "none:",
            AutoSwitchApps: "",
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
            TiltLeftAction: "tap:^z",
            TiltRightAction: "tap:^y",
            WheelUpAction: "none:",
            WheelDownAction: "none:",
            AutoSwitchApps: "",
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
        TiltLeftAction: "tap:^z",
        TiltRightAction: "tap:^y",
        WheelUpAction: "none:",
        WheelDownAction: "none:",
        AutoSwitchApps: "",
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

CloseMacroGui() {
    global MacroGui, MacroRecording, MacroRecordLastTick, ButtonActionEditGui, MacroActionEditorWasHidden
    global ButtonActionMacroDDL

    MacroRecording := false
    MacroRecordLastTick := 0

    if IsObject(MacroGui) {
        try MacroGui.Destroy()
    }

    MacroGui := ""

    if MacroActionEditorWasHidden && IsObject(ButtonActionEditGui) {
        try ButtonActionEditGui.Show()
        
        ; Refresh macro dropdown list in case new macros were added
        if IsObject(ButtonActionMacroDDL) {
            macroNames := ["(none)"]
            for _, macroName in GetMacroNameList() {
                macroNames.Push(macroName)
            }
            ButtonActionMacroDDL.Delete()
            for _, name in macroNames {
                ButtonActionMacroDDL.Add([name])
            }
        }
        
        try WinActivate("ahk_id " ButtonActionEditGui.Hwnd)
    }

    MacroActionEditorWasHidden := false
}

StartMacroRecording() {
    global MacroRecording, MacroRecordLastTick, MacroGui

    if !IsObject(MacroGui) {
        return
    }

    MacroRecording := true
    MacroRecordLastTick := 0
    ToolTip("Macro recording started")
    SetTimer(() => ToolTip(), -900)
}

StopMacroRecording() {
    global MacroRecording, MacroRecordLastTick

    MacroRecording := false
    MacroRecordLastTick := 0
    ToolTip("Macro recording stopped")
    SetTimer(() => ToolTip(), -900)
}

AppendMacroStep(stepText) {
    global MacroStepsEdit

    if !IsObject(MacroStepsEdit) {
        return
    }

    step := Trim(stepText)

    if step = "" {
        return
    }

    if MacroStepsEdit.Value = "" {
        MacroStepsEdit.Value := step
    } else {
        MacroStepsEdit.Value .= "`n" step
    }
}