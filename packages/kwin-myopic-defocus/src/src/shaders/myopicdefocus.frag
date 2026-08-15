/*
    kwin-myopic-defocus - Myopic chromatic defocus effect for KWin (Plasma 6)

    Per-pixel filter: the red channel stays sharp, the green channel is
    blurred a little and the blue channel is blurred more.  This simulates
    the myopic chromatic aberration ("red in focus") that, per Swiatczak
    et al. (2024, doi:10.15626/sjovs.v17i2.4232), may help control myopia
    progression during computer work.

    The reference implementation is the Refractify browser extension
    (https://github.com/refractify/myopic_defocus): it splits RGB into
    separate channels, applies a Gaussian blur to G and B with different
    radii and recombines them.  We do the same here in a single pass.

    Alpha handling: KWin's offscreen textures are premultiplied, and
    windows (panels, rounded corners, shadows) contain transparent pixels.
    The Gaussian is therefore applied to the *premultiplied* G/B channels
    together with alpha, and the result is normalized by the blurred alpha.
    Without that normalization the transparent taps (premultiplied 0)
    would drag G/B down at window edges, producing a red rim on white
    panels and dark halos on rounded corners.  For fully opaque content
    the normalization is a no-op (blurred alpha == 1) and the math is
    exactly the naive per-channel Gaussian.

    SPDX-FileCopyrightText: 2026 waymca contributors
    SPDX-License-Identifier: GPL-3.0-or-later
*/

#version 140

// Provided by KWin's MapTexture pipeline (OffscreenEffect):
// "sampler" is the redirected window texture, "textureWidth"/"textureHeight"
// its size in device pixels.  This is what makes the blur radius a real
// pixel value for any screen resolution and window size.
uniform sampler2D sampler;
uniform int textureWidth;
uniform int textureHeight;

// WayMCA configuration (kwinrc group [Effect-waymca]).
// Radii are Gaussian sigmas in device pixels.  effectStrength blends the
// blurred result with the original (0.0 = off, 1.0 = fully blurred).
uniform float greenBlurRadius;
uniform float blueBlurRadius;
uniform float effectStrength;

in vec2 texcoord0;
out vec4 fragColor;

// Unnormalized 1D Gaussian weight at offset x (in pixels) for sigma.
float gaussianWeight(float x, float sigma)
{
    return exp(-0.5 * (x * x) / (sigma * sigma));
}

void main()
{
    // Premultiplied RGBA (KWin's offscreen textures are premultiplied).
    vec4 color = texture(sampler, texcoord0);

    // Fully transparent pixels carry no color information; blurring them
    // in would darken window edges.  Keep them untouched.
    if (color.a < 0.0039) {
        fragColor = color;
        return;
    }

    // Strength 0 disables the filter entirely.
    if (effectStrength < 0.01) {
        fragColor = color;
        return;
    }

    vec2 pixelSize = vec2(1.0 / float(textureWidth), 1.0 / float(textureHeight));

    // Clamp tiny radii so the kernel stays a proper Gaussian.
    float sigmaG = max(greenBlurRadius, 0.6);
    float sigmaB = max(blueBlurRadius, 0.6);

    // Single-pass 2D Gaussian, 11x11 taps.  Covers sigma up to ~7 px
    // with acceptable truncation at the kernel edge.
    const int kernelRadius = 5;

    // Blur the premultiplied G/B channels and alpha with the same kernels.
    // Dividing the blurred premultiplied color by the blurred alpha yields
    // the straight-space blurred color, weighted by the opaque coverage of
    // each tap.  Transparent taps then contribute nothing instead of
    // dragging the channels toward zero.
    float greenSum = 0.0;
    float blueSum = 0.0;
    float alphaSumG = 0.0;
    float alphaSumB = 0.0;

    for (int y = -kernelRadius; y <= kernelRadius; ++y) {
        for (int x = -kernelRadius; x <= kernelRadius; ++x) {
            vec4 tap = texture(sampler, texcoord0 + vec2(float(x), float(y)) * pixelSize);

            float wG = gaussianWeight(float(x), sigmaG) * gaussianWeight(float(y), sigmaG);
            greenSum += tap.g * wG;
            alphaSumG += tap.a * wG;

            float wB = gaussianWeight(float(x), sigmaB) * gaussianWeight(float(y), sigmaB);
            blueSum += tap.b * wB;
            alphaSumB += tap.a * wB;
        }
    }

    // Center pixel in straight space (color.a > 0 is guaranteed here).
    vec3 straight = color.rgb / color.a;

    // Normalize the blurred premultiplied values to straight space.  Guard
    // against an (almost) fully transparent neighborhood: keep the center
    // color then instead of amplifying noise.
    float blurredGreen = alphaSumG > 0.0001 ? greenSum / alphaSumG : straight.g;
    float blurredBlue = alphaSumB > 0.0001 ? blueSum / alphaSumB : straight.b;

    // Red stays sharp; G and B are blended toward their blurred values in
    // straight space, then re-premultiplied for the compositor.
    vec3 result = vec3(straight.r,
                       mix(straight.g, blurredGreen, effectStrength),
                       mix(straight.b, blurredBlue, effectStrength));

    fragColor = vec4(result * color.a, color.a);
}
