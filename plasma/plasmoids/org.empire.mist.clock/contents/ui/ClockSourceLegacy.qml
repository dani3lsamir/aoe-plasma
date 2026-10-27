// Plasma 6.0 – 6.5: the "time" data engine, aligned to the minute
// (the same source the Digital Clock used on those versions).
import QtQuick
import org.kde.plasma.plasma5support as P5Support

Item {
    readonly property var dateTime: timeSource.data.Local ? timeSource.data.Local.DateTime : new Date()

    P5Support.DataSource {
        id: timeSource
        engine: "time"
        connectedSources: ["Local"]
        interval: 60000
        intervalAlignment: P5Support.Types.AlignToMinute
    }
}
