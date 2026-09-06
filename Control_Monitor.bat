@echo off
title Control - Monitor de Descargas

:: Verifica si se esta ejecutando como Administrador; si no, se relanza
:: a si mismo pidiendo el permiso automaticamente.
net session >nul 2>&1
if %errorLevel% NEQ 0 (
    echo Solicitando permisos de administrador...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

:: Auto-reparacion: registra/actualiza la tarea programada apuntando a la
:: ubicacion ACTUAL de esta carpeta. Esto hace que el proyecto sea portable:
:: si moviste o renombraste la carpeta, se corrige solo, sin pasos manuales.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0instalar_tarea.ps1" -Silencioso >nul 2>&1

:: Abre el panel grafico (con botones clickeables + atajos de teclado 1-6)
powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0Panel_Monitor.ps1"
exit
