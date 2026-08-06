#include "niri_output_model.h"

NiriOutputModel::NiriOutputModel(QObject *parent)
    : QAbstractListModel(parent)
{
}

int NiriOutputModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid())
        return 0;
    return m_outputs.count();
}

QVariant NiriOutputModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_outputs.count())
        return {};

    const NiriOutput &output = m_outputs.at(index.row());
    switch (role) {
    case NameRole:
        return output.name;
    case MakeRole:
        return output.make;
    case ModelRole:
        return output.model;
    case SerialRole:
        return output.serial;
    case LogicalXRole:
        return output.logicalX;
    case LogicalYRole:
        return output.logicalY;
    case LogicalWidthRole:
        return output.logicalWidth;
    case LogicalHeightRole:
        return output.logicalHeight;
    case ScaleRole:
        return output.scale;
    case TransformRole:
        return output.transform;
    case CurrentModeRole:
        return output.currentMode;
    case VrrEnabledRole:
        return output.vrrEnabled;
    default:
        return {};
    }
}

QHash<int, QByteArray> NiriOutputModel::roleNames() const
{
    return {
        {NameRole, "name"},
        {MakeRole, "make"},
        {ModelRole, "model"},
        {SerialRole, "serial"},
        {LogicalXRole, "logicalX"},
        {LogicalYRole, "logicalY"},
        {LogicalWidthRole, "logicalWidth"},
        {LogicalHeightRole, "logicalHeight"},
        {ScaleRole, "scale"},
        {TransformRole, "transform"},
        {CurrentModeRole, "currentMode"},
        {VrrEnabledRole, "vrrEnabled"},
    };
}

bool NiriOutputModel::setOutputs(const QList<NiriOutput> &outputs)
{
    bool sameRows = m_outputs.count() == outputs.count();
    if (sameRows) {
        for (int i = 0; i < m_outputs.count(); ++i) {
            if (m_outputs.at(i).name != outputs.at(i).name) {
                sameRows = false;
                break;
            }
        }
    }

    if (sameRows) {
        bool changed = false;
        for (int i = 0; i < outputs.count(); ++i) {
            const NiriOutput &oldOutput = m_outputs.at(i);
            const NiriOutput &newOutput = outputs.at(i);
            QList<int> changedRoles;
            if (oldOutput.name != newOutput.name)
                changedRoles.append(NameRole);
            if (oldOutput.make != newOutput.make)
                changedRoles.append(MakeRole);
            if (oldOutput.model != newOutput.model)
                changedRoles.append(ModelRole);
            if (oldOutput.serial != newOutput.serial)
                changedRoles.append(SerialRole);
            if (oldOutput.logicalX != newOutput.logicalX)
                changedRoles.append(LogicalXRole);
            if (oldOutput.logicalY != newOutput.logicalY)
                changedRoles.append(LogicalYRole);
            if (oldOutput.logicalWidth != newOutput.logicalWidth)
                changedRoles.append(LogicalWidthRole);
            if (oldOutput.logicalHeight != newOutput.logicalHeight)
                changedRoles.append(LogicalHeightRole);
            if (oldOutput.scale != newOutput.scale)
                changedRoles.append(ScaleRole);
            if (oldOutput.transform != newOutput.transform)
                changedRoles.append(TransformRole);
            if (oldOutput.currentMode != newOutput.currentMode)
                changedRoles.append(CurrentModeRole);
            if (oldOutput.vrrEnabled != newOutput.vrrEnabled)
                changedRoles.append(VrrEnabledRole);

            if (changedRoles.isEmpty())
                continue;

            m_outputs[i] = newOutput;
            const QModelIndex modelIndex = index(i);
            emit dataChanged(modelIndex, modelIndex, changedRoles);
            changed = true;
        }
        return changed;
    }

    const int oldCount = m_outputs.count();
    beginResetModel();
    m_outputs = outputs;
    endResetModel();
    if (oldCount != m_outputs.count())
        emit countChanged();
    return true;
}

const QList<NiriOutput> &NiriOutputModel::outputs() const
{
    return m_outputs;
}

QVariantMap NiriOutputModel::outputByName(const QString &name) const
{
    for (const NiriOutput &output : m_outputs) {
        if (output.name == name)
            return toMap(output);
    }
    return {};
}

QVariantMap NiriOutputModel::toMap(const NiriOutput &output) const
{
    return {
        {QStringLiteral("name"), output.name},
        {QStringLiteral("make"), output.make},
        {QStringLiteral("model"), output.model},
        {QStringLiteral("serial"), output.serial},
        {QStringLiteral("logicalX"), output.logicalX},
        {QStringLiteral("logicalY"), output.logicalY},
        {QStringLiteral("logicalWidth"), output.logicalWidth},
        {QStringLiteral("logicalHeight"), output.logicalHeight},
        {QStringLiteral("scale"), output.scale},
        {QStringLiteral("transform"), output.transform},
        {QStringLiteral("currentMode"), output.currentMode},
        {QStringLiteral("vrrEnabled"), output.vrrEnabled},
    };
}
