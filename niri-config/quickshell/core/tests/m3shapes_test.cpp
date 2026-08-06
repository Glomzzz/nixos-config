#include "m3shapes/morph/Morph.hpp"
#include "m3shapes/shapes/MaterialShapes.hpp"
#include "m3shapes/shapes/Shapes.hpp"

#include <QQmlComponent>
#include <QQmlEngine>
#include <QQuickItem>
#include <QScopedPointer>
#include <QSignalSpy>
#include <QTest>

#include <array>
#include <cmath>

using RoundedPolygon::MaterialShapes;
using RoundedPolygon::Morph;
using RoundedPolygon::RoundedPolygonShape;
using RoundedPolygon::Shapes;

namespace {

constexpr int kMaterialShapeCount =
    static_cast<int>(MaterialShapes::ShapeType::Heart) + 1;

void verifyFiniteCubics(const std::vector<RoundedPolygon::Cubic>& cubics) {
    QVERIFY(!cubics.empty());
    for (const auto& cubic : cubics) {
        for (const float coordinate : cubic.points()) {
            QVERIFY(std::isfinite(coordinate));
        }
    }
}

void verifyUsableShape(const RoundedPolygonShape& shape) {
    verifyFiniteCubics(shape.cubics());

    const auto bounds = shape.calculateBounds(false);
    for (const float coordinate : bounds) {
        QVERIFY(std::isfinite(coordinate));
    }
    QVERIFY(bounds[2] > bounds[0]);
    QVERIFY(bounds[3] > bounds[1]);
}

} // namespace

class M3ShapesTest : public QObject {
    Q_OBJECT

private slots:
    void everyMaterialPresetIsValid();
    void everyMaterialPresetMorphsFromCircle();
    void customFactoriesProduceUsableGeometry();
    void qmlModuleLoadsAndCreatesMaterialShape();
};

void M3ShapesTest::everyMaterialPresetIsValid() {
    for (int value = 0; value < kMaterialShapeCount; ++value) {
        const auto type = static_cast<MaterialShapes::ShapeType>(value);
        const auto shape = MaterialShapes::getShape(type);
        verifyUsableShape(shape);

        const auto normalized = shape.normalized();
        const auto bounds = normalized.calculateBounds(false);
        constexpr float epsilon = 0.001f;
        QVERIFY(bounds[0] >= -epsilon);
        QVERIFY(bounds[1] >= -epsilon);
        QVERIFY(bounds[2] <= 1.0f + epsilon);
        QVERIFY(bounds[3] <= 1.0f + epsilon);
    }
}

void M3ShapesTest::everyMaterialPresetMorphsFromCircle() {
    const auto circle = MaterialShapes::circle();

    for (int value = 0; value < kMaterialShapeCount; ++value) {
        const auto target = MaterialShapes::getShape(
            static_cast<MaterialShapes::ShapeType>(value));
        const Morph morph(circle, target);

        for (const float progress : std::array{0.0f, 0.5f, 1.0f}) {
            verifyFiniteCubics(morph.asCubics(progress));
        }
    }
}

void M3ShapesTest::customFactoriesProduceUsableGeometry() {
    verifyUsableShape(Shapes::circle(12).normalized());
    verifyUsableShape(Shapes::rectangle(2.0f, 1.0f,
        RoundedPolygon::CornerRounding(0.2f, 0.5f)).normalized());
    verifyUsableShape(Shapes::star(7, 1.0f, 0.45f,
        RoundedPolygon::CornerRounding(0.08f, 0.4f)).normalized());
    verifyUsableShape(Shapes::pill(2.0f, 1.0f, 0.5f).normalized());
}

void M3ShapesTest::qmlModuleLoadsAndCreatesMaterialShape() {
    QQmlEngine engine;
    engine.addImportPath(QStringLiteral(M3SHAPES_IMPORT_PATH));

    QQmlComponent component(&engine);
    component.setData(R"QML(
        import QtQuick
        import M3Shapes

        MaterialShape {
            width: 120
            height: 80
            shape: MaterialShape.Cookie12Sided
            fromShape: MaterialShape.Pill
            toShape: MaterialShape.Gem
            morphProgress: 0.5
            color: "#ff6750a4"
        }
    )QML",
        QUrl(QStringLiteral("inline:m3shapes-smoke.qml")));

    if (component.status() == QQmlComponent::Loading) {
        QSignalSpy statusChanged(&component, &QQmlComponent::statusChanged);
        QVERIFY(statusChanged.wait(5000));
    }

    QScopedPointer<QObject> object(component.create());
    QVERIFY2(object, qPrintable(component.errorString()));
    auto* item = qobject_cast<QQuickItem*>(object.data());
    QVERIFY(item);
    QCOMPARE(item->width(), 120.0);
    QCOMPARE(item->height(), 80.0);
    QVERIFY(item->contains(QPointF(60.0, 40.0)));
}

QTEST_MAIN(M3ShapesTest)

#include "m3shapes_test.moc"
