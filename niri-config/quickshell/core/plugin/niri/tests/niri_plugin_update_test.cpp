#include "niri_plugin.h"

#include <QJsonArray>
#include <QJsonObject>
#include <QSignalSpy>
#include <QtTest>

class NiriPluginUpdateTest : public QObject {
    Q_OBJECT

private:
    QByteArray m_originalSocket;
    bool m_hadSocket = false;

    static bool deliver(NiriPlugin &plugin, const QJsonObject &event)
    {
        return QMetaObject::invokeMethod(
            &plugin,
            "handleEvent",
            Qt::DirectConnection,
            Q_ARG(QJsonObject, event));
    }

    static QJsonObject workspaceEvent(const QString &name = QStringLiteral("Main"),
                                      const QString &output = QStringLiteral("eDP-1"))
    {
        QJsonObject workspace{
            {QStringLiteral("id"), 1},
            {QStringLiteral("idx"), 1},
            {QStringLiteral("name"), name},
            {QStringLiteral("output"), output},
            {QStringLiteral("is_active"), true},
            {QStringLiteral("is_focused"), true},
            {QStringLiteral("is_urgent"), false},
            {QStringLiteral("active_window_id"), QJsonValue()},
        };
        return QJsonObject{
            {QStringLiteral("WorkspacesChanged"),
             QJsonObject{{QStringLiteral("workspaces"), QJsonArray{workspace}}}},
        };
    }

    static QJsonObject windowEvent(const QString &title = QStringLiteral("Terminal"))
    {
        QJsonObject window{
            {QStringLiteral("id"), 11},
            {QStringLiteral("title"), title},
            {QStringLiteral("app_id"), QStringLiteral("test.app")},
            {QStringLiteral("pid"), 123},
            {QStringLiteral("workspace_id"), 1},
            {QStringLiteral("is_focused"), true},
            {QStringLiteral("is_floating"), false},
            {QStringLiteral("is_urgent"), false},
            {QStringLiteral("layout"), QJsonObject{
                {QStringLiteral("pos_in_scrolling_layout"), QJsonArray{1, 0}},
            }},
        };
        return QJsonObject{
            {QStringLiteral("WindowOpenedOrChanged"),
             QJsonObject{{QStringLiteral("window"), window}}},
        };
    }

    static QJsonObject outputEvent(int logicalX = 0, int logicalWidth = 1920)
    {
        const QJsonObject output{
            {QStringLiteral("make"), QStringLiteral("Test Make")},
            {QStringLiteral("model"), QStringLiteral("Test Model")},
            {QStringLiteral("serial"), QStringLiteral("123")},
            {QStringLiteral("vrr_enabled"), false},
            {QStringLiteral("logical"), QJsonObject{
                {QStringLiteral("x"), logicalX},
                {QStringLiteral("y"), 0},
                {QStringLiteral("width"), logicalWidth},
                {QStringLiteral("height"), 1080},
                {QStringLiteral("scale"), 1.0},
                {QStringLiteral("transform"), QStringLiteral("Normal")},
            }},
            {QStringLiteral("current_mode"), 0},
            {QStringLiteral("modes"), QJsonArray{QJsonObject{
                {QStringLiteral("width"), 1920},
                {QStringLiteral("height"), 1080},
                {QStringLiteral("refresh_rate"), 60.0},
            }}},
        };
        return QJsonObject{
            {QStringLiteral("OutputsChanged"),
             QJsonObject{{QStringLiteral("outputs"), QJsonObject{{QStringLiteral("eDP-1"), output}}}}},
        };
    }

    static void clearSpies(QSignalSpy &workspaces,
                           QSignalSpy &windows,
                           QSignalSpy &outputs,
                           QSignalSpy &focusedWindow,
                           QSignalSpy &focusedWorkspace)
    {
        workspaces.clear();
        windows.clear();
        outputs.clear();
        focusedWindow.clear();
        focusedWorkspace.clear();
    }

private slots:
    void initTestCase()
    {
        m_hadSocket = qEnvironmentVariableIsSet("NIRI_SOCKET");
        if (m_hadSocket)
            m_originalSocket = qgetenv("NIRI_SOCKET");
        qunsetenv("NIRI_SOCKET");
    }

    void cleanupTestCase()
    {
        if (m_hadSocket)
            qputenv("NIRI_SOCKET", m_originalSocket);
        else
            qunsetenv("NIRI_SOCKET");
    }

