#include "niri_output_model.h"
#include "niri_window_model.h"
#include "niri_workspace_model.h"

#include <QSignalSpy>
#include <QtTest>

class NiriModelUpdateTest : public QObject {
    Q_OBJECT

private:
    static NiriWorkspace workspace(quint64 id, const QString &name = {})
    {
        NiriWorkspace result;
        result.id = id;
        result.index = static_cast<int>(id);
        result.name = name.isEmpty() ? QStringLiteral("workspace-%1").arg(id) : name;
        result.output = QStringLiteral("eDP-1");
        return result;
    }

    static NiriWindow window(quint64 id)
    {
        NiriWindow result;
        result.id = id;
        result.title = QStringLiteral("Window %1").arg(id);
        result.appId = QStringLiteral("test.app");
        result.appName = QStringLiteral("Test App");
        result.pid = static_cast<qint64>(id);
        result.workspaceId = 1;
        result.layoutColumn = static_cast<int>(id);
        return result;
    }

    static NiriOutput output(const QString &name = QStringLiteral("eDP-1"))
    {
        NiriOutput result;
        result.name = name;
        result.make = QStringLiteral("Test Make");
        result.model = QStringLiteral("Test Model");
        result.serial = QStringLiteral("123");
        result.logicalWidth = 1920;
        result.logicalHeight = 1080;
        result.scale = 1.0;
        result.currentMode = QStringLiteral("1920x1080@60");
        return result;
    }

    static void verifySpyValidity(const QSignalSpy &dataChanged,
                                  const QSignalSpy &modelReset,
                                  const QSignalSpy &countChanged)
    {
        QVERIFY(dataChanged.isValid());
        QVERIFY(modelReset.isValid());
        QVERIFY(countChanged.isValid());
    }

private slots:
    void identicalWorkspaceSnapshotIsSilent()
    {
        NiriWorkspaceModel model;
        const QList<NiriWorkspace> snapshot{workspace(1)};
        model.setWorkspaces(snapshot);

        QSignalSpy dataChanged(&model, &QAbstractItemModel::dataChanged);
        QSignalSpy modelReset(&model, &QAbstractItemModel::modelReset);
        QSignalSpy countChanged(&model, &NiriWorkspaceModel::countChanged);
        verifySpyValidity(dataChanged, modelReset, countChanged);

        QVERIFY(!model.setWorkspaces(snapshot));
        QCOMPARE(dataChanged.count(), 0);
        QCOMPARE(modelReset.count(), 0);
        QCOMPARE(countChanged.count(), 0);
    }

    void workspaceRoleChangeIsGranular()
    {
        NiriWorkspaceModel model;
        model.setWorkspaces({workspace(1)});
        QSignalSpy dataChanged(&model, &QAbstractItemModel::dataChanged);
        QVERIFY(dataChanged.isValid());

        QList<NiriWorkspace> changed{workspace(1)};
        changed[0].name = QStringLiteral("renamed");
        QVERIFY(model.setWorkspaces(changed));
        QCOMPARE(dataChanged.count(), 1);
        QCOMPARE(dataChanged.at(0).at(2).value<QList<int>>(),
                 QList<int>{NiriWorkspaceModel::NameRole});
    }

    void workspaceIdentityChangesReset()
    {
        NiriWorkspaceModel model;
        model.setWorkspaces({workspace(1), workspace(2)});
        QSignalSpy dataChanged(&model, &QAbstractItemModel::dataChanged);
        QSignalSpy modelReset(&model, &QAbstractItemModel::modelReset);
        QSignalSpy countChanged(&model, &NiriWorkspaceModel::countChanged);
        verifySpyValidity(dataChanged, modelReset, countChanged);

        QVERIFY(model.setWorkspaces({workspace(2), workspace(1)}));
        QCOMPARE(dataChanged.count(), 0);
        QCOMPARE(modelReset.count(), 1);
        QCOMPARE(countChanged.count(), 0);

        dataChanged.clear();
        modelReset.clear();
        countChanged.clear();
        QVERIFY(model.setWorkspaces({workspace(1)}));
        QCOMPARE(dataChanged.count(), 0);
        QCOMPARE(modelReset.count(), 1);
        QCOMPARE(countChanged.count(), 1);
    }

