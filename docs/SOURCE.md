# Source and release provenance

This repository is an unofficial Kona build. It is not a complete copy of the
MobileGlues source tree; the source is the upstream repository at a pinned commit,
with the patches in [`../patches`](../patches) applied.

## Versions

| Part | Value |
| --- | --- |
| App package | `com.fcl.plugin.mobileglues` |
| App versionName | `2.9.9-CustomKona` (Kona 2.9.9) |
| App versionCode | 2990 |
| MobileGlues core | `2.0.1·Dev1` |
| MobileGlues base | `MobileGL-Dev/MobileGlues` commit `0c27a3a` |
| SimpleFPEWrapper | `26.11-dev`, commit `3042d8a` |
| Native library | `libmobileglues-2.0.1-0c27a3a-kona.so`, sha256 `f8358ac9d969...` |
| APK | `MobileGlues-Kona-2.9.9.apk`, sha256 `b0ed18f3c28c...` |

## What is in the native library

The library is built from `MobileGL-Dev/MobileGlues` at `0c27a3a` (the `dev` tip at
the time of the build) plus:

1. `0001-strip-noperspective.patch` — removes `noperspective` and the
   `GL_NV_shader_noperspective_interpolation` directive before ES compilation.
2. `0002-mali-linear-window-surface.patch` — selects a linear window surface on
   Mali only when `GL_EXT_sRGB_write_control` is unavailable. On this test device MG
   reports `sRGB_write_control=1`, so the branch does not run.
3. `0003-shader-cache-salt.patch` — adds `custom-1` to the shader cache key.

None of the three patches is a performance change. The MobileGlues `[Perf]` series
(`1d9a227`, `58d7da8`, `e8dde9d`, `4be9784`, `a7970b6`, `9235866`, `478d479`,
`502656f`, `7040143`) is already in the `0c27a3a` tree and therefore in this build.

The launcher's SimpleFPEWrapper is used at `3042d8a`. Upstream wrapper commits after
that (`1b801c1` and the four `[Perf] (FPE)` commits `bb33a89`, `5474e47`, `5e168dd`,
`e78ea33`) are not included in this build. They are a separate wrapper update, not a
MobileGlues core change.

## How the APK was produced

The APK is a repack of the official MobileGlues plugin APK (`2.9.9` line), with:

- the native `libmobileglues.so` replaced by the Kona build above;
- the display strings and version name changed to `2.9.9-CustomKona` / Kona;
- the APK signed with the Kona key.

It is therefore a **different signer** from the official `CN=MGDev` APK. Android will
not install it over the official package; uninstall the official plugin first and
keep a backup.

The native library is reproducible with [`../scripts/build-kona.sh`](../scripts/build-kona.sh).
The smali/string repack steps are instance-specific and not scripted here; the
native source and patch set are the parts that matter for the renderer behavior.

## LGPL source offer

MobileGlues and the plugin are LGPL-2.1. The complete corresponding source for the
native library is the upstream `MobileGlues` repository at `0c27a3a`, the patches in
this repository, and the build script. For the repacked APK's version strings, the
changes are limited to the display strings and version metadata described above.
If you redistribute the APK, keep this document, the license, and the patch set with
it.

## Third-party components

The upstream third-party list applies: SPIRV-Cross (Apache-2.0), glslang (various),
cJSON (MIT), FidelityFX-FSR (MIT), Perfetto (Apache-2.0), xxHash (BSD-2-Clause),
flat_hash_map (BSL-1.0), Miuix/Jetpack Compose/AndroidX/kotlinx.coroutines/Gson
(Apache-2.0). See the upstream
[third-party list](https://github.com/MobileGL-Dev/MobileGlues-release#third-party-components).
