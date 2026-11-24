# Cambia el icono y la información de versión de veyra_qml_ui.exe por los de Txcmatheo Vision,
# sin recompilar (API de recursos de Windows), y deja el resultado con otro nombre.
#
#   python rebrand-txcmatheo-exe.py <exe origen> <exe destino> <logo.png>
#
# El exe de origen no se modifica: se copia al destino y se edita la copia.
import ctypes, io, shutil, struct, sys
from ctypes import wintypes
from PIL import Image, ImageDraw

src, dst, logo_path = sys.argv[1], sys.argv[2], sys.argv[3]
PRODUCT = "Txcmatheo Vision"
DESCRIPTION = "Txcmatheo Vision"  # lo que muestra la barra de tareas; el crédito va en Copyright y Comments
COPYRIGHT = "Basado en Veyra NR Video de Likely7 y colaboradores. GPL-3.0."
ICON_GROUP_ID = 101  # IDI_VEYRA (apps/veyra/resource.h): lo carga main.cpp para la barra de tareas
RT_ICON, RT_GROUP_ICON, RT_VERSION = 3, 14, 16

k32 = ctypes.WinDLL("kernel32", use_last_error=True)
k32.LoadLibraryExW.restype = wintypes.HMODULE
k32.LoadLibraryExW.argtypes = [wintypes.LPCWSTR, wintypes.HANDLE, wintypes.DWORD]
k32.FindResourceExW.restype = wintypes.HANDLE
k32.FindResourceExW.argtypes = [wintypes.HMODULE, ctypes.c_void_p, ctypes.c_void_p, wintypes.WORD]
k32.FindResourceW.restype = wintypes.HANDLE
k32.FindResourceW.argtypes = [wintypes.HMODULE, ctypes.c_void_p, ctypes.c_void_p]
k32.LoadResource.restype = wintypes.HANDLE
k32.LoadResource.argtypes = [wintypes.HMODULE, wintypes.HANDLE]
k32.LockResource.restype = ctypes.c_void_p
k32.LockResource.argtypes = [wintypes.HANDLE]
k32.SizeofResource.restype = wintypes.DWORD
k32.SizeofResource.argtypes = [wintypes.HMODULE, wintypes.HANDLE]
k32.FreeLibrary.argtypes = [wintypes.HMODULE]
k32.BeginUpdateResourceW.restype = wintypes.HANDLE
k32.BeginUpdateResourceW.argtypes = [wintypes.LPCWSTR, wintypes.BOOL]
k32.UpdateResourceW.restype = wintypes.BOOL
k32.UpdateResourceW.argtypes = [wintypes.HANDLE, ctypes.c_void_p, ctypes.c_void_p, wintypes.WORD, ctypes.c_void_p, wintypes.DWORD]
k32.EndUpdateResourceW.restype = wintypes.BOOL
k32.EndUpdateResourceW.argtypes = [wintypes.HANDLE, wintypes.BOOL]
EnumLangProc = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HMODULE, ctypes.c_void_p, ctypes.c_void_p, wintypes.WORD, ctypes.c_void_p)
k32.EnumResourceLanguagesW.argtypes = [wintypes.HMODULE, ctypes.c_void_p, ctypes.c_void_p, EnumLangProc, ctypes.c_void_p]

def check(ok, what):
    if not ok:
        raise ctypes.WinError(ctypes.get_last_error(), what)

def read_resource(mod, rtype, rid):
    langs = []
    k32.EnumResourceLanguagesW(mod, rtype, rid, EnumLangProc(lambda m, t, n, lang, p: langs.append(lang) or True), None)
    if not langs:
        raise SystemExit(f"recurso {rtype}/{rid} no encontrado")
    h = k32.FindResourceExW(mod, rtype, rid, langs[0])
    check(h, "FindResourceEx")
    size = k32.SizeofResource(mod, h)
    data = ctypes.string_at(k32.LockResource(k32.LoadResource(mod, h)), size)
    return langs[0], data

# ---------------------------------------------------------------- leer lo que hay
shutil.copy2(src, dst)
mod = k32.LoadLibraryExW(dst, None, 0x2 | 0x20)  # LOAD_LIBRARY_AS_DATAFILE | AS_IMAGE_RESOURCE
check(mod, "LoadLibraryEx")
icon_lang, group = read_resource(mod, RT_GROUP_ICON, ICON_GROUP_ID)
count = struct.unpack_from("<HHH", group, 0)[2]
old_icon_ids = [struct.unpack_from("<H", group, 6 + i * 14 + 12)[0] for i in range(count)]
ver_lang, version = read_resource(mod, RT_VERSION, 1)
k32.FreeLibrary(mod)

