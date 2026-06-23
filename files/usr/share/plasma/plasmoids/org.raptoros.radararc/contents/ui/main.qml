import QtQuick
import QtQuick.Controls
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    preferredRepresentation: fullRepresentation

    readonly property color arcColor:   plasmoid.configuration.arcColor
    readonly property color sweepColor: plasmoid.configuration.sweepColor
    readonly property int   sweepSpeed: plasmoid.configuration.sweepSpeed
    readonly property bool  showClock:  plasmoid.configuration.showClock
    readonly property real  arcOpacity: plasmoid.configuration.arcOpacity
    readonly property int   gridLines:  plasmoid.configuration.gridLines

    // Size: square based on panel height, or 160px minimum as a standalone widget
    readonly property real radarSize: Math.max(
        plasmoid.formFactor === PlasmaCore.Types.Horizontal ||
        plasmoid.formFactor === PlasmaCore.Types.Vertical
            ? Kirigami.Units.iconSizes.enormous   // panel: ~64px icon unit
            : 160,
        64
    )

    // ── Blip contacts ─────────────────────────────────────────────────────────
    property var blips: []

    Component.onCompleted: {
        var b = []
        var count = 8 + Math.floor(Math.random() * 6)
        for (var i = 0; i < count; i++) {
            b.push({
                angle:      Math.random() * Math.PI * 2,
                dist:       0.25 + Math.random() * 0.65,
                brightness: Math.random()
            })
        }
        root.blips = b
    }

    // Blip decay timer — time-based, not frame-rate-dependent
    Timer {
        id: blipDecayTimer
        interval: 50   // 20 fps decay tick, independent of render rate
        repeat: true
        running: true
        onTriggered: {
            var b = root.blips
            var changed = false
            for (var i = 0; i < b.length; i++) {
                if (b[i].brightness > 0.02) {
                    b[i].brightness = Math.max(0, b[i].brightness - 0.015)
                    changed = true
                }
            }
            if (changed) root.blips = b
        }
    }

    fullRepresentation: Item {
        id: fullRep
        // In a panel: match the panel cross-axis size; as a desktop widget: use radarSize
        implicitWidth:  root.radarSize
        implicitHeight: root.radarSize

        Canvas {
            id: radarCanvas
            anchors.fill: parent

            property real sweepAngle: 0

            NumberAnimation on sweepAngle {
                from: 0
                to:   Math.PI * 2
                duration: (11 - root.sweepSpeed) * 1000
                loops:    Animation.Infinite
                running:  true
                onRunningChanged: if (!running) radarCanvas.sweepAngle = 0
            }

            onSweepAngleChanged: {
                // Light up blips as the sweep passes them
                var b = root.blips
                var sa = ((sweepAngle % (Math.PI * 2)) + Math.PI * 2) % (Math.PI * 2)
                for (var i = 0; i < b.length; i++) {
                    var ba   = ((b[i].angle % (Math.PI * 2)) + Math.PI * 2) % (Math.PI * 2)
                    var diff = sa - ba
                    if (diff < 0) diff += Math.PI * 2
                    if (diff >= 0 && diff < 0.08) {
                        b[i].brightness = 0.9 + Math.random() * 0.1
                    }
                }
                root.blips = b
                requestPaint()
            }

            onPaint: {
                var ctx  = getContext("2d")
                var cx   = width  / 2
                var cy   = height / 2
                var maxR = Math.min(cx, cy) - 4

                ctx.clearRect(0, 0, width, height)

                ctx.save()
                ctx.beginPath()
                ctx.arc(cx, cy, maxR, 0, Math.PI * 2)
                ctx.clip()

                // Background
                ctx.fillStyle = "#08120e"
                ctx.fillRect(0, 0, width, height)
                var bgGrad = ctx.createRadialGradient(cx, cy, 0, cx, cy, maxR)
                bgGrad.addColorStop(0,   "rgba(0,40,20,0.5)")
                bgGrad.addColorStop(0.7, "rgba(0,20,10,0.2)")
                bgGrad.addColorStop(1,   "rgba(0,0,0,0)")
                ctx.fillStyle = bgGrad
                ctx.fillRect(0, 0, width, height)

                // Grid rings
                ctx.strokeStyle = root.arcColor
                ctx.lineWidth   = 0.5
                ctx.globalAlpha = 0.25
                for (var i = 1; i <= root.gridLines; i++) {
                    var r = (maxR / root.gridLines) * i
                    ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2); ctx.stroke()
                }

                // Crosshairs
                ctx.globalAlpha = 0.18
                ctx.beginPath(); ctx.moveTo(cx - maxR, cy);  ctx.lineTo(cx + maxR, cy);  ctx.stroke()
                ctx.beginPath(); ctx.moveTo(cx, cy - maxR);  ctx.lineTo(cx, cy + maxR);  ctx.stroke()
                ctx.globalAlpha = 0.10
                var d = maxR * 0.7071
                ctx.beginPath(); ctx.moveTo(cx - d, cy - d); ctx.lineTo(cx + d, cy + d); ctx.stroke()
                ctx.beginPath(); ctx.moveTo(cx + d, cy - d); ctx.lineTo(cx - d, cy + d); ctx.stroke()

                // Sweep trail
                ctx.globalAlpha = 1.0
                var fadeLen    = Math.PI / 2
                var trailSteps = 48
                for (var s = 0; s < trailSteps; s++) {
                    var frac   = s / trailSteps
                    var startA = sweepAngle - fadeLen * frac
                    var endA   = sweepAngle - fadeLen * (frac + 1 / trailSteps)
                    ctx.beginPath()
                    ctx.moveTo(cx, cy)
                    ctx.arc(cx, cy, maxR, startA, endA, true)
                    ctx.closePath()
                    ctx.fillStyle   = root.sweepColor
                    ctx.globalAlpha = (1 - frac) * 0.28
                    ctx.fill()
                }

                // Sweep line
                ctx.globalAlpha = root.arcOpacity
                ctx.strokeStyle = root.sweepColor
                ctx.lineWidth   = 1.5
                ctx.beginPath()
                ctx.moveTo(cx, cy)
                ctx.lineTo(cx + maxR * Math.cos(sweepAngle), cy + maxR * Math.sin(sweepAngle))
                ctx.stroke()

                // Blips
                var sc = root.sweepColor
                var b  = root.blips
                for (var bi = 0; bi < b.length; bi++) {
                    var blip = b[bi]
                    if (blip.brightness < 0.02) continue
                    var bx = cx + blip.dist * maxR * Math.cos(blip.angle)
                    var by = cy + blip.dist * maxR * Math.sin(blip.angle)
                    var glowG = ctx.createRadialGradient(bx, by, 0, bx, by, 7)
                    glowG.addColorStop(0, Qt.rgba(Qt.color(sc).r, Qt.color(sc).g, Qt.color(sc).b, blip.brightness * 0.55))
                    glowG.addColorStop(1, "rgba(0,0,0,0)")
                    ctx.globalAlpha = 1.0
                    ctx.fillStyle   = glowG
                    ctx.beginPath(); ctx.arc(bx, by, 7, 0, Math.PI * 2); ctx.fill()
                    ctx.fillStyle   = root.sweepColor
                    ctx.globalAlpha = blip.brightness
                    ctx.beginPath(); ctx.arc(bx, by, 1.8, 0, Math.PI * 2); ctx.fill()
                }

                // Centre pip
                ctx.globalAlpha = 1.0
                ctx.fillStyle   = root.sweepColor
                ctx.beginPath(); ctx.arc(cx, cy, 3, 0, Math.PI * 2); ctx.fill()

                ctx.restore()

                // Outer border ring
                ctx.globalAlpha = 0.75
                ctx.strokeStyle = root.arcColor
                ctx.lineWidth   = 1.5
                ctx.beginPath(); ctx.arc(cx, cy, maxR, 0, Math.PI * 2); ctx.stroke()
                ctx.globalAlpha = 1.0
            }
        }

        // Bearing tick marks
        Repeater {
            model: 36
            delegate: Item {
                property real angleDeg: index * 10
                property real angleRad: angleDeg * Math.PI / 180
                property real cx:    fullRep.width  / 2
                property real cy:    fullRep.height / 2
                property real maxR:  Math.min(cx, cy) - 4
                property bool major: angleDeg % 90 === 0
                property real innerR: maxR - (major ? 8 : 4)

                x: cx + innerR * Math.cos(angleRad) - 1
                y: cy + innerR * Math.sin(angleRad) - 1
                width: 2; height: 2

                Rectangle {
                    width:  1
                    height: parent.major ? 8 : 4
                    color:  Qt.rgba(Qt.color(root.arcColor).r,
                                    Qt.color(root.arcColor).g,
                                    Qt.color(root.arcColor).b, 0.45)
                    anchors.centerIn: parent
                    rotation:        parent.angleDeg + 90
                    transformOrigin: Item.Center
                }
            }
        }

        // HUD clock — only shown as desktop widget (not in panel)
        Column {
            visible: root.showClock && (
                plasmoid.formFactor !== PlasmaCore.Types.Horizontal &&
                plasmoid.formFactor !== PlasmaCore.Types.Vertical
            )
            anchors.bottom:           parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottomMargin:     16
            spacing: 2

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                color: root.arcColor; font.pixelSize: 7; font.family: "monospace"
                opacity: 0.45; letterSpacing: 1.5
                text: "RNG  " + root.gridLines + "×"
            }
            Text {
                id: clockText
                anchors.horizontalCenter: parent.horizontalCenter
                color: root.arcColor; font.pixelSize: 13; font.family: "monospace"
                font.bold: true; opacity: 0.85; letterSpacing: 2
                text: Qt.formatTime(new Date(), "HH:mm:ss")
                Timer {
                    interval: 1000; running: root.showClock; repeat: true
                    onTriggered: clockText.text = Qt.formatTime(new Date(), "HH:mm:ss")
                }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                color: root.arcColor; font.pixelSize: 7; font.family: "monospace"
                opacity: 0.35; letterSpacing: 1
                text: "IFF  ON  │  MODE-S  STBY"
            }
        }
    }
}
