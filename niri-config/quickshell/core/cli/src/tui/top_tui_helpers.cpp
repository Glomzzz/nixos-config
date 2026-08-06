#include "top_tui_helpers.h"

#include <algorithm>
#include <cmath>

namespace Clavis::TopTuiDetail {
namespace {

int divideRoundUp(int value, int divisor)
{
    return divisor > 0 ? (value + divisor - 1) / divisor : 0;
}

int rasterIndex(const LineRaster &raster, int x, int y)
{
    if (x < 0 || x >= raster.width || y < 0 || y >= raster.height)
        return -1;
    return y * raster.width + x;
}

void markPoint(LineRaster &raster, int x, int y)
{
    const int index = rasterIndex(raster, x, y);
    if (index >= 0)
        raster.points.at(index) = true;
}

void addConnection(LineRaster &raster,
                   int x,
                   int y,
                   LineConnection connection)
{
    const int index = rasterIndex(raster, x, y);
    if (index >= 0)
        raster.connections.at(index) |= connection;
}

void connectAdjacent(LineRaster &raster,
                     int fromX,
                     int fromY,
                     int toX,
                     int toY)
{
    if (fromX == toX) {
        if (fromY < toY) {
            addConnection(raster, fromX, fromY, ConnectDown);
            addConnection(raster, toX, toY, ConnectUp);
        } else if (fromY > toY) {
            addConnection(raster, fromX, fromY, ConnectUp);
            addConnection(raster, toX, toY, ConnectDown);
        }
        return;
    }

    if (fromY == toY) {
        if (fromX < toX) {
            addConnection(raster, fromX, fromY, ConnectRight);
            addConnection(raster, toX, toY, ConnectLeft);
        } else {
            addConnection(raster, fromX, fromY, ConnectLeft);
            addConnection(raster, toX, toY, ConnectRight);
        }
    }
}

} // namespace

CoreGridLayout calculateCoreGridLayout(int width,
                                       int height,
                                       int coreCount,
                                       int largestCoreId,
                                       int requestedPage)
{
    CoreGridLayout result;
    if (width <= 0 || height <= 0 || coreCount <= 0)
        return result;

    const int labelDigits =
        std::max(
            2,
            static_cast<int>(
                QString::number(std::max(0, largestCoreId)).size()));
    result.labelWidth = 1 + labelDigits;

    constexpr int minimumMeterWidth = 5;
    constexpr int percentWidth = 4;
    constexpr int interCellGap = 1;
    constexpr int internalGaps = 2;
    const int minimumCellWidth =
        result.labelWidth + minimumMeterWidth + percentWidth
        + internalGaps + interCellGap;

    const int maximumColumns = std::max(1, width / minimumCellWidth);
    const int neededColumns =
        std::max(1, divideRoundUp(coreCount, height));
    result.columns = std::min(neededColumns, maximumColumns);
    result.rows = height;
    result.cellWidth = std::max(1, width / result.columns);
    result.meterWidth =
        std::max(0,
                 result.cellWidth - interCellGap - result.labelWidth
                     - percentWidth - internalGaps);
    result.capacity = std::max(1, result.columns * result.rows);
    result.pageCount = std::max(1, divideRoundUp(coreCount, result.capacity));
    result.page = std::clamp(requestedPage, 0, result.pageCount - 1);
    result.firstIndex = result.page * result.capacity;
    result.visibleCount =
        std::min(result.capacity, coreCount - result.firstIndex);
    return result;
}

PageLayout calculatePageLayout(int itemCount,
                               int itemsPerPage,
                               int requestedPage)
{
    PageLayout result;
    if (itemCount <= 0 || itemsPerPage <= 0)
        return result;

    result.pageCount = std::max(1, divideRoundUp(itemCount, itemsPerPage));
    result.page = std::clamp(requestedPage, 0, result.pageCount - 1);
    result.firstIndex = result.page * itemsPerPage;
    result.visibleCount =
        std::min(itemsPerPage, itemCount - result.firstIndex);
    return result;
}

QString borderlessMeter(const std::optional<double> &percent,
                        int width,
                        bool unicode)
{
    if (width <= 0)
        return {};

    const QString full = unicode ? QStringLiteral("█") : QStringLiteral("#");
    const QString empty = unicode ? QStringLiteral("░") : QStringLiteral("-");
    if (!percent || !std::isfinite(*percent))
        return empty.repeated(width);

    const double normalized =
        std::clamp(*percent, 0.0, 100.0) / 100.0;
    const int filled =
        std::clamp(static_cast<int>(std::lround(normalized * width)), 0, width);
    return full.repeated(filled) + empty.repeated(width - filled);
}

unsigned char LineRaster::connectionAt(int x, int y) const
{
    const int index = rasterIndex(*this, x, y);
    return index >= 0 ? connections.at(index) : ConnectNone;
}

bool LineRaster::pointAt(int x, int y) const
{
    const int index = rasterIndex(*this, x, y);
    return index >= 0 && points.at(index);
}

LineRaster rasterizeLine(const std::deque<double> &history,
                         int width,
                         int height,
                         double maximum)
{
    LineRaster result;
    result.width = std::max(0, width);
    result.height = std::max(0, height);
    const int cellCount = result.width * result.height;
    result.connections.assign(cellCount, ConnectNone);
    result.points.assign(cellCount, false);

    if (history.empty() || result.width <= 0 || result.height <= 0)
        return result;

    maximum = std::max(maximum, 0.000001);
    const int sampleCount =
        std::min(result.width, static_cast<int>(history.size()));
    const int startColumn = result.width - sampleCount;
    const auto firstSample = history.end() - sampleCount;

    std::vector<int> rows;
    rows.reserve(sampleCount);
    for (auto iterator = firstSample; iterator != history.end(); ++iterator) {
        const double value = std::isfinite(*iterator) ? *iterator : 0.0;
        const double ratio = std::clamp(value / maximum, 0.0, 1.0);
        rows.push_back(
            result.height - 1
            - static_cast<int>(
                std::lround(ratio * std::max(0, result.height - 1))));
    }

    for (int index = 0; index < sampleCount; ++index)
        markPoint(result, startColumn + index, rows.at(index));

    for (int index = 1; index < sampleCount; ++index) {
        const int previousX = startColumn + index - 1;
        const int currentX = startColumn + index;
        const int previousY = rows.at(index - 1);
        const int currentY = rows.at(index);

        connectAdjacent(
            result, previousX, previousY, currentX, previousY);
        const int direction = currentY >= previousY ? 1 : -1;
        for (int y = previousY; y != currentY; y += direction)
            connectAdjacent(result, currentX, y, currentX, y + direction);
    }

    return result;
}

int nextGraphSource(int currentSource, int gpuCount)
{
    const int sourceCount = std::max(1, gpuCount + 1);
    if (currentSource < 0 || currentSource >= sourceCount)
        return 0;
    return (currentSource + 1) % sourceCount;
}

int adjustedRefreshInterval(int currentIntervalMs, int deltaMs)
{
    constexpr int minimumIntervalMs = 250;
    constexpr int maximumIntervalMs = 60000;
    return std::clamp(
        currentIntervalMs + deltaMs, minimumIntervalMs, maximumIntervalMs);
}

int resolveProcessSelection(bool explicitlySelected,
                            long long previousPid,
                            int previousIndex,
                            const std::vector<long long> &orderedPids)
{
    if (orderedPids.empty() || !explicitlySelected)
        return 0;

    if (previousPid > 0) {
        const auto restored =
            std::find(orderedPids.begin(), orderedPids.end(), previousPid);
        if (restored != orderedPids.end())
            return static_cast<int>(
                std::distance(orderedPids.begin(), restored));
    }

    return std::clamp(
        previousIndex, 0, static_cast<int>(orderedPids.size()) - 1);
}

} // namespace Clavis::TopTuiDetail
