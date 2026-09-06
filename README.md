[README.md](https://github.com/user-attachments/files/31890112/README.md)
# Download Monitor with Windows Defender

*[🇪🇸 Versión en Español más abajo / Spanish version below](#monitor-de-descargas-con-windows-defender)*

---

Automation system for Windows that forces a **Windows Defender** scan on
every new file that appears in your downloads/frequently used folders, in
real time and with no manual intervention.

## What it does

- Watches multiple folders at once (Downloads, Desktop, Documents,
  Pictures, and any other you configure) using native OS events, not
  polling.
- Detects when a file has **finished** downloading (ignores `.crdownload`,
  `.tmp`, `.part`, etc. while incomplete).
- Runs `MpCmdRun.exe` (the Windows Defender CLI) on that specific file,
  without waiting for Windows' automatic scan cycle.
- If a threat is detected, shows a **native Windows alert window** (not a
  toast notification that gets lost in the Action Center).
- Runs as a single background instance with minimal resource usage
  (~13-18 MB RAM, 0% CPU at rest).
- Starts automatically at login (Windows scheduled task), with a graphical
  panel to start/stop/enable-disable everything with one click.
- **Portable**: the project folder can be moved or renamed anywhere, and it
  self-repairs the next time it's opened.
- Does not require Python installed on the target PC (distributed compiled
  with PyInstaller).

## Architecture

```
Download completes in a watched folder
        │
        ▼
watchdog detects the event (created/moved)
        │
        ▼
Waits for the file size to stabilize
        │
        ▼
Runs: MpCmdRun.exe -Scan -ScanType 3 -File "<path>"
        │
   ┌────┴────┐
  clean    threat
   │         │
  log    alert window (native MessageBox)
```

## Project structure

| File | Role |
|---|---|
| `monitor_downloads.py` | Main engine: watches folders and triggers scans |
| `instalar_tarea.ps1` | Registers the Windows scheduled task (auto-detects whether to use the compiled `.exe` or Python) |
| `Control_Monitor.bat` | Entry point: requests admin permissions, self-repairs the path if the folder was moved, and opens the panel |
| `Panel_Monitor.ps1` | Graphical interface (Windows Forms) with buttons to start/stop/enable/disable/check status |
| `Iniciar_Monitor.ps1` / `Detener_Monitor.ps1` / `Ver_Estado.ps1` | Standalone helper scripts with the same logic as the panel |

## Requirements

- Windows 10 or 11, with Windows Defender active.
- To build from source: Python 3.9+ and the `watchdog`, `plyer`, and
  `pyinstaller` libraries.
- To use it already compiled: **no additional requirements**, not even
  Python.

## Installation (from source)

```powershell
pip install watchdog plyer pyinstaller
pyinstaller --onedir --noconsole --name MonitorDescargas monitor_downloads.py
```

This generates `dist\MonitorDescargas\MonitorDescargas.exe`. Copy that
entire folder (`MonitorDescargas\`, with the `.exe` and the `_internal`
subfolder) next to the rest of the repository's files.

> **Technical note:** `--onedir` is used instead of `--onefile`.
> `--onefile` mode spawns an extra "bootloader" process that stays
> resident in memory, needlessly duplicating processes. `--onedir` runs as
> a single clean instance, at the cost of distributing a folder instead of
> a single file.

## Usage

1. Run `Control_Monitor.bat` (double-click).
2. Accept the administrator permission prompt (required to manage the
   Windows scheduled task).
3. Use the button panel (or keys 1-6) to:
   1. Start the monitor now
   2. Stop the monitor now
   3. Enable auto-start at login
   4. Disable auto-start at login
   5. Check current status
   6. Exit

## Portability

The project is designed to be moved freely: `Control_Monitor.bat`
automatically re-registers the scheduled task pointing to its current
location every time it's opened, preserving whether auto-start was enabled
or disabled. You can cut and paste the entire folder to another location
(or another Windows PC) and it will keep working with no additional manual
steps.

## Configuring which folders to watch

Edit the `CARPETAS_A_VIGILAR` list in `monitor_downloads.py`:

```python
CARPETAS_A_VIGILAR = [
    (str(Path.home() / "Downloads"),  False),
    (str(Path.home() / "Desktop"),    True),   # True = includes subfolders
    (str(Path.home() / "Documents"),  True),
    (str(Path.home() / "Pictures"),   True),
    (r"C:\Programas",                 True),
]
```

Each tuple is `(path, recursive)`. If a folder already covered recursively
contains another folder from the list, don't add the inner one separately
— it would cause duplicate scans.

## Known limitations

- Only detects content by **destination folder**, not directly by "browser
  origin" (if you manually save a file to an unwatched folder, it won't be
  scanned).
- The on-demand CLI scan is a complement to Windows Defender's real-time
  protection, not a replacement — both run in parallel.

## Roadmap / future ideas

- [ ] Browser extension (Native Messaging) to detect downloads by origin
      instead of by destination folder.
- [ ] Structured (JSON) logging for historical analysis.
- [ ] Automatic quarantine of suspicious files.
- [ ] Graphical installer (Inno Setup / NSIS).

## License

Personal learning project. Free to study, adapt, and reuse.

---
---

# Monitor de Descargas con Windows Defender

*[🇬🇧 English version above](#download-monitor-with-windows-defender)*

---

Sistema de automatización para Windows que fuerza un escaneo de **Windows
Defender** sobre cada archivo nuevo que aparece en tus carpetas de
descargas/uso frecuente, en tiempo real y sin intervención manual.

## ¿Qué hace?

- Vigila varias carpetas a la vez (Descargas, Escritorio, Documentos,
  Imágenes, y cualquier otra que configures) usando eventos nativos del
  sistema operativo, no polling.
- Detecta cuándo un archivo **terminó** de descargarse (ignora `.crdownload`,
  `.tmp`, `.part`, etc. mientras está incompleto).
- Ejecuta `MpCmdRun.exe` (la CLI de Windows Defender) sobre ese archivo
  específico, sin esperar al ciclo de escaneo automático de Windows.
- Si detecta una amenaza, muestra una **ventana de alerta nativa de Windows**
  (no una notificación que se pierde en el Centro de actividades).
- Corre como una única instancia en segundo plano, con consumo de recursos
  mínimo (~13-18 MB de RAM, 0% de CPU en reposo).
- Arranca solo al iniciar sesión (tarea programada de Windows), con un panel
  gráfico para iniciar/detener/activar-desactivar todo con un clic.
- **Portable**: se puede mover o renombrar la carpeta del proyecto a
  cualquier lugar, y se auto-repara solo la próxima vez que lo abras.
- No requiere Python instalado en la PC destino (se distribuye compilado
  con PyInstaller).

## Arquitectura

```
Descarga completa en una carpeta vigilada
        │
        ▼
watchdog detecta el evento (created/moved)
        │
        ▼
Se espera a que el tamaño del archivo se estabilice
        │
        ▼
Se invoca: MpCmdRun.exe -Scan -ScanType 3 -File "<ruta>"
        │
   ┌────┴────┐
 limpio   amenaza
   │         │
  log    ventana de alerta (MessageBox nativo)
```

## Estructura del proyecto

| Archivo | Rol |
|---|---|
| `monitor_downloads.py` | Motor principal: vigila carpetas y dispara los escaneos |
| `instalar_tarea.ps1` | Registra la tarea programada de Windows (detecta automáticamente si usar el `.exe` compilado o Python) |
| `Control_Monitor.bat` | Punto de entrada: pide permisos de administrador, auto-repara la ruta si la carpeta se movió, y abre el panel |
| `Panel_Monitor.ps1` | Interfaz gráfica (Windows Forms) con botones para iniciar/detener/activar/desactivar/ver estado |
| `Iniciar_Monitor.ps1` / `Detener_Monitor.ps1` / `Ver_Estado.ps1` | Scripts auxiliares independientes con la misma lógica del panel |

## Requisitos

- Windows 10 o 11, con Windows Defender activo.
- Para compilar desde el código fuente: Python 3.9+ y las librerías
  `watchdog`, `plyer` y `pyinstaller`.
- Para usarlo ya compilado: **ningún requisito adicional**, ni siquiera
  Python.

## Instalación (desde código fuente)

```powershell
pip install watchdog plyer pyinstaller
pyinstaller --onedir --noconsole --name MonitorDescargas monitor_downloads.py
```

Esto genera `dist\MonitorDescargas\MonitorDescargas.exe`. Copia esa carpeta
completa (`MonitorDescargas\`, con el `.exe` y la subcarpeta `_internal`)
junto a los demás archivos del repositorio.

> **Nota técnica:** se usa `--onedir` en vez de `--onefile`. El modo
> `--onefile` genera un proceso "empaquetador" adicional que queda residente
> en memoria, duplicando procesos sin necesidad. `--onedir` corre como una
> única instancia limpia, a costa de distribuir una carpeta en vez de un
> solo archivo.

## Uso

1. Ejecuta `Control_Monitor.bat` (doble clic).
2. Acepta el permiso de administrador (necesario para gestionar la tarea
   programada de Windows).
3. Usa el panel con botones (o las teclas 1-6) para:
   1. Iniciar el monitor ahora
   2. Detener el monitor ahora
   3. Activar inicio automático al iniciar sesión
   4. Desactivar inicio automático al iniciar sesión
   5. Ver estado actual
   6. Salir

## Portabilidad

El proyecto está diseñado para moverse libremente: `Control_Monitor.bat`
re-registra automáticamente la tarea programada apuntando a su ubicación
actual cada vez que se abre, preservando si el inicio automático estaba
activado o desactivado. Podés cortar y pegar la carpeta completa a otra
ubicación (o a otra PC con Windows) y va a seguir funcionando sin pasos
manuales adicionales.

## Configurar qué carpetas vigilar

Edita la lista `CARPETAS_A_VIGILAR` en `monitor_downloads.py`:

```python
CARPETAS_A_VIGILAR = [
    (str(Path.home() / "Downloads"),  False),
    (str(Path.home() / "Desktop"),    True),   # True = incluye subcarpetas
    (str(Path.home() / "Documents"),  True),
    (str(Path.home() / "Pictures"),   True),
    (r"C:\Programas",                 True),
]
```

Cada tupla es `(ruta, recursivo)`. Si una carpeta ya cubierta de forma
recursiva contiene otra carpeta de la lista, no agregues la de adentro
aparte — generaría escaneos duplicados.

## Limitaciones conocidas

- Solo detecta contenido por **carpeta de destino**, no directamente por
  "descargado desde el navegador" (si guardás manualmente un archivo en una
  carpeta no vigilada, no se escaneará).
- El escaneo puntual vía CLI es un complemento a la protección en tiempo
  real de Windows Defender, no un reemplazo — ambos corren en paralelo.

## Roadmap / ideas a futuro

- [ ] Extensión de navegador (Native Messaging) para detectar descargas
      por origen en vez de por carpeta de destino.
- [ ] Logging estructurado (JSON) para análisis histórico.
- [ ] Cuarentena automática de archivos sospechosos.
- [ ] Instalador gráfico (Inno Setup / NSIS).

## Licencia

Proyecto personal de aprendizaje. Libre para estudiar, adaptar y reutilizar.
