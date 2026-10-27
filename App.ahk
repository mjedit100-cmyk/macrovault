#Requires AutoHotkey v2.0
#SingleInstance Force
; File properties mirror APP_NAME and APP_VERSION. The running app reads the constants.
;@Ahk2Exe-SetName MacroVault
;@Ahk2Exe-SetDescription MacroVault
;@Ahk2Exe-SetVersion 1.4.2.0
;@Ahk2Exe-SetCompanyName MJ

global APP_NAME := "MacroVault"
global APP_VERSION := "1.4.2"
global REPO_RAW_URL := "https://raw.githubusercontent.com/mjedit100-cmyk/macrovault/main/manifest.json"

global ScriptOrder := []
global ScriptModules := Map()
global Settings := ""
global macroActive := false
global boundTrigger := ""
global boundStop := ""
global timerArmed := false
global appReady := false
global mainWnd := ""
global splashWnd := ""
global splashTitle := ""
global splashBar := ""
global splashBarTrack := ""
global splashHttp := ""
global splashBarX := 48
global splashBarY := 342
global splashBarMax := 544
global libWnd := ""
global settingsWnd := ""
global playCtrl := ""
global statusCtrl := ""
global nameCtrl := ""
global channelCtrl := ""
global buttonMap := Map()
global hoveredHwnd := 0
global catalog := ""
global settingsRows := []
global triggerCtrl := ""
global stopCtrl := ""
global settingsNote := ""
global libList := ""
global libDesc := ""
global libWarn := ""
global libNote := ""
global libIds := []
global libBusy := false
global devlogWnd := ""
global tagCtrl := ""

OnExit(AppOnExit)
Persistent(true)

#Include "scripts\flick.ahk"
#Include "scripts\flick-combo.ahk"
#Include "scripts\flick-queue.ahk"
#Include "scripts\flick-chain.ahk"
#Include "scripts\flick-restart.ahk"

if (A_Args.Length && A_Args[1] = "--self-test")
    RunSelfTest()

OnError(AppError)
Startup()

^+F12:: {
    try {
        if appReady
            CancelCurrent()
    }
    ExitApp()
}

Startup() {
    global timerArmed, appReady
    SendMode "Event"
    DllCall("winmm\timeBeginPeriod", "UInt", 1)
    timerArmed := true
    LoadSettings()
    EnsureAssets()
    SetupTray()
    try ApplyStopHotkey()
    SetTimer(HoverTimer, 40)
    OpenSplash()
    PlayIntro()
    SplashStatus("Checking for updates...")
    found := ReadManifestResult()
    if !IsObject(found) || !found.remote {
        found := FetchManifestNow()
        if IsObject(found)
            catalog := found
    }
    if IsUpdateAvailable(found) {
        SplashStatus("Update found â€” v" found.app.version)
        Sleep 500
        if ApplyAppUpdate(found.app.version, found.app.exeUrl)
            return
        SplashStatus("Update failed â€” opening current build")
        Sleep 1600
    } else if IsObject(found) && found.remote {
        SplashStatus("You're on v" APP_VERSION)
        Sleep 450
    }
    CloseSplash()
    BuildMain()
    ShowAt(mainWnd, 640, 400)
    WinSetTransparent(0, "ahk_id " mainWnd.Hwnd)
    FadeHwnd(mainWnd.Hwnd, 0, 255, 220)
    try WinSetTransparent("Off", "ahk_id " mainWnd.Hwnd)
    appReady := true
}

AssetDir() {
    dir := SettingsDir() "\assets"
    DirCreate(dir)
    return dir
}

AssetFile(name) {
    return AssetDir() "\" name
}

EnsureAssets() {
    dir := AssetDir()
    FileInstall "assets\splash.jpg", dir "\splash.jpg", 1
    FileInstall "assets\main-girl.jpg", dir "\main-girl.jpg", 1
    FileInstall "assets\avatar.jpg", dir "\avatar.jpg", 1
    FileInstall "devlog.md", dir "\devlog.md", 1
}

AppOnExit(*) {
    if appReady {
        try CancelCurrent()
    }
    if timerArmed
        DllCall("winmm\timeEndPeriod", "UInt", 1)
}

AppError(err, mode) {
    try FileAppend(A_Now " " err.Message " @ " err.Line "`n" err.Stack "`n`n", SettingsDir() "\error.log", "UTF-8")
    return true
}

ScriptRegister(meta, params, runFn, cancelFn) {
    ScriptOrder.Push(meta.id)
    ScriptModules[meta.id] := {meta: meta, params: params, run: runFn, cancel: cancelFn}
}

MkGui(extra) {
    wnd := Gui(extra, APP_NAME)
    wnd.BackColor := "14141c"
    wnd.MarginX := 0
    wnd.MarginY := 0
    wnd.SetFont("s10 cE8E6F2", "Segoe UI")
    return wnd
}

AddButton(owner, x, y, w, h, label, bg, hover, fg, onClick) {
    ctrl := owner.AddText("x" x " y" y " w" w " h" h " Center 0x200 +0x100 Background" bg " c" fg, label)
    ctrl.OnEvent("Click", onClick)
    buttonMap[ctrl.Hwnd] := {ctrl: ctrl, owner: owner.Hwnd, bg: bg, hover: hover}
    return ctrl
}

PaintButton(info, hot) {
    color := hot ? info.hover : info.bg
    try info.ctrl.Opt("Background" color)
}

SetButtonColors(ctrl, bg, hover) {
    if !buttonMap.Has(ctrl.Hwnd)
        return
    info := buttonMap[ctrl.Hwnd]
    info.bg := bg
    info.hover := hover
    PaintButton(info, hoveredHwnd = ctrl.Hwnd)
}

HoverTimer() {
    global hoveredHwnd
    if (buttonMap.Count = 0)
        return
    ctrlHwnd := 0
    try MouseGetPos(&mx, &my, &winHwnd, &ctrlHwnd, 2)
    catch
        return
    if (hoveredHwnd && !buttonMap.Has(hoveredHwnd))
        hoveredHwnd := 0
    if (ctrlHwnd = hoveredHwnd)
        return
    if (hoveredHwnd && buttonMap.Has(hoveredHwnd))
        PaintButton(buttonMap[hoveredHwnd], false)
    hoveredHwnd := 0
    if (ctrlHwnd && buttonMap.Has(ctrlHwnd)) {
        hoveredHwnd := ctrlHwnd
        PaintButton(buttonMap[ctrlHwnd], true)
    }
}

DestroyWnd(wnd) {
    global hoveredHwnd
    if !IsObject(wnd)
        return
    owner := wnd.Hwnd
    stale := []
    for hwnd, info in buttonMap {
        if (info.owner = owner)
            stale.Push(hwnd)
    }
    for , hwnd in stale
        buttonMap.Delete(hwnd)
    if (hoveredHwnd && !buttonMap.Has(hoveredHwnd))
        hoveredHwnd := 0
    try wnd.Destroy()
}

