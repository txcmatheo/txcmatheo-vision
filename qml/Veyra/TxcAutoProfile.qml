// Txcmatheo Vision: cambio automático de perfil de juego (30 <-> 60 FPS).
//
// Con un perfil de 30 FPS (GTA VI) en el menú de la PS5, que va a 60, salía el aviso "60 FPS
// detected" y el frame gen generaba 4X sobre 60 (240 cuadros para una pantalla de 144 Hz). Este
// componente mira cada segundo cuántas imágenes NUEVAS llegan (la misma medida del aviso:
// pushLiveStats().contentFps con la quitada automática de repetidas) y, si durante varios segundos
// seguidos no coinciden con el perfil, aplica el perfil del usuario de esa frecuencia:
//   - llegan ~60 y el perfil es de 30  -> el último perfil de 60 usado (FC 27)
//   - llegan ~30 y el perfil es de 60  -> el último perfil de 30 usado (GTA VI o FC 27 Capturadora)
// No hace nada con una imagen quieta, una pantalla de carga o la quitada fija "60→30", ni si el
// usuario lo apaga (Quick setup → Game profile → Auto). Su estado se guarda dentro de pushProfiles
// (campo "txc"), porque Vision solo guarda preferencias que conoce.
import QtQuick

QtObject {
    id: auto
    // El PushQuickSetup de la portada (siempre existe, aunque no se vea): sus funciones de perfiles.
    property Item quick: null
    signal switched(string from, string to, int fps)

    readonly property int stableSeconds: 5      // segundos seguidos que tiene que durar la diferencia
    readonly property int cooldownSeconds: 12   // tras un cambio, no volver a cambiar enseguida
    property string pending: ""                 // "30" o "60" mientras se cuenta
    property int count: 0
    property int cooldown: 0

    readonly property var txc: quick && quick.profiles && typeof quick.profiles.txc === "object" && quick.profiles.txc ? quick.profiles.txc : ({})
    readonly property bool autoOn: txc.auto !== false

    function gameByName(name) { return quick ? quick.games.find(g => g.name === name) : undefined }
    function gamesWith(fps) {
        if (!quick) return []
        return quick.games.filter(g => Number(g.fps) === fps && (!g.console || g.console === quick.consoleId))
    }
    // El perfil al que ir: el último de esa frecuencia que se usó, o el primero que haya.
    function targetFor(fps) {
        const list = gamesWith(fps)
        if (list.length === 0) return ""
        const last = fps === 60 ? txc.last60 : txc.last30
        return list.some(g => g.name === last) ? last : list[0].name
    }
    function writeTxc(changes) {
        if (!quick) return
        const p = quick.copyProfiles()
        const t = typeof p.txc === "object" && p.txc ? p.txc : {}
        for (const k in changes) t[k] = changes[k]
        p.txc = t
        quick.writeProfiles(p)
    }
    function setEnabled(on) { writeTxc({ auto: on }); auto.pending = ""; auto.count = 0 }
    // Recordar el último perfil de cada frecuencia, lo elija el usuario o este componente.
    function rememberActive() {
        const g = gameByName(quick ? quick.activeGame : "")
        if (!g) return
        const fps = Number(g.fps)
        if (fps === 30 && txc.last30 !== g.name) writeTxc({ last30: g.name })
        else if (fps === 60 && txc.last60 !== g.name) writeTxc({ last60: g.name })
    }
    // Al abrir la app, el perfil activo cuenta también como el último de su frecuencia.
    onQuickChanged: Qt.callLater(auto.rememberActive)
    property Connections watchActive: Connections {
        target: auto.quick
        ignoreUnknownSignals: true
        function onActiveGameChanged() { Qt.callLater(auto.rememberActive) }
    }

    function tick() {
        if (auto.cooldown > 0) { auto.cooldown--; return }
        const active = gameByName(quick.activeGame)
        if (!active) { auto.pending = ""; return }
        const st = veyra.pushLiveStats() || {}
        const capture = Number(st.captureFps || 0), content = Number(st.contentFps || 0)
        // Solo con una señal de 60 Hz y la quitada automática de repetidas (contentRate 1).
        let seen = ""
        if (st.running === true && Math.abs(capture - 60) < 3 && Number(veyra.contentRate) === 1) {
            if (content >= 52) seen = "60"
            else if (content >= 26 && content <= 34) seen = "30"
        }
        const now = Number(active.fps) === 60 ? "60" : Number(active.fps) === 30 ? "30" : ""
        if (seen === "" || seen === now) { auto.pending = ""; auto.count = 0; return }
        if (auto.pending !== seen) { auto.pending = seen; auto.count = 1; return }
        if (++auto.count < auto.stableSeconds) return
        const to = targetFor(Number(seen))
        auto.pending = ""; auto.count = 0
        if (to === "" || to === active.name) return
        veyra.logUi("txc-auto-profile", "content=" + content.toFixed(1) + " capture=" + capture.toFixed(1) + " " + active.name + " -> " + to)
        // El perfil del que se sale es el "último" de su frecuencia: a él se vuelve después.
        if (now === "30") writeTxc({ last30: active.name }); else if (now === "60") writeTxc({ last60: active.name })
        quick.applyGame(to)
        auto.cooldown = auto.cooldownSeconds
        auto.switched(active.name, to, Number(seen))
    }
    property Timer timer: Timer {
        interval: 1000; repeat: true
        running: auto.quick !== null && auto.autoOn && veyra.hasSource === true && veyra.fgEnabled === true
                 && auto.gamesWith(30).length > 0 && auto.gamesWith(60).length > 0
        onRunningChanged: { auto.pending = ""; auto.count = 0 }
        onTriggered: auto.tick()
    }
}
