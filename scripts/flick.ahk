; Flick Macro (Stable), original v2. Hold the trigger to keep hopping.
; Timing numbers match the held-key version. The shell owns the hotkey, stop, and timer.

global flickAbort := false

FlickMeta := {
    id: "flick",
    name: "Flick Macro",
    game: "Roblox",
    version: "2.0.0",
    channel: "Stable",
    description: "Original v2. Hold the key to keep hopping. Release to stop.",
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
    {name: "BoostHold", default: 40, min: 0, max: 200},
    {name: "LoopGap", default: 0, min: 0, max: 500}
]

RunFlick(params, triggerKey) {
    global flickAbort
    flickAbort := false
    LoopGap := params["LoopGap"]

    while GetKeyState(triggerKey, "P") {
        if flickAbort
            break
        if !FlickHop(params)
            break
        if (LoopGap > 0)
            Sleep LoopGap
    }
    Send "{Space up}"
}

FlickHop(params) {
    global flickAbort

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
        return false
    }
    Send "{Space up}"

    Sleep DelayBeforeFlick
    if flickAbort
        return false

    Send "{Space down}"

    Loop Steps
    {
        if flickAbort {
            Send "{Space up}"
            return false
        }
        DllCall("mouse_event", "UInt", 0x0001, "Int", -stepSize, "Int", 0, "UInt", 0, "UPtr", 0)
        Sleep StepDelay
    }

    if flickAbort {
        Send "{Space up}"
        return false
    }

    Sleep Max(PauseAtEdge, BoostHold - Steps * StepDelay)
    Send "{Space up}"

    if flickAbort
        return false

    Loop Steps
    {
        if flickAbort
            return false
        DllCall("mouse_event", "UInt", 0x0001, "Int", stepSize, "Int", 0, "UInt", 0, "UPtr", 0)
        Sleep StepDelay
    }
    return true
}

CancelFlick(*) {
    global flickAbort
    flickAbort := true
    Send "{Space up}"
}

ScriptRegister(FlickMeta, FlickParams, RunFlick, CancelFlick)
