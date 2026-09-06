# Ver_Estado.ps1
# Verifica de forma independiente:
#   1) si el proceso de monitoreo esta corriendo AHORA MISMO
#   2) si el inicio automatico (al iniciar sesion) esta habilitado
# y muestra el estado combinado en español, en la terminal.

$task = Get-ScheduledTask -TaskName 'MonitorDescargasDefender' -ErrorAction SilentlyContinue

if (-not $task) {
    Write-Host "No se encontro la tarea 'MonitorDescargasDefender'."
    Write-Host "Verifica que se haya ejecutado instalar_tarea.ps1 al menos una vez."
    exit
}

# Inicio automatico habilitado/deshabilitado (independiente de si esta corriendo)
$autoStart = $task.Settings.Enabled

# Proceso corriendo AHORA MISMO (se adapta segun si la tarea usa el .exe compilado o pythonw.exe)
$rutaEjecutable = $task.Actions[0].Execute
$nombreProceso = [System.IO.Path]::GetFileName($rutaEjecutable)

if ($nombreProceso -ieq 'pythonw.exe') {
    $proceso = Get-CimInstance Win32_Process -Filter "Name='pythonw.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -like '*monitor_downloads.py*' }
} else {
    $proceso = Get-CimInstance Win32_Process -Filter "Name='$nombreProceso'" -ErrorAction SilentlyContinue
}
$activo = $null -ne $proceso

if ($activo -and $autoStart) {
    $texto = "Activado, Inicio Automatico activado"
} elseif ($activo -and -not $autoStart) {
    $texto = "Activado, Inicio Automatico desactivado"
} elseif (-not $activo -and $autoStart) {
    $texto = "Desactivado, Inicio Automatico activado"
} else {
    $texto = "Desactivado, Inicio Automatico desactivado"
}

Write-Host ""
Write-Host "Tarea:  MonitorDescargasDefender"
Write-Host "Estado: $texto"
