# Choosing blur parameters

The effect's defaults (`GreenBlurRadius = 2.5`, `BlueBlurRadius = 7.0`,
`EffectStrength = 0.30`) follow the same refraction physics as the
Refractify browser extension.

## The physics

The human eye has longitudinal chromatic aberration (LCA): short
wavelengths are focused in front of the retina.  In diopters:

- Red:   −0.23 D
- Green: +0.24 D
- Blue:  +1.10 D

To simulate the myopic condition on a screen, the green and blue
channels are blurred such that the blur circle (in pixels) equals the
geometric blur those channels would have at the eye:

```
pix_mm      = screen_diag_mm / screen_diag_px        # mm per pixel
base        = pupil_mm * distance_mm * 0.32 / (1000 * pix_mm)
blur_green  = base * (0.24 - (−0.23)) D = base * 0.47 D
blur_blue   = base * (1.10 − (−0.23)) D = base * 1.33 D
```

The 0.32 factor and the strength blend (Refractify uses 10 %) tone the
effect down to a comfortable level;  `EffectStrength` replaces that
blend, and `GreenBlurRadius`/`BlueBlurRadius` replace the computed
values directly.

## Computing your own values

| Parameter | Symbol | Example value |
| --------- | ------ | ------------- |
| screen diagonal | —     | 15.6 in = 396 mm |
| resolution      | —     | 1920×1080 (diag 2202.9 px) |
| viewing distance| —     | 500 mm |
| pupil diameter  | —     | 6.5 mm |

```
pix_mm = 396 / 2202.9 = 0.180
base   = 6.5 * 500 * 0.32 / (1000 * 0.180) = 5.78
blur_green = 5.78 * 0.47 = 2.7 px   → GreenBlurRadius
blur_blue  = 5.78 * 1.33 = 7.7 px   → BlueBlurRadius
```

Start with `EffectStrength = 0.3` and adjust by ±0.1 until the effect
is noticeable but not distracting.  If you want exactly the Refractify
feel, set `EffectStrength = 0.1`.

## References

- Swiatczak, Ingrassia, Scholl & Schaeffel (2024), *Pilot study:
  simulating myopic chromatic aberration on a computer screen induces
  progressive choroidal thickening in myopes*, SJOVS 17(2),
  doi:10.15626/sjovs.v17i2.4232.
- Refractify browser extension: <https://github.com/refractify/myopic_defocus>
