.pragma library
// Txcmatheo Vision: traduce los mensajes del motor que llegan al QML en chino.
// El motor traduce un mensaje solo si coincide entero con el catálogo; los de la PS5 llegan con el código
// pegado al final ("PS5 已结束或拒绝串流…（终止码 2 / 错误 2002）") y se quedaban en chino. Aquí se traduce
// por partes con el mismo catálogo (tr = qsTr de quien llama: el traductor del motor no mira el contexto).

function hasHan(s) { return /[㐀-鿿]/.test(s) }

function fill(shape, values) {
    var i = 0
    return shape.replace(/\{\}/g, function () { return i < values.length ? values[i++] : "" })
}

function fix(s, tr) {
    s = s === undefined || s === null ? "" : String(s)
    if (!hasHan(s)) return s
    var whole = tr(s)
    if (whole.length > 0 && whole !== s) return whole
    // "…（终止码 2 / 错误 2002）": la frase y el código por separado
    var code = s.match(/^([\s\S]*?)（终止码\s*([^\s\/）]+)\s*\/\s*错误\s*([^\s）]+)）\s*$/)
    if (code) {
        var tail = tr("（终止码 {} / 错误 {}）")
        if (tail.length === 0 || hasHan(tail)) tail = " (exit code {} / error {})"
        return fix(code[1], tr) + fill(tail, [code[2], code[3]])
    }
    // Varias frases juntas: cada una por su lado
    var seps = ["\n", "；", " · "]
    for (var k = 0; k < seps.length; ++k) {
        var parts = s.split(seps[k])
        if (parts.length < 2) continue
        for (var j = 0; j < parts.length; ++j) parts[j] = fix(parts[j].trim(), tr)
        return parts.join(seps[k] === "；" ? "; " : seps[k])
    }
    return s
}

// PSN Account ID: PSNTools enseña el ID en Base64 ("AbCdEfGh123=") y en hexadecimal; si se copian los dos juntos
// ("AbCdEfGh123=0123456789ABCDEF") el emparejamiento falla. Se queda solo con el Base64.
function cleanAccount(t) {
    t = String(t || "").trim()
    var b64 = t.match(/[A-Za-z0-9+\/]{11}=/)
    if (b64 && t !== b64[0]) return b64[0]
    return t
}
