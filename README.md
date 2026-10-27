# MacroVault

MacroVault is a small Windows launcher for game and app macros. It is built for two people: MJ, and one friend. The friend gets the compiled exe. The macro source stays in this repository.

Window titles, the splash, the tray tip, and the settings folder all come from the `APP_NAME` constant in `App.ahk`. The update catalog is `REPO_RAW_URL` in that same file.

## What the friend gets

Download `MacroVault.exe` from the latest GitHub Release. Do not send the `.ahk` files.

Settings are saved per Windows user at `%AppData%\MacroVault\settings.ini`. An update replaces the exe and leaves that file alone.

## Play

1. Open the exe. A short splash plays, then the main window.
2. The first script is Flick Macro (Stable). Press **PLAY**. There is no confirm step.
3. While it is armed, the button turns into a red **STOP**. The status line shows the script and its trigger key.
4. The trigger (C by default) runs the macro only when `RobloxPlayerBeta.exe` is the active window. Anywhere else, that key behaves normally.
5. **F12** stops the macro and releases keys. It does not close the app.
6. **Ctrl+Shift+F12** closes the app from anywhere.
7. The window X hides to the tray. The tray menu is Show, Stop, and Exit.

## Library and settings

**LIBRARY** lists the catalog from `manifest.json`: name, game, channel, version, and whether it is installed. **SELECT** arms that script for PLAY. Beta and WIP rows warn that they may not behave consistently. A row marked New is not in this exe yet; updating the app installs it.

**SETTINGS** is the only thing a player can change:

- Trigger key, remembered per script
- Stop key
- Sliders built from that script's Params

**SAVE** applies the key immediately. No restart. **RESET TO DEFAULTS** restores that script's timing numbers. Frame rate and mouse sensitivity are different for each player, which is what the sliders are for.

## Build

Install [AutoHotkey v2](https://www.autohotkey.com/) and [Ahk2Exe](https://github.com/AutoHotkey/Ahk2Exe/releases). Then, from this folder:

```bat
Ahk2Exe.exe /in App.ahk /out MacroVault.exe /icon MacroVault.ico /base "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe" /compress 0
```

`build.bat` runs that command when Ahk2Exe is in the usual install path.

The scripts are pulled in with `#Include`, so they are compiled into the one exe. Do not FileInstall the `.ahk` source, and do not ship those files beside the exe.

Optional lock:

```bat
Ahk2Exe.exe /in App.ahk /out MacroVault.exe /icon MacroVault.ico /base "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe" /pass YourPassword
```

The password deters casual opening of the exe. It is not unbreakable. Someone with time and the right tools can still recover bytecode.

## Publish a release

1. Bump `APP_VERSION` in `App.ahk`.
2. Set `manifest.json` `app.version` to the same number, and point `exeUrl` at the new tag, for example `https://github.com/mjedit100-cmyk/macrovault/releases/download/v1.0.1/MacroVault.exe`.
3. Build `MacroVault.exe`.
4. Commit and push `main`.
5. Publish the exe. It is not committed to the repo.

```bat
gh release create v1.0.1 MacroVault.exe --title "MacroVault v1.0.1" --notes "Short notes."
```

On launch, the app reads `manifest.json` from `REPO_RAW_URL`. If `app.version` is newer, it downloads `exeUrl`, waits until this process exits, replaces the exe, and starts it again. If the network fails, it keeps running the installed build.

## Add a script

1. Add `scripts/<id>.ahk`. It must call `ScriptRegister` with:
   - Meta: `id`, `name`, `game`, `version`, `channel` (`Stable`, `Beta`, or `WIP`), `description`, `targetExe` (an exe name, or `any`), `defaultKey`, `maxThreads` (1, or 2 when a press must re-enter during a hop)
   - Params: a list of `{name, default, min, max}`. Settings builds the sliders from this list. Do not edit the Settings window for a new slider.
   - `Run(params, triggerKey)` and `Cancel()`. Cancel must release any held keys.
2. Add `#Include "scripts\<id>.ahk"` to `App.ahk`.
3. Add one object to the `scripts` array in `manifest.json`.
4. Bump the app version, build, and publish a release.

Keep hop timing in that script's Params defaults. The shell does not change `SendMode` or the 1 ms timer period: `SendMode "Event"` and `timeBeginPeriod(1)`.

## Private repository

This repo is public so update checks work with no token. The source is readable by anyone who can open the repo. The friend should only be given the exe.

To hide the source, make the repo private:

```bat
gh repo edit mjedit100-cmyk/macrovault --visibility private
```

A private repo cannot be read anonymously. On each PC, add a token that can read contents and releases to the ini file (this field is not shown in the app):

```ini
[General]
GithubToken=github_pat_xxxxxxxx
```

The app sends it as `Authorization: Bearer ...` when it downloads the manifest and the exe. For a private release asset, set `exeUrl` to the API asset URL and the app will also send `Accept: application/octet-stream`.

Do not put the token in the source, and do not commit the ini file.
