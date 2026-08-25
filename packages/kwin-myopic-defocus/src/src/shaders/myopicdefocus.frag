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

    Kernel: the 1D Gaussian is precomputed on the CPU as a table of
    offsets and pair-sums.  Half-integer offsets land exactly between two
    texels, so with GL_LINEAR filtering one texture fetch covers two
    Gaussian taps at half weight each (offset 1.5 px averages texels 1
    and 2, 3.5 px averages texels 3 and 4; offsets 0 and 5 px fetch a
    single texel).  The pair-sums keep the total kernel energy exact,
    while cutting the tap count from 11x11 (121) to 7x7 (49) fetches per
    pixel -- important on iGPUs where this effect runs full-screen even
    for fullscreen windows.

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

// WayMCA configuration: effectStrength blends the blurred result with the
// original (0.0 = off, 1.0 = fully blurred).  The blur radii are baked
// into greenKernel/blueKernel below (precomputed on the CPU).
uniform float effectStrength;

// Precomputed 1D blur kernel, in device pixels.  kernelOffset holds sample
// positions relative to the current texel; greenKernel/blueKernel hold the
// Gaussian pair-sums at those positions for the configured radii (see the
// effect's kernel table computation).  The 2D kernel is the outer product
// of the 1D table, evaluated as a 7x7 tap loop.
uniform float kernelOffset[7];
uniform float greenKernel[7];
uniform float blueKernel[7];

in vec2 texcoord0;
out vec4 fragColor;

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

    // Blur the premultiplied G/B channels and alpha with the same kernels.
    // Dividing the blurred premultiplied color by the blurred alpha yields
    // the straight-space blurred color, weighted by the opaque coverage of
    // each tap.  Transparent taps then contribute nothing instead of
    // dragging the channels toward zero.
    float greenSum = 0.0;
    float blueSum = 0.0;
    float alphaSumG = 0.0;
    float alphaSumB = 0.0;

    for (int y = 0; y < 7; ++y) {
        for (int x = 0; x < 7; ++x) {
            vec4 tap = texture(sampler, texcoord0 + vec2(kernelOffset[x], kernelOffset[y]) * pixelSize);

            float wG = greenKernel[x] * greenKernel[y];
            float wB = blueKernel[x] * blueKernel[y];
            greenSum += tap.g * wG;
            alphaSumG += tap.a * wG;

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
