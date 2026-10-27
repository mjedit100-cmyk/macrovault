; Flick Jump Combo. You jump yourself. Press the key for flick + boost Space only.
; No initiating jump. Timing for the flick body matches the original hop.

global fcomboAbort := false

FlickComboMeta := {
    id: "flick-combo",
    name: "Flick Jump Combo",
    game: "Roblox",
    version: "1.0.0",
    channel: "Stable",
    description: "You jump yourself. Press the key for the flick + boost Space only. No auto jump before the flick.",
    targetExe: "RobloxPlayerBeta.exe",
    defaultKey: "c",
    maxThreads: 1
}

FlickComboParams := [
    {name: "DelayBeforeFlick", default: 0, min: 0, max: 500},
    {name: "FlickDistance", default: 800, min: 50, max: 3000},
    {name: "Steps", default: 6, min: 1, max: 30},
    {name: "StepDelay", default: 6, min: 1, max: 50},
    {name: "PauseAtEdge", default: 10, min: 0, max: 200},
    {name: "BoostHold", default: 40, min: 0, max: 200}
]

RunFlickCombo(params, triggerKey) {
    global fcomboAbort
    fcomboAbort := false

    DelayBeforeFlick := params["DelayBeforeFlick"]
    FlickDistance := params["FlickDistance"]
    Steps := params["Steps"]
    StepDelay := params["StepDelay"]
    PauseAtEdge := params["PauseAtEdge"]
    BoostHold := params["BoostHold"]
    if (Steps < 1)
        Steps := 6

    stepSize := Round(FlickDistance / Steps)

    if (DelayBeforeFlick > 0) {
        Sleep DelayBeforeFlick
        if fcomboAbort
            return
    }

    ; boost Space while flicking — you already jumped
    Send "{Space down}"

    Loop Steps
    {
        if fcomboAbort {
            Send "{Space up}"
            return
        }
        DllCall("mouse_event", "UInt", 0x0001, "Int", -stepSize, "Int", 0, "UInt", 0, "UPtr", 0)
        Sleep StepDelay
    }

    if fcomboAbort {
        Send "{Space up}"
        return
    }

    Sleep Max(PauseAtEdge, BoostHold - Steps * StepDelay)
    Send "{Space up}"

    if fcomboAbort
        return

    Loop Steps
    {
        if fcomboAbort
            return
        DllCall("mouse_event", "UInt", 0x0001, "Int", stepSize, "Int", 0, "UInt", 0, "UPtr", 0)
        Sleep StepDelay
    }

    while GetKeyState(triggerKey, "P") {
        if fcomboAbort
            return
        Sleep 10
    }
}

CancelFlickCombo(*) {
    global fcomboAbort
    fcomboAbort := true
    Send "{Space up}"
}

ScriptRegister(FlickComboMeta, FlickComboParams, RunFlickCombo, CancelFlickCombo)
