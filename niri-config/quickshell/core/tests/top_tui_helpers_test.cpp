#include "../cli/src/tui/top_tui_helpers.h"

#include <QtTest>

using namespace Clavis::TopTuiDetail;

class TopTuiHelpersTest : public QObject {
    Q_OBJECT

private slots:
    void borderlessMeterKeepsExactWidth();
    void coreGridPaginatesWithoutDroppingCores();
    void listPageLayoutClampsAndKeepsLastItems();
    void lineRasterConnectsRawSamples();
    void graphSourceCyclesAcrossAllGpus();
    void refreshIntervalStaysWithinSupportedRange();
    void defaultProcessSelectionTracksFirstRow();
};

void TopTuiHelpersTest::borderlessMeterKeepsExactWidth()
{
    const QString oneDigit = borderlessMeter(6.0, 18, true);
    const QString twoDigits = borderlessMeter(13.0, 18, true);
    const QString full = borderlessMeter(100.0, 18, true);

    QCOMPARE(oneDigit.size(), 18);
    QCOMPARE(twoDigits.size(), 18);
    QCOMPARE(full.size(), 18);
    QVERIFY(!oneDigit.contains(QLatin1Char('[')));
    QVERIFY(!oneDigit.contains(QLatin1Char(']')));
}

void TopTuiHelpersTest::coreGridPaginatesWithoutDroppingCores()
{
    const CoreGridLayout small =
        calculateCoreGridLayout(72, 10, 20, 19, 0);
    QCOMPARE(small.pageCount, 1);
    QCOMPARE(small.visibleCount, 20);

    const CoreGridLayout first =
        calculateCoreGridLayout(72, 10, 96, 95, 0);
    QVERIFY(first.capacity > 0);
    QVERIFY(first.capacity < 96);
    QVERIFY(first.pageCount > 1);
    QCOMPARE(first.firstIndex, 0);

    const CoreGridLayout last =
        calculateCoreGridLayout(72, 10, 96, 95, first.pageCount - 1);
    QCOMPARE(last.firstIndex + last.visibleCount, 96);
    QVERIFY(last.meterWidth >= 5);

    const CoreGridLayout many =
        calculateCoreGridLayout(72, 10, 192, 191, 99);
    QCOMPARE(many.firstIndex + many.visibleCount, 192);
    QCOMPARE(many.page, many.pageCount - 1);
}

void TopTuiHelpersTest::listPageLayoutClampsAndKeepsLastItems()
{
    const PageLayout first = calculatePageLayout(7, 3, 0);
    QCOMPARE(first.pageCount, 3);
    QCOMPARE(first.firstIndex, 0);
    QCOMPARE(first.visibleCount, 3);

    const PageLayout last = calculatePageLayout(7, 3, 99);
    QCOMPARE(last.page, 2);
    QCOMPARE(last.firstIndex, 6);
    QCOMPARE(last.visibleCount, 1);

    const PageLayout empty = calculatePageLayout(0, 3, 4);
    QCOMPARE(empty.page, 0);
    QCOMPARE(empty.pageCount, 1);
    QCOMPARE(empty.visibleCount, 0);
}

void TopTuiHelpersTest::lineRasterConnectsRawSamples()
{
    const std::deque<double> samples{0.0, 50.0, 100.0};
    const LineRaster raster = rasterizeLine(samples, 3, 5, 100.0);

    QVERIFY(raster.pointAt(0, 4));
    QVERIFY(raster.pointAt(1, 2));
    QVERIFY(raster.pointAt(2, 0));
    QVERIFY(raster.connectionAt(1, 3) != ConnectNone);
    QVERIFY(raster.connectionAt(2, 1) != ConnectNone);
}

void TopTuiHelpersTest::graphSourceCyclesAcrossAllGpus()
{
    QCOMPARE(nextGraphSource(0, 2), 1);
    QCOMPARE(nextGraphSource(1, 2), 2);
    QCOMPARE(nextGraphSource(2, 2), 0);
    QCOMPARE(nextGraphSource(0, 0), 0);
    QCOMPARE(nextGraphSource(99, 2), 0);
}

void TopTuiHelpersTest::refreshIntervalStaysWithinSupportedRange()
{
    QCOMPARE(adjustedRefreshInterval(1000, 250), 1250);
    QCOMPARE(adjustedRefreshInterval(1000, -250), 750);
    QCOMPARE(adjustedRefreshInterval(250, -250), 250);
    QCOMPARE(adjustedRefreshInterval(60000, 250), 60000);
}

void TopTuiHelpersTest::defaultProcessSelectionTracksFirstRow()
{
    const std::vector<long long> firstSample{1, 20, 30};
    const std::vector<long long> sortedSample{30, 20, 1};

    QCOMPARE(resolveProcessSelection(false, 1, 0, sortedSample), 0);
    QCOMPARE(resolveProcessSelection(true, 20, 1, sortedSample), 1);
    QCOMPARE(resolveProcessSelection(true, 999, 7, firstSample), 2);
}

QTEST_MAIN(TopTuiHelpersTest)

#include "top_tui_helpers_test.moc"
