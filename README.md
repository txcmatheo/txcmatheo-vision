# Txcmatheo Vision

Juega la PS5 en el PC (con capturadora o PS5 Remote Play) con más fluidez: genera cuadros
intermedios para pasar de 30 o 60 fps a 90–120, con un diseño propio en morado.

Txcmatheo Vision es una versión modificada de **[PushFPS](https://github.com/DosukaSOL/PushFPS)**
(DosukaSOL), que a su vez se basa en **[Veyra NR Video](https://github.com/Likely7/Veyra-NRVideo)**
(Likely7). Todo el mérito del motor, la captura, el streaming y la generación de cuadros es de esos
proyectos. Este repositorio solo contiene los cambios de Txcmatheo.

## Instalar

1. En [Releases](../../releases/latest) descarga el **instalador** (`Txcmatheo-Vision-…-instalador.exe`).
2. Ábrelo y pulsa **Instalar**: no pide permisos de administrador, crea los accesos directos y se puede
   quitar desde *Configuración → Aplicaciones instaladas*.
3. Si Windows avisa de que la app es desconocida: *Más información* → *Ejecutar de todas formas*.

¿Prefieres sin instalar? Las notas de cada release enlazan el **.zip completo**: descomprímelo entero y
abre **`Txcmatheo Vision.exe`** de la carpeta principal.

Requisitos: Windows 10/11 de 64 bits y tarjeta gráfica **NVIDIA**. El archivo
`LEEME - Txcmatheo Vision.txt` explica cómo conectar la PS5.

## Actualizaciones

`Txcmatheo Vision.exe` es un lanzador: al abrirse mira la última release de este repositorio y, si hay
una versión nueva, la descarga, comprueba su SHA-256 e instala sin tocar tus ajustes ni tus perfiles.
Los cambios pequeños llegan como **parche**; cuando cambia el motor, como paquete completo.
Sin internet abre la versión que ya tienes.

## Qué cambia respecto a PushFPS

- Diseño Txcmatheo: tema grafito y morado, logo, intro y portada propios.
- **Perfil automático**: cambia solo entre el perfil de 60 fps y el de 30 según lo que manda la consola.
- **Calidad de VFG por perfil**.
- **Rescate del frame gen**: si una escena pesada lo deja parado, baja la calidad o lo reinicia solo.
- Sin aviso de actualización de PushFPS (las actualiza el lanzador de este repositorio).
- Los mensajes del motor que salían en chino se muestran en inglés (`TxcText.js`).

## Código y licencia

GNU GPL-3.0 (ver `LICENSE`), sin ninguna garantía. Los créditos y avisos legales de PushFPS y Veyra
siguen dentro de la app (*Settings → About*) y en sus archivos `NOTICE.md` y `THIRD_PARTY_NOTICES.md`.

- `qml/Veyra/` — la interfaz (QML) de PushFPS con los cambios de Txcmatheo (`TxcAutoProfile.qml`,
  `TxcFgRescue.qml`, `HomePage.qml`, `Theme.qml`, …).
- `launcher/TxcLauncher.cs` — el lanzador que actualiza.
- `launcher/TxcInstalador.cs` — el instalador de un solo archivo (el zip va pegado al final del .exe).
- `tools/` — los scripts que arman cada versión: cambio de icono y nombre del exe, imágenes,
  versión para compartir y publicación.
- `share/ORIGEN.txt` — de qué versiones de PushFPS y Veyra se parte y dónde está su código fuente.

Nada se recompila: la app es el paquete oficial de Veyra + los archivos de PushFPS + esta interfaz.
