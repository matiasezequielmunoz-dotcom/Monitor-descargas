# Panel_Monitor.ps1
# Interfaz grafica (ventana con botones) para controlar el Monitor de Descargas.
# Cada opcion se puede ejecutar haciendo CLIC en el boton, o presionando la
# tecla numerica correspondiente (1-6) en el teclado.

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$TAREA = 'MonitorDescargasDefender'

# ===================== FUNCIONES DE ACCION =====================

function Get-ProcesoActivo {
    $task = Get-ScheduledTask -TaskName $TAREA -ErrorAction SilentlyContinue
    if (-not $task) { return $null }

    $rutaEjecutable = $task.Actions[0].Execute
    $nombreProceso = [System.IO.Path]::GetFileName($rutaEjecutable)

    if ($nombreProceso -ieq 'pythonw.exe') {
        # Modo script .py: hay muchos procesos pythonw.exe posibles, hay que
        # verificar que sea especificamente el que ejecuta nuestro script.
        Get-CimInstance Win32_Process -Filter "Name='pythonw.exe'" -ErrorAction SilentlyContinue |
            Where-Object { $_.CommandLine -like '*monitor_downloads.py*' }
    }
    else {
        # Modo .exe compilado: el nombre del proceso ya es suficientemente especifico.
        Get-CimInstance Win32_Process -Filter "Name='$nombreProceso'" -ErrorAction SilentlyContinue
    }
}

function Iniciar-Monitor {
    $task = Get-ScheduledTask -TaskName $TAREA -ErrorAction SilentlyContinue
    if (-not $task) { return "No se encontro la tarea '$TAREA'. Ejecuta instalar_tarea.ps1 primero." }

    if (Get-ProcesoActivo) { return "El monitor ya estaba activado. No es necesario hacer nada mas." }

    $accion = $task.Actions[0]
    try {
        if ([string]::IsNullOrWhiteSpace($accion.Arguments)) {
            Start-Process -FilePath $accion.Execute -WindowStyle Hidden -ErrorAction Stop
        } else {
            Start-Process -FilePath $accion.Execute -ArgumentList $accion.Arguments -WindowStyle Hidden -ErrorAction Stop
        }
        Start-Sleep -Seconds 1
        return "Listo. El monitor esta corriendo en segundo plano."
    } catch {
        return "No se pudo iniciar el monitor. Detalle: $($_.Exception.Message)"
    }
}

function Detener-Monitor {
    $procesos = Get-ProcesoActivo
    if (-not $procesos) { return "El monitor ya estaba detenido. No es necesario hacer nada mas." }

    foreach ($p in $procesos) {
        try { Stop-Process -Id $p.ProcessId -Force -ErrorAction Stop }
        catch { return "No se pudo detener el proceso (PID $($p.ProcessId)). Detalle: $($_.Exception.Message)" }
    }
    return "Listo. El monitor se detuvo."
}

function Activar-InicioAutomatico {
    try {
        Enable-ScheduledTask -TaskName $TAREA -ErrorAction Stop | Out-Null
        return "Listo. La proxima vez que inicies sesion, el monitor arrancara solo."
    } catch {
        return "No se pudo activar el inicio automatico. Detalle: $($_.Exception.Message)"
    }
}

function Desactivar-InicioAutomatico {
    try {
        Disable-ScheduledTask -TaskName $TAREA -ErrorAction Stop | Out-Null
        return "Listo. El monitor YA NO arrancara solo al iniciar sesion.`r`n(Esto no borra la configuracion, solo la pausa)."
    } catch {
        return "No se pudo desactivar el inicio automatico. Detalle: $($_.Exception.Message)"
    }
}

function Ver-Estado {
    $task = Get-ScheduledTask -TaskName $TAREA -ErrorAction SilentlyContinue
    if (-not $task) { return "No se encontro la tarea '$TAREA'." }

    $autoStart = $task.Settings.Enabled
    $activo = $null -ne (Get-ProcesoActivo)

    if ($activo -and $autoStart)      { $texto = "Activado, Inicio Automatico activado" }
    elseif ($activo -and -not $autoStart) { $texto = "Activado, Inicio Automatico desactivado" }
    elseif (-not $activo -and $autoStart) { $texto = "Desactivado, Inicio Automatico activado" }
    else                               { $texto = "Desactivado, Inicio Automatico desactivado" }

    return "Tarea:  $TAREA`r`nEstado: $texto"
}

# ===================== INTERFAZ GRAFICA =====================

$form = New-Object System.Windows.Forms.Form
$form.Text = "Control - Monitor de Descargas"
$form.Size = New-Object System.Drawing.Size(430, 470)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.KeyPreview = $true  # permite capturar teclas incluso si el foco esta en un boton

$fuenteBoton = New-Object System.Drawing.Font("Segoe UI", 10)

$resultado = New-Object System.Windows.Forms.TextBox
$resultado.Multiline = $true
$resultado.ReadOnly = $true
$resultado.ScrollBars = "Vertical"
$resultado.Location = New-Object System.Drawing.Point(15, 300)
$resultado.Size = New-Object System.Drawing.Size(385, 115)
$resultado.Font = New-Object System.Drawing.Font("Consolas", 9)

function Escribir-Resultado($texto) {
    $resultado.Text = $texto
}

function Crear-Boton($texto, $y, $accion) {
    $boton = New-Object System.Windows.Forms.Button
    $boton.Text = $texto
    $boton.Font = $fuenteBoton
    $boton.Location = New-Object System.Drawing.Point(15, $y)
    $boton.Size = New-Object System.Drawing.Size(385, 40)
    $boton.TextAlign = "MiddleLeft"
    $boton.Padding = New-Object System.Windows.Forms.Padding(10, 0, 0, 0)
    $boton.Add_Click($accion)
    $form.Controls.Add($boton)
    return $boton
}

$btn1 = Crear-Boton "1.  Iniciar el monitor ahora"                         20  { Escribir-Resultado (Iniciar-Monitor) }
$btn2 = Crear-Boton "2.  Detener el monitor ahora"                         65  { Escribir-Resultado (Detener-Monitor) }
$btn3 = Crear-Boton "3.  Activar inicio automatico (al iniciar sesion)"    110 { Escribir-Resultado (Activar-InicioAutomatico) }
$btn4 = Crear-Boton "4.  Desactivar inicio automatico (al iniciar sesion)" 155 { Escribir-Resultado (Desactivar-InicioAutomatico) }
$btn5 = Crear-Boton "5.  Ver estado actual"                                200 { Escribir-Resultado (Ver-Estado) }
$btn6 = Crear-Boton "6.  Salir"                                            245 { $form.Close() }

$form.Controls.Add($resultado)

# Atajos de teclado: presionar 1-6 ejecuta la misma accion que el clic
$form.Add_KeyDown({
    switch ($_.KeyCode) {
        "D1" { Escribir-Resultado (Iniciar-Monitor) }
        "D2" { Escribir-Resultado (Detener-Monitor) }
        "D3" { Escribir-Resultado (Activar-InicioAutomatico) }
        "D4" { Escribir-Resultado (Desactivar-InicioAutomatico) }
        "D5" { Escribir-Resultado (Ver-Estado) }
        "D6" { $form.Close() }
    }
})

# Muestra el estado apenas se abre la ventana, para orientarse de entrada
Escribir-Resultado (Ver-Estado)

[void]$form.ShowDialog()
