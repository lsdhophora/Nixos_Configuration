/*
    kwin-myopic-defocus - Myopic chromatic defocus effect for KWin (Plasma 6)

    SPDX-FileCopyrightText: 2026 kwin-myopic-defocus contributors
    SPDX-License-Identifier: GPL-3.0-or-later
*/

#pragma once

#include "effect/offscreeneffect.h"

#include <QHash>
#include <QMetaObject>
#include <memory>

namespace KWin
{

class GLShader;

/**
 * MyopicDefocusEffect simulates myopic chromatic defocus on the whole screen.
 *
 * The green and blue color channels of every window are blurred (green a
 * little, blue more) while the red channel stays sharp.  This "red in
 * focus" filter reproduces the myopic chromatic aberration described by
 * Swiatczak et al. (2024), doi:10.15626/sjovs.v17i2.4232, and is the
 * desktop-wide equivalent of the Refractify browser extension.
 */
class MyopicDefocusEffect : public OffscreenEffect
{
    Q_OBJECT

public:
    MyopicDefocusEffect();
    ~MyopicDefocusEffect() override;

    bool isActive() const override;
    int requestedEffectChainPosition() const override;
    void reconfigure(ReconfigureFlags flags) override;
    void prePaintScreen(ScreenPrePaintData &data) override;

    static bool supported();
    static bool enabledByDefault();

public Q_SLOTS:
    /**
     * Temporarily enable/disable the filter at runtime.
     * The kwinrc "[Plugins] myopicdefocusEnabled" flag controls whether the
     * effect is loaded at all; this toggles it until the session ends.
     */
    void toggleEffect();

private:
    void loadShader();

    // Decoration-freshness ("self-healing"): when a window's decoration
    // state changes (focus change via windowActivated, or any repaint via
    // windowDamaged), the window's screen area is scheduled for a repaint so
    // stale content can't linger -- e.g. a sharp red close-button left behind
    // by a skipped/coalesced hover-exit repaint, even when the compositor is
    // otherwise idle ("no focus" case).  The refresh is deliberately
    // non-destructive: KWin's damage pipeline keeps the offscreen target in
    // sync, so only a repaint is needed.  (A previous version force-recreated
    // the target with unredirect+redirect on every damage; that churn raced
    // with the render pass and produced garbled frames, so it was removed.)
    void onWindowActivated(EffectWindow *window);
    void onWindowDeleted(EffectWindow *window);
    void onWindowDamaged(EffectWindow *window);
    void refreshWindow(EffectWindow *window);

    bool m_valid = false;
    bool m_enabled = false;
    std::unique_ptr<GLShader> m_shader;
    QList<EffectWindow *> m_windows;
    QHash<EffectWindow *, QMetaObject::Connection> m_damagedConnections;
    EffectWindow *m_lastActive = nullptr;

    // Configuration, read from kwinrc group [Effect-myopicdefocus]
    float m_greenBlurRadius = 2.5f;
    float m_blueBlurRadius = 7.0f;
    float m_effectStrength = 0.30f;
};

inline int MyopicDefocusEffect::requestedEffectChainPosition() const
{
    return 98; // near the end of the chain, right before final composition
}

inline bool MyopicDefocusEffect::enabledByDefault()
{
    return false;
}

} // namespace KWin
