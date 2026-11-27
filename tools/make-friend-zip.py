# Txcmatheo Vision: los dos paquetes para amigos nuevos, desde el stage que deja el publicador.
#
#   python tools/make-friend-zip.py <stage> "<Escritorio>\Txcmatheo Vision <versión> (para amigos).zip" [--solo-exe]
#
# 1. El zip, con todo dentro de una carpeta "Txcmatheo Vision/" para descomprimir donde quieran.
# 2. Al lado, "Txcmatheo Vision <versión> (instalador).exe": launcher/TxcInstalador.cs con ese mismo zip
#    pegado al final ([instalador][zip][tamaño int64][TXCSFX01]); instala, crea accesos directos y desinstalador.
# Con --solo-exe no rehace el zip (usa el que ya existe) y solo arma el instalador.
import os, struct, subprocess, sys, tempfile, zipfile

REPO_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CSC = r"C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
MAGIC = b"TXCSFX01"

def partial(out):
    # El archivo a medias va a %TEMP% (mismo disco, el renombrado es instantáneo): en el escritorio un
    # ".partial" sale con el icono de descarga parcial de Internet Explorer.
    return os.path.join(tempfile.gettempdir(), os.path.basename(out) + ".partial")

def make_zip(stage, out):
    tmp = partial(out)
    n = 0
    with zipfile.ZipFile(tmp, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as z:
        for root, dirs, files in os.walk(stage):
            dirs.sort()
            for f in sorted(files):
                p = os.path.join(root, f)
                arc = "Txcmatheo Vision/" + os.path.relpath(p, stage).replace(os.sep, "/")
                z.write(p, arc)
                n += 1
    os.replace(tmp, out)
    with zipfile.ZipFile(out) as z:
        bad = z.testzip()
    print("zip:", n, "archivos,", round(os.path.getsize(out) / 1e6), "MB, testzip:", bad or "ok")

def make_installer(zip_path, out):
    work = tempfile.mkdtemp(prefix="txc-instalador-")
    ico, logo, stub = (os.path.join(work, n) for n in ("txc.ico", "logo.png", "stub.exe"))
    from PIL import Image
    im = Image.open(os.path.join(REPO_DIR, "assets", "txcmatheo-logo.png")).convert("RGBA")
    im.save(ico, sizes=[(16, 16), (32, 32), (48, 48), (256, 256)])
    im.resize((192, 192), Image.LANCZOS).save(logo)
    subprocess.run([CSC, "/nologo", "/target:winexe", "/optimize+", "/codepage:65001", "/win32icon:" + ico,
                    "/resource:" + logo + ",logo.png", "/out:" + stub,
                    "/r:System.IO.Compression.dll", "/r:System.Web.Extensions.dll", "/r:System.Windows.Forms.dll",
                    "/r:System.Drawing.dll", "/r:Microsoft.VisualBasic.dll",
                    os.path.join(REPO_DIR, "launcher", "TxcInstalador.cs")], check=True)
    tmp = partial(out)
    size = os.path.getsize(zip_path)
    with open(tmp, "wb") as dst:
        dst.write(open(stub, "rb").read())
        with open(zip_path, "rb") as src:
            while True:
                c = src.read(1 << 22)
                if not c: break
                dst.write(c)
        dst.write(struct.pack("<q", size) + MAGIC)
    os.replace(tmp, out)
    with open(out, "rb") as f:
        f.seek(-16, 2)
        n, m = struct.unpack("<q8s", f.read(16))
    assert m == MAGIC and n == size
    print("instalador:", round(os.path.getsize(out) / 1e6), "MB ->", out)

def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    stage, out = args
    if "--solo-exe" not in sys.argv:
        make_zip(stage, out)
    exe = out.replace(" (para amigos).zip", " (instalador).exe")
    assert exe != out and exe.endswith(".exe"), "el zip debe llamarse '... (para amigos).zip'"
    make_installer(out, exe)

main()
