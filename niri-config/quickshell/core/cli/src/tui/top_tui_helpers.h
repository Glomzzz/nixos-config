#pragma once

#include <QString>

#include <deque>
#include <optional>
#include <vector>

namespace Clavis::TopTuiDetail {

struct CoreGridLayout {
    int columns = 0;
    int rows = 0;
    int cellWidth = 0;
    int labelWidth = 0;
    int meterWidth = 0;
    int capacity = 0;
    int page = 0;
    int pageCount = 0;
    int firstIndex = 0;
    int visibleCount = 0;
};

CoreGridLayout calculateCoreGridLayout(int width,
                                       int height,
                                       int coreCount,
                                       int largestCoreId,
                                       int requestedPage);

struct PageLayout {
    int page = 0;
    int pageCount = 1;
    int firstIndex = 0;
    int visibleCount = 0;
};

PageLayout calculatePageLayout(int itemCount,
                               int itemsPerPage,
                               int requestedPage);

QString borderlessMeter(const std::optional<double> &percent,
                        int width,
                        bool unicode);

enum LineConnection : unsigned char {
    ConnectNone = 0,
    ConnectUp = 1 << 0,
    ConnectRight = 1 << 1,
    ConnectDown = 1 << 2,
    ConnectLeft = 1 << 3,
};

struct LineRaster {
    int width = 0;
    int height = 0;
    std::vector<unsigned char> connections;
    std::vector<bool> points;

    unsigned char connectionAt(int x, int y) const;
    bool pointAt(int x, int y) const;
};

LineRaster rasterizeLine(const std::deque<double> &history,
                         int width,
                         int height,
                         double maximum);

int nextGraphSource(int currentSource, int gpuCount);

int adjustedRefreshInterval(int currentIntervalMs, int deltaMs);

int resolveProcessSelection(bool explicitlySelected,
                            long long previousPid,
                            int previousIndex,
                            const std::vector<long long> &orderedPids);

} // namespace Clavis::TopTuiDetail
