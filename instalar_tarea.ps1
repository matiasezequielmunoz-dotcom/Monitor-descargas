<#
instalar_tarea.ps1
-------------------
Registra una tarea programada de Windows que ejecuta el monitor de descargas
automaticamente cada vez que inicias sesion, sin ventana visible.

Detecta automaticamente:
  - Si existe MonitorDescargas.exe (version compilada con PyInstaller) -> lo usa
    directamente, SIN necesitar Python instalado.
  - Si no existe, busca monitor_downloads.py y pythonw.exe (version original).

Uso manual:
    powershell.exe -ExecutionPolicy Bypass -File ".\instalar_tarea.ps1"

Uso silencioso (lo usa Control_Monitor.bat automaticamente en cada apertura,
para que el proyecto sea "portable": si moviste o renombraste la carpeta,
se auto-repara sin pedirte nada):
    powershell.exe -ExecutionPolicy Bypass -File ".\instalar_tarea.ps1" -Silencioso
#>

param(
    [switch]$Silencioso
)

$ErrorActionPreference = "Stop"

$carpetaScript = Split-Path -Parent $MyInvocation.MyCommand.Path
$rutaExeDirecta = Join-Path $carpetaScript "MonitorDescargas.exe"
$rutaExeEnSubcarpeta = Join-Path $carpetaScript "MonitorDescargas\MonitorDescargas.exe"
$rutaScriptPython = Join-Path $carpetaScript "monitor_downloads.py"

if (Test-Path $rutaExeEnSubcarpeta) {
    $usarExe = $true
    $rutaExe = $rutaExeEnSubcarpeta
} elseif (Test-Path $rutaExeDirecta) {
    $usarExe = $true
    $rutaExe = $rutaExeDirecta
} else {
    $usarExe = $false
}

if ($usarExe) {
    if (-not $Silencioso) {
        Write-Host "Version compilada encontrada: $rutaExe" -ForegroundColor Green
        Write-Host "No se necesita Python instalado en este equipo." -ForegroundColor Green
    }
    $ejecutable = $rutaExe
    $argumentos = $null
}
else {
    if (-not (Test-Path $rutaScriptPython)) {
        if ($Silencioso) { exit 1 }
        Write-Host "ERROR: No se encontro ni MonitorDescargas.exe ni monitor_downloads.py en:" -ForegroundColor Red
        Write-Host "  $carpetaScript"
        Read-Host "Presiona Enter para salir"
        exit 1
    }

    $pythonw = (Get-Command pythonw.exe -ErrorAction SilentlyContinue).Source
    if (-not $pythonw) {
        if ($Silencioso) { exit 1 }
        Write-Host "ERROR: No se encontro pythonw.exe en el PATH del sistema." -ForegroundColor Red
        Write-Host "Verifica que Python este instalado y agregado al PATH," -ForegroundColor Red
        Write-Host "o genera MonitorDescargas.exe con PyInstaller para no depender de Python." -ForegroundColor Red
        Read-Host "Presiona Enter para salir"
        exit 1
    }

    if (-not $Silencioso) {
        Write-Host "Python encontrado en: $pythonw" -ForegroundColor Green
        Write-Host "Script a ejecutar:    $rutaScriptPython" -ForegroundColor Green
    }
    $ejecutable = $pythonw
    $argumentos = "`"$rutaScriptPython`""
}

$nombreTarea = "MonitorDescargasDefender"

# Si ya existe una tarea previa con este nombre, se elimina para evitar duplicados.
# Antes de borrarla, guardamos si el inicio automatico estaba activado o
# desactivado, para restaurar ese mismo estado despues de re-registrarla
# (sin esto, cada auto-reparacion "reactivaria" el inicio automatico sin querer).
$tareaExistente = Get-ScheduledTask -TaskName $nombreTarea -ErrorAction SilentlyContinue
$estabaHabilitada = $null
if ($tareaExistente) {
    $estabaHabilitada = $tareaExistente.Settings.Enabled
    if (-not $Silencioso) { Write-Host "Ya existe una tarea previa. Se reemplazara..." -ForegroundColor Yellow }
    Unregister-ScheduledTask -TaskName $nombreTarea -Confirm:$false
}

if ($argumentos) {
    $accion = New-ScheduledTaskAction -Execute $ejecutable -Argument $argumentos
} else {
    $accion = New-ScheduledTaskAction -Execute $ejecutable
}

$disparador = New-ScheduledTaskTrigger -AtLogOn
$configuracion = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Days 0)  # sin limite de tiempo de ejecucion

Register-ScheduledTask `
    -TaskName $nombreTarea `
    -Action $accion `
    -Trigger $disparador `
    -Settings $configuracion `
    -Description "Monitorea la carpeta Descargas y escanea archivos nuevos con Windows Defender" `
    -Force | Out-Null

# Restaurar el estado de habilitado/deshabilitado que tenia antes de re-registrar.
# Si la tarea no existia previamente (primera instalacion), queda habilitada
# por defecto, que es el comportamiento esperado en una instalacion nueva.
if ($estabaHabilitada -eq $false) {
    Disable-ScheduledTask -TaskName $nombreTarea | Out-Null
}

if (-not $Silencioso) {
    Write-Host ""
    Write-Host "===========================================================" -ForegroundColor Cyan
    Write-Host " Tarea '$nombreTarea' registrada correctamente." -ForegroundColor Cyan
    Write-Host " Se ejecutara automaticamente la proxima vez que inicies sesion." -ForegroundColor Cyan
    Write-Host "===========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Para probarlo AHORA sin reiniciar, ejecuta:"
    Write-Host "  Start-ScheduledTask -TaskName '$nombreTarea'" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Para verificar que quedo activo:"
    Write-Host "  Get-ScheduledTask -TaskName '$nombreTarea'" -ForegroundColor Yellow
    Write-Host ""
    Read-Host "Presiona Enter para cerrar"
}
