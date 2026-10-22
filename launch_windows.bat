@echo off
setlocal
rem Append a dot so the quoted path does not end with a backslash. Without it,
rem Godot can parse the closing quote as part of the project directory.
set "PROJECT_DIR=%~dp0."
set "GODOT_EXE="

where godot >nul 2>nul && set "GODOT_EXE=godot"
if not defined GODOT_EXE if exist "%USERPROFILE%\Desktop\Godot_v4.7-stable_win64.exe" set "GODOT_EXE=%USERPROFILE%\Desktop\Godot_v4.7-stable_win64.exe"

if not defined GODOT_EXE (
  echo Godot 4.7 was not found.
  echo Install it or add the godot executable to PATH, then run this file again.
  pause
  exit /b 1
)

"%GODOT_EXE%" --path "%PROJECT_DIR%"
if errorlevel 1 pause
