import QtQuick
import QtQuick.Controls
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    preferredRepresentation: fullRepresentation

    readonly property color arcColor: plasmoid.configuration.arcColor
    readonly property color sweepColor: plasmoid.configuration.sweepColor
    readonly property int sweepSpeed: plasmoid.configuration.sweepSpeed
    readonly property bool showClock: plasmoid.configuration.showClock
    readonly property real arcOpacity: plasmoid.configuration.arcOpacity
    readonly property int gridLines: plasmoid.configuration.gridLines

    fullRepresentation: Item {
        id: fullRep

        implicitWidth: 400
        implicitHeight: 400

        Canvas {
            id: radarCanvas
            anchors.fill: parent

            property real sweepAngle: 0
            property real fadeLength: Math.PI / 2

            NumberAnimation on sweepAngle {
                from: 0
                to: Math.PI * 2
                duration: (11 - root.sweepSpeed) * 1000
                loops: Animation.Infinite
                running: true
            }

            onSweepAngleChanged: requestPaint()

            onPaint: {
                var ctx = getContext("2d")
                var cx = width / 2
                var cy = height / 2
                var maxR = Math.min(cx, cy) - 8

                ctx.clearRect(0, 0, width, height)

                ctx.fillStyle = "#08120e"
                ctx.beginPath()
                ctx.arc(cx, cy, maxR, 0, Math.PI * 2)
                ctx.fill()

                ctx.strokeStyle = root.arcColor
                ctx.lineWidth = 0.5
                ctx.globalAlpha = 0.3
                for (var i = 1; i <= root.gridLines; i++) {
                    var r = (maxR / root.gridLines) * i
                    ctx.beginPath()
                    ctx.arc(cx, cy, r, 0, Math.PI * 2)
                    ctx.stroke()
                }

                ctx.beginPath()
                ctx.moveTo(cx - maxR, cy)
                ctx.lineTo(cx + maxR, cy)
                ctx.stroke()
                ctx.beginPath()
                ctx.moveTo(cx, cy - maxR)
                ctx.lineTo(cx, cy + maxR)
                ctx.stroke()

                ctx.globalAlpha = 1.0
                var trailSteps = 48
                for (var s = 0; s < trailSteps; s++) {
                    var frac = s / trailSteps
                    var startA = radarCanvas.sweepAngle - radarCanvas.fadeLength * frac
                    var endA = radarCanvas.sweepAngle - radarCanvas.fadeLength * (frac + 1 / trailSteps)
                    ctx.beginPath()
                    ctx.moveTo(cx, cy)
                    ctx.arc(cx, cy, maxR, startA, endA, true)
                    ctx.closePath()
                    ctx.fillStyle = root.sweepColor
                    ctx.globalAlpha = (1 - frac) * 0.22
                    ctx.fill()
                }

                ctx.globalAlpha = root.arcOpacity
                ctx.strokeStyle = root.sweepColor
                ctx.lineWidth = 1.5
                ctx.beginPath()
                ctx.moveTo(cx, cy)
                ctx.lineTo(
                    cx + maxR * Math.cos(radarCanvas.sweepAngle),
                    cy + maxR * Math.sin(radarCanvas.sweepAngle)
                )
                ctx.stroke()

                ctx.globalAlpha = 1.0
                ctx.fillStyle = root.sweepColor
                ctx.beginPath()
                ctx.arc(cx, cy, 3, 0, Math.PI * 2)
                ctx.fill()

                ctx.globalCompositeOperation = "destination-in"
                ctx.beginPath()
                ctx.arc(cx, cy, maxR, 0, Math.PI * 2)
                ctx.fillStyle = "#ffffffff"
                ctx.fill()
                ctx.globalCompositeOperation = "source-over"

                ctx.globalAlpha = 0.7
                ctx.strokeStyle = root.arcColor
                ctx.lineWidth = 1.5
                ctx.beginPath()
                ctx.arc(cx, cy, maxR, 0, Math.PI * 2)
                ctx.stroke()
            }
        }

        Text {
            visible: root.showClock
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottomMargin: 24
            color: root.arcColor
            font.pixelSize: 13
            font.family: "monospace"
            opacity: 0.8
            text: Qt.formatTime(new Date(), "HH:mm:ss")

            Timer {
                interval: 1000
                running: root.showClock
                repeat: true
                onTriggered: parent.text = Qt.formatTime(new Date(), "HH:mm:ss")
            }
        }
    }
}
