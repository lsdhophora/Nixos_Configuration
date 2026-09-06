/*
    kwin-myopic-defocus - Myopic chromatic defocus effect for KWin (Plasma 6)

    SPDX-FileCopyrightText: 2026 kwin-myopic-defocus contributors
    SPDX-License-Identifier: GPL-3.0-or-later
*/

#include "myopicdefocus.h"

#include <core/rendertarget.h>
#include <core/renderviewport.h>
#include <effect/effecthandler.h>
#include <opengl/glframebuffer.h>
#include <opengl/glshader.h>
#include <opengl/glshadermanager.h>
#include <opengl/gltexture.h>
#include <opengl/glvertexbuffer.h>

#include <KConfig>
#include <KConfigGroup>

#include <QFile>
#include <QMatrix4x4>
#include <QVector2D>

#include <algorithm>
#include <cmath>
#include <cstring>
#include <epoxy/gl.h>
#include <span>

static void ensureResources()
{
    // Embed the shader in the plugin binary (myopicdefocus.qrc).
    Q_INIT_RESOURCE(myopicdefocus);
}

namespace
{

// The 1D blur kernel is sampled at offsets that pair adjacent texels
// through GL_LINEAR filtering: offset 1.5 px lands exactly between texels
// 1 and 2, so one texture fetch covers two Gaussian taps at half weight
// each.  The table stores the Gaussian pair-sums at those positions,
// which keeps the total kernel energy exact while cutting the tap count
// from 11x11 to 7x7 fetches per pixel.  The effect runs over the whole
// composited desktop -- including fullscreen windows -- so on iGPUs this
// is what keeps the compositor ahead of the frame deadline under load.
constexpr int kKernelSize = 7;
constexpr float kKernelOffsets[kKernelSize] = {
    0.0f,
    1.5f,
    3.5f,
    5.0f,
    -1.5f,
    -3.5f,
    -5.0f,
};

// Weights per offset for a channel with Gaussian sigma:
//   offset 0   -> g(0)
//   offset 1.5 -> g(1) + g(2)   (samples texels 1 and 2)
//   offset 3.5 -> g(3) + g(4)
//   offset 5   -> g(5)
// and symmetrically for the negative offsets.
void kernelWeights(float sigma, float (&out)[kKernelSize])
{
    const float s = std::max(sigma, 0.6f);
    const auto g = [s](float x) {
        return std::exp(-0.5f * (x * x) / (s * s));
    };
    out[0] = g(0.0f);
    out[1] = g(1.0f) + g(2.0f);
    out[2] = g(3.0f) + g(4.0f);
    out[3] = g(5.0f);
    out[4] = out[1];
    out[5] = out[2];
    out[6] = out[3];
}

// Minimal pass-through vertex shader: the effect runs as the first effect in
// the chain, captures the whole composited scene into a per-output texture in
// paintScreen() and then draws one fullscreen quad sampling that texture.
const QByteArray s_vertexSource = QByteArrayLiteral(R"(
#version 140
uniform mat4 modelViewProjectionMatrix;
in vec2 position;
in vec2 texcoord;
out vec2 texcoord0;
void main()
{
    gl_Position = modelViewProjectionMatrix * vec4(position, 0.0, 1.0);
    texcoord0 = texcoord;
}
)");

} // namespace

namespace KWin
{

MyopicDefocusEffect::MyopicDefocusEffect()
    : Effect()
{
    reconfigure(ReconfigureAll);

    // The kwinrc "[Plugins] myopicdefocusEnabled" flag decides whether the
    // effect is loaded; once loaded, the filter is on by default.
    if (m_valid) {
        m_enabled = true;
    }

    connect(effects, &EffectsHandler::screenRemoved, this, &MyopicDefocusEffect::slotScreenRemoved);
}

MyopicDefocusEffect::~MyopicDefocusEffect()
{
    if (effects) {
        effects->makeOpenGLContextCurrent();
    }
    unloadShader();
}

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

