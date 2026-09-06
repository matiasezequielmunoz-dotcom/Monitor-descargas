# Iniciar_Monitor.ps1
# Lanza el proceso de monitoreo directamente (sin pasar por Start-ScheduledTask,
# que falla si la tarea esta deshabilitada). Usa la misma ruta de python y script
# que ya tiene configurada la tarea programada.

$task = Get-ScheduledTask -TaskName 'MonitorDescargasDefender' -ErrorAction SilentlyContinue

if (-not $task) {
    Write-Host "No se encontro la tarea 'MonitorDescargasDefender'."
    Write-Host "Ejecuta instalar_tarea.ps1 al menos una vez antes de continuar."
    exit
}

# Si ya esta corriendo, no hacemos nada y avisamos amigablemente (sin error)
$rutaEjecutable = $task.Actions[0].Execute
$nombreProceso = [System.IO.Path]::GetFileName($rutaEjecutable)

if ($nombreProceso -ieq 'pythonw.exe') {
    $proceso = Get-CimInstance Win32_Process -Filter "Name='pythonw.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -like '*monitor_downloads.py*' }
} else {
    $proceso = Get-CimInstance Win32_Process -Filter "Name='$nombreProceso'" -ErrorAction SilentlyContinue
}

if ($proceso) {
    Write-Host "El monitor ya estaba activado. No es necesario hacer nada mas."
    exit
}

$accion = $task.Actions[0]

try {
    if ([string]::IsNullOrWhiteSpace($accion.Arguments)) {
        Start-Process -FilePath $accion.Execute -WindowStyle Hidden -ErrorAction Stop
    } else {
        Start-Process -FilePath $accion.Execute -ArgumentList $accion.Arguments -WindowStyle Hidden -ErrorAction Stop
    }
    Start-Sleep -Seconds 1
    Write-Host "Listo. El monitor esta corriendo en segundo plano."
} catch {
    Write-Host "No se pudo iniciar el monitor."
    Write-Host "Detalle: $($_.Exception.Message)"
}
