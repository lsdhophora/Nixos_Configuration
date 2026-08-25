# kwin-myopic-defocus

Myopic chromatic defocus effect for **KWin (KDE Plasma 6)**.

The filter blurs the **green** and **blue** channels of the whole screen
while keeping the **red** channel sharp.  This reproduces the myopic
chromatic aberration ("red in focus") described in:

> Swiatczak et al. (2024), *Pilot study: simulating myopic chromatic
> aberration on a computer screen induces progressive choroidal
> thickening in myopes*, Scandinavian Journal of Optometry and Visual
> Science, doi:10.15626/sjovs.v17i2.4232.

In that pilot study, myopic subjects who worked 2 h/day with a "red in
focus" filter showed progressive choroidal thickening (+18 ± 14 µm,
p < 0.0001) and axial-length shortening (−31 ± 39 µm, p < 0.01) over
12 days — an inhibitory effect on myopia progression.

This is the desktop-wide equivalent of the Refractify browser extension
(<https://github.com/refractify/myopic_defocus>).  The original thread
that motivated this implementation:
<https://emacs-china.org/t/vibe-coding/30816>

## How it works

Every visible window is redirected into an offscreen texture
(`KWin::OffscreenEffect`) and drawn with a single-pass GLSL shader that:

1. leaves the red channel untouched,
2. blurs the green channel with a Gaussian of `GreenBlurRadius` px,
3. blurs the blue channel with a Gaussian of `BlueBlurRadius` px
   (typically ~2.8× the green radius, following the refraction physics
   used by Refractify: longitudinal chromatic aberration of
   R −0.23 D / G +0.24 D / B +1.10 D),
4. blends the blurred result with the original by `EffectStrength`.

The kernel is a 7×7-tap Gaussian whose 1D table (offsets {0, ±1.5, ±3.5,
±5} px, precomputed on the CPU for the configured radii) pairs adjacent
texels through GL_LINEAR sampling, so each texture fetch covers two
Gaussian taps at half weight each: 49 fetches per pixel instead of 121
for an 11×11 kernel.  The pixel size is taken from the
`textureWidth`/`textureHeight` uniforms that KWin sets automatically — so
the blur radius is a true pixel value at any screen resolution or window
scale.  The reduced tap count keeps the compositor ahead of the frame
deadline on iGPUs even when the effect covers the full screen.

## Configuration

Two ways to configure the effect, both writing the same `kwinrc` keys
(group `[Effect-myopicdefocus]`):

- **System Settings → Desktop Effects → Myopic Defocus → Configure** —
  a native configuration dialog (KCModule) with the three parameters
  below; Apply pushes the values to the running compositor immediately.
- **`kwinrc`** directly (or via your NixOS/home-manager config):

| Key                 | Default | Meaning                                        |
| ------------------- | ------- | ---------------------------------------------- |
| `GreenBlurRadius`   | `2.5`   | Gaussian sigma (px) for the green channel      |
| `BlueBlurRadius`    | `7.0`   | Gaussian sigma (px) for the blue channel       |
| `EffectStrength`    | `0.30`  | Blend of blurred over original (0..1)          |

Defaults correspond to a 1920×1080 laptop panel at ~50 cm viewing
distance.  See `docs/blur-parameters.md` for the physics formula to
compute personal values.

Enable/disable the effect in *System Settings → Desktop Effects*
(plugin id `myopicdefocus`, kwinrc `[Plugins] myopicdefocusEnabled`),
or toggle it at runtime with the **Meta+Shift+D** global shortcut.

## Building

### From source

```sh
cmake -B build -DCMAKE_INSTALL_PREFIX=/usr
cmake --build build
sudo cmake --install build   # installs to <prefix>/lib/qt6/plugins/kwin/effects/plugins
```

Requirements: CMake ≥ 3.16, Qt 6.6+, KF6 (GlobalAccel, WindowSystem,
Config), KWin 6 dev headers, libepoxy, extra-cmake-modules.

### Nix

```sh
nix build --impure --expr '
  let pkgs = (builtins.getFlake "github:NixOS/nixpkgs/nixos-unstable").legacyPackages.x86_64-linux;
      kd = pkgs.kdePackages;
  in import ./nix/package.nix {
       inherit (kd) qtbase kglobalaccel kwindowsystem kconfig kwin extra-cmake-modules;
       inherit (pkgs) lib stdenv cmake;
       epoxy = pkgs.libepoxy;
       src = ./.;
     }'
```


## Development

Full tests (offline shader simulation and a nested-compositor visual
verification harness) live in the development copy at
`~/Projects/kwin-myopic-defocus`.

## Layout

```
src/myopicdefocus.h/.cpp  — KWin effect (OffscreenEffect + GLSL)
src/main.cpp              — KWIN_EFFECT_FACTORY plugin entry
src/shaders/myopicdefocus.frag — the per-channel Gaussian blur shader
src/myopicdefocus.qrc     — embeds the shader in the plugin binary
src/kcm/                  — System Settings configuration dialog (KCModule)
src/myopicdefocus.kcfg    — KConfigXT schema for the kwinrc settings
nix/package.nix           — Nix derivation
test/                     — offline + nested-compositor tests
```

## License

GPL-3.0-or-later.  Not medical advice — see a professional for actual
vision care.
