import QtQuick
import QtTest
import "../../Modules/Keystone/Hub" as Hub

TestCase {
    id: testCase

    name: "RetainedPageLoader"

    property int createdPageCount: 0

    Component {
        id: pageComponent

        Item {
            property bool pageActive: parent ? parent.presented : false

            Component.onCompleted: testCase.createdPageCount += 1
        }
    }

    Component {
        id: loaderComponent

        Hub.RetainedPageLoader {
            sourceComponent: pageComponent
        }
    }

    function init() {
        testCase.createdPageCount = 0
    }

    function test_loadsOnceAndRetainsInactivePage() {
        const loader = createTemporaryObject(loaderComponent, testCase)
        verify(loader)
        compare(loader.item, null)
        verify(!loader.active)
        verify(!loader.visible)

        loader.presented = true
        tryCompare(loader, "status", Loader.Ready)
        tryCompare(loader, "opacity", 1, 1000)
        const page = loader.item
        verify(page)
        verify(page.pageActive)
        compare(testCase.createdPageCount, 1)

        loader.presented = false
        verify(loader.active)
        compare(loader.item, page)
        verify(!page.pageActive)
        tryCompare(loader, "opacity", 0, 1000)

        loader.presented = true
        tryCompare(loader, "opacity", 1, 1000)
        compare(loader.item, page)
        verify(page.pageActive)
        compare(testCase.createdPageCount, 1)
    }
}
