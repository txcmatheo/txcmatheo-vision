# Txcmatheo Vision: publica una versión para que los lanzadores de tus amigos se actualicen solos.
#
#   python tools/publish-txcmatheo.py --owner <usuario-github> --notes "qué cambió" [--full] [--dry-run]
#
# Arma la versión para compartir desde la carpeta personal (Theme.txcShare = true, sin datos
# personales), con el lanzador (launcher/TxcLauncher.cs) en la raíz y la app en app\. Si el motor no
# cambió desde el último paquete completo publicado, sube solo un PARCHE con los archivos distintos;
# si cambió (o con --full), sube el paquete COMPLETO, que es también el que se manda a un amigo nuevo.
# Cada release lleva latest.json (lo que lee el lanzador) con URL, tamaño y SHA-256 de cada paquete.
# Con --dry-run prepara todo en local y no sube nada.
import argparse, hashlib, json, os, re, shutil, subprocess, sys, tempfile, zipfile

REPO_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STATE = os.path.join(REPO_DIR, "publish-state", "state.json")
CSC = r"C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
GH = r"C:\Program Files\GitHub CLI\gh.exe"
GH_REPO = "txcmatheo-vision"
SIGN = os.path.join(REPO_DIR, "launcher", "TxcSign.exe")   # firma con la clave privada (solo en este PC)

def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for c in iter(lambda: f.read(1 << 20), b""): h.update(c)
    return h.hexdigest().upper()

def index(root):
    out = {}
    for d, _, files in os.walk(root):
        for f in files:
            full = os.path.join(d, f)
            out[os.path.relpath(full, root).replace("\\", "/")] = sha256(full)
    return out

def write_version(path, version):
    assert re.fullmatch(r"[0-9.]+", version)
    open(path, "w", encoding="utf-8", newline="\n").write(
        ".pragma library\n// Txcmatheo Vision: versión que se muestra en la pantalla de inicio (HomePage.qml).\n"
        "// La escribe tools/publish-txcmatheo.py en cada release; no editar a mano.\n"
        f'var version = "{version}";\n')

