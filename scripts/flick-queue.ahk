; Flick Macro (Queue). Untested. A press during a hop is queued.
; Timing numbers are the original defaults. maxThreads is 2 so a press can enter while a hop runs.

global fqBusy := false
global fqQueued := 0
global fqLastPress := 0
global fqAbort := false

FlickQueueMeta := {
    id: "flick-queue",
    name: "Flick Macro (Queue)",
    game: "Roblox",
    version: "0.1.0",
    channel: "Beta",
    description: "Untested. A press during a hop is queued and fires right after it.",
    targetExe: "RobloxPlayerBeta.exe",
    defaultKey: "c",
    maxThreads: 2
}

FlickQueueParams := [
    {name: "DelayBeforeFlick", default: 190, min: 0, max: 500},
    {name: "FlickDistance", default: 800, min: 50, max: 3000},
    {name: "Steps", default: 6, min: 1, max: 30},
    {name: "StepDelay", default: 6, min: 1, max: 50},
    {name: "PauseAtEdge", default: 10, min: 0, max: 200},
    {name: "JumpHold", default: 40, min: 0, max: 200},
    {name: "BoostHold", default: 40, min: 0, max: 200},
    {name: "GapBetweenHops", default: 60, min: 0, max: 500},
    {name: "MaxQueue", default: 1, min: 0, max: 5},
    {name: "MinGap", default: 80, min: 0, max: 500}
]

RunFlickQueue(params, triggerKey) {
    global fqBusy, fqQueued, fqLastPress, fqAbort

    MinGap := params["MinGap"]
    MaxQueue := params["MaxQueue"]
    GapBetweenHops := params["GapBetweenHops"]

    if (A_TickCount - fqLastPress < MinGap)
        return
    fqLastPress := A_TickCount

    if fqBusy {
        if (fqQueued < MaxQueue && !fqAbort)
            fqQueued += 1
        return
    }

    fqAbort := false
    fqBusy := true
    FlickQueueHop(params)
    while (fqQueued > 0 && !fqAbort) {
        fqQueued -= 1
        Sleep GapBetweenHops
        if fqAbort
            break
        FlickQueueHop(params)
    }
    fqBusy := false
    if fqAbort {
        fqQueued := 0
        Send "{Space up}"
    }
}

FlickQueueHop(params) {
    global fqAbort

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
    if fqAbort {
        Send "{Space up}"
        return
    }
    Send "{Space up}"

    Sleep DelayBeforeFlick
    if fqAbort
        return

    Send "{Space down}"

    Loop Steps
    {
        if fqAbort {
            Send "{Space up}"
            return
        }
        DllCall("mouse_event", "UInt", 0x0001, "Int", -stepSize, "Int", 0, "UInt", 0, "UPtr", 0)
        Sleep StepDelay
    }

    if fqAbort {
        Send "{Space up}"
        return
    }

    Sleep Max(PauseAtEdge, BoostHold - Steps * StepDelay)
    Send "{Space up}"

    if fqAbort
        return

    Loop Steps
    {
        if fqAbort
            return
        DllCall("mouse_event", "UInt", 0x0001, "Int", stepSize, "Int", 0, "UInt", 0, "UPtr", 0)
        Sleep StepDelay
    }
}

CancelFlickQueue(*) {
    global fqAbort, fqQueued
    fqAbort := true
    fqQueued := 0
    Send "{Space up}"
}

ScriptRegister(FlickQueueMeta, FlickQueueParams, RunFlickQueue, CancelFlickQueue)
