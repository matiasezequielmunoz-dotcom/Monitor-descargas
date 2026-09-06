# Detener_Monitor.ps1
# Detiene el proceso de monitoreo directamente buscandolo por su linea de
# comando (funciona sin importar si se inicio via tarea programada o manualmente).

$task = Get-ScheduledTask -TaskName 'MonitorDescargasDefender' -ErrorAction SilentlyContinue
if (-not $task) {
    Write-Host "No se encontro la tarea 'MonitorDescargasDefender'."
    exit
}

$rutaEjecutable = $task.Actions[0].Execute
$nombreProceso = [System.IO.Path]::GetFileName($rutaEjecutable)

if ($nombreProceso -ieq 'pythonw.exe') {
    $proceso = Get-CimInstance Win32_Process -Filter "Name='pythonw.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -like '*monitor_downloads.py*' }
} else {
    $proceso = Get-CimInstance Win32_Process -Filter "Name='$nombreProceso'" -ErrorAction SilentlyContinue
}

if (-not $proceso) {
    Write-Host "El monitor ya estaba detenido. No es necesario hacer nada mas."
    exit
}

foreach ($p in $proceso) {
    try {
        Stop-Process -Id $p.ProcessId -Force -ErrorAction Stop
    } catch {
        Write-Host "No se pudo detener el proceso (PID $($p.ProcessId))."
        Write-Host "Detalle: $($_.Exception.Message)"
    }
}

Write-Host "Listo. El monitor se detuvo."
