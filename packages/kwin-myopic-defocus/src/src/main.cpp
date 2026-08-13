/*
    kwin-myopic-defocus - Myopic chromatic defocus effect for KWin (Plasma 6)

    SPDX-FileCopyrightText: 2026 kwin-myopic-defocus contributors
    SPDX-License-Identifier: GPL-3.0-or-later
*/

#include "myopicdefocus.h"

namespace KWin
{

KWIN_EFFECT_FACTORY_SUPPORTED_ENABLED(MyopicDefocusEffect,
                                     "metadata.json",
                                     return MyopicDefocusEffect::supported();,
                                     return MyopicDefocusEffect::enabledByDefault();)

} // namespace KWin

#include "main.moc"
