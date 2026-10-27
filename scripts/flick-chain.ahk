; Flick Macro (Chain). Tested: little improvement. Presses during a hop are still dropped.
; Timing numbers are the original defaults.

global fcLastPress := 0
global fcChainCount := 0
global fcAbort := false

FlickChainMeta := {
    id: "flick-chain",
    name: "Flick Macro (Chain)",
    game: "Roblox",
    version: "0.1.0",
    channel: "WIP",
    description: "Tested, little improvement. Shifts the delay earlier on rapid presses, but presses are still dropped.",
    targetExe: "RobloxPlayerBeta.exe",
    defaultKey: "c",
    maxThreads: 1
}

FlickChainParams := [
    {name: "DelayBeforeFlick", default: 190, min: 0, max: 500},
    {name: "FlickDistance", default: 800, min: 50, max: 3000},
    {name: "Steps", default: 6, min: 1, max: 30},
    {name: "StepDelay", default: 6, min: 1, max: 50},
    {name: "PauseAtEdge", default: 10, min: 0, max: 200},
    {name: "JumpHold", default: 40, min: 0, max: 200},
    {name: "BoostHold", default: 40, min: 0, max: 200},
    {name: "ChainWindow", default: 700, min: 0, max: 2000},
    {name: "ChainDelayShift", default: -10, min: -200, max: 0},
    {name: "ChainMinDelay", default: 150, min: 0, max: 500},
    {name: "ChainMaxShift", default: -40, min: -200, max: 0},
    {name: "ChainStepShift", default: -5, min: -50, max: 0}
]

FlickChainDelay(base, count, delayShift, stepShift, maxShift, minDelay) {
    delay := base
    if (count > 1) {
        shift := delayShift + (count - 2) * stepShift
        if (shift < maxShift)
            shift := maxShift
        delay := base + shift
        if (delay < minDelay)
            delay := minDelay
    }
    return delay
}

RunFlickChain(params, triggerKey) {
    global fcLastPress, fcChainCount, fcAbort
    fcAbort := false

    DelayBeforeFlick := params["DelayBeforeFlick"]
    FlickDistance := params["FlickDistance"]
    Steps := params["Steps"]
    StepDelay := params["StepDelay"]
    PauseAtEdge := params["PauseAtEdge"]
    JumpHold := params["JumpHold"]
    BoostHold := params["BoostHold"]
    ChainWindow := params["ChainWindow"]
    ChainDelayShift := params["ChainDelayShift"]
    ChainMinDelay := params["ChainMinDelay"]
    ChainMaxShift := params["ChainMaxShift"]
    ChainStepShift := params["ChainStepShift"]
    if (Steps < 1)
        Steps := 6

    now := A_TickCount
    if (fcLastPress != 0 && now - fcLastPress <= ChainWindow)
        fcChainCount += 1
    else
        fcChainCount := 1
    fcLastPress := now

    delay := FlickChainDelay(DelayBeforeFlick, fcChainCount, ChainDelayShift, ChainStepShift, ChainMaxShift, ChainMinDelay)

    stepSize := Round(FlickDistance / Steps)

    Send "{Space down}"
    Sleep JumpHold
    if fcAbort {
        Send "{Space up}"
        return
    }
    Send "{Space up}"

    Sleep delay
    if fcAbort
        return

    Send "{Space down}"

    Loop Steps
    {
        if fcAbort {
            Send "{Space up}"
            return
        }
        DllCall("mouse_event", "UInt", 0x0001, "Int", -stepSize, "Int", 0, "UInt", 0, "UPtr", 0)
        Sleep StepDelay
    }

    if fcAbort {
        Send "{Space up}"
        return
    }

    Sleep Max(PauseAtEdge, BoostHold - Steps * StepDelay)
    Send "{Space up}"

    if fcAbort
        return

    Loop Steps
    {
        if fcAbort
            return
        DllCall("mouse_event", "UInt", 0x0001, "Int", stepSize, "Int", 0, "UInt", 0, "UPtr", 0)
        Sleep StepDelay
    }

    if !fcAbort
        fcLastPress := A_TickCount

    while GetKeyState(triggerKey, "P") {
        if fcAbort
            return
        Sleep 10
    }
}

CancelFlickChain(*) {
    global fcAbort, fcLastPress, fcChainCount
    fcAbort := true
    fcLastPress := 0
    fcChainCount := 0
    Send "{Space up}"
}

ScriptRegister(FlickChainMeta, FlickChainParams, RunFlickChain, CancelFlickChain)
