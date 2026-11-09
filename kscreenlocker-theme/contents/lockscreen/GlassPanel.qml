import QtQuick 2.12
import LingmoUI.CompatibleModule 3.0 as LingmoUI

// A lock screen panel in the "Vidro Lingmo" material (Settings > Appearance >
// Glass): the Theme glass tint, hairline and the 1 px light along the top,
// over the lock screen's own blurred wallpaper. Solid with Glass off.
// (Not a LingmoUI.GlassSurface: that one turns nearly opaque when KWin does not
// blur behind it, and here the backdrop is the lock screen's own blur.)
Rectangle {
    id: panel

    readonly property int level: LingmoUI.Theme.glassEffectiveLevel

    radius: LingmoUI.Theme.bigRadius + 2
    color: Qt.rgba(LingmoUI.Theme.glassTint.r, LingmoUI.Theme.glassTint.g,
                   LingmoUI.Theme.glassTint.b, LingmoUI.Theme.glassOpacity)
    border.width: 1
    border.color: LingmoUI.Theme.glassBorderColor

    Behavior on color { ColorAnimation { duration: LingmoUI.Units.longDuration } }

    // Inner highlight along the top edge
    Rectangle {
        visible: panel.level > 0
        x: panel.radius
        y: 1
        width: panel.width - panel.radius * 2
        height: 1
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: LingmoUI.Theme.glassHighlight }
            GradientStop { position: 1.0; color: Qt.rgba(LingmoUI.Theme.glassHighlight.r, LingmoUI.Theme.glassHighlight.g,
                                                         LingmoUI.Theme.glassHighlight.b, LingmoUI.Theme.glassHighlight.a * 0.2) }
        }
    }
}