    kernelWeights(m_greenBlurRadius, m_greenKernel);
    kernelWeights(m_blueBlurRadius, m_blueKernel);
    std::memcpy(m_kernelOffsets, kKernelOffsets, sizeof(kKernelOffsets));

    if (!m_valid) {
        loadShader();
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

    QFile fragFile(QStringLiteral(":/effects/myopicdefocus/shaders/myopicdefocus.frag"));
    if (!fragFile.open(QIODevice::ReadOnly)) {
        qWarning() << "MyopicDefocus: failed to read the embedded fragment shader";
        return;
    }
    const QByteArray fragSource = fragFile.readAll();
    fragFile.close();

    m_shader = ShaderManager::instance()->generateCustomShader(ShaderTrait::MapTexture, s_vertexSource, fragSource);
    if (!m_shader) {
        qWarning() << "MyopicDefocus: failed to compile the shader program";
        m_shader.reset();
        return;
    }

    m_locTexture = m_shader->uniformLocation("sampler");
    m_locMvp = m_shader->uniformLocation("modelViewProjectionMatrix");
    m_locTextureWidth = m_shader->uniformLocation("textureWidth");
    m_locTextureHeight = m_shader->uniformLocation("textureHeight");
    m_locEffectStrength = m_shader->uniformLocation("effectStrength");
    m_locKernelOffset = m_shader->uniformLocation("kernelOffset");
    m_locGreenKernel = m_shader->uniformLocation("greenKernel");
    m_locBlueKernel = m_shader->uniformLocation("blueKernel");

    m_valid = true;
}

void MyopicDefocusEffect::unloadShader()
{
    m_screens.clear(); // frees the textures and framebuffers
    m_shader.reset();
    m_valid = false;
}

void MyopicDefocusEffect::setUniforms(const QSize &textureSize)
{
    ShaderBinder binder(m_shader.get());

    if (m_locTexture >= 0) {
        m_shader->setUniform(m_locTexture, 0);
    }
    if (m_locTextureWidth >= 0) {
        m_shader->setUniform(m_locTextureWidth, textureSize.width());
    }
    if (m_locTextureHeight >= 0) {
        m_shader->setUniform(m_locTextureHeight, textureSize.height());
    }
    if (m_locEffectStrength >= 0) {
        m_shader->setUniform(m_locEffectStrength, m_effectStrength);
    }
    if (m_locKernelOffset >= 0) {
        glUniform1fv(m_locKernelOffset, kKernelSize, m_kernelOffsets);
    }
    if (m_locGreenKernel >= 0) {
        glUniform1fv(m_locGreenKernel, kKernelSize, m_greenKernel);
    }
    if (m_locBlueKernel >= 0) {
        glUniform1fv(m_locBlueKernel, kKernelSize, m_blueKernel);
    }
}

void MyopicDefocusEffect::paintScreen(const RenderTarget &renderTarget,
                                      const RenderViewport &viewport,
                                      int mask,
                                      const Region &deviceRegion,
                                      LogicalOutput *screen)
{
    if (!m_valid || !renderTarget.texture()) {
        effects->paintScreen(renderTarget, viewport, mask, deviceRegion, screen);
        return;
    }

    ScreenState &state = m_screens[screen];
    const qreal scale = viewport.scale();
    const QSize nativeSize = (QSizeF(screen->geometry().size()) * scale).toSize();
    const GLenum format = renderTarget.texture()->internalFormat();

    if (nativeSize.isEmpty()) {
        effects->paintScreen(renderTarget, viewport, mask, deviceRegion, screen);
        return;
    }

    if (!state.texture || state.texture->size() != nativeSize || state.texture->internalFormat() != format) {
        state.framebuffer.reset();
        state.texture = GLTexture::allocate(format, nativeSize);
        if (!state.texture) {
            m_screens.erase(screen);
            effects->paintScreen(renderTarget, viewport, mask, deviceRegion, screen);
            return;
        }
        state.texture->setFilter(GL_LINEAR);
        state.texture->setWrapMode(GL_CLAMP_TO_EDGE);
        state.framebuffer = std::make_unique<GLFramebuffer>(state.texture.get());
        if (!state.framebuffer || !state.framebuffer->valid()) {
            m_screens.erase(screen);
            effects->paintScreen(renderTarget, viewport, mask, deviceRegion, screen);
            return;
        }
    }

    // Step 1: render the already-composited scene (decorations included) into
    // this output's texture.  The scene is drawn by the rest of the effect
    // chain into our framebuffer, so the texture always holds the desktop
    // exactly as it would have been presented this frame.
    RenderTarget sceneTarget(state.framebuffer.get(), renderTarget.colorDescription());
    RenderViewport sceneViewport(viewport.renderRect(), viewport.scale(), sceneTarget, QPoint());
    GLFramebuffer::pushFramebuffer(state.framebuffer.get());
    effects->paintScreen(sceneTarget, sceneViewport, mask, deviceRegion, screen);
    GLFramebuffer::popFramebuffer();

    // Step 2: draw the captured desktop through the per-channel blur.
    const RectF outputRect = screen->geometry().scaled(scale);
    const float x0 = outputRect.left();
    const float y0 = outputRect.top();
    const float x1 = outputRect.right();
    const float y1 = outputRect.bottom();

    GLVertexBuffer *vbo = GLVertexBuffer::streamingBuffer();
    vbo->reset();
    vbo->setAttribLayout(std::span(GLVertexBuffer::GLVertex2DLayout), sizeof(GLVertex2D));
    const auto vertices = vbo->map<GLVertex2D>(6);
    if (!vertices) {
        effects->paintScreen(renderTarget, viewport, mask, deviceRegion, screen);
        return;
    }
    const auto v = *vertices;
    v[0] = GLVertex2D{ .position = QVector2D(x0, y0), .texcoord = QVector2D(0.0f, 1.0f) };
    v[1] = GLVertex2D{ .position = QVector2D(x1, y1), .texcoord = QVector2D(1.0f, 0.0f) };
    v[2] = GLVertex2D{ .position = QVector2D(x0, y1), .texcoord = QVector2D(0.0f, 0.0f) };
    v[3] = GLVertex2D{ .position = QVector2D(x0, y0), .texcoord = QVector2D(0.0f, 1.0f) };
    v[4] = GLVertex2D{ .position = QVector2D(x1, y0), .texcoord = QVector2D(1.0f, 1.0f) };
    v[5] = GLVertex2D{ .position = QVector2D(x1, y1), .texcoord = QVector2D(1.0f, 0.0f) };
    vbo->unmap();

    ShaderManager *shaderManager = ShaderManager::instance();
    shaderManager->pushShader(m_shader.get());

    if (m_locMvp >= 0) {
        m_shader->setUniform(m_locMvp, viewport.projectionMatrix());
    }
    setUniforms(nativeSize);

    const GLboolean blendWasEnabled = glIsEnabled(GL_BLEND);
    if (blendWasEnabled) {
        glDisable(GL_BLEND);
    }
    glActiveTexture(GL_TEXTURE0);
    state.texture->bind();
    vbo->bindArrays();
    vbo->draw(GL_TRIANGLES, 0, 6);
    vbo->unbindArrays();
    state.texture->unbind();
    if (blendWasEnabled) {
        glEnable(GL_BLEND);
    }
    shaderManager->popShader();
}

void MyopicDefocusEffect::slotScreenRemoved(LogicalOutput *screen)
{
    if (effects) {
        effects->makeOpenGLContextCurrent();
    }
    m_screens.erase(screen);
}

} // namespace KWin

#include "moc_myopicdefocus.cpp"
