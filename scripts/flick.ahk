; Flick Macro (Stable). Timing numbers are the original defaults.
; The shell owns the hotkey, the stop key, and the timer.

global flickAbort := false

FlickMeta := {
    id: "flick",
    name: "Flick Macro",
    game: "Roblox",
    version: "1.0.0",
    channel: "Stable",
    description: "Original proven version. Single press per hop; presses during a hop are ignored.",
    targetExe: "RobloxPlayerBeta.exe",
    defaultKey: "c",
    maxThreads: 1
}

FlickParams := [
    {name: "DelayBeforeFlick", default: 190, min: 0, max: 500},
    {name: "FlickDistance", default: 800, min: 50, max: 3000},
    {name: "Steps", default: 6, min: 1, max: 30},
    {name: "StepDelay", default: 6, min: 1, max: 50},
    {name: "PauseAtEdge", default: 10, min: 0, max: 200},
    {name: "JumpHold", default: 40, min: 0, max: 200},
    {name: "BoostHold", default: 40, min: 0, max: 200}
]

RunFlick(params, triggerKey) {
    global flickAbort
    flickAbort := false

    DelayBeforeFlick := params["DelayBeforeFlick"]
    FlickDistance := params["FlickDistance"]
    Steps := params["Steps"]
    StepDelay := params["StepDelay"]
    PauseAtEdge := params["PauseAtEdge"]
    JumpHold := params["JumpHold"]
    BoostHold := params["BoostHold"]
    if (Steps < 1)
        Steps := 6

    stepSize := Round(FlickDistance / Steps)

    Send "{Space down}"
    Sleep JumpHold
    if flickAbort {
        Send "{Space up}"
        return
    }
    Send "{Space up}"

    Sleep DelayBeforeFlick
    if flickAbort
        return

    Send "{Space down}"

    Loop Steps
    {
        if flickAbort {
            Send "{Space up}"
            return
        }
        DllCall("mouse_event", "UInt", 0x0001, "Int", -stepSize, "Int", 0, "UInt", 0, "UPtr", 0)
        Sleep StepDelay
    }

    if flickAbort {
        Send "{Space up}"
        return
    }

    Sleep Max(PauseAtEdge, BoostHold - Steps * StepDelay)
    Send "{Space up}"

    if flickAbort
        return

    Loop Steps
    {
        if flickAbort
            return
        DllCall("mouse_event", "UInt", 0x0001, "Int", stepSize, "Int", 0, "UInt", 0, "UPtr", 0)
        Sleep StepDelay
    }

    while GetKeyState(triggerKey, "P") {
        if flickAbort
            return
        Sleep 10
    }
}

CancelFlick(*) {
    global flickAbort
    flickAbort := true
    Send "{Space up}"
}

ScriptRegister(FlickMeta, FlickParams, RunFlick, CancelFlick)
