@echo off
rem Ejecuta los tests de SPATIUM IV. Las pruebas de integracion cargan la escena
rem completa (con Terrain3D): cada archivo corre en su propio proceso de Godot.
setlocal
if "%GODOT%"=="" set GODOT=Godot_v4.7.2-stable_win64_console.exe
set ROOT=%~dp0..\game
set FAIL=0
"%GODOT%" --headless --path "%ROOT%" -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gdir=res://tests/unit -gexit || set FAIL=1
for %%F in ("%ROOT%\tests\integration\test_*.gd") do (
  "%GODOT%" --headless --path "%ROOT%" -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gdir=res://tests/integration -gselect=%%~nF -gexit || set FAIL=1
)
if %FAIL%==1 (echo HAY TESTS FALLANDO & exit /b 1) else (echo TODOS LOS TESTS PASARON)
