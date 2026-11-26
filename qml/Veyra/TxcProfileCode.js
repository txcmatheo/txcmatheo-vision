.pragma library
// Txcmatheo Vision: código para compartir un perfil de juego ("TXC1:" + JSON en Base64).
// Lleva lo que guarda el perfil (fps del juego, objetivo, realce y su look, calidad VFG, recorte…) y, aparte,
// lo que se ajusta en modo Pro (método de frame gen, multiplicador, Output cap, tamaño y fuerza del NR).
// No lleva zonas de HUD ni nada del PC (rutas, consola emparejada, cuentas). Al leerlo solo se aceptan
// estas claves, con valores comprobados: un código manipulado no puede meter otra cosa.

var prefix = "TXC1:"
var B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

function utf8Bytes(s) {
    var esc = encodeURIComponent(s), out = []
    for (var i = 0; i < esc.length; ++i) {
        if (esc[i] === "%") { out.push(parseInt(esc.substr(i + 1, 2), 16)); i += 2 }
        else out.push(esc.charCodeAt(i))
    }
    return out
}
function utf8String(bytes) {
    var esc = ""
    for (var i = 0; i < bytes.length; ++i) esc += "%" + (bytes[i] < 16 ? "0" : "") + bytes[i].toString(16)
    return decodeURIComponent(esc)
}
function toB64(bytes) {
    var out = ""
    for (var i = 0; i < bytes.length; i += 3) {
        var n = (bytes[i] << 16) | ((bytes[i + 1] || 0) << 8) | (bytes[i + 2] || 0)
        out += B64[(n >> 18) & 63] + B64[(n >> 12) & 63]
        out += i + 1 < bytes.length ? B64[(n >> 6) & 63] : "="
        out += i + 2 < bytes.length ? B64[n & 63] : "="
    }
    return out
}
function fromB64(s) {
    s = s.replace(/[^A-Za-z0-9+\/]/g, "")
    var out = []
    for (var i = 0; i + 1 < s.length; i += 4) {
        var a = B64.indexOf(s[i]), b = B64.indexOf(s[i + 1])
        var c = i + 2 < s.length ? B64.indexOf(s[i + 2]) : -1, d = i + 3 < s.length ? B64.indexOf(s[i + 3]) : -1
        out.push((a << 2) | (b >> 4))
        if (c >= 0) out.push(((b & 15) << 4) | (c >> 2))
        if (d >= 0) out.push(((c & 3) << 6) | d)
    }
    return out
}

function encode(obj) { return prefix + toB64(utf8Bytes(JSON.stringify(obj))) }

function num(v, lo, hi) { var n = Number(v); return isFinite(n) && n >= lo && n <= hi ? n : undefined }
function bool(v) { return typeof v === "boolean" ? v : undefined }
function put(o, k, v) { if (v !== undefined) o[k] = v }

// Devuelve { name, profile, pro } con solo valores válidos, o null si el texto no es un código TXC1.
function decode(text) {
    text = String(text || "").trim()
    var at = text.indexOf(prefix)
    if (at < 0 || text.length > 20000) return null
    var raw
    try { raw = JSON.parse(utf8String(fromB64(text.slice(at + prefix.length)))) } catch (e) { return null }
    if (!raw || typeof raw !== "object" || !raw.profile || typeof raw.profile !== "object") return null
    var p = raw.profile, s = {}
    put(s, "fps", [30, 40, 60].indexOf(Number(p.fps)) >= 0 ? Number(p.fps) : 30)
    if (["off", "60", "90", "120", "monitor"].indexOf(p.target) >= 0) s.target = p.target
    put(s, "enhance", bool(p.enhance)); put(s, "adaptive", bool(p.adaptive)); put(s, "pacing", bool(p.pacing))
    put(s, "hudLock", bool(p.hudLock)); put(s, "lowLatency", bool(p.lowLatency))
    put(s, "vfgQuality", num(p.vfgQuality, 0, 20))
    if (p.look && typeof p.look === "object") {
        var look = {}
        put(look, "tone", num(p.look.tone, 0, 1)); put(look, "structure", num(p.look.structure, 0, 1))
        if (p.look.fine && typeof p.look.fine === "object" && !Array.isArray(p.look.fine)) {
            var fine = {}
            for (var k in p.look.fine) if (/^[A-Za-z]{1,24}$/.test(k)) put(fine, k, num(p.look.fine[k], -10, 10))
            look.fine = fine
        }
        if (look.tone !== undefined && look.structure !== undefined) s.look = look
    }
    if (p.crop === false) s.crop = false
    else if (p.crop && typeof p.crop === "object") {
        var c = {}, keys = ["l", "t", "r", "b", "zoom", "x", "y"]
        for (var i = 0; i < keys.length; ++i) put(c, keys[i], num(p.crop[keys[i]], -10000, 10000))
        if (Object.keys(c).length === keys.length) s.crop = c
    }
    var pro = null
    if (raw.pro && typeof raw.pro === "object") {
        var r = raw.pro
        pro = {}
        put(pro, "fg", bool(r.fg))
        if (typeof r.backend === "string" && /^[a-z0-9_-]{1,24}$/.test(r.backend)) pro.backend = r.backend
        put(pro, "mult", num(r.mult, 2, 20)); put(pro, "auto", bool(r.auto))
        put(pro, "rate", num(r.rate, 0, 2)); put(pro, "fps", num(r.fps, 1, 1000))
        if (r.nr && typeof r.nr === "object") {
            var nr = {}
            put(nr, "sizePolicy", num(r.nr.sizePolicy, 0, 6)); put(nr, "sizePercent", num(r.nr.sizePercent, 25, 100))
            put(nr, "manual", bool(r.nr.manual)); put(nr, "intensity", num(r.nr.intensity, 0, 1))
            put(nr, "performance", bool(r.nr.performance))
            pro.nr = nr
        }
    }
    var name = String(raw.name || "").replace(/[\u0000-\u001f]/g, "").trim().slice(0, 40)
    return { name: name.length > 0 ? name : "Perfil importado", profile: s, pro: pro }
}
