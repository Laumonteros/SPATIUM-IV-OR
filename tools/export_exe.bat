@echo off
rem Exporta build\SPATIUM_IV.exe (regla del proyecto). Usa la variable GODOT o el exe en el PATH.
if "%GODOT%"=="" set GODOT=Godot_v4.7.2-stable_win64_console.exe
if not exist "%~dp0..uild" mkdir "%~dp0..uild"
"%GODOT%" --headless --path "%~dp0..\game" --export-release "Windows Desktop" ../build/SPATIUM_IV.exe
if not exist "%~dp0..uild\SPATIUM_IV.exe" (echo ERROR: no se genero el .exe & exit /b 1)
echo EXE LISTO: build\SPATIUM_IV.exe
