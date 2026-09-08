/*
    kwin-myopic-defocus - Myopic chromatic defocus effect for KWin (Plasma 6)

    SPDX-FileCopyrightText: 2026 kwin-myopic-defocus contributors
    SPDX-License-Identifier: GPL-3.0-or-later
*/

#pragma once

#include <effect/effect.h>

#include <map>
#include <memory>

namespace KWin
{

class GLFramebuffer;
class GLShader;
class GLTexture;
class LogicalOutput;

/**
 * MyopicDefocusEffect simulates myopic chromatic defocus on the whole screen.
 *
 * The green and blue color channels of the final composited desktop are
 * blurred (green a little, blue more) while the red channel stays sharp.
 * This "red in focus" filter reproduces the myopic chromatic aberration
 * described by Swiatczak et al. (2024), doi:10.15626/sjovs.v17i2.4232, and is
 * the desktop-wide equivalent of the Refractify browser extension.
 *
 * The effect is a *whole-screen* post pass, not a per-window filter: in
 * paintScreen() the already-composited scene (decorations included, exactly
 * as KWin presents it) is rendered into a per-output offscreen texture and
 * then drawn through the fragment shader on a fullscreen quad.  Because the
 * filter is re-applied to the freshly composited desktop on every frame,
 * there is no cached per-window result that could go stale: a decoration
 * repaint (e.g. the Klassy close-button hover fading out) is reflected in
 * the very next presented frame, with no "red residue" left behind.
 */
class MyopicDefocusEffect : public Effect
{
    Q_OBJECT

public:
    MyopicDefocusEffect();
    ~MyopicDefocusEffect() override;

    bool isActive() const override;
    int requestedEffectChainPosition() const override;
    void reconfigure(ReconfigureFlags flags) override;
    void paintScreen(const RenderTarget &renderTarget, const RenderViewport &viewport, int mask, const Region &deviceRegion, LogicalOutput *screen) override;

    static bool supported();
    static bool enabledByDefault();

public Q_SLOTS:
    void slotScreenRemoved(LogicalOutput *screen);

private:
    // A per-output offscreen texture that holds one frame of the composited
    // desktop (the input to the filter) plus its framebuffer.
    struct ScreenState
    {
        std::unique_ptr<GLTexture> texture;
        std::unique_ptr<GLFramebuffer> framebuffer;
        // Whether the texture already contains the whole desktop.  KWin only
        // repaints the damaged region of a frame into it, so right after the
        // texture is (re)created it would be mostly empty -- the effect must
        // then recapture the entire screen once before trusting incremental
        // damage again.
        bool complete = false;
    };

    void loadShader();
    void unloadShader();
    void setUniforms(const QSize &textureSize);
    bool m_valid = false;
    bool m_enabled = false;
    std::unique_ptr<GLShader> m_shader;
    std::map<LogicalOutput *, ScreenState> m_screens;

    // Uniform locations (resolved once after the shader is compiled).
    int m_locTexture = -1;
    int m_locMvp = -1;
    int m_locTextureWidth = -1;
    int m_locTextureHeight = -1;
    int m_locEffectStrength = -1;
    int m_locKernelOffset = -1;
    int m_locGreenKernel = -1;
    int m_locBlueKernel = -1;

    // Configuration, read from kwinrc group [Effect-myopicdefocus]
    float m_greenBlurRadius = 2.5f;
    float m_blueBlurRadius = 7.0f;
    float m_effectStrength = 0.30f;

    // Precomputed 1D blur kernels for the configured radii.
    float m_kernelOffsets[7] = {};
    float m_greenKernel[7] = {};
    float m_blueKernel[7] = {};
};

inline int MyopicDefocusEffect::requestedEffectChainPosition() const
{
    return 0; // run first so paintScreen() can capture the whole scene
}

inline bool MyopicDefocusEffect::enabledByDefault()
{
    return false;
}

} // namespace KWin
