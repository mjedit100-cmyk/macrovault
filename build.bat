@echo off
setlocal
set "ROOT=%~dp0"
set "BASE=%ProgramFiles%\AutoHotkey\v2\AutoHotkey64.exe"
set "AHK2EXE=%ProgramFiles%\AutoHotkey\Compiler\Ahk2Exe.exe"
if not exist "%AHK2EXE%" set "AHK2EXE=%LocalAppData%\Programs\AutoHotkey\Compiler\Ahk2Exe.exe"
if not exist "%AHK2EXE%" set "AHK2EXE=%TEMP%\MacroVault-Ahk2Exe\Ahk2Exe.exe"
if not exist "%AHK2EXE%" (
  echo Ahk2Exe was not found.
  echo Install it from https://github.com/AutoHotkey/Ahk2Exe/releases
  echo Then run:
  echo   Ahk2Exe.exe /in "%ROOT%App.ahk" /out "%ROOT%MacroVault.exe" /icon "%ROOT%MacroVault.ico" /base "%BASE%" /compress 0
  exit /b 1
)
if not exist "%BASE%" (
  echo AutoHotkey v2 base was not found at "%BASE%"
  exit /b 1
)
"%AHK2EXE%" /in "%ROOT%App.ahk" /out "%ROOT%MacroVault.exe" /icon "%ROOT%MacroVault.ico" /base "%BASE%" /compress 0 /silent
exit /b %ERRORLEVEL%
