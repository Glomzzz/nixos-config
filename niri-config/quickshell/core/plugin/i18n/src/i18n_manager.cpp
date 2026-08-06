#include "i18n_manager.h"

#include <QCoreApplication>
#include <QQmlEngine>

I18nManager::I18nManager(QObject *parent)
    : QObject(parent)
{
}

I18nManager::~I18nManager()
{
    if (m_installed)
        QCoreApplication::removeTranslator(&m_translator);
}

QString I18nManager::language() const
{
    return m_language;
}

QString I18nManager::lastError() const
{
    return m_lastError;
}

QString I18nManager::normalizeLanguage(const QString &language)
{
    const QString normalized = language.trimmed().replace(QLatin1Char('-'), QLatin1Char('_'));
    const QString lower = normalized.toLower();
    if (lower.startsWith(QStringLiteral("en")))
        return QStringLiteral("en_US");
    if (lower == QStringLiteral("zh_tw")
            || lower == QStringLiteral("zh_hk")
            || lower == QStringLiteral("zh_mo")
            || lower.contains(QStringLiteral("hant"))) {
        return QStringLiteral("zh_TW");
    }
    return QStringLiteral("zh_CN");
}

void I18nManager::setLastError(const QString &message)
{
    if (m_lastError == message)
        return;
    m_lastError = message;
    emit lastErrorChanged();
}

bool I18nManager::setLanguage(const QString &language)
{
    const QString normalized = normalizeLanguage(language);
    if (m_language == normalized && m_installed)
        return true;

    if (m_installed) {
        QCoreApplication::removeTranslator(&m_translator);
        m_installed = false;
    }

    const QString resourcePath = QStringLiteral(":/i18n/clavis_%1.qm").arg(normalized);
    if (!m_translator.load(resourcePath)) {
        setLastError(QStringLiteral("Unable to load translation catalog: %1").arg(resourcePath));
        return false;
    }

    if (!QCoreApplication::installTranslator(&m_translator)) {
        setLastError(QStringLiteral("Unable to install translation catalog: %1").arg(resourcePath));
        return false;
    }

    m_installed = true;
    m_language = normalized;
    QLocale::setDefault(QLocale(normalized));
    if (QQmlEngine *engine = qmlEngine(this)) {
        engine->setUiLanguage(normalized);
        engine->retranslate();
    }

    setLastError(QString());
    emit languageChanged();
    return true;
}