    void identicalWindowSnapshotIsSilent()
    {
        NiriWindowModel model;
        const QList<NiriWindow> snapshot{window(1)};
        model.setWindows(snapshot);

        QSignalSpy dataChanged(&model, &QAbstractItemModel::dataChanged);
        QSignalSpy modelReset(&model, &QAbstractItemModel::modelReset);
        QSignalSpy countChanged(&model, &NiriWindowModel::countChanged);
        verifySpyValidity(dataChanged, modelReset, countChanged);

        QVERIFY(!model.setWindows(snapshot));
        QCOMPARE(dataChanged.count(), 0);
        QCOMPARE(modelReset.count(), 0);
        QCOMPARE(countChanged.count(), 0);
    }

    void windowRoleChangeIsGranular()
    {
        NiriWindowModel model;
        model.setWindows({window(1)});
        QSignalSpy dataChanged(&model, &QAbstractItemModel::dataChanged);
        QVERIFY(dataChanged.isValid());

        QList<NiriWindow> changed{window(1)};
        changed[0].title = QStringLiteral("renamed");
        QVERIFY(model.setWindows(changed));
        QCOMPARE(dataChanged.count(), 1);
        QCOMPARE(dataChanged.at(0).at(2).value<QList<int>>(),
                 QList<int>{NiriWindowModel::TitleRole});
    }

    void windowIdentityChangesReset()
    {
        NiriWindowModel model;
        model.setWindows({window(1), window(2)});
        QSignalSpy dataChanged(&model, &QAbstractItemModel::dataChanged);
        QSignalSpy modelReset(&model, &QAbstractItemModel::modelReset);
        QSignalSpy countChanged(&model, &NiriWindowModel::countChanged);
        verifySpyValidity(dataChanged, modelReset, countChanged);

        QVERIFY(model.setWindows({window(2), window(1)}));
        QCOMPARE(dataChanged.count(), 0);
        QCOMPARE(modelReset.count(), 1);
        QCOMPARE(countChanged.count(), 0);

        dataChanged.clear();
        modelReset.clear();
        countChanged.clear();
        QVERIFY(model.setWindows({window(1)}));
        QCOMPARE(dataChanged.count(), 0);
        QCOMPARE(modelReset.count(), 1);
        QCOMPARE(countChanged.count(), 1);
    }

    void identicalOutputSnapshotIsSilent()
    {
        NiriOutputModel model;
        const QList<NiriOutput> snapshot{output()};
        model.setOutputs(snapshot);

        QSignalSpy dataChanged(&model, &QAbstractItemModel::dataChanged);
        QSignalSpy modelReset(&model, &QAbstractItemModel::modelReset);
        QSignalSpy countChanged(&model, &NiriOutputModel::countChanged);
        verifySpyValidity(dataChanged, modelReset, countChanged);

        QVERIFY(!model.setOutputs(snapshot));
        QCOMPARE(dataChanged.count(), 0);
        QCOMPARE(modelReset.count(), 0);
        QCOMPARE(countChanged.count(), 0);
    }

    void outputRoleChangeIsGranular()
    {
        NiriOutputModel model;
        model.setOutputs({output()});
        QSignalSpy dataChanged(&model, &QAbstractItemModel::dataChanged);
        QVERIFY(dataChanged.isValid());

        QList<NiriOutput> changed{output()};
        changed[0].logicalWidth = 2560;
        QVERIFY(model.setOutputs(changed));
        QCOMPARE(dataChanged.count(), 1);
        QCOMPARE(dataChanged.at(0).at(2).value<QList<int>>(),
                 QList<int>{NiriOutputModel::LogicalWidthRole});
    }

    void outputIdentityChangesReset()
    {
        NiriOutputModel model;
        model.setOutputs({output(QStringLiteral("eDP-1")), output(QStringLiteral("DP-1"))});
        QSignalSpy dataChanged(&model, &QAbstractItemModel::dataChanged);
        QSignalSpy modelReset(&model, &QAbstractItemModel::modelReset);
        QSignalSpy countChanged(&model, &NiriOutputModel::countChanged);
        verifySpyValidity(dataChanged, modelReset, countChanged);

        QVERIFY(model.setOutputs({output(QStringLiteral("DP-1")), output(QStringLiteral("eDP-1"))}));
        QCOMPARE(dataChanged.count(), 0);
        QCOMPARE(modelReset.count(), 1);
        QCOMPARE(countChanged.count(), 0);

        dataChanged.clear();
        modelReset.clear();
        countChanged.clear();
        QVERIFY(model.setOutputs({output(QStringLiteral("eDP-1"))}));
        QCOMPARE(dataChanged.count(), 0);
        QCOMPARE(modelReset.count(), 1);
        QCOMPARE(countChanged.count(), 1);
    }
};

QTEST_GUILESS_MAIN(NiriModelUpdateTest)

#include "niri_model_update_test.moc"
