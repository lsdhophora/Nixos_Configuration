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
            } else if (!wantRedirect && haveRedirect) {
                unredirect(window);
                m_windows.removeOne(window);
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
    } else {
        m_enabled = m_valid;
    }

    effects->addRepaintFull();
}

} // namespace KWin

#include "moc_myopicdefocus.cpp"
