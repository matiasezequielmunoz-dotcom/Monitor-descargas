"""
monitor_downloads.py
---------------------
Monitorea la carpeta de Descargas y fuerza un escaneo de Windows Defender
(MpCmdRun.exe) sobre cada archivo nuevo en cuanto termina de descargarse.

Probado para: Windows 10 Home 22H2 (build 19045)
Requisitos:
    pip install watchdog plyer

Uso:
    python monitor_downloads.py
    (Ctrl+C para detener)

Recomendado: ejecutar como tarea programada al iniciar sesión (ver sección
"Ejecución automática" en la guía adjunta).
"""

import os
import sys
import time
import ctypes
import logging
import threading
import subprocess
from pathlib import Path
from datetime import datetime

from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

# Ya no usamos 'plyer' para las alertas de amenaza: ahora se muestran como
# una ventana nativa de Windows (MessageBox) mediante ctypes, sin dependencias
# externas. Se deja plyer como opción para avisos NO urgentes si se desea.
try:
    from plyer import notification
    NOTIFICACIONES_DISPONIBLES = True
except ImportError:
    NOTIFICACIONES_DISPONIBLES = False

# Constantes de la API de Windows para MessageBoxW
MB_OK = 0x0
MB_ICONWARNING = 0x30
MB_ICONINFORMATION = 0x40
MB_SYSTEMMODAL = 0x1000  # Fuerza que la ventana quede siempre al frente

# ============ CONFIGURACIÓN ============

# Carpetas a vigilar. Cada tupla es (ruta, recursivo).
# recursivo=True tambien vigila TODAS las subcarpetas dentro de esa ruta.
# Ojo: si dos rutas de la lista quedan "una dentro de la otra" (ej. Escritorio
# y Escritorio\Juegos) y la de afuera es recursiva, NO agregues la de adentro
# aparte -- ya queda cubierta, y agregarla de nuevo generaria doble escaneo.
CARPETAS_A_VIGILAR = [
    (str(Path.home() / "Downloads"),  False),  # Descargas: no hace falta recursivo
    (str(Path.home() / "Desktop"),    True),   # Escritorio (incluye Juegos automaticamente)
    (str(Path.home() / "Documents"),  True),   # Documentos
    (str(Path.home() / "Pictures"),   True),   # Imagenes
    (r"C:\Programas",                 True),   # Carpeta personal de programas
]

# Ruta estándar de MpCmdRun.exe en Windows 10
RUTA_DEFENDER_CLI = r"C:\Program Files\Windows Defender\MpCmdRun.exe"

# Extensiones que indican una descarga incompleta (se ignoran hasta que cambien)
EXTENSIONES_TEMPORALES = {".crdownload", ".tmp", ".part", ".download", ".partial"}

# Cuánto esperar (segundos) entre lecturas de tamaño para confirmar que el
# archivo terminó de escribirse en disco (importante en HDD: más lento que SSD)
INTERVALO_VERIFICACION = 1.5
LECTURAS_ESTABLES_REQUERIDAS = 3  # nº de lecturas iguales seguidas

# Archivo de log
RUTA_LOG = str(Path.home() / "monitor_descargas.log")

logging.basicConfig(
    filename=RUTA_LOG,
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)
console = logging.StreamHandler(sys.stdout)
console.setLevel(logging.INFO)
logging.getLogger().addHandler(console)


# ============ UTILIDADES ============

def _mostrar_ventana_alerta(titulo: str, mensaje: str, icono: int):
    """
    Abre una ventana modal nativa de Windows (MessageBox). Se ejecuta en un
    hilo aparte para no bloquear el monitoreo mientras el usuario no la cierra.
    """
    try:
        ctypes.windll.user32.MessageBoxW(
            0, mensaje, titulo, icono | MB_SYSTEMMODAL
        )
    except Exception as e:
        logging.warning(f"No se pudo mostrar la ventana de alerta: {e}")


def notificar(titulo: str, mensaje: str, urgente: bool = False):
    """
    Muestra una alerta. Las urgentes (amenaza detectada / error crítico) se
    muestran como una VENTANA de Windows que exige clic en 'Aceptar'.
    Las no urgentes usan una notificación toast normal (si plyer está disponible).
    """
    logging.info(f"ALERTA: {titulo} - {mensaje}")

    if urgente:
        icono = MB_ICONWARNING
        # Se lanza en un hilo daemon para que la ventana no congele el
        # observador de watchdog mientras espera a que el usuario la cierre.
        hilo = threading.Thread(
            target=_mostrar_ventana_alerta,
            args=(titulo, mensaje, icono),
            daemon=True,
        )
        hilo.start()
    elif NOTIFICACIONES_DISPONIBLES:
        try:
            notification.notify(
                title=titulo,
                message=mensaje,
                app_name="Monitor de Descargas",
                timeout=5,
            )
        except Exception as e:
            logging.warning(f"No se pudo mostrar notificación: {e}")


def es_archivo_temporal(ruta: str) -> bool:
    return Path(ruta).suffix.lower() in EXTENSIONES_TEMPORALES


