/*
    kwin-myopic-defocus - Myopic chromatic defocus effect for KWin (Plasma 6)

    SPDX-FileCopyrightText: 2026 kwin-myopic-defocus contributors
    SPDX-License-Identifier: GPL-3.0-or-later
*/
#include "myopicdefocus_config.h"

// KConfigSkeleton generated from myopicdefocus.kcfg
#include "myopicdefocusconfig.h"

#include <KPluginFactory>
#include <kwineffects_interface.h>

K_PLUGIN_CLASS_WITH_JSON(KWin::MyopicDefocusConfig, "metadata.json")

namespace KWin
{

MyopicDefocusConfig::MyopicDefocusConfig(QObject *parent, const KPluginMetaData &data)
    : KCModule(parent, data)
{
    // No aboutData/help pages are provided, so drop the (dead) Help button.
    setButtons(Apply | Default);

    ui.setupUi(widget());
    MyopicDefocusSettings::instance(QStringLiteral("kwinrc"));
    addConfig(MyopicDefocusSettings::self(), widget());
}

MyopicDefocusConfig::~MyopicDefocusConfig()
{
}

void MyopicDefocusConfig::save()
{
    KCModule::save();

    // Ask KWin to re-read kwinrc and push the new values to the effect.
    OrgKdeKwinEffectsInterface interface(QStringLiteral("org.kde.KWin"),
                                         QStringLiteral("/Effects"),
                                         QDBusConnection::sessionBus());
    interface.reconfigureEffect(QStringLiteral("myopicdefocus"));
}

} // namespace KWin

#include "myopicdefocus_config.moc"

#include "moc_myopicdefocus_config.cpp"
