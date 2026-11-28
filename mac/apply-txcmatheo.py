# Txcmatheo Vision para Mac: pone el diseño Txcmatheo a la app de Linux/macOS de PushFPS (portable/).
#
#   python3 mac/apply-txcmatheo.py <carpeta de PushFPS> <versión de Txcmatheo Vision>
#
# La app de Mac de PushFPS es otra app (más pequeña: capturadora, frame gen propio, sin NVIDIA) y su
# interfaz va compilada dentro, así que no basta con copiar QML como en Windows: este script cambia la
# copia de PushFPS antes de compilarla (lo hace .github/workflows/build-mac.yml en un Mac de GitHub).
#   - Theme.qml y PushWordmark.qml de Txcmatheo (grafito + morado, "Txcmatheo Vision"), compartidos con Windows;
#   - logo e icono Txcmatheo; nombre de la app, del paquete .app y textos de permisos de macOS;
#   - "Acerca de" con los créditos de PushFPS (DosukaSOL) y Veyra (Likely7), que se mantienen (GPL-3.0).
# Falla si algo no está donde se espera (otra versión de PushFPS): mejor no compilar que compilar a medias.
import os, re, sys
from PIL import Image

src, version = sys.argv[1], sys.argv[2]
assert re.fullmatch(r"[0-9]+(\.[0-9]+){2,3}", version), version
here = os.path.dirname(os.path.abspath(__file__))
repo = os.path.dirname(here)

def edit(rel, reps):
    p = os.path.join(src, rel)
    s = open(p, encoding="utf-8").read()
    for a, b in reps:
        n = s.count(a)
        assert n >= 1, f"{rel}: no encuentro {a!r}"
        s = s.replace(a, b)
    open(p, "w", encoding="utf-8").write(s)
    print("cambiado:", rel)

# 1. Diseño compartido con Windows (los mismos archivos que usa Txcmatheo Vision en Windows).
for name in ("Theme.qml", "PushWordmark.qml"):
    s = open(os.path.join(repo, "qml", "Veyra", name), encoding="utf-8").read()
    if name == "Theme.qml":
        # La app de Mac solo lleva logo.png (sin logo-dusk ni fondos dusk): mismas imágenes en todos los modos.
        s, n1 = re.subn(r'readonly property string backdropImage: .*', 'readonly property string backdropImage: "backdrop.png"', s)
        s, n2 = re.subn(r'readonly property string logoImage: .*', 'readonly property string logoImage: "logo.png"', s)
        assert n1 == 1 and n2 == 1, "Theme.qml: no encuentro backdropImage/logoImage"
    open(os.path.join(src, "qml", "Veyra", name), "w", encoding="utf-8").write(s)
    print("copiado:", "qml/Veyra/" + name)

# 2. Logo (barra de título) e icono de la app.
logo = Image.open(os.path.join(repo, "assets", "txcmatheo-logo.png")).convert("RGBA")
logo.resize((1024, 1024), Image.LANCZOS).save(os.path.join(src, "portable", "app", "qml", "icon.png"))
canvas = Image.new("RGBA", (360, 240), (0, 0, 0, 0))
canvas.paste(logo.resize((240, 240), Image.LANCZOS), (60, 0))
canvas.save(os.path.join(src, "portable", "app", "qml", "logo.png"))
print("logo e icono Txcmatheo")

# 3. Nombre de la app y del paquete.
edit("portable/app/CMakeLists.txt", [
    ("OUTPUT_NAME PushFPS", "OUTPUT_NAME TxcmatheoVision"),
    ("MACOSX_BUNDLE_GUI_IDENTIFIER io.github.dosukasol.pushfps", "MACOSX_BUNDLE_GUI_IDENTIFIER io.github.txcmatheo.vision"),
    ("MACOSX_BUNDLE_BUNDLE_NAME PushFPS", 'MACOSX_BUNDLE_BUNDLE_NAME "Txcmatheo Vision"'),
    ("MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION}", f"MACOSX_BUNDLE_SHORT_VERSION_STRING {version}"),
])
edit("portable/app/packaging/Info.plist.in", [
    ("<string>PushFPS.icns</string>", "<string>AppIcon.icns</string>"),
    ("<key>CFBundleDisplayName</key>\n    <string>PushFPS</string>", "<key>CFBundleDisplayName</key>\n    <string>Txcmatheo Vision</string>"),
    ("<string>PushFPS shows the picture", "<string>Txcmatheo Vision shows the picture"),
    ("<string>PushFPS plays the sound", "<string>Txcmatheo Vision plays the sound"),
])
edit("portable/app/qml/Main.qml", [('title: "PushFPS"', 'title: "Txcmatheo Vision"')])

# 4. Ajustes → Acerca de: nuestro nombre y versión, con los créditos de PushFPS y Veyra.
edit("portable/app/qml/SettingsPage.qml", [
    ('Line { text: "PushFPS " + app.version + " · " + app.platformName }',
     f'Line {{ text: "Txcmatheo Vision {version} para Mac · basado en PushFPS " + app.version + " (DosukaSOL) y Veyra (Likely7) · " + app.platformName }}'),
    ('qsTr("PushFPS 绿")', '"Txcmatheo"'),
])
print("listo: Txcmatheo Vision", version, "para Mac")