def esperar_archivo_completo(ruta: str, timeout: int = 120) -> bool:
    """
    Espera hasta que el tamaño del archivo deje de cambiar, indicando que
    la descarga terminó. Devuelve False si el archivo desaparece o si se
    supera el timeout.
    """
    inicio = time.time()
    tamano_anterior = -1
    lecturas_iguales = 0

    while time.time() - inicio < timeout:
        if not os.path.exists(ruta):
            return False  # el archivo fue renombrado/movido/borrado

        try:
            tamano_actual = os.path.getsize(ruta)
        except OSError:
            time.sleep(INTERVALO_VERIFICACION)
            continue

        if tamano_actual == tamano_anterior and tamano_actual > 0:
            lecturas_iguales += 1
            if lecturas_iguales >= LECTURAS_ESTABLES_REQUERIDAS:
                return True
        else:
            lecturas_iguales = 0

        tamano_anterior = tamano_actual
        time.sleep(INTERVALO_VERIFICACION)

    return False


def escanear_con_defender(ruta: str) -> tuple[bool, str]:
    """
    Invoca MpCmdRun.exe sobre un archivo específico.
    Retorna (limpio: bool, salida_completa: str)
    """
    if not os.path.exists(RUTA_DEFENDER_CLI):
        raise FileNotFoundError(
            f"No se encontró MpCmdRun.exe en {RUTA_DEFENDER_CLI}. "
            "Verifica que Windows Defender esté instalado y activo."
        )

    comando = [
        RUTA_DEFENDER_CLI,
        "-Scan",
        "-ScanType", "3",      # 3 = escaneo personalizado (archivo/carpeta específica)
        "-File", ruta,
        "-DisableRemediation", "false",  # permite que Defender actúe si hay amenaza
    ]

    # CREATE_NO_WINDOW evita que Windows muestre brevemente una ventana de
    # consola al lanzar MpCmdRun.exe (que es un programa de consola), aunque
    # nuestro programa principal no tenga consola propia.
    banderas_sin_ventana = getattr(subprocess, "CREATE_NO_WINDOW", 0)

    try:
        resultado = subprocess.run(
            comando,
            capture_output=True,
            text=True,
            timeout=180,
            creationflags=banderas_sin_ventana,
        )
        salida = resultado.stdout + resultado.stderr
        # MpCmdRun devuelve 0 si no hay amenazas
        limpio = resultado.returncode == 0
        return limpio, salida
    except subprocess.TimeoutExpired:
        return False, "El escaneo superó el tiempo límite (180s)."
    except PermissionError:
        return False, (
            "Permiso denegado al ejecutar MpCmdRun.exe. "
            "Prueba ejecutando este script como Administrador."
        )


# ============ MANEJADOR DE EVENTOS ============

class ManejadorDescargas(FileSystemEventHandler):

    def on_created(self, event):
        if event.is_directory:
            return
        self._procesar(event.src_path)

    def on_moved(self, event):
        # Cuando el navegador renombra "archivo.crdownload" -> "archivo.pdf"
        if event.is_directory:
            return
        self._procesar(event.dest_path)

    def _procesar(self, ruta: str):
        if es_archivo_temporal(ruta):
            logging.info(f"Ignorando archivo temporal: {ruta}")
            return

        nombre = os.path.basename(ruta)
        logging.info(f"Nuevo archivo detectado: {nombre}. Esperando a que termine de escribirse...")

        if not esperar_archivo_completo(ruta):
            logging.warning(f"'{nombre}' no se estabilizó o desapareció. Se omite el escaneo.")
            return

        logging.info(f"Escaneando '{nombre}' con Windows Defender...")
        try:
            limpio, salida = escanear_con_defender(ruta)
        except FileNotFoundError as e:
            logging.error(str(e))
            notificar("Error de configuración", str(e), urgente=True)
            return

        if limpio:
            logging.info(f"'{nombre}' escaneado: SIN AMENAZAS.")
        else:
            logging.error(f"'{nombre}' -> POSIBLE AMENAZA DETECTADA.\nSalida:\n{salida}")
            notificar(
                "⚠️ Amenaza detectada",
                f"Windows Defender encontró un problema en: {nombre}",
                urgente=True,
            )


# ============ PROGRAMA PRINCIPAL ============

def main():
    if not NOTIFICACIONES_DISPONIBLES:
        logging.warning(
            "El paquete 'plyer' no está instalado; no se mostrarán notificaciones "
            "de escritorio. Instálalo con: pip install plyer"
        )

    logging.info(f"Usando motor: {RUTA_DEFENDER_CLI}")

    manejador = ManejadorDescargas()
    observador = Observer()

    carpetas_activas = 0
    for ruta, recursivo in CARPETAS_A_VIGILAR:
        if not os.path.isdir(ruta):
            logging.warning(f"La carpeta '{ruta}' no existe, se omite.")
            continue
        observador.schedule(manejador, ruta, recursive=recursivo)
        logging.info(f"Vigilando: {ruta} (recursivo={recursivo})")
        carpetas_activas += 1

    if carpetas_activas == 0:
        print("Ninguna de las carpetas configuradas existe. Revisa CARPETAS_A_VIGILAR.")
        sys.exit(1)

    observador.start()

    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        logging.info("Deteniendo monitoreo (Ctrl+C detectado).")
        observador.stop()
    observador.join()


if __name__ == "__main__":
    main()
