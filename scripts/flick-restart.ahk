; Flick Macro (Restart). Tested: chains did not work.
; Every press cancels the current hop and starts it again. maxThreads is 2.
; Timing numbers and the run-id checkpoints match the original.

global frRunId := 0
global frLastStart := 0

FlickRestartMeta := {
    id: "flick-restart",
    name: "Flick Macro (Restart)",
    game: "Roblox",
    version: "0.1.0",
    channel: "WIP",
    description: "Tested, chains did not work. Every press cancels the current hop and restarts it.",
    targetExe: "RobloxPlayerBeta.exe",
    defaultKey: "c",
    maxThreads: 2
}

FlickRestartParams := [
    {name: "DelayBeforeFlick", default: 190, min: 0, max: 500},
    {name: "FlickDistance", default: 800, min: 50, max: 3000},
    {name: "Steps", default: 6, min: 1, max: 30},
    {name: "StepDelay", default: 6, min: 1, max: 50},
    {name: "PauseAtEdge", default: 10, min: 0, max: 200},
    {name: "JumpHold", default: 40, min: 0, max: 200},
    {name: "BoostHold", default: 40, min: 0, max: 200},
    {name: "MinGap", default: 120, min: 0, max: 500}
]

RunFlickRestart(params, triggerKey) {
    global frRunId, frLastStart

    DelayBeforeFlick := params["DelayBeforeFlick"]
    FlickDistance := params["FlickDistance"]
    Steps := params["Steps"]
    StepDelay := params["StepDelay"]
    PauseAtEdge := params["PauseAtEdge"]
    JumpHold := params["JumpHold"]
    BoostHold := params["BoostHold"]
    MinGap := params["MinGap"]
    if (Steps < 1)
        Steps := 6

    if GetKeyState(triggerKey, "P") && (A_PriorKey = triggerKey) && (A_TimeSincePriorHotkey < MinGap)
        return

    now := A_TickCount
    if (now - frLastStart < MinGap)
        return
    frLastStart := now

    Send "{Space up}"

    frRunId += 1
    myId := frRunId
    stepSize := Round(FlickDistance / Steps)

    Send "{Space down}"
    Sleep JumpHold
    if (myId != frRunId)
        return
    Send "{Space up}"

    Sleep DelayBeforeFlick
    if (myId != frRunId)
        return

    Send "{Space down}"

    Loop Steps
    {
        if (myId != frRunId) {
            Send "{Space up}"
            return
        }
        DllCall("mouse_event", "UInt", 0x0001, "Int", -stepSize, "Int", 0, "UInt", 0, "UPtr", 0)
        Sleep StepDelay
    }

    Sleep Max(PauseAtEdge, BoostHold - Steps * StepDelay)
    Send "{Space up}"

    Loop Steps
    {
        DllCall("mouse_event", "UInt", 0x0001, "Int", stepSize, "Int", 0, "UInt", 0, "UPtr", 0)
        Sleep StepDelay
    }
}

CancelFlickRestart(*) {
    global frRunId
    frRunId += 1
    Send "{Space up}"
}

ScriptRegister(FlickRestartMeta, FlickRestartParams, RunFlickRestart, CancelFlickRestart)