FadeHwnd(hwnd, from, to, ms) {
    steps := 12
    delay := Max(1, ms // steps)
    Loop steps {
        v := Round(from + (to - from) * (A_Index / steps))
        if (v < 0)
            v := 0
        if (v > 255)
            v := 255
        try WinSetTransparent(v, "ahk_id " hwnd)
        Sleep delay
    }
    try WinSetTransparent(to, "ahk_id " hwnd)
}

EaseOut(t) {
    if (t < 0)
        t := 0
    if (t > 1)
        t := 1
    inv := 1 - t
    return 1 - inv * inv * inv
}

CenterOf(w, h) {
    wa := Buffer(16, 0)
    DllCall("SystemParametersInfoW", "UInt", 48, "UInt", 0, "Ptr", wa, "UInt", 0)
    left := NumGet(wa, 0, "Int")
    top := NumGet(wa, 4, "Int")
    right := NumGet(wa, 8, "Int")
    bottom := NumGet(wa, 12, "Int")
    x := left + (right - left - w) // 2
    y := top + (bottom - top - h) // 2
    if (x < left)
        x := left
    if (y < top)
        y := top
    return [x, y]
}

ShowAt(wnd, w, h) {
    spot := CenterOf(w, h)
    wnd.Show("x" spot[1] " y" spot[2] " w" w " h" h)
}

ShowHiddenAt(wnd, w, h) {
    spot := CenterOf(w, h)
    DetectHiddenWindows(true)
    wnd.Show("x" spot[1] " y" spot[2] " w" w " h" h " Hide")
    WinSetTransparent(0, "ahk_id " wnd.Hwnd)
    wnd.Show()
    WinSetTransparent(0, "ahk_id " wnd.Hwnd)
    DetectHiddenWindows(false)
}

ApplyWindowIcon(wnd) {
    ico := A_ScriptDir "\" APP_NAME ".ico"
    if !FileExist(ico)
        return
    try {
        big := LoadPicture(ico, "w32 Icon1", &kind)
        small := LoadPicture(ico, "w16 Icon1", &kindSmall)
        if big
            SendMessage(0x80, 1, big, unset, "ahk_id " wnd.Hwnd)
        if small
            SendMessage(0x80, 0, small, unset, "ahk_id " wnd.Hwnd)
    }
}

OpenSplash() {
    global splashWnd, splashTitle, splashBar, splashBarTrack, splashBarX, splashBarY, splashBarMax
    splashWnd := MkGui("+AlwaysOnTop -Caption +ToolWindow -Resize")
    art := AssetFile("splash.jpg")
    if FileExist(art)
        splashWnd.AddPic("x0 y0 w640 h360", art)
    ; Thin footer so her face stays visible above it
    splashWnd.AddText("x0 y292 w640 h68 Background0B0B12", "")
    splashWnd.AddText("x0 y292 w640 h2 Background7c5cff", "")
    splashWnd.SetFont("s26 w700 cF4F2FF", "Segoe UI")
    splashTitle := splashWnd.AddText("x28 y302 w584 h32 Center Background0B0B12", APP_NAME)
    splashBarX := 48
    splashBarY := 342
    splashBarMax := 544
    splashBarTrack := splashWnd.AddText("x" splashBarX " y" splashBarY " w" splashBarMax " h4 Background242433", "")
    splashBar := splashWnd.AddText("x" splashBarX " y" splashBarY " w1 h4 Background7c5cff", "")
    ShowHiddenAt(splashWnd, 640, 360)
}

SplashStatus(text) {
    global splashTitle, splashWnd
    if !IsObject(splashTitle)
        return
    try WinSetTransparent(255, "ahk_id " splashWnd.Hwnd)
    splashTitle.SetFont("s16 w600 cF4F2FF", "Segoe UI")
    splashTitle.Text := text
    splashTitle.Move(28, 304, 584, 32)
    Sleep 30
}

SweepProgress(pct := "") {
    global splashBar, splashBarX, splashBarY, splashBarMax
    if !IsObject(splashBar)
        return
    static sweep := 1
    static dir := 1
    if (pct != "" && IsNumber(pct)) {
        w := Max(1, Round(splashBarMax * Max(0, Min(100, Number(pct))) / 100))
        splashBar.Move(splashBarX, splashBarY, w, 4)
        return
    }
    sweep += dir * 28
    if (sweep >= splashBarMax) {
        sweep := splashBarMax
        dir := -1
    } else if (sweep <= 1) {
        sweep := 1
        dir := 1
    }
    splashBar.Move(splashBarX, splashBarY, sweep, 4)
}

PlayIntro() {
    BeginManifestRequest()
    start := A_TickCount
    duration := 2000
    while (A_TickCount - start < duration) {
        t := EaseOut((A_TickCount - start) / duration)
        try WinSetTransparent(Round(255 * t), "ahk_id " splashWnd.Hwnd)
        splashTitle.Move(28, Round(308 - 6 * t), 584, 32)
        splashBar.Move(48, 342, Max(1, Round(544 * t)), 4)
        Sleep 15
    }
    try WinSetTransparent(255, "ahk_id " splashWnd.Hwnd)
    splashTitle.SetFont("s18 w600 cF4F2FF", "Segoe UI")
    splashTitle.Text := "Welcome to " APP_NAME
    splashTitle.Move(28, 304, 584, 32)
    hold := A_TickCount + 1000
    while (A_TickCount < hold)
        Sleep 15
}

CloseSplash() {
    global splashWnd, splashTitle, splashBar, splashBarTrack
    if !IsObject(splashWnd)
        return
    FadeHwnd(splashWnd.Hwnd, 255, 0, 200)
    DestroyWnd(splashWnd)
    splashWnd := ""
    splashTitle := ""
    splashBar := ""
    splashBarTrack := ""
}

BuildMain() {
    global mainWnd, nameCtrl, channelCtrl, playCtrl, statusCtrl, tagCtrl
    mainWnd := MkGui("-Resize -MaximizeBox")
    ; Accent rail + soft stage panels
    mainWnd.AddText("x0 y0 w8 h400 Background7c5cff", "")
    mainWnd.AddText("x8 y0 w632 h72 Background101018", "")
    mainWnd.AddText("x8 y72 w392 h252 Background181824", "")
    mainWnd.AddText("x400 y72 w240 h252 Background101018", "")
    mainWnd.AddText("x8 y324 w632 h76 Background101018", "")

    avatar := AssetFile("avatar.jpg")
    if FileExist(avatar)
        mainWnd.AddPic("x24 y14 w44 h44", avatar)

    mainWnd.SetFont("s22 w700 cF4F2FF", "Segoe UI")
    mainWnd.AddText("x80 y12 w300 h34 Background101018", APP_NAME)
    mainWnd.SetFont("s9 cA79BFF", "Segoe UI")
    mainWnd.AddText("x80 y44 w300 h18 Background101018", "macros Â· cute chaos Â· v" APP_VERSION)

    ; Character cutout stage (3:4 slot so nothing stretches weird)
    art := AssetFile("main-girl.jpg")
    if FileExist(art)
        mainWnd.AddPic("x418 y80 w206 h274", art)

    mainWnd.SetFont("s9 c8E8A9E", "Segoe UI")
    mainWnd.AddText("x28 y88 w340 h16 Background181824", "NOW LOADED")
    mainWnd.SetFont("s17 w700 cF4F2FF", "Segoe UI")
    nameCtrl := mainWnd.AddText("x28 y108 w340 h30 Background181824", "")
    mainWnd.SetFont("s9 w700 c14141c", "Segoe UI")
    channelCtrl := mainWnd.AddText("x28 y144 w96 h22 Center 0x200 Background3DD68C", "")
    mainWnd.SetFont("s9 c9A97AD", "Segoe UI")
    tagCtrl := mainWnd.AddText("x136 y146 w240 h18 Background181824", "")

    mainWnd.SetFont("s17 w700 cFFFFFF", "Segoe UI")
    playCtrl := AddButton(mainWnd, 28, 184, 340, 54, "PLAY", "7c5cff", "9480ff", "FFFFFF", OnPlay)
    mainWnd.SetFont("s10 cF4F2FF", "Segoe UI")
    AddButton(mainWnd, 28, 250, 108, 38, "LIBRARY", "2a2a38", "3a3a4c", "F4F2FF", ShowLibrary)
    AddButton(mainWnd, 144, 250, 108, 38, "SETTINGS", "2a2a38", "3a3a4c", "F4F2FF", ShowSettings)
    AddButton(mainWnd, 260, 250, 108, 38, "DEVLOG", "3a2a55", "52406e", "F4F2FF", ShowDevlog)

    mainWnd.SetFont("s9 c8E8A9E", "Segoe UI")
    mainWnd.AddText("x28 y304 w340 h16 Background181824", "STATUS")
    mainWnd.SetFont("s11 c8E8A9E", "Segoe UI")
    statusCtrl := mainWnd.AddText("x28 y338 w592 h36 0x200 Background1A1A28", "  Idle")

    mainWnd.OnEvent("Close", HideMain)
    ApplyWindowIcon(mainWnd)
    RefreshMain()
    SetStatusIdle()
}

HideMain(thisWnd) {
    FadeHwnd(thisWnd.Hwnd, 255, 0, 160)
}

ShowFromTray(*) {
    if !IsObject(mainWnd)
        return
    DetectHiddenWindows(true)
    visible := DllCall("IsWindowVisible", "Ptr", mainWnd.Hwnd)
    if !visible
        WinSetTransparent(0, "ahk_id " mainWnd.Hwnd)
    DetectHiddenWindows(false)
    if visible {
        try WinActivate("ahk_id " mainWnd.Hwnd)
        return
    }
    mainWnd.Show()
    FadeHwnd(mainWnd.Hwnd, 0, 255, 180)
    try WinSetTransparent("Off", "ahk_id " mainWnd.Hwnd)
}

RefreshMain() {
    if !IsObject(nameCtrl)
        return
    id := Settings.selected
    if !ScriptModules.Has(id)
        id := "flick"
    meta := ScriptModules[id].meta
    nameCtrl.Text := meta.name
    channelCtrl.Text := meta.channel
    channelCtrl.Opt("Background" ChannelBg(meta.channel))
    channelCtrl.SetFont("s9 w700 c" ChannelFg(meta.channel), "Segoe UI")
    if IsObject(tagCtrl)
        tagCtrl.Text := meta.game "  Â·  v" meta.version
    if macroActive
        SetStatusActive()
}

ChannelBg(channel) {
    if (channel = "Stable")
        return "3DD68C"
    if (channel = "Beta")
        return "E6B450"
    return "FF8A3D"
}

ChannelFg(channel) {
    return "14141c"
}

ChannelColor(channel) {
    return ChannelBg(channel)
}

SetStatusIdle() {
    if !IsObject(statusCtrl)
        return
    statusCtrl.Text := "  Idle  Â·  waiting for PLAY"
    statusCtrl.Opt("Background1A1A28")
    statusCtrl.SetFont("s11 c8E8A9E", "Segoe UI")
}

SetStatusActive() {
    if !IsObject(statusCtrl)
        return
    meta := ScriptModules[Settings.selected].meta
    statusCtrl.Text := "  Active  Â·  " meta.name " on " GetScriptKey(Settings.selected)
    statusCtrl.Opt("Background163A28")
    statusCtrl.SetFont("s11 c3DD68C", "Segoe UI")
}

SetPlayButton(active) {
    if !IsObject(playCtrl)
        return
    if active {
        playCtrl.Text := "STOP"
        SetButtonColors(playCtrl, "c43b3b", "e15a5a")
    } else {
        playCtrl.Text := "PLAY"
        SetButtonColors(playCtrl, "7c5cff", "9480ff")
    }
}

OnPlay(*) {
    if macroActive
        StopMacro()
    else
        StartMacro()
}

StartMacro() {
    if !ScriptModules.Has(Settings.selected)
        return
    try RegisterTrigger()
    catch {
        SetPlayButton(false)
        SetStatusIdle()
        return
    }
    SetPlayButton(true)
    SetStatusActive()
}

StopMacro(*) {
    if macroActive
        try CancelCurrent()
    try UnregisterTrigger()
    SetPlayButton(false)
    SetStatusIdle()
}

CancelCurrent() {
    if !IsObject(Settings)
        return
    id := Settings.selected
    if ScriptModules.Has(id)
        ScriptModules[id].cancel.Call()
}

TargetHotIf(*) {
    if !macroActive
        return false
    id := Settings.selected
    if !ScriptModules.Has(id)
        return false
    target := ScriptModules[id].meta.targetExe
    if (target = "" || StrLower(target) = "any")
        return true
    return WinActive("ahk_exe " target)
}

TriggerFire(*) {
    if !macroActive
        return
    id := Settings.selected
    if !ScriptModules.Has(id)
        return
    try ScriptModules[id].run.Call(GetParamMap(id), GetScriptKey(id))
    catch
        try ScriptModules[id].cancel.Call()
}

RegisterTrigger() {
    global boundTrigger, macroActive
    id := Settings.selected
    mod := ScriptModules[id]
    hk := "$" GetScriptKey(id)
    threads := mod.meta.maxThreads
    if !IsInteger(threads) || (threads < 1)
        threads := 1
    opt := "On T" threads
    HotIf(TargetHotIf)
    try {
        Hotkey(hk, TriggerFire, opt)
        if (boundTrigger != "" && boundTrigger != hk)
            try Hotkey(boundTrigger, "Off")
        boundTrigger := hk
        macroActive := true
    } finally {
        HotIf()
    }
}

UnregisterTrigger() {
    global boundTrigger, macroActive
    if (boundTrigger != "") {
        HotIf(TargetHotIf)
        try {
            Hotkey(boundTrigger, "Off")
        } finally {
            HotIf()
        }
        boundTrigger := ""
    }
    macroActive := false
}

ApplyStopHotkey() {
    global boundStop
    hk := "$" Settings.stopKey
    if (hk = boundStop)
        return
    HotIf()
    Hotkey(hk, StopHandler, "On")
    if (boundStop != "" && boundStop != hk)
        try Hotkey(boundStop, "Off")
    boundStop := hk
}

StopHandler(*) {
    StopMacro()
}

GetScriptKey(id) {
    if IsObject(Settings) && Settings.keys.Has(id) && Settings.keys[id] != ""
        return Settings.keys[id]
    return ScriptModules[id].meta.defaultKey
}

GetParamMap(id) {
    mod := ScriptModules[id]
    saved := Settings.params.Has(id) ? Settings.params[id] : Map()
    out := Map()
    for , p in mod.params
        out[p.name] := SanitizeNum(saved.Has(p.name) ? saved[p.name] : p.default, p.default, p.min, p.max)
    return out
}

SanitizeNum(value, fallback, lower, upper) {
    if IsNumber(value) {
        n := Integer(Round(Number(value)))
        if (n >= lower && n <= upper)
            return n
    }
    return Integer(fallback)
}

NormalizeKey(raw) {
    raw := Trim(raw)
    if (raw = "")
        return ""
    if (SubStr(raw, 1, 1) = "$")
        raw := SubStr(raw, 2)
    if (StrLen(raw) = 1)
        return StrLower(raw)
    return raw
}

SettingsDir() {
    root := EnvGet("APPDATA")
    if (root = "")
        root := A_Temp
    dir := root "\" APP_NAME
    DirCreate(dir)
    return dir
}

SettingsPath() {
    return SettingsDir() "\settings.ini"
}

LoadSettings() {
    global Settings
    Settings := {selected: "flick", stopKey: "F12", keys: Map(), params: Map()}
    for , id in ScriptOrder {
        Settings.keys[id] := ScriptModules[id].meta.defaultKey
        pmap := Map()
        for , p in ScriptModules[id].params
            pmap[p.name] := p.default
        Settings.params[id] := pmap
    }
    path := SettingsPath()
    if FileExist(path) {
        try {
            sel := IniRead(path, "General", "Selected", "flick")
            if ScriptModules.Has(sel)
                Settings.selected := sel
            stop := NormalizeKey(IniRead(path, "General", "StopKey", "F12"))
            if (stop != "")
                Settings.stopKey := stop
            for , id in ScriptOrder {
                k := NormalizeKey(IniRead(path, "Keys", id, ScriptModules[id].meta.defaultKey))
                if (k != "")
                    Settings.keys[id] := k
                for , p in ScriptModules[id].params {
                    raw := IniRead(path, "Params:" id, p.name, p.default)
                    Settings.params[id][p.name] := SanitizeNum(raw, p.default, p.min, p.max)
                }
            }
        }
    }
    SaveSettings()
}

SaveSettings() {
    path := SettingsPath()
    IniWrite(Settings.selected, path, "General", "Selected")
    IniWrite(Settings.stopKey, path, "General", "StopKey")
    for , id in ScriptOrder {
        IniWrite(GetScriptKey(id), path, "Keys", id)
        for , p in ScriptModules[id].params {
            val := Settings.params[id].Has(p.name) ? Settings.params[id][p.name] : p.default
            IniWrite(val, path, "Params:" id, p.name)
        }
    }
}

ReadToken() {
    path := SettingsPath()
    if !FileExist(path)
        return ""
    token := ""
    try token := Trim(IniRead(path, "General", "GithubToken", ""))
    if (token = "ERROR")
        return ""
    return token
}

SetupTray() {
    try A_TrayMenu.Delete()
    catch {
        for , item in ["Open", "Help", "Window Spy", "Reload Script", "Edit Script", "Suspend Hotkeys", "Pause Script", "Exit"]
            try A_TrayMenu.Delete(item)
    }
    A_TrayMenu.Add("Show", ShowFromTray)
    A_TrayMenu.Add("Stop", StopMacro)
    A_TrayMenu.Add()
    A_TrayMenu.Add("Exit", (*) => ExitApp())
    A_IconTip := APP_NAME
    ico := A_ScriptDir "\" APP_NAME ".ico"
    if FileExist(ico)
        try TraySetIcon(ico)
}

ShowLibrary(*) {
    global libWnd, libList, libDesc, libWarn, libNote
    if IsObject(libWnd)
        return
    libWnd := MkGui("-Resize -MaximizeBox")
    libWnd.AddText("x0 y0 w8 h470 Background7c5cff", "")
    libWnd.AddText("x8 y0 w732 h58 Background101018", "")
    avatar := AssetFile("avatar.jpg")
    if FileExist(avatar)
        libWnd.AddPic("x24 y10 w38 h38", avatar)
    libWnd.SetFont("s18 w700 cF4F2FF", "Segoe UI")
    libWnd.AddText("x74 y10 w500 h28 Background101018", "Library")
    libWnd.SetFont("s9 cA79BFF", "Segoe UI")
    libWnd.AddText("x74 y36 w500 h16 Background101018", "Click a row to load it. Feels quick. Not an executor.")
    libWnd.SetFont("s10 cE8E6F2", "Segoe UI")
    libList := libWnd.AddListView("x24 y70 w696 h220 Background181824 cE8E6F2", ["Name", "Game/App", "Channel", "Version", "Status"])
    libList.ModifyCol(1, 230)
    libList.ModifyCol(2, 110)
    libList.ModifyCol(3, 80)
    libList.ModifyCol(4, 80)
    libList.ModifyCol(5, 150)
    libList.OnEvent("ItemSelect", OnLibSelect)
    libList.OnEvent("DoubleClick", (*) => ChooseScript())
    libWnd.AddText("x24 y302 w696 h90 Background181824", "")
    libDesc := libWnd.AddText("x36 y312 w672 h40 Background181824", "")
    libWnd.SetFont("s9 cE6B450", "Segoe UI")
    libWarn := libWnd.AddText("x36 y354 w672 h16 Background181824", "")
    libWnd.SetFont("s9 c9A97AD", "Segoe UI")
    libNote := libWnd.AddText("x36 y372 w672 h16 Background181824", "")
    libWnd.SetFont("s10 cFFFFFF", "Segoe UI")
    AddButton(libWnd, 24, 410, 150, 38, "LOAD", "7c5cff", "9480ff", "FFFFFF", ChooseScript)
    libWnd.SetFont("s10 cF4F2FF", "Segoe UI")
    AddButton(libWnd, 186, 410, 190, 38, "Check for updates", "2a2a38", "3a3a4c", "F4F2FF", ManualCheck)
    AddButton(libWnd, 570, 410, 150, 38, "CLOSE", "2a2a38", "3a3a4c", "F4F2FF", (*) => CloseLibrary(libWnd))
    libWnd.OnEvent("Close", CloseLibrary)
    ApplyWindowIcon(libWnd)
    FillLibrary()
    ShowAt(libWnd, 740, 470)
    WinSetTransparent(0, "ahk_id " libWnd.Hwnd)
    FadeHwnd(libWnd.Hwnd, 0, 255, 160)
    try WinSetTransparent("Off", "ahk_id " libWnd.Hwnd)
}

ShowDevlog(*) {
    global devlogWnd
    if IsObject(devlogWnd)
        return
    devlogWnd := MkGui("-Resize -MaximizeBox")
    devlogWnd.AddText("x0 y0 w8 h460 Background7c5cff", "")
    devlogWnd.AddText("x8 y0 w552 h58 Background101018", "")
    avatar := AssetFile("avatar.jpg")
    if FileExist(avatar)
        devlogWnd.AddPic("x24 y10 w38 h38", avatar)
    devlogWnd.SetFont("s18 w700 cF4F2FF", "Segoe UI")
    devlogWnd.AddText("x74 y10 w400 h28 Background101018", "Devlog")
    devlogWnd.SetFont("s9 cA79BFF", "Segoe UI")
    devlogWnd.AddText("x74 y36 w400 h16 Background101018", "What shipped, newest first")
    body := ReadDevlog()
    box := devlogWnd.AddEdit("x24 y72 w516 h320 ReadOnly Multi +VScroll Background181824 cE8E6F2", body)
    box.Value := body
    try SendMessage(0xB1, -1, 0, , "ahk_id " box.Hwnd) ; clear selection
    try box.Focus()
    try SendMessage(0xB1, -1, 0, , "ahk_id " box.Hwnd)
    devlogWnd.SetFont("s10 cF4F2FF", "Segoe UI")
    AddButton(devlogWnd, 390, 406, 150, 36, "CLOSE", "2a2a38", "3a3a4c", "F4F2FF", (*) => CloseDevlog(devlogWnd))
    devlogWnd.OnEvent("Close", CloseDevlog)
    ApplyWindowIcon(devlogWnd)
    ShowAt(devlogWnd, 560, 460)
    WinSetTransparent(0, "ahk_id " devlogWnd.Hwnd)
    FadeHwnd(devlogWnd.Hwnd, 0, 255, 160)
    try WinSetTransparent("Off", "ahk_id " devlogWnd.Hwnd)
}

CloseDevlog(thisWnd, *) {
    global devlogWnd
    if !IsObject(devlogWnd)
        return true
    FadeHwnd(devlogWnd.Hwnd, 255, 0, 120)
    DestroyWnd(devlogWnd)
    devlogWnd := ""
    return true
}

ReadDevlog() {
    path := AssetFile("devlog.md")
    if FileExist(path) {
        try return FileRead(path, "UTF-8")
    }
    localPath := A_ScriptDir "\devlog.md"
    if FileExist(localPath) {
        try return FileRead(localPath, "UTF-8")
    }
    return "# MacroVault Devlog`n`nNo devlog file found."
}

CloseLibrary(thisWnd, *) {
    global libWnd, libList
    if !IsObject(libWnd)
        return true
    FadeHwnd(libWnd.Hwnd, 255, 0, 140)
    DestroyWnd(libWnd)
    libWnd := ""
    libList := ""
    return true
}

FillLibrary() {
    global libBusy, libIds
    if !IsObject(libList)
        return
    libBusy := true
    libList.Delete()
    libIds := []
    currentRow := 0
    for , entry in LibraryScripts() {
        id := Field(entry, "id")
        if (id = "")
            continue
        libList.Add(, Field(entry, "name"), Field(entry, "game"), Field(entry, "channel"), Field(entry, "version"), ScriptStatus(entry))
        libIds.Push(entry)
        if (id = Settings.selected)
            currentRow := libIds.Length
    }
    StyleList(libList)
    if (currentRow < 1 && libIds.Length > 0)
        currentRow := 1
    if (currentRow > 0) {
        libList.Modify(currentRow, "Select Focus")
        ShowLibDetails(currentRow)
    }
    libBusy := false
}

; Always list every script baked into this exe, then any remote-only "New" rows.
; A stale GitHub manifest must never hide a script the user already installed.
LibraryScripts() {
    remoteById := Map()
    remoteOrder := []
    if IsObject(catalog) && HasProp(catalog, "scripts") {
        for , entry in catalog.scripts {
            id := Field(entry, "id")
            if (id = "")
                continue
            remoteById[id] := entry
            remoteOrder.Push(entry)
        }
    }
    scripts := []
    seen := Map()
    for , id in ScriptOrder {
        meta := ScriptModules[id].meta
        scripts.Push({
            id: meta.id,
            name: meta.name,
            game: meta.game,
            channel: meta.channel,
            version: meta.version,
            description: meta.description
        })
        seen[id] := true
    }
    for , entry in remoteOrder {
        id := Field(entry, "id")
        if (id = "" || seen.Has(id))
            continue
        scripts.Push(entry)
        seen[id] := true
    }
    return scripts
}

StyleList(list) {
    try {
        hwnd := list.Hwnd
        ; COLORREF is BGR. wParam must be 0; the color is lParam.
        bg := 0x1C1414
        fg := 0xF2E6E8
        DllCall("uxtheme\SetWindowTheme", "Ptr", hwnd, "Str", "DarkMode_Explorer", "Ptr", 0)
        DllCall("SendMessage", "Ptr", hwnd, "UInt", 0x1001, "Ptr", 0, "Ptr", bg)
        DllCall("SendMessage", "Ptr", hwnd, "UInt", 0x1026, "Ptr", 0, "Ptr", bg)
        DllCall("SendMessage", "Ptr", hwnd, "UInt", 0x1024, "Ptr", 0, "Ptr", fg)
        DllCall("InvalidateRect", "Ptr", hwnd, "Ptr", 0, "Int", 1)
    }
}

OnLibSelect(ctrl, row, selected) {
    if libBusy || !selected
        return
    LoadLibraryRow(row, false)
}

ShowLibDetails(row) {
    if (row < 1 || row > libIds.Length)
        return
    entry := libIds[row]
    libDesc.Text := Field(entry, "description")
    channel := Field(entry, "channel")
    if (channel = "Beta" || channel = "WIP")
        libWarn.Text := "Work in progress, may not behave consistently."
    else
        libWarn.Text := ""
    status := ScriptStatus(entry)
    if (status = "New" || status = "Update available")
        libNote.Text := "Updating the app installs it."
    else
        libNote.Text := ""
}

ChooseScript(*) {
    if !IsObject(libList)
        return
    row := libList.GetNext()
    if (row < 1) {
        libNote.Text := "Click a script to load it."
        return
    }
    LoadLibraryRow(row, true)
}

LoadLibraryRow(row, closeAfter) {
    ShowLibDetails(row)
    if (row < 1 || row > libIds.Length)
        return
    entry := libIds[row]
    if (ScriptStatus(entry) = "New") {
        libNote.Text := "Updating the app installs it."
        return
    }
    id := Field(entry, "id")
    if !ScriptModules.Has(id)
        return
    if (Settings.selected != id) {
        wasActive := macroActive
        if wasActive
            try UnregisterTrigger()
        Settings.selected := id
        SaveSettings()
        RefreshMain()
        if wasActive {
            try RegisterTrigger()
            SetPlayButton(true)
            SetStatusActive()
        }
    }
    libNote.Text := "Loaded."
    if closeAfter
        CloseLibrary(libWnd)
}

ScriptStatus(entry) {
    id := Field(entry, "id")
    if !ScriptModules.Has(id)
        return "New"
    remoteVer := RemoteScriptVersion(id)
    if (remoteVer = "")
        remoteVer := Field(entry, "version")
    if (remoteVer != "" && VerGreater(remoteVer, ScriptModules[id].meta.version))
        return "Update available"
    return "Installed"
}

RemoteScriptVersion(id) {
    if !IsObject(catalog) || !HasProp(catalog, "scripts")
        return ""
    for , entry in catalog.scripts {
        if (Field(entry, "id") = id)
            return Field(entry, "version")
    }
    return ""
}

ManualCheck(*) {
    global libBusy, catalog
    if libBusy
        return
    libBusy := true
    libNote.Text := "Checking..."
    Sleep 40
    parsed := FetchManifestNow()
    libBusy := false
    if !IsObject(parsed) {
        libNote.Text := "Update check failed."
        return
    }
    catalog := parsed
    if IsObject(libWnd)
        FillLibrary()
    if IsUpdateAvailable(parsed) {
        if !A_IsCompiled {
            libNote.Text := "v" parsed.app.version " is out. Run the compiled .exe to auto-install."
            return
        }
        libNote.Text := "Downloading v" parsed.app.version "..."
        Sleep 200
        if !ApplyAppUpdate(parsed.app.version, parsed.app.exeUrl) && IsObject(libNote)
            libNote.Text := "Update failed. Download the release manually."
    } else if IsObject(libNote) {
        libNote.Text := "You're on the latest version (v" APP_VERSION ")."
    }
}

ShowSettings(*) {
    global settingsRows, settingsWnd, triggerCtrl, stopCtrl, settingsNote
    if IsObject(settingsWnd)
        return
    id := Settings.selected
    mod := ScriptModules[id]
    settingsRows := []
    settingsWnd := MkGui("-Resize -MaximizeBox")
    settingsWnd.SetFont("s16 w700 cF4F2FF", "Segoe UI")
    settingsWnd.AddText("x20 y12 w460 h28 Background14141c", "Settings")
    settingsWnd.SetFont("s10 c9A97AD", "Segoe UI")
    settingsWnd.AddText("x20 y42 w460 h18 Background14141c", mod.meta.name)
    settingsWnd.SetFont("s9 c9A97AD", "Segoe UI")
    settingsWnd.AddText("x20 y68 w460 h16 Background14141c", "Click a box, then press a key.")
    settingsWnd.SetFont("s10 cE8E6F2", "Segoe UI")
    settingsWnd.AddText("x20 y90 w140 h24 Background14141c", "Trigger key")
    settingsWnd.AddText("x250 y90 w140 h24 Background14141c", "Stop key")
    triggerCtrl := settingsWnd.AddHotkey("x20 y114 w180 h28", GetScriptKey(id))
    stopCtrl := settingsWnd.AddHotkey("x250 y114 w180 h28", Settings.stopKey)
    settingsWnd.SetFont("s10 w600 cF4F2FF", "Segoe UI")
    settingsWnd.AddText("x20 y154 w460 h20 Background14141c", "Tuning")
    y := 180
    settingsWnd.SetFont("s9 cE8E6F2", "Segoe UI")
    saved := GetParamMap(id)
    for , p in mod.params {
        lower := p.min
        upper := p.max
        fallback := p.default
        current := saved[p.name]
        span := upper - lower
        if (span < 1)
            span := 1
        settingsWnd.AddText("x20 y" y " w280 h16 Background14141c", PrettyName(p.name))
        valLbl := settingsWnd.AddText("x390 y" y " w80 h16 Right Background14141c", String(current))
        slider := settingsWnd.AddSlider("x20 y" (y + 14) " w440 h22 Range0-" span " TickInterval0", current - lower)
        slider.OnEvent("Change", SliderChanged.Bind(slider, valLbl, lower))
        settingsRows.Push({name: p.name, slider: slider, lower: lower, upper: upper, def: fallback, valueLabel: valLbl})
        y += 36
    }
    settingsWnd.SetFont("s9 c9A97AD", "Segoe UI")
    settingsNote := settingsWnd.AddText("x20 y" y " w460 h18 Background14141c", "")
    settingsWnd.SetFont("s10 cFFFFFF", "Segoe UI")
    AddButton(settingsWnd, 20, y + 26, 140, 36, "SAVE", "7c5cff", "9480ff", "FFFFFF", SaveFromSettings)
    settingsWnd.SetFont("s9 cF4F2FF", "Segoe UI")
    AddButton(settingsWnd, 172, y + 26, 180, 36, "RESET TO DEFAULTS", "2a2a38", "3a3a4c", "F4F2FF", ResetParams)
    settingsWnd.OnEvent("Close", CloseSettings)
    ApplyWindowIcon(settingsWnd)
    ShowAt(settingsWnd, 500, y + 78)
    WinSetTransparent(0, "ahk_id " settingsWnd.Hwnd)
    FadeHwnd(settingsWnd.Hwnd, 0, 255, 160)
    try WinSetTransparent("Off", "ahk_id " settingsWnd.Hwnd)
}

CloseSettings(thisWnd, *) {
    global settingsWnd, triggerCtrl, stopCtrl, settingsRows
    if !IsObject(settingsWnd)
        return true
    FadeHwnd(settingsWnd.Hwnd, 255, 0, 140)
    DestroyWnd(settingsWnd)
    settingsWnd := ""
    triggerCtrl := ""
    stopCtrl := ""
    settingsRows := []
    return true
}

SliderChanged(slider, valLbl, lower, *) {
    valLbl.Text := slider.Value + lower
}

PrettyName(raw) {
    out := ""
    parts := StrSplit(raw)
    for i, ch in parts {
        if (i > 1 && RegExMatch(ch, "[A-Z]"))
            out .= " "
        out .= ch
    }
    return out
}

SaveFromSettings(*) {
    id := Settings.selected
    newTrigger := NormalizeKey(triggerCtrl.Value)
    newStop := NormalizeKey(stopCtrl.Value)
    if (newTrigger = "" || newStop = "") {
        settingsNote.Text := "Press a key in both boxes."
        return
    }
    if (StrLower(newTrigger) = StrLower(newStop)) {
        settingsNote.Text := "Trigger and stop must be different keys."
        return
    }
    if (StrLower(newTrigger) = "^+f12" || StrLower(newStop) = "^+f12") {
        settingsNote.Text := "That key is reserved."
        return
    }
    prevTrigger := GetScriptKey(id)
    prevStop := Settings.stopKey
    wasActive := macroActive
    oldParams := Settings.params[id]
    newParams := Map()
    for , row in settingsRows
        newParams[row.name] := SanitizeNum(row.slider.Value + row.lower, row.def, row.lower, row.upper)
    Settings.keys[id] := newTrigger
    Settings.stopKey := newStop
    Settings.params[id] := newParams
    failed := ""
    if wasActive
        try UnregisterTrigger()
    try ApplyStopHotkey()
    catch
        failed := "That stop key could not be used."
    if (failed = "") {
        try {
            RegisterTrigger()
            if !wasActive
                UnregisterTrigger()
        } catch {
            failed := "That trigger key could not be used."
        }
    }
    if (failed != "") {
        Settings.keys[id] := prevTrigger
        Settings.stopKey := prevStop
        Settings.params[id] := oldParams
        try ApplyStopHotkey()
        if wasActive
            try RegisterTrigger()
        settingsNote.Text := failed
        return
    }
    SaveSettings()
    RefreshMain()
    if macroActive
        SetStatusActive()
    settingsNote.Text := "Saved."
}

ResetParams(*) {
    id := Settings.selected
    pmap := Map()
    for , row in settingsRows {
        row.slider.Value := row.def - row.lower
        row.valueLabel.Text := row.def
        pmap[row.name] := row.def
    }
    Settings.params[id] := pmap
    SaveSettings()
    settingsNote.Text := "Defaults restored."
}

ApplyHttpHeaders(req, download := false) {
    req.SetRequestHeader("User-Agent", APP_NAME)
    token := ReadToken()
    if (token != "")
        req.SetRequestHeader("Authorization", "Bearer " token)
    if download
        req.SetRequestHeader("Accept", "application/octet-stream")
}

ManifestUrl() {
    ; Bust GitHub raw CDN cache so the library picks up new scripts after a release.
    return REPO_RAW_URL "?v=" APP_VERSION "&t=" A_TickCount
}

BeginManifestRequest() {
    global splashHttp
    splashHttp := ""
    try {
        req := ComObject("WinHttp.WinHttpRequest.5.1")
        req.Open("GET", ManifestUrl(), true)
        req.SetTimeouts(4000, 4000, 8000, 12000)
        ApplyHttpHeaders(req)
        req.SetRequestHeader("Cache-Control", "no-cache")
        req.Send()
        splashHttp := req
    } catch {
        splashHttp := ""
    }
}

ReadManifestResult() {
    global catalog, splashHttp
    if IsObject(splashHttp) {
        started := A_TickCount
        while !splashHttp.WaitForResponse(0) {
            if (A_TickCount - started > 10000)
                break
            SweepProgress()
            Sleep 30
        }
        text := ""
        code := 0
        try {
            code := splashHttp.Status
            text := splashHttp.ResponseText
        } catch {
            try splashHttp.Abort()
        }
        parsed := ""
        if (code = 200 && text != "")
            parsed := ParseManifest(text)
        catalog := IsObject(parsed) ? parsed : LocalCatalog()
    } else {
        catalog := LocalCatalog()
    }
    splashHttp := ""
    return catalog
}

FetchManifestNow() {
    try {
        req := ComObject("WinHttp.WinHttpRequest.5.1")
        req.Open("GET", ManifestUrl(), false)
        req.SetTimeouts(4000, 4000, 8000, 12000)
        ApplyHttpHeaders(req)
        req.SetRequestHeader("Cache-Control", "no-cache")
        req.Send()
        if (req.Status != 200)
            return ""
        return ParseManifest(req.ResponseText)
    } catch {
        return ""
    }
}

LocalCatalog() {
    scripts := []
    for , id in ScriptOrder {
        meta := ScriptModules[id].meta
        scripts.Push({id: meta.id, name: meta.name, game: meta.game, channel: meta.channel, version: meta.version, description: meta.description})
    }
    return {app: {version: APP_VERSION, exeUrl: ""}, scripts: scripts, remote: false}
}

ParseManifest(text) {
    try {
        if (SubStr(text, 1, 1) = Chr(0xFEFF))
            text := SubStr(text, 2)
        m := JsonParse(text)
        if !HasProp(m, "app") || !HasProp(m.app, "version")
            return ""
        if !HasProp(m, "scripts") || !IsObject(m.scripts)
            return ""
        m.remote := true
        return m
    } catch {
        return ""
    }
}

IsUpdateAvailable(m) {
    try {
        if !IsObject(m) || !m.remote
            return false
        if !VerGreater(m.app.version, APP_VERSION)
            return false
        url := HasProp(m.app, "exeUrl") ? m.app.exeUrl : ""
        return url != ""
    } catch {
        return false
    }
}

ApplyAppUpdate(version, url) {
    global appReady
    if !A_IsCompiled {
        SplashStatus("Update v" version " needs the .exe build")
        Sleep 900
        return false
    }
    if !IsObject(splashWnd)
        OpenSplash()
    try WinSetTransparent(255, "ahk_id " splashWnd.Hwnd)
    SplashStatus("Downloading v" version "...")
    LogUpdate("begin " version " " url)
    dest := A_Temp "\" APP_NAME "-new.exe"
    if FileExist(dest)
        try FileDelete(dest)
    if !DownloadExe(url, dest) {
        SplashStatus("Download failed")
        LogUpdate("download failed")
        Sleep 1000
        return false
    }
    SplashStatus("Installing v" version "...")
    SweepProgress(100)
    Sleep 350
    if !LaunchSwap(dest) {
        SplashStatus("Install helper failed")
        LogUpdate("swap failed")
        Sleep 1000
        return false
    }
    SplashStatus("Restarting...")
    LogUpdate("swap launched")
    appReady := true
    Sleep 400
    ExitApp()
}

LogUpdate(msg) {
    try FileAppend(A_Now " " msg "`n", SettingsDir() "\update.log", "UTF-8")
}

DownloadExe(url, path) {
    if DownloadExeCurl(url, path) && LooksLikeExe(path)
        return true
    if DownloadExeWinHttp(url, path) && LooksLikeExe(path)
        return true
    if DownloadExePowerShell(url, path) && LooksLikeExe(path)
        return true
    return false
}

DownloadExeCurl(url, path) {
    curl := A_WinDir "\System32\curl.exe"
    if !FileExist(curl)
        return false
    SplashStatus("Downloading... (curl)")
    cmd := Format('"{1}" -L --fail --retry 2 --connect-timeout 8 -A "{2}" -o "{3}" "{4}"', curl, APP_NAME, path, url)
    try {
        pid := 0
        Run(cmd, , "Hide", &pid)
        started := A_TickCount
        while ProcessExist(pid) {
            if (A_TickCount - started > 180000) {
                try ProcessClose(pid)
                return false
            }
            SweepProgress()
            Sleep 40
        }
        return LooksLikeExe(path)
    } catch {
        return false
    }
}

DownloadExeWinHttp(url, path) {
    try {
        SplashStatus("Downloading... (http)")
        req := ComObject("WinHttp.WinHttpRequest.5.1")
        req.Open("GET", url, true)
        req.SetTimeouts(8000, 8000, 30000, 180000)
        try req.Option[6] := true ; follow redirects
        ApplyHttpHeaders(req, InStr(url, "api.github.com"))
        req.Send()
        started := A_TickCount
        while !req.WaitForResponse(0) {
            if (A_TickCount - started > 180000) {
                try req.Abort()
                return false
            }
            SweepProgress()
            Sleep 30
        }
        if (req.Status != 200)
            return false
        if !SaveResponseBody(req, path)
            return false
        return LooksLikeExe(path)
    } catch {
        return false
    }
}

DownloadExePowerShell(url, path) {
    try {
        SplashStatus("Downloading... (ps)")
        script := A_Temp "\" APP_NAME "-dl.ps1"
        if FileExist(script)
            FileDelete(script)
        f := FileOpen(script, "w", "UTF-8")
        f.Write('Invoke-WebRequest -Uri "' url '" -OutFile "' path '" -UserAgent "' APP_NAME '"`r`n')
        f.Close()
        pid := 0
        Run('powershell -NoProfile -ExecutionPolicy Bypass -File "' script '"', , "Hide", &pid)
        started := A_TickCount
        while ProcessExist(pid) {
            if (A_TickCount - started > 180000) {
                try ProcessClose(pid)
                return false
            }
            SweepProgress()
            Sleep 40
        }
        try FileDelete(script)
        return LooksLikeExe(path)
    } catch {
        return false
    }
}

SaveResponseBody(req, path) {
    stream := ComObject("ADODB.Stream")
    stream.Type := 1
    stream.Open()
    stream.Write(req.ResponseBody)
    if FileExist(path)
        FileDelete(path)
    stream.SaveToFile(path, 2)
    stream.Close()
    return FileExist(path)
}

LooksLikeExe(path) {
    try {
        if (FileGetSize(path) < 100000)
            return false
        f := FileOpen(path, "r")
        sig := f.ReadUShort()
        f.Close()
        return sig = 0x5A4D
    } catch {
        return false
    }
}

LaunchSwap(newFile) {
    batPath := A_Temp "\" APP_NAME "-update.bat"
    WriteSwapBat(batPath)
    pid := DllCall("GetCurrentProcessId")
    cmd := Format('"{1}" "{2}" "{3}" "{4}"', batPath, pid, newFile, A_ScriptFullPath)
    try Run(cmd, , "Hide")
    catch
        return false
    return true
}

WriteSwapBat(batPath) {
    q := Chr(34)
    if FileExist(batPath)
        FileDelete(batPath)
    f := FileOpen(batPath, "w", "UTF-8-RAW")
    f.Write("@echo off`r`n")
    f.Write("setlocal`r`n")
    f.Write("set " q "PID=%~1" q "`r`n")
    f.Write("set " q "NEW=%~2" q "`r`n")
    f.Write("set " q "DEST=%~3" q "`r`n")
    f.Write("set /a W=0`r`n")
    f.Write(":waitloop`r`n")
    f.Write("set /a W+=1`r`n")
    f.Write("tasklist /FI " q "PID eq %PID%" q " | find " q "%PID%" q " >nul`r`n")
    f.Write("if not errorlevel 1 (`r`n")
    f.Write("  if %W% lss 40 (`r`n")
    f.Write("    ping 127.0.0.1 -n 2 >nul`r`n")
    f.Write("    goto waitloop`r`n")
    f.Write("  )`r`n")
    f.Write(")`r`n")
    f.Write("set /a N=0`r`n")
    f.Write(":copytry`r`n")
    f.Write("set /a N+=1`r`n")
    f.Write("copy /y " q "%NEW%" q " " q "%DEST%" q " >nul`r`n")
    f.Write("if errorlevel 1 (`r`n")
    f.Write("  if %N% lss 25 (`r`n")
    f.Write("    ping 127.0.0.1 -n 2 >nul`r`n")
    f.Write("    goto copytry`r`n")
    f.Write("  )`r`n")
    f.Write("  if exist " q "%DEST%" q " start " q q " " q "%DEST%" q "`r`n")
    f.Write("  exit /b 1`r`n")
    f.Write(")`r`n")
    f.Write("start " q q " " q "%DEST%" q "`r`n")
    f.Write("del /f /q " q "%NEW%" q "`r`n")
    f.Write("del /f /q " q "%~f0" q "`r`n")
    f.Close()
}

Field(obj, name, fallback := "") {
    try {
        if IsObject(obj) && HasProp(obj, name) {
            val := obj.%name%
            if (val != "")
                return val
        }
    }
    return fallback
}

VerParts(v) {
    v := Trim(v)
    if (SubStr(v, 1, 1) = "v" || SubStr(v, 1, 1) = "V")
        v := SubStr(v, 2)
    bits := StrSplit(v, ".")
    out := [0, 0, 0]
    Loop 3 {
        if (A_Index <= bits.Length && IsNumber(bits[A_Index]))
            out[A_Index] := Integer(bits[A_Index])
    }
    return out
}

VerGreater(a, b) {
    pa := VerParts(a)
    pb := VerParts(b)
    Loop 3 {
        if (pa[A_Index] > pb[A_Index])
            return true
        if (pa[A_Index] < pb[A_Index])
            return false
    }
    return false
}

JsonParse(text) {
    at := 1
    return JsonValue(text, &at)
}

JsonSkip(text, &at) {
    while (at <= StrLen(text)) {
        ch := SubStr(text, at, 1)
        if (ch != " " && ch != "`t" && ch != "`r" && ch != "`n")
            break
        at += 1
    }
}

JsonValue(text, &at) {
    JsonSkip(text, &at)
    if (at > StrLen(text))
        throw Error("Unexpected end of JSON")
    ch := SubStr(text, at, 1)
    if (ch = "{")
        return JsonObject(text, &at)
    if (ch = "[")
        return JsonArray(text, &at)
    if (ch = Chr(34))
        return JsonString(text, &at)
    if (ch = "-" || (ch >= "0" && ch <= "9"))
        return JsonNumber(text, &at)
    if (SubStr(text, at, 4) = "true") {
        at += 4
        return true
    }
    if (SubStr(text, at, 5) = "false") {
        at += 5
        return false
    }
    if (SubStr(text, at, 4) = "null") {
        at += 4
        return ""
    }
    throw Error("Invalid JSON")
}

JsonObject(text, &at) {
    obj := {}
    at += 1
    JsonSkip(text, &at)
    if (SubStr(text, at, 1) = "}") {
        at += 1
        return obj
    }
    Loop {
        JsonSkip(text, &at)
        if (SubStr(text, at, 1) != Chr(34))
            throw Error("JSON key")
        key := JsonString(text, &at)
        JsonSkip(text, &at)
        if (SubStr(text, at, 1) != ":")
            throw Error("JSON colon")
        at += 1
        obj.%key% := JsonValue(text, &at)
        JsonSkip(text, &at)
        ch := SubStr(text, at, 1)
        if (ch = ",") {
            at += 1
            continue
        }
        if (ch = "}") {
            at += 1
            break
        }
        throw Error("JSON object")
    }
    return obj
}

JsonArray(text, &at) {
    arr := []
    at += 1
    JsonSkip(text, &at)
    if (SubStr(text, at, 1) = "]") {
        at += 1
        return arr
    }
    Loop {
        arr.Push(JsonValue(text, &at))
        JsonSkip(text, &at)
        ch := SubStr(text, at, 1)
        if (ch = ",") {
            at += 1
            continue
        }
        if (ch = "]") {
            at += 1
            break
        }
        throw Error("JSON array")
    }
    return arr
}

JsonString(text, &at) {
    at += 1
    out := ""
    while (at <= StrLen(text)) {
        ch := SubStr(text, at, 1)
        if (ch = Chr(34)) {
            at += 1
            return out
        }
        if (ch = "\") {
            at += 1
            esc := SubStr(text, at, 1)
            if (esc = "n")
                out .= "`n"
            else if (esc = "r")
                out .= "`r"
            else if (esc = "t")
                out .= "`t"
            else if (esc = "u") {
                hex := SubStr(text, at + 1, 4)
                out .= Chr("0x" hex)
                at += 4
            } else
                out .= esc
            at += 1
            continue
        }
        out .= ch
        at += 1
    }
    throw Error("JSON string")
}

JsonNumber(text, &at) {
    start := at
    if (SubStr(text, at, 1) = "-")
        at += 1
    while (at <= StrLen(text)) {
        ch := SubStr(text, at, 1)
        if ((ch >= "0" && ch <= "9") || ch = "." || ch = "e" || ch = "E" || ch = "+")
            at += 1
        else
            break
    }
    token := SubStr(text, start, at - start)
    if InStr(token, ".") || InStr(token, "e") || InStr(token, "E")
        return Number(token)
    return Integer(token)
}

RunSelfTest() {
    if (APP_NAME != "MacroVault")
        ExitApp(2)
    if (ScriptOrder.Length != 5)
        ExitApp(10)
    if (ScriptOrder[1] != "flick" || ScriptOrder[2] != "flick-combo" || ScriptOrder[3] != "flick-queue" || ScriptOrder[4] != "flick-chain" || ScriptOrder[5] != "flick-restart")
        ExitApp(11)
    if (ScriptModules["flick-combo"].meta.maxThreads != 1)
        ExitApp(48)
    for , p in ScriptModules["flick-combo"].params {
        if (p.name = "JumpHold")
            ExitApp(49)
        if (p.name = "DelayBeforeFlick" && p.default != 0)
            ExitApp(50)
        if (p.name = "BoostHold" && p.default != 40)
            ExitApp(51)
    }
    if (ScriptModules["flick"].meta.maxThreads != 1)
        ExitApp(12)
    if (ScriptModules["flick-queue"].meta.maxThreads != 2 || ScriptModules["flick-restart"].meta.maxThreads != 2)
        ExitApp(13)
    if (ScriptModules["flick-chain"].meta.maxThreads != 1)
        ExitApp(14)
    for , id in ScriptOrder {
        meta := ScriptModules[id].meta
        if (meta.defaultKey != "c" || meta.targetExe != "RobloxPlayerBeta.exe")
            ExitApp(15)
    }
    expect := Map(
        "DelayBeforeFlick", 190,
        "FlickDistance", 800,
        "Steps", 6,
        "StepDelay", 6,
        "PauseAtEdge", 10,
        "JumpHold", 40,
        "BoostHold", 40,
        "LoopGap", 0
    )
    for , p in ScriptModules["flick"].params {
        if (expect.Has(p.name) && p.default != expect[p.name])
            ExitApp(16)
    }
    qExpect := Map("GapBetweenHops", 60, "MaxQueue", 1, "MinGap", 80)
    for , p in ScriptModules["flick-queue"].params {
        if (qExpect.Has(p.name) && p.default != qExpect[p.name])
            ExitApp(17)
    }
    cExpect := Map("ChainWindow", 700, "ChainDelayShift", -10, "ChainMinDelay", 150, "ChainMaxShift", -40, "ChainStepShift", -5)
    for , p in ScriptModules["flick-chain"].params {
        if (cExpect.Has(p.name) && p.default != cExpect[p.name])
            ExitApp(18)
    }
    for , p in ScriptModules["flick-restart"].params {
        if (p.name = "MinGap" && p.default != 120)
            ExitApp(19)
    }
    if (Round(800 / 6) != 133)
        ExitApp(20)
    if (Max(10, 40 - 6 * 6) != 10)
        ExitApp(21)
    if (FlickChainDelay(190, 1, -10, -5, -40, 150) != 190)
        ExitApp(30)
    if (FlickChainDelay(190, 2, -10, -5, -40, 150) != 180)
        ExitApp(31)
    if (FlickChainDelay(190, 3, -10, -5, -40, 150) != 175)
        ExitApp(32)
    if (FlickChainDelay(190, 8, -10, -5, -40, 150) != 150)
        ExitApp(33)
    if (FlickChainDelay(190, 9, -10, -5, -40, 150) != 150)
        ExitApp(34)
    if (FlickChainDelay(190, 9, -10, -5, -40, 160) != 160)
        ExitApp(35)
    if !VerGreater("1.0.1", "1.0.0") || !VerGreater("1.2.0", "1.0.9") || !VerGreater("2.0.0", "1.9.9")
        ExitApp(36)
    if VerGreater("1.0.0", "1.0.0") || VerGreater("1.0.0", "1.0.1")
        ExitApp(37)
    if (SanitizeNum("nope", 190, 0, 500) != 190 || SanitizeNum(9999, 190, 0, 500) != 190 || SanitizeNum(200, 190, 0, 500) != 200)
        ExitApp(38)
    try {
        raw := FileRead(A_ScriptDir "\manifest.json", "UTF-8")
        m := JsonParse(raw)
    } catch {
        ExitApp(39)
    }
    if (m.app.version != APP_VERSION || m.scripts.Length != 5)
        ExitApp(45)
    for , entry in m.scripts {
        id := entry.id
        if !ScriptModules.Has(id)
            ExitApp(40)
        if (entry.version != ScriptModules[id].meta.version)
            ExitApp(41)
        if (entry.name != ScriptModules[id].meta.name)
            ExitApp(42)
        if (entry.channel != ScriptModules[id].meta.channel)
            ExitApp(43)
        if (entry.description != ScriptModules[id].meta.description)
            ExitApp(44)
    }
    sample := '{"app":{"version":"1.2.0","exeUrl":"https://example.test/a.exe"},"scripts":[{"id":"flick","name":"Flick Macro","game":"Roblox","channel":"Stable","version":"1.0.0","description":"Hello"}]}'
    s := JsonParse(sample)
    if (s.app.version != "1.2.0" || s.scripts[1].id != "flick" || s.scripts[1].description != "Hello")
        ExitApp(46)
    if (InStr(REPO_RAW_URL, "macrovault") = 0)
        ExitApp(47)
    for , name in ["splash.jpg", "main-girl.jpg", "avatar.jpg"] {
        if !FileExist(A_ScriptDir "\assets\" name)
            ExitApp(52)
    }
    catalog := {app: {version: "0.0.1", exeUrl: ""}, scripts: [{id: "flick", name: "old", game: "Roblox", channel: "Stable", version: "0.0.1", description: "stale"}], remote: true}
    rows := LibraryScripts()
    if (rows.Length < ScriptOrder.Length)
        ExitApp(53)
    foundCombo := false
    for , entry in rows {
        if (Field(entry, "id") = "flick-combo")
            foundCombo := true
    }
    if !foundCombo
        ExitApp(54)
    catalog := LocalCatalog()
    ExitApp(0)
}