def make_zip(root, rels, dest):
    with zipfile.ZipFile(dest, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as z:
        for rel in sorted(rels): z.write(os.path.join(root, rel), rel)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--app", default=os.path.join(os.path.expanduser("~"), "Desktop", "Txcmatheo Vision"))
    ap.add_argument("--owner", required=True)
    ap.add_argument("--notes", default="")
    ap.add_argument("--full", action="store_true")
    ap.add_argument("--version", default="")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--out", default=os.path.join(tempfile.gettempdir(), "txcmatheo-publish"))
    a = ap.parse_args()

    state = json.load(open(STATE, encoding="utf-8")) if os.path.exists(STATE) else {}
    pv = open(os.path.join(a.app, "PushFPS-VERSION.txt"), encoding="utf-8-sig").read()
    pushfps = re.search(r"PushFPS ([0-9.]+)", pv).group(1)
    engine = re.search(r"Runtime: (.+)", pv).group(1).strip() + " / PushFPS " + pushfps
    n = state.get("n", {}).get(pushfps, 0) + 1
    # Numeración propia, sin seguir la de PushFPS: cada publicación sube el último número de la anterior
    # (4.5.4.2 -> 4.5.4.3 aunque PushFPS vaya por la 5.0.0). --version solo si el usuario pide otro número.
    last = state.get("last")
    if a.version:
        version = a.version
    elif last:
        parts = last.split(".") + ["0"] * (4 - len(last.split(".")))
        parts[-1] = str(int(parts[-1]) + 1)
        version = ".".join(parts)
    else:
        version = pushfps
    assert re.fullmatch(r"[0-9]+(\.[0-9]+){2,3}", version), version
    if last:
        key = lambda v: [int(x) for x in v.split(".")] + [0] * (4 - len(v.split(".")))
        assert key(version) > key(last), f"{version} no es mayor que {last}"
    tag = "v" + version

    if os.path.exists(a.out): shutil.rmtree(a.out)
    stage = os.path.join(a.out, "stage"); os.makedirs(stage)
    # La app para compartir en stage\app
    subprocess.run([sys.executable, os.path.join(REPO_DIR, "tools", "make-txcmatheo-share.py"), a.app, os.path.join(stage, "app")], check=True)
    # La versión que enseña la pantalla de inicio
    write_version(os.path.join(stage, "app", "qml", "Veyra", "TxcVersion.js"), version)
    # Lanzador con el repositorio del dueño
    pub = subprocess.run([SIGN, "pub"], capture_output=True, text=True, check=True).stdout.strip()
    assert pub.startswith("<RSAKeyValue>") and '"' not in pub
    src = open(os.path.join(REPO_DIR, "launcher", "TxcLauncher.cs"), encoding="utf-8").read().replace("__OWNER__", a.owner).replace("__PUBKEY__", pub)
    cs = os.path.join(a.out, "TxcLauncher.cs"); open(cs, "w", encoding="utf-8").write(src)
    ico = os.path.join(a.out, "txc.ico")
    subprocess.run([sys.executable, "-c", "from PIL import Image; Image.open(r'%s').save(r'%s', sizes=[(16,16),(32,32),(48,48),(256,256)])"
                    % (os.path.join(REPO_DIR, "assets", "txcmatheo-logo.png"), ico)], check=True)
    subprocess.run([CSC, "/nologo", "/target:winexe", "/optimize+", "/win32icon:" + ico, "/out:" + os.path.join(stage, "Txcmatheo Vision.exe"),
                    "/r:System.IO.Compression.dll", "/r:System.IO.Compression.FileSystem.dll", "/r:System.Web.Extensions.dll",
                    "/r:System.Windows.Forms.dll", "/r:System.Drawing.dll", cs], check=True)
    shutil.copy2(os.path.join(stage, "app", "LEEME - Txcmatheo Vision.txt"), stage)

    # Paquete completo solo si cambia el motor Veyra; una versión nueva de PushFPS sobre el mismo motor va
    # en parche (solo los archivos distintos, mucho más ligero que el completo de ~830 MB).
    full_needed = a.full or not state.get("base") or state.get("engine", "").split(" / ")[0] != engine.split(" / ")[0]
    base = version if full_needed else state["base"]
    json.dump({"version": version, "base": base}, open(os.path.join(stage, "app", "txc-version.json"), "w"))
    idx = index(stage)

    assets, manifest = [], {"version": version, "engine": engine, "notes": a.notes}
    url = lambda t, name: f"https://github.com/{a.owner}/{GH_REPO}/releases/download/{t}/{name}"
    if full_needed:
        name = f"Txcmatheo-Vision-{version}.zip"
        zpath = os.path.join(a.out, name); make_zip(stage, idx.keys(), zpath)
        manifest["full"] = {"url": url(tag, name), "sha256": sha256(zpath), "size": os.path.getsize(zpath), "base": base}
        manifest["patch"] = None
        assets.append(zpath)
    else:
        prev = state["index"]
        changed = [r for r, h in idx.items() if prev.get(r) != h and r != "app/txc-version.json"]
        name = f"Txcmatheo-Vision-{version}-parche.zip"
        zpath = os.path.join(a.out, name); make_zip(stage, changed, zpath)
        manifest["full"] = state["full"]
        manifest["patch"] = {"url": url(tag, name), "sha256": sha256(zpath), "size": os.path.getsize(zpath), "base": base,
                             "files": len(changed)}
        assets.append(zpath)
        print(f"parche: {len(changed)} archivos cambiados")
    mpath = os.path.join(a.out, "latest.json")
    json.dump(manifest, open(mpath, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
    subprocess.run([SIGN, "sign", mpath], check=True)
    subprocess.run([SIGN, "verify", mpath], check=True)
    assets += [mpath, mpath + ".sig"]
    for p in assets: print(f"{os.path.basename(p)}  {round(os.path.getsize(p) / 1e6, 1)} MB")

    if a.dry_run:
        print("dry-run: nada subido. Carpeta:", a.out); return
    # Para amigos nuevos: el zip y el instalador .exe de esta versión en el escritorio; el .exe va también
    # a la release (con nombre sin espacios: GitHub los cambia por puntos).
    friend = os.path.join(os.path.expanduser("~"), "Desktop", f"Txcmatheo Vision {version} (para amigos).zip")
    subprocess.run([sys.executable, os.path.join(REPO_DIR, "tools", "make-friend-zip.py"), stage, friend], check=True)
    inst_name = f"Txcmatheo-Vision-{version}-instalador.exe"
    inst = os.path.join(a.out, inst_name)
    os.link(friend.replace(" (para amigos).zip", " (instalador).exe"), inst)
    assets.append(inst)
    notes = ((a.notes or "Actualización de Txcmatheo Vision.") +
             "\n\n**¿Ya tienes Txcmatheo Vision con lanzador?** No hagas nada: abre \"Txcmatheo Vision.exe\" (el de fuera de la carpeta app) y se actualiza solo." +
             f"\n\n**¿Primera vez?** Descarga el instalador **{inst_name}** (abajo, en Assets), ábrelo y pulsa Instalar. "
             "Si Windows avisa \"Windows protegió tu PC\", pulsa Más información → Ejecutar de todas formas. A partir de ahí se actualiza solo." +
             f"\n\n¿Prefieres sin instalar? Paquete completo en zip: {manifest['full']['url']} — descomprímelo y abre \"Txcmatheo Vision.exe\".")
    subprocess.run([GH, "release", "create", tag, *assets, "--repo", f"{a.owner}/{GH_REPO}", "--title", f"Txcmatheo Vision {version}",
                    "--notes", notes, "--latest"], check=True)
    state.setdefault("n", {})[pushfps] = n
    state["last"] = version
    if full_needed:
        state.update({"base": base, "engine": engine, "index": idx, "full": manifest["full"]})
    os.makedirs(os.path.dirname(STATE), exist_ok=True)
    json.dump(state, open(STATE, "w", encoding="utf-8"), indent=1)
    # Ya publicada: la app personal y el repositorio enseñan la misma versión
    for p in (os.path.join(a.app, "qml", "Veyra", "TxcVersion.js"), os.path.join(REPO_DIR, "pushfps", "qml", "Veyra", "TxcVersion.js")):
        write_version(p, version)
    print("publicado:", tag)
    # El usuario quiere solo los paquetes de la última versión en el escritorio: los de versiones anteriores
    # ("Txcmatheo Vision <v> (para amigos).zip" / "(instalador).exe") van a la Papelera, solo tras publicar bien.
    desk = os.path.join(os.path.expanduser("~"), "Desktop")
    old = [os.path.join(desk, f) for f in os.listdir(desk)
           if re.fullmatch(r"Txcmatheo Vision [0-9.]+ \((para amigos\)\.zip|instalador\)\.exe)", f)
           and not f.startswith(f"Txcmatheo Vision {version} (")]
    for f in old:
        # La ruta va dentro del comando (con -Command, $args no recibe los argumentos que siguen).
        quoted = "'" + f.replace("'", "''") + "'"
        subprocess.run(["powershell", "-NoProfile", "-Command",
                        "Add-Type -AssemblyName Microsoft.VisualBasic; [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile("
                        + quoted + ", 'OnlyErrorDialogs', 'SendToRecycleBin')"], check=True)
        print("a la Papelera:", os.path.basename(f))

main()
