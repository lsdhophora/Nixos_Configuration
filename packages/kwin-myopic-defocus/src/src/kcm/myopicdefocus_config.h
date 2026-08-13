/*
    kwin-myopic-defocus - Myopic chromatic defocus effect for KWin (Plasma 6)

    SPDX-FileCopyrightText: 2026 kwin-myopic-defocus contributors
    SPDX-License-Identifier: GPL-3.0-or-later
*/

#pragma once

#include "ui_myopicdefocus_config.h"

#include <KCModule>

namespace KWin
{

class MyopicDefocusConfig : public KCModule
{
    Q_OBJECT

public:
    explicit MyopicDefocusConfig(QObject *parent, const KPluginMetaData &data);
    ~MyopicDefocusConfig() override;

    void save() override;

private:
    ::Ui::MyopicDefocusConfig ui;
};

} // namespace KWin
