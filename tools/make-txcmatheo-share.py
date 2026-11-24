# Txcmatheo Vision: arma la versión para compartir a partir de la carpeta personal.
#
#   python tools/make-txcmatheo-share.py "<carpeta personal>" "<carpeta de salida>" [--zip "<archivo.zip>"] [--dlss]
#
#   --dlss: variante para tarjetas potentes (RTX 40/50): los perfiles encienden el realce de imagen
#   por IA (AI picture enhancement, "DLSS 5 NR") y usan VFG en calidad Medium.
#
# Qué cambia respecto a la versión personal:
#   - Theme.txcShare = true: no comprueba ni avisa de actualizaciones y quita la fila de Ajustes.
#   - Sin datos personales: ni logs, ni la capturadora o la sesión del usuario, ni copias .bak / .old.
#     El emparejamiento de la PS5 nunca va dentro de la carpeta (está en %LOCALAPPDATA%\Veyra).
#   - Ajustes de partida genéricos: inglés, música de inicio, perfiles FC 27 / GTA VI, sin protección de HUD.
#   - LEEME para los amigos y la carpeta codigo-fuente (GPL-3.0: licencia, créditos y fuente se conservan).
import json, os, shutil, sys, zipfile

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def main():
    args = sys.argv[1:]
    zip_out = None
    dlss = "--dlss" in args
    if dlss: args.remove("--dlss")
    if "--zip" in args:
        i = args.index("--zip"); zip_out = args[i + 1]; del args[i:i + 2]
    src, out = args
    if os.path.exists(out):
        sys.exit(f"ya existe: {out}")

    def skip(rel):
        r = rel.replace("\\", "/")
        name = r.rsplit("/", 1)[-1]
        return (r.startswith("logs/") or r.startswith("runtime_local/user-data")
                or name.endswith((".bak", ".dmp")) or ".old" in name or name.startswith("RESPALDO"))

    n = 0
    for root, dirs, files in os.walk(src):
        for f in files:
            full = os.path.join(root, f)
            rel = os.path.relpath(full, src)
            if skip(rel):
                continue
            dst = os.path.join(out, rel)
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            shutil.copy2(full, dst); n += 1
    os.makedirs(os.path.join(out, "logs"), exist_ok=True)

    # Modo para compartir
    theme = os.path.join(out, "qml", "Veyra", "Theme.qml")
    s = open(theme, encoding="utf-8").read()
    assert s.count("readonly property bool txcShare: false") == 1
    open(theme, "w", encoding="utf-8", newline="").write(s.replace("txcShare: false", "txcShare: true"))

    # Ajustes de partida (sin nada del PC del usuario)
    ud = os.path.join(out, "runtime_local", "user-data-2.0.0")
    os.makedirs(ud, exist_ok=True)
    def game(name, fps):
        g = {"fps": fps, "target": "120", "enhance": dlss, "adaptive": False, "pacing": False,
             "hudLock": False, "lowLatency": False, "name": name, "console": "ps5", "preset": ""}
        if dlss: g["vfgQuality"] = 1      # Medium
        return g
    prefs = {
        "language": "en", "introMusic": True, "volume": 1,
        "hudLock": False, "fgAdaptive": False, "pacingRepair": False, "vfgAutoRegulate": True,
        "pushConsole": "ps5", "pushGameFps": 60,
        "pushProfiles": json.dumps({"games": [game("FC 27", 60), game("GTA VI", 30)], "game": "FC 27", "v": 1},
                                   separators=(",", ":")),
    }
    open(os.path.join(ud, "qml-preferences.v1.json"), "w", encoding="utf-8").write(json.dumps(prefs, indent=4))

    # LEEME y código fuente
    shutil.copy2(os.path.join(REPO, "share", "LEEME - Txcmatheo Vision.txt"), out)
    if dlss:
        with open(os.path.join(out, "LEEME - Txcmatheo Vision.txt"), "a", encoding="utf-8") as f:
            f.write(open(os.path.join(REPO, "share", "LEEME-DLSS.txt"), encoding="utf-8").read())
    cf = os.path.join(out, "codigo-fuente")
    os.makedirs(os.path.join(cf, "tools"), exist_ok=True)
    for t in ("rebrand-txcmatheo-exe.py", "make-txcmatheo-assets.py", "make-txcmatheo-share.py"):
        shutil.copy2(os.path.join(REPO, "tools", t), os.path.join(cf, "tools", t))
    shutil.copy2(os.path.join(REPO, "share", "ORIGEN.txt"), cf)

    print(f"ok: {n} archivos en {out}")
    if zip_out:
        top = os.path.basename(os.path.normpath(out))
        with zipfile.ZipFile(zip_out + ".part", "w", zipfile.ZIP_DEFLATED, compresslevel=6) as z:
            for root, dirs, files in os.walk(out):
                if not files and not dirs:
                    z.writestr(os.path.relpath(root, os.path.dirname(out)).replace("\\", "/") + "/", "")
                for f in files:
                    full = os.path.join(root, f)
                    z.write(full, os.path.join(top, os.path.relpath(full, out)))
        os.replace(zip_out + ".part", zip_out)
        print(f"zip: {zip_out} ({round(os.path.getsize(zip_out) / 1e6)} MB)")

main()
