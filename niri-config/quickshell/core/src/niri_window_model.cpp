#include "niri_window_model.h"

NiriWindowModel::NiriWindowModel(QObject *parent)
    : QAbstractListModel(parent)
{
}

int NiriWindowModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid())
        return 0;
    return m_windows.count();
}

QVariant NiriWindowModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_windows.count())
        return {};

    const NiriWindow &window = m_windows.at(index.row());
    switch (role) {
    case IdRole:
        return QVariant::fromValue(window.id);
    case TitleRole:
        return window.title;
    case AppIdRole:
        return window.appId;
    case AppNameRole:
        return window.appName;
    case PidRole:
        return window.pid;
    case WorkspaceIdRole:
        return QVariant::fromValue(window.workspaceId);
    case IsFocusedRole:
        return window.isFocused;
    case IsFloatingRole:
        return window.isFloating;
    case IsUrgentRole:
        return window.isUrgent;
    case LayoutColumnRole:
        return window.layoutColumn;
    case LayoutRowRole:
        return window.layoutRow;
    case IconPathRole:
        return window.iconPath;
    default:
        return {};
    }
}

QHash<int, QByteArray> NiriWindowModel::roleNames() const
{
    return {
        {IdRole, "id"},
        {TitleRole, "title"},
        {AppIdRole, "appId"},
        {AppNameRole, "appName"},
        {PidRole, "pid"},
        {WorkspaceIdRole, "workspaceId"},
        {IsFocusedRole, "isFocused"},
        {IsFloatingRole, "isFloating"},
        {IsUrgentRole, "isUrgent"},
        {LayoutColumnRole, "layoutColumn"},
        {LayoutRowRole, "layoutRow"},
        {IconPathRole, "iconPath"},
    };
}

bool NiriWindowModel::setWindows(const QList<NiriWindow> &windows)
{
    bool sameRows = m_windows.count() == windows.count();
    if (sameRows) {
        for (int i = 0; i < m_windows.count(); ++i) {
            if (m_windows.at(i).id != windows.at(i).id) {
                sameRows = false;
                break;
            }
        }
    }

    if (sameRows) {
        bool changed = false;
        for (int i = 0; i < windows.count(); ++i) {
            const NiriWindow &oldWindow = m_windows.at(i);
            const NiriWindow &newWindow = windows.at(i);
            QList<int> changedRoles;
            if (oldWindow.id != newWindow.id)
                changedRoles.append(IdRole);
            if (oldWindow.title != newWindow.title)
                changedRoles.append(TitleRole);
            if (oldWindow.appId != newWindow.appId)
                changedRoles.append(AppIdRole);
            if (oldWindow.appName != newWindow.appName)
                changedRoles.append(AppNameRole);
            if (oldWindow.pid != newWindow.pid)
                changedRoles.append(PidRole);
            if (oldWindow.workspaceId != newWindow.workspaceId)
                changedRoles.append(WorkspaceIdRole);
            if (oldWindow.isFocused != newWindow.isFocused)
                changedRoles.append(IsFocusedRole);
            if (oldWindow.isFloating != newWindow.isFloating)
                changedRoles.append(IsFloatingRole);
            if (oldWindow.isUrgent != newWindow.isUrgent)
                changedRoles.append(IsUrgentRole);
            if (oldWindow.layoutColumn != newWindow.layoutColumn)
                changedRoles.append(LayoutColumnRole);
            if (oldWindow.layoutRow != newWindow.layoutRow)
                changedRoles.append(LayoutRowRole);
            if (oldWindow.iconPath != newWindow.iconPath)
                changedRoles.append(IconPathRole);

            if (changedRoles.isEmpty())
                continue;

            m_windows[i] = newWindow;
            const QModelIndex modelIndex = index(i);
            emit dataChanged(modelIndex, modelIndex, changedRoles);
            changed = true;
        }
        return changed;
    }

    const int oldCount = m_windows.count();
    beginResetModel();
    m_windows = windows;
    endResetModel();
    if (oldCount != m_windows.count())
        emit countChanged();
    return true;
}

const QList<NiriWindow> &NiriWindowModel::windows() const
{
    return m_windows;
}

QVariantMap NiriWindowModel::windowById(quint64 id) const
{
    for (const NiriWindow &window : m_windows) {
        if (window.id == id)
            return toMap(window);
    }
    return {};
}

QVariantList NiriWindowModel::windowsForWorkspace(quint64 workspaceId) const
{
    QVariantList result;
    for (const NiriWindow &window : m_windows) {
        if (window.workspaceId == workspaceId)
            result.append(toMap(window));
    }
    return result;
}

QVariantList NiriWindowModel::allWindows() const
{
    QVariantList result;
    for (const NiriWindow &window : m_windows)
        result.append(toMap(window));
    return result;
}

QVariantMap NiriWindowModel::toMap(const NiriWindow &window) const
{
    return {
        {QStringLiteral("id"), QVariant::fromValue(window.id)},
        {QStringLiteral("title"), window.title},
        {QStringLiteral("appId"), window.appId},
        {QStringLiteral("appName"), window.appName},
        {QStringLiteral("pid"), window.pid},
        {QStringLiteral("workspaceId"), QVariant::fromValue(window.workspaceId)},
        {QStringLiteral("isFocused"), window.isFocused},
        {QStringLiteral("isFloating"), window.isFloating},
        {QStringLiteral("isUrgent"), window.isUrgent},
        {QStringLiteral("layoutColumn"), window.layoutColumn},
        {QStringLiteral("layoutRow"), window.layoutRow},
        {QStringLiteral("iconPath"), window.iconPath},
    };
}
