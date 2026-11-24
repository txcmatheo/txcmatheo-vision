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

def make_zip(root, rels, dest):
    with zipfile.ZipFile(dest, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as z:
        for rel in sorted(rels): z.write(os.path.join(root, rel), rel)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--app", default=os.path.join(os.path.expanduser("~"), "Desktop", "Txcmatheo Vision 4.5.0"))
    ap.add_argument("--owner", required=True)
    ap.add_argument("--notes", default="")
    ap.add_argument("--full", action="store_true")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--out", default=os.path.join(tempfile.gettempdir(), "txcmatheo-publish"))
    a = ap.parse_args()

    state = json.load(open(STATE, encoding="utf-8")) if os.path.exists(STATE) else {}
    pv = open(os.path.join(a.app, "PushFPS-VERSION.txt"), encoding="utf-8-sig").read()
    pushfps = re.search(r"PushFPS ([0-9.]+)", pv).group(1)
    engine = re.search(r"Runtime: (.+)", pv).group(1).strip() + " / PushFPS " + pushfps
    n = state.get("n", {}).get(pushfps, 0) + 1
    # 4.5.0 la primera publicación sobre PushFPS 4.5.0; después 4.5.0.1, 4.5.0.2…
    version = pushfps if n == 1 else f"{pushfps}.{n - 1}"
    tag = "v" + version

    if os.path.exists(a.out): shutil.rmtree(a.out)
    stage = os.path.join(a.out, "stage"); os.makedirs(stage)
    # La app para compartir en stage\app
    subprocess.run([sys.executable, os.path.join(REPO_DIR, "tools", "make-txcmatheo-share.py"), a.app, os.path.join(stage, "app")], check=True)
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

    full_needed = a.full or not state.get("base") or state.get("engine") != engine
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
    notes = (a.notes or "Actualización de Txcmatheo Vision.") + "\n\nPara instalar por primera vez: descarga el .zip completo, descomprímelo y abre \"Txcmatheo Vision.exe\"."
    subprocess.run([GH, "release", "create", tag, *assets, "--repo", f"{a.owner}/{GH_REPO}", "--title", f"Txcmatheo Vision {version}",
                    "--notes", notes, "--latest"], check=True)
    state.setdefault("n", {})[pushfps] = n
    state["last"] = version
    if full_needed:
        state.update({"base": base, "engine": engine, "index": idx, "full": manifest["full"]})
    os.makedirs(os.path.dirname(STATE), exist_ok=True)
    json.dump(state, open(STATE, "w", encoding="utf-8"), indent=1)
    print("publicado:", tag)

main()
