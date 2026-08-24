/*
    kwin-myopic-defocus - Myopic chromatic defocus effect for KWin (Plasma 6)

    SPDX-FileCopyrightText: 2026 kwin-myopic-defocus contributors
    SPDX-License-Identifier: GPL-3.0-or-later
*/

#include "myopicdefocus.h"

#include <effect/effecthandler.h>
#include <effect/effectwindow.h>
#include <opengl/glshader.h>
#include <opengl/glshadermanager.h>

#include <KConfig>
#include <KConfigGroup>
#include <KGlobalAccel>

#include <QAction>
#include <QKeySequence>

#include <algorithm>

static void ensureResources()
{
    // Embed the shader in the plugin binary (myopicdefocus.qrc).
    Q_INIT_RESOURCE(myopicdefocus);
}

namespace KWin
{

MyopicDefocusEffect::MyopicDefocusEffect()
    : OffscreenEffect()
{
    reconfigure(ReconfigureAll);

    // Global shortcut to toggle the filter at runtime.
    QAction *toggleAction = new QAction(this);
    toggleAction->setObjectName(QStringLiteral("ToggleMyopicDefocus"));
    toggleAction->setText(QStringLiteral("Toggle Myopic Defocus Effect"));
    toggleAction->setAutoRepeat(false);
    KGlobalAccel::self()->setDefaultShortcut(toggleAction, QList<QKeySequence>({QKeySequence(QStringLiteral("Meta+Shift+D"))}));
    KGlobalAccel::self()->setShortcut(toggleAction, QList<QKeySequence>({QKeySequence(QStringLiteral("Meta+Shift+D"))}));
    connect(toggleAction, &QAction::triggered, this, &MyopicDefocusEffect::toggleEffect);

    // The kwinrc "[Plugins] myopicdefocusEnabled" flag decides whether the
    // effect is loaded; once loaded, the filter is on by default.
    if (m_valid) {
        m_enabled = true;
    }

    // Self-healing: keep offscreen textures in sync with decoration state
    // changes (focus change via windowActivated, titlebar/button repaints
    // via windowDamaged).  The filter keeps the red channel sharp, so a
    // stale texture shows as a sharp red close-button that lingers after
    // the real decoration turned grey -- visible as a "red edge" when the
    // compositor is otherwise idle (e.g. nothing focused).
    connect(effects, &EffectsHandler::windowActivated, this, &MyopicDefocusEffect::onWindowActivated);
    connect(effects, &EffectsHandler::windowDeleted, this, &MyopicDefocusEffect::onWindowDeleted);
}

void MyopicDefocusEffect::onWindowActivated(EffectWindow *window)
{
    // Both the window that lost focus (its decoration went grey) and the one
    // that gained it may keep stale sharp-red pixels in their offscreen
    // textures; force both to re-render fresh.
    if (m_lastActive && m_lastActive != window) {
        scheduleRefresh(m_lastActive);
    }
    scheduleRefresh(window);
    m_lastActive = window;
}

void MyopicDefocusEffect::onWindowDamaged(EffectWindow *window)
{
    if (!m_enabled || !m_valid || !window) {
        return;
    }
    // Only decorated windows have titlebar buttons.  Rebuilding the offscreen
    // texture for undecorated content repaints (videos, games, fullscreen
    // terminals) would churn the GPU for nothing.
    if (!window->hasDecoration()) {
        return;
    }
    scheduleRefresh(window);
}

void MyopicDefocusEffect::scheduleRefresh(EffectWindow *window)
{
    if (!m_enabled || !m_valid || !window) {
        return;
    }
    // Coalesce per frame; repaint only this window's screen area, not the
    // whole screen.  The previous fix called addRepaintFull() on every
    // damage event, which kept the compositor busy and made titlebar button
    // repaints stutter.
    m_pendingRefresh.insert(window);
    effects->addRepaint(window->expandedGeometry());
}

void MyopicDefocusEffect::onWindowDeleted(EffectWindow *window)
{
    auto it = m_damagedConnections.find(window);
    if (it != m_damagedConnections.end()) {
        disconnect(*it);
        m_damagedConnections.erase(it);
    }
    m_pendingRefresh.remove(window);
    if (m_lastActive == window) {
        m_lastActive = nullptr;
    }
}

MyopicDefocusEffect::~MyopicDefocusEffect() = default;

bool MyopicDefocusEffect::supported()
{
    return effects->compositingType() == OpenGLCompositing;
}

bool MyopicDefocusEffect::isActive() const
{
    return m_valid && m_enabled;
}

void MyopicDefocusEffect::reconfigure(ReconfigureFlags flags)
{
    Q_UNUSED(flags)

    KConfig config(QStringLiteral("kwinrc"));
    KConfigGroup conf(&config, QStringLiteral("Effect-myopicdefocus"));

    m_greenBlurRadius = conf.readEntry("GreenBlurRadius", 2.5);
    m_blueBlurRadius = conf.readEntry("BlueBlurRadius", 7.0);
    m_effectStrength = conf.readEntry("EffectStrength", 0.30);
    m_effectStrength = std::clamp(m_effectStrength, 0.0f, 1.0f);

    if (!m_valid) {
        loadShader();
    } else if (m_shader) {
        // Push new uniform values to the existing program.
        ShaderBinder binder(m_shader.get());
        m_shader->setUniform("greenBlurRadius", m_greenBlurRadius);
        m_shader->setUniform("blueBlurRadius", m_blueBlurRadius);
        m_shader->setUniform("effectStrength", m_effectStrength);
    }

    effects->addRepaintFull();
}

void MyopicDefocusEffect::loadShader()
{
    m_valid = false;
    m_shader.reset();

    if (!supported()) {
        return;
    }

    ensureResources();

    m_shader = ShaderManager::instance()->generateShaderFromFile(
        ShaderTrait::MapTexture,
        QString(), // use the built-in MapTexture vertex shader
        QStringLiteral(":/effects/myopicdefocus/shaders/myopicdefocus.frag"));

    if (!m_shader) {
        qWarning() << "MyopicDefocus: failed to load the fragment shader";
        m_shader.reset();
        return;
    }

    ShaderBinder binder(m_shader.get());
    m_shader->setUniform("greenBlurRadius", m_greenBlurRadius);
    m_shader->setUniform("blueBlurRadius", m_blueBlurRadius);
    m_shader->setUniform("effectStrength", m_effectStrength);

    m_valid = true;
}

void MyopicDefocusEffect::prePaintScreen(ScreenPrePaintData &data)
{
    if (m_enabled && m_valid) {
        // Self-healing bookkeeping: keep every visible window on the
        // current desktop redirected, so the filter always covers the
        // full screen no matter which windows appear, vanish, move to
        // another desktop or get minimized.
        const auto windows = effects->stackingOrder();
        for (EffectWindow *window : windows) {
            const bool wantRedirect = window->isOnCurrentDesktop() && !window->isMinimized();
            const bool haveRedirect = m_windows.contains(window);
            if (wantRedirect && !haveRedirect) {
                redirect(window);
                setShader(window, m_shader.get());
                m_windows.append(window);

                // Self-healing: any decoration/content repaint for this
                // window schedules a forced texture re-render, so a skipped
                // or coalesced repaint can't leave stale sharp-red pixels
                // (e.g. the close-button hover highlight).
                m_damagedConnections.insert(
                    window,
                    connect(window, &EffectWindow::windowDamaged, this, &MyopicDefocusEffect::onWindowDamaged));
            } else if (!wantRedirect && haveRedirect) {
                auto it = m_damagedConnections.find(window);
                if (it != m_damagedConnections.end()) {
                    disconnect(*it);
                    m_damagedConnections.erase(it);
                }
                m_pendingRefresh.remove(window);
                unredirect(window);
                m_windows.removeOne(window);
            }
        }

        // Apply pending self-heals: re-create each window's offscreen target
        // so it re-renders fresh this frame, clearing any stale content.
        // KWin 6 exposes no damage-region API on EffectWindow (no addDamage /
        // damageRegion), so unredirect+redirect is the only reliable refresh
        // primitive: redirect() forces the window to render into a fresh target.
        if (!m_pendingRefresh.isEmpty()) {
            const QSet<EffectWindow *> pending = m_pendingRefresh;
            m_pendingRefresh.clear();
            for (EffectWindow *window : pending) {
                if (!m_windows.contains(window)) {
                    continue;
                }
                unredirect(window);
                m_windows.removeOne(window);
                redirect(window);
                setShader(window, m_shader.get());
                m_windows.append(window);
            }
        }
    }

    effects->prePaintScreen(data);
}

void MyopicDefocusEffect::toggleEffect()
{
    if (m_enabled) {
        m_enabled = false;
        for (EffectWindow *window : std::as_const(m_windows)) {
            unredirect(window);
        }
        m_windows.clear();
        for (auto &conn : m_damagedConnections) {
            disconnect(conn);
        }
        m_damagedConnections.clear();
        m_pendingRefresh.clear();
        m_lastActive = nullptr;
    } else {
        m_enabled = m_valid;
    }

    effects->addRepaintFull();
}

} // namespace KWin

#include "moc_myopicdefocus.cpp"
