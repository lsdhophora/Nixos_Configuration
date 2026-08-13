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

    float greenSum = 0.0;
    float blueSum = 0.0;
    float greenWeightSum = 0.0;
    float blueWeightSum = 0.0;

    for (int y = -kernelRadius; y <= kernelRadius; ++y) {
        for (int x = -kernelRadius; x <= kernelRadius; ++x) {
            vec3 sample = texture(sampler, texcoord0 + vec2(float(x), float(y)) * pixelSize).rgb;

            float wG = gaussianWeight(float(x), sigmaG) * gaussianWeight(float(y), sigmaG);
            greenSum += sample.g * wG;
            greenWeightSum += wG;

            float wB = gaussianWeight(float(x), sigmaB) * gaussianWeight(float(y), sigmaB);
            blueSum += sample.b * wB;
            blueWeightSum += wB;
        }
    }

    float blurredGreen = greenSum / greenWeightSum;
    float blurredBlue = blueSum / blueWeightSum;

    // Red stays sharp; G and B are blended toward their blurred values.
    fragColor = vec4(color.r,
                     mix(color.g, blurredGreen, effectStrength),
                     mix(color.b, blurredBlue, effectStrength),
                     color.a);
}