# ---------------------------------------------------------------- icono nuevo
logo = Image.open(logo_path).convert("RGBA")
sizes = [256, 128, 96, 64, 48, 40, 32, 24, 20, 16]
images = []
for s in sizes:
    big = logo.resize((s * 4, s * 4), Image.LANCZOS)
    mask = Image.new("L", big.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, big.width - 1, big.height - 1], int(big.width * 0.22), fill=255)
    big.putalpha(mask)
    im = big.resize((s, s), Image.LANCZOS)
    buf = io.BytesIO()
    if s >= 64:
        im.save(buf, "PNG")  # PNG dentro del icono (Vista+)
        data = buf.getvalue()
    else:
        # DIB de 32 bits: cabecera BITMAPINFO + píxeles BGRA de abajo arriba + máscara AND vacía
        px = im.tobytes("raw", "BGRA")
        rows = [px[y * s * 4:(y + 1) * s * 4] for y in range(s)][::-1]
        and_row = ((s + 31) // 32) * 4
        data = struct.pack("<IiiHHIIiiII", 40, s, s * 2, 1, 32, 0, s * s * 4, 0, 0, 0, 0) + b"".join(rows) + b"\0" * (and_row * s)
    images.append((s, data))

# ---------------------------------------------------------------- versión nueva
def pad4(b):
    return b + b"\0" * ((4 - len(b) % 4) % 4)

def node(key, value_bytes, value_len, vtype, children=b""):
    k = (key + "\0").encode("utf-16-le")
    body = pad4(struct.pack("<HHH", 0, value_len, vtype) + k)
    if value_bytes:
        body = pad4(body + value_bytes)
    body += children
    return struct.pack("<H", len(body)) + body[2:]

def string_node(key, text):
    v = (text + "\0").encode("utf-16-le")
    return pad4(node(key, v, len(text) + 1, 1))

# VS_FIXEDFILEINFO del original (52 bytes tras la clave "VS_VERSION_INFO")
fixed_off = 6 + len("VS_VERSION_INFO\0".encode("utf-16-le"))
fixed_off += (4 - fixed_off % 4) % 4
fixed = version[fixed_off:fixed_off + 52]
assert struct.unpack_from("<I", fixed, 0)[0] == 0xFEEF04BD, "VS_FIXEDFILEINFO no encontrado"
display_version = "%d.%d.%d" % (struct.unpack_from("<I", fixed, 8)[0] >> 16, struct.unpack_from("<I", fixed, 8)[0] & 0xFFFF,
                                 struct.unpack_from("<I", fixed, 12)[0] >> 16)
dst_name = dst.replace("\\", "/").rsplit("/", 1)[-1]
strings = b"".join(string_node(k, v) for k, v in [
    ("CompanyName", "Txcmatheo"),
    ("FileDescription", DESCRIPTION),
    ("FileVersion", display_version),
    ("InternalName", PRODUCT),
    ("LegalCopyright", COPYRIGHT),
    ("OriginalFilename", dst_name),
    ("ProductName", PRODUCT),
    ("ProductVersion", display_version),
    ("Comments", "Fork de https://github.com/Likely7/Veyra-NRVideo"),
])
table = pad4(node("040904B0", b"", 0, 1, strings))
sfi = pad4(node("StringFileInfo", b"", 0, 1, table))
var = pad4(node("Translation", struct.pack("<HH", 0x0409, 1200), 4, 0))
vfi = pad4(node("VarFileInfo", b"", 0, 1, var))
new_version = node("VS_VERSION_INFO", fixed, 52, 0, sfi + vfi)

# ---------------------------------------------------------------- escribir
h = k32.BeginUpdateResourceW(dst, False)
check(h, "BeginUpdateResource")
def put(rtype, rid, lang, data):
    buf = ctypes.create_string_buffer(data, len(data)) if data else None
    check(k32.UpdateResourceW(h, rtype, rid, lang, buf, len(data) if data else 0), f"UpdateResource {rtype}/{rid}")
for i in [i for i in old_icon_ids if not (1 <= i <= len(images))]:
    put(RT_ICON, i, icon_lang, None)
first_id = 1
grp = struct.pack("<HHH", 0, 1, len(images))
for n, (s, data) in enumerate(images):
    put(RT_ICON, first_id + n, icon_lang, data)
    grp += struct.pack("<BBBBHHIH", s % 256, s % 256, 0, 0, 1, 32, len(data), first_id + n)
put(RT_GROUP_ICON, ICON_GROUP_ID, icon_lang, grp)
put(RT_VERSION, 1, ver_lang, new_version)
check(k32.EndUpdateResourceW(h, False), "EndUpdateResource")
print(f"ok: {dst_name} · iconos {len(images)} (antes {len(old_icon_ids)}) · versión {display_version}")
