// Txcmatheo Vision: rescate automático del frame gen (NVIDIA VFG).
//
// En una escena pesada (GTA VI, 3X con VFG Medium en una RTX 3050) el frame gen tardaba más que el
// tiempo entre dos cuadros reales; entonces no generaba nada y la salida caía a 30 FPS. Y se quedaba
// así aunque la escena se aligerara, hasta cambiar a mano el multiplicador. El motor lo informa:
// pushLiveStats().fgIdle (engine/PushFgHealth.h) 3 = "la tarjeta no llega", tras ~10 s sin cuadros.
// Este componente:
//   1. con fgIdle 3, baja un escalón la calidad de VFG (High … Medium → Medium+Low → Low);
//   2. si sigue parado 10 s más (o ya está en Low), reinicia el frame gen bajando y
//      subiendo el multiplicador, el mismo arreglo que funcionó a mano;
//   3. tras un rato sin problemas vuelve a la calidad con la que se empezó; si vuelve a caerse,
//      deja la más ligera el resto de la sesión.
// Un cambio de perfil (perfil automático o a mano) pone la calidad del perfil y empieza de cero.
import QtQuick

QtObject {
    id: rescue
    signal rescued(string text)

    // De más cara a más barata (veyra.vfgQuality: 0 Low, 1 Medium, 2 High, 3 High+Medium,
    // 4 High+Low, 5 Medium+Low).
    readonly property var ladder: [2, 3, 1, 4, 5, 0]
    readonly property var names: ({ 0: "Low", 1: "Medium", 2: "High", 3: "High+Medium", 4: "High+Low", 5: "Medium+Low" })
    readonly property bool es: Qt.uiLanguage.indexOf("es") === 0

    property int wanted: -1        // la calidad de antes del primer rescate (-1: no hay rescate en curso)
    property int quietSeconds: 0   // segundos seguidos generando bien desde el último rescate
    property int idleSeconds: 0    // segundos seguidos con fgIdle 3 desde la última acción
    property int retries: 0        // veces que se intentó volver a la calidad buena
    property bool stayLow: false   // se cayó al volver: no intentar más en esta sesión
    property int bounceTo: 0       // multiplicador a restaurar tras el reinicio
    property bool ownChange: false // el cambio de calidad lo hizo este componente

    function say(es, en) { rescue.rescued(rescue.es ? es : en) }
    function lighter(q) {
        const i = ladder.indexOf(q)
        return i < 0 || i === ladder.length - 1 ? -1 : ladder[i + 1]
    }
    function setQuality(q) { rescue.ownChange = true; veyra.vfgQuality = q; Qt.callLater(() => rescue.ownChange = false) }
    function reset() { rescue.wanted = -1; rescue.quietSeconds = 0; rescue.idleSeconds = 0; rescue.retries = 0; rescue.stayLow = false }

    // Un cambio de calidad que no hizo el rescate (perfil o a mano): empezar de cero.
    property Connections watchQuality: Connections {
        target: veyra
        ignoreUnknownSignals: true
        function onVfgQualityChanged() { if (!rescue.ownChange) rescue.reset() }
    }

    function tick() {
        const st = veyra.pushLiveStats() || {}
        if (st.running !== true) { rescue.idleSeconds = 0; return }
        const idle = Number(st.fgIdle || 0) === 3
        const q = Number(veyra.vfgQuality)
        if (!idle) {
            rescue.idleSeconds = 0
            if (rescue.wanted >= 0 && !rescue.stayLow && q !== rescue.wanted && ++rescue.quietSeconds >= 90) {
                // Un rato sin problemas: probar otra vez la calidad de antes.
                rescue.quietSeconds = 0
                rescue.retries++
                veyra.logUi("txc-fg-rescue", "back to quality " + rescue.wanted + " (try " + rescue.retries + ")")
                rescue.setQuality(rescue.wanted)
                say("Frame gen: vuelve a " + names[rescue.wanted], "Frame gen: back to " + names[rescue.wanted])
            }
            return
        }
        rescue.quietSeconds = 0
        // Volver a la calidad buena hizo caer el frame gen otra vez: quedarse ligera esta sesión.
        if (rescue.wanted >= 0 && q === rescue.wanted && rescue.retries >= 2) rescue.stayLow = true
        // Una acción cada 10 s de parada (el motor tarda en ver que vuelve a generar): las pares bajan
        // un escalón de calidad si se puede, las impares (o ya en Low) reinician el frame gen.
        const t = rescue.idleSeconds++
        if (t % 10 !== 0) return
        const next = lighter(q)
        if ((t / 10) % 2 === 0 && next >= 0) {
            if (rescue.wanted < 0) rescue.wanted = q
            veyra.logUi("txc-fg-rescue", "fgIdle=3: quality " + q + " -> " + next)
            rescue.setQuality(next)
            say("Frame gen: escena pesada, calidad " + names[next], "Frame gen: heavy scene, quality " + names[next])
            return
        }
        const m = Number(veyra.fgMultiplier)
        if (m >= 3) {
            veyra.logUi("txc-fg-rescue", "fgIdle=3: restart via multiplier " + m + " -> " + (m - 1) + " -> " + m)
            rescue.bounceTo = m
            veyra.fgMultiplier = m - 1
            bounce.restart()
            say("Frame gen: reiniciado", "Frame gen: restarted")
        }
    }
    property Timer bounce: Timer {
        interval: 1500
        onTriggered: if (rescue.bounceTo >= 3) { veyra.fgMultiplier = rescue.bounceTo; rescue.bounceTo = 0 }
    }
    property Timer timer: Timer {
        interval: 1000; repeat: true
        running: veyra.hasSource === true && veyra.fgEnabled === true && veyra.fgBackendName === "vfg"
        onRunningChanged: { rescue.idleSeconds = 0; if (!running) rescue.reset() }
        onTriggered: rescue.tick()
    }
}
