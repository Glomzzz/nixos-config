import QtQuick
import qs.Common
import qs.Widgets.common

PopupToolTip {
    id: root

    property font font

    respectParentHierarchy: true
    horizontalPadding: 10
    verticalPadding: 5
    font {
        family: Sizes.fontFamily
        pixelSize: 12
        hintingPreference: Font.PreferNoHinting
    }

}
