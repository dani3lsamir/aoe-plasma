/*
    Empire Media — one module: │ Track title  ⏮ ⏯ ⏭

    Why not the native Media Player widget: in a panel it only shows an icon;
    the title and the controls live in a popup. The design asks for the title
    and previous / play-pause / next inline, in a single module that vanishes
    when nothing is playing. Data comes from the same MPRIS model Plasma's own
    media widget uses (org.kde.plasma.private.mpris → libkmpris): D-Bus
    signals, no polling, no extra process.
*/
import QtQuick
import QtQuick.Layouts

import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.mpris as Mpris

PlasmoidItem {
    id: root

    readonly property var player: mpris.currentPlayer
    readonly property int playbackStatus: player?.playbackStatus ?? Mpris.PlaybackStatus.Unknown
    readonly property bool isPlaying: playbackStatus === Mpris.PlaybackStatus.Playing
    readonly property bool hasMedia: player !== null && player !== undefined
        && (playbackStatus === Mpris.PlaybackStatus.Playing || playbackStatus === Mpris.PlaybackStatus.Paused)
    readonly property string title: {
        const track = player?.track ?? "";
        if (track.length > 0) {
            return track;
        }
        return player?.identity ?? "";
    }
    readonly property int controlSize: Math.max(14, Math.round(root.height * 0.55))

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    // Hidden status removes the applet from the panel layout while idle.
    Plasmoid.status: hasMedia ? PlasmaCore.Types.ActiveStatus : PlasmaCore.Types.HiddenStatus

    toolTipMainText: player?.track ?? ""
    toolTipSubText: {
        const artist = player?.artist ?? "";
        const identity = player?.identity ?? "";
        return artist.length > 0 ? artist + " — " + identity : identity;
    }

    Mpris.Mpris2Model {
        id: mpris
    }

    component ControlButton: MouseArea {
        id: button

        property string iconName
        property bool available: true

        implicitWidth: root.controlSize + 6
        implicitHeight: root.controlSize + 6
        enabled: available
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        Rectangle {
            anchors.fill: parent
            radius: 5
            visible: button.containsMouse
            color: Qt.tint(Kirigami.Theme.backgroundColor, Qt.alpha(Kirigami.Theme.highlightColor, 0.55))
        }

        Kirigami.Icon {
            anchors.centerIn: parent
            width: root.controlSize
            height: root.controlSize
            source: button.iconName
            color: button.available ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor
            isMask: true
        }
    }

    fullRepresentation: RowLayout {
        id: layout

        spacing: 0
        visible: root.hasMedia
        Layout.minimumWidth: root.hasMedia ? implicitWidth : 0
        Layout.preferredWidth: Layout.minimumWidth
        Layout.maximumWidth: Layout.minimumWidth
        Layout.fillHeight: true

        // Leading separator travels with the module, so it disappears with it.
        Rectangle {
            Layout.leftMargin: 6
            Layout.rightMargin: 8
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: 1
            implicitHeight: Math.round(root.height * 0.5)
            color: Qt.tint(Kirigami.Theme.backgroundColor, Qt.alpha(Kirigami.Theme.textColor, 0.22))
        }

        Text {
            id: titleLabel
            Layout.maximumWidth: Plasmoid.configuration.maxTitleWidth
            Layout.alignment: Qt.AlignVCenter
            Layout.rightMargin: 4
            text: root.title
            elide: Text.ElideRight
            maximumLineCount: 1
            color: root.isPlaying ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor
            font: Kirigami.Theme.defaultFont
            renderType: Text.NativeRendering

            MouseArea {
                anchors.fill: parent
                enabled: root.player?.canRaise ?? false
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.player.Raise()
            }
        }

        ControlButton {
            iconName: "media-skip-backward-symbolic"
            available: root.player?.canGoPrevious ?? false
            onClicked: root.player.Previous()
        }
        ControlButton {
            iconName: root.isPlaying ? "media-playback-pause-symbolic" : "media-playback-start-symbolic"
            available: root.isPlaying ? (root.player?.canPause ?? false) : (root.player?.canPlay ?? false)
            onClicked: root.player.PlayPause()
        }
        ControlButton {
            iconName: "media-skip-forward-symbolic"
            available: root.player?.canGoNext ?? false
            onClicked: root.player.Next()
        }
    }
}