    void identicalWorkspaceEventIsSilent()
    {
        NiriPlugin plugin;
        QSignalSpy workspaces(&plugin, &NiriPlugin::workspacesChanged);
        QSignalSpy windows(&plugin, &NiriPlugin::windowsChanged);
        QSignalSpy outputs(&plugin, &NiriPlugin::outputsChanged);
        QSignalSpy focusedWindow(&plugin, &NiriPlugin::focusedWindowChanged);
        QSignalSpy focusedWorkspace(&plugin, &NiriPlugin::focusedWorkspaceChanged);
        QVERIFY(workspaces.isValid());
        QVERIFY(windows.isValid());
        QVERIFY(outputs.isValid());
        QVERIFY(focusedWindow.isValid());
        QVERIFY(focusedWorkspace.isValid());

        const QJsonObject event = workspaceEvent();
        QVERIFY(deliver(plugin, event));
        clearSpies(workspaces, windows, outputs, focusedWindow, focusedWorkspace);

        QVERIFY(deliver(plugin, event));
        QCOMPARE(workspaces.count(), 0);
        QCOMPARE(windows.count(), 0);
        QCOMPARE(outputs.count(), 0);
        QCOMPARE(focusedWindow.count(), 0);
        QCOMPARE(focusedWorkspace.count(), 0);
    }

    void focusedWorkspaceNotifierTracksCurrentOutput()
    {
        NiriPlugin plugin;
        QSignalSpy workspaces(&plugin, &NiriPlugin::workspacesChanged);
        QSignalSpy windows(&plugin, &NiriPlugin::windowsChanged);
        QSignalSpy outputs(&plugin, &NiriPlugin::outputsChanged);
        QSignalSpy focusedWindow(&plugin, &NiriPlugin::focusedWindowChanged);
        QSignalSpy focusedWorkspace(&plugin, &NiriPlugin::focusedWorkspaceChanged);

        QVERIFY(deliver(plugin, workspaceEvent()));
        clearSpies(workspaces, windows, outputs, focusedWindow, focusedWorkspace);

        QVERIFY(deliver(plugin, workspaceEvent(QStringLiteral("Main"), QStringLiteral("DP-1"))));
        QCOMPARE(workspaces.count(), 1);
        QCOMPARE(focusedWorkspace.count(), 1);
        QCOMPARE(focusedWindow.count(), 0);
    }

    void focusedWindowChangesArePublishedGranularly()
    {
        NiriPlugin plugin;
        QSignalSpy workspaces(&plugin, &NiriPlugin::workspacesChanged);
        QSignalSpy windows(&plugin, &NiriPlugin::windowsChanged);
        QSignalSpy outputs(&plugin, &NiriPlugin::outputsChanged);
        QSignalSpy focusedWindow(&plugin, &NiriPlugin::focusedWindowChanged);
        QSignalSpy focusedWorkspace(&plugin, &NiriPlugin::focusedWorkspaceChanged);

        QVERIFY(deliver(plugin, workspaceEvent()));
        QVERIFY(deliver(plugin, windowEvent()));
        clearSpies(workspaces, windows, outputs, focusedWindow, focusedWorkspace);

        QVERIFY(deliver(plugin, windowEvent()));
        QCOMPARE(workspaces.count(), 0);
        QCOMPARE(windows.count(), 0);
        QCOMPARE(focusedWindow.count(), 0);

        QVERIFY(deliver(plugin, windowEvent(QStringLiteral("Updated title"))));
        QCOMPARE(workspaces.count(), 0);
        QCOMPARE(windows.count(), 1);
        QCOMPARE(focusedWindow.count(), 1);
        QCOMPARE(focusedWorkspace.count(), 0);
        QCOMPARE(plugin.focusedWindow().value(QStringLiteral("title")).toString(),
                 QStringLiteral("Updated title"));
    }

    void outputUpdatesDoNotRepublishUnchangedWindows()
    {
        NiriPlugin plugin;
        QSignalSpy workspaces(&plugin, &NiriPlugin::workspacesChanged);
        QSignalSpy windows(&plugin, &NiriPlugin::windowsChanged);
        QSignalSpy outputs(&plugin, &NiriPlugin::outputsChanged);
        QSignalSpy focusedWindow(&plugin, &NiriPlugin::focusedWindowChanged);
        QSignalSpy focusedWorkspace(&plugin, &NiriPlugin::focusedWorkspaceChanged);

        QVERIFY(deliver(plugin, workspaceEvent()));
        QVERIFY(deliver(plugin, windowEvent()));
        QVERIFY(deliver(plugin, outputEvent()));
        clearSpies(workspaces, windows, outputs, focusedWindow, focusedWorkspace);

        QVERIFY(deliver(plugin, outputEvent()));
        QCOMPARE(workspaces.count(), 0);
        QCOMPARE(windows.count(), 0);
        QCOMPARE(outputs.count(), 0);

        QVERIFY(deliver(plugin, outputEvent(0, 2560)));
        QCOMPARE(workspaces.count(), 0);
        QCOMPARE(windows.count(), 0);
        QCOMPARE(outputs.count(), 1);
        QCOMPARE(focusedWindow.count(), 0);
        QCOMPARE(focusedWorkspace.count(), 0);
    }
};

QTEST_GUILESS_MAIN(NiriPluginUpdateTest)

#include "niri_plugin_update_test.moc"
