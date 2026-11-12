<!-- markdownlint-disable MD028 MD033 MD041 MD045 -->

# MobileGlues-Kona

> [!WARNING]
> **This is an unofficial fork.**
>
> It is not affiliated with, endorsed by, or supported by MobileGL-Dev. Do not report
> bugs from this build to the upstream project. The APK is repacked and signed with a
> different key than the official `CN=MGDev` release, so it will not update over or
> verify against an official MobileGlues install.
>
> Tested on a Mali-G57 MC2 device only, with OpenGL ES 3.2 and Minecraft 26.3 /
> 26.4 snapshots. Use it at your own risk and keep a backup of your working renderer.

**Kona version:** `2.9.9-Kona` (package versionName `2.9.9-CustomKona`, versionCode 2990)  
**Core:** MobileGlues `2.0.1·Dev1`  
**Base commit:** [MobileGL-Dev/MobileGlues `0c27a3a`](https://github.com/MobileGL-Dev/MobileGlues/tree/0c27a3a)  
**Wrapper:** SimpleFPEWrapper `26.11-dev`, commit `3042d8a` (supplied by the launcher)  
**Release:** [Download the latest Kona APK](https://github.com/Konaimav2/MobileGlues-Kona/releases/latest)

**MobileGlues**, which stands for "(on) Mobile, GL uses ES", is a GL implementation
running on top of host OpenGL ES 3.x (best on 3.2, minimum 3.0), with running
Minecraft: Java Edition in mind.

This repository packages a Kona build of MobileGlues for one specific job: running
Minecraft 26.3 and 26.4 snapshots on a Mali-G57 MC2 device through ZalithLauncher 2,
with the launcher's SimpleFPEWrapper doing the fixed-function translation. The
native library is built from the upstream `dev` branch at `0c27a3a` plus three small
patches. The APK is a repack of the official plugin APK with the custom library and
Kona version strings.

# Features

1. Capable of running Minecraft [Sodium](https://github.com/CaffeineMC/sodium) mod;

2. Capable of rendering most minecraft shaders with Minecraft
   [Iris](https://github.com/IrisShaders/Iris) mod or
   [Optifine](https://optifine.net/home).

3. Capable of running some Minecraft mods with custom rendering routines, such as
   [JourneyMap](https://teamjm.github.io/journeymap-docs/latest) and
   [Create](https://createmod.net).

4. Additional QoL features: optional ANGLE as ES driver, shader caching for fast
   shaderpack reloads, supports Minecraft GPU% reporting, ...and more!

# Kona patches

The build applies these patches on top of MobileGlues `0c27a3a`:

- `0001-strip-noperspective.patch` — removes the desktop-only `noperspective`
  qualifier and the `GL_NV_shader_noperspective_interpolation` directive before ES
  compilation. Iris shadow programs otherwise fail on Mali.
- `0002-mali-linear-window-surface.patch` — asks for a linear window surface on Mali
  when the backend cannot expose `GL_EXT_sRGB_write_control`. On devices where MG
  reports `sRGB_write_control=1` this branch is inactive.
- `0003-shader-cache-salt.patch` — adds a `custom-1` salt to the shader cache key so
  converted shaders from an older build are not replayed.

The patches are in [`patches/`](patches/). They are correctness and cache fixes, not
performance patches. The performance work lives upstream (see
[`docs/SOURCE.md`](docs/SOURCE.md)).

# Install

1. Back up your current renderer and your launcher version config.
2. If the official `com.fcl.plugin.mobileglues` is installed, uninstall it first. The
   Kona APK uses a different signing key, so Android will reject an in-place update.
3. Install `MobileGlues-Kona-2.9.9.apk` from the
   [latest release](https://github.com/Konaimav2/MobileGlues-Kona/releases/latest).
4. In ZalithLauncher 2, select the MobileGlues renderer for the instance and enable
   the SimpleFPEWrapper plugin layer.

A tested 26.4 configuration:

```json
{
  "graphicsApi": "OPENGL",
  "renderer": "com.fcl.plugin.mobileglues",
  "sfpewPluginLayer": "ENABLE",
  "javaRuntime": "Internal-25",
  "driver": "com.mio.plugin.renderer.turnip2600d.r27d.sdk29"
}
```

For 26.3 the same renderer and `sfpewPluginLayer` values work. If you patch the game
jar, set `skipGameIntegrityCheck` to `SKIP` for that instance; leave it alone for a
clean jar. Vulkan is not supported on this Mali device; use OpenGL.

# Tested setup

| Item | Value |
| --- | --- |
| Device GPU | Mali-G57 MC2, OpenGL ES 3.2 |
| Android | 15 |
| Launcher | ZalithLauncher 2 |
| Minecraft | 26.3 and 26.4-snapshot-8 |
| Loader | Fabric 0.20.1 |
| Wrapper | SimpleFPEWrapper 26.11-dev, `3042d8a` |
| Shaders | Iris 1.11.7, E-LITE 5.1.3, Miniature 2.19 |

The 26.3 run reports `MobileGlues 2.0.1·Dev1`; the 26.4 run reports the same core
with the launcher wrapper. The 26.4 instance needs the plugin renderer and
`sfpewPluginLayer=ENABLE`; the built-in renderer is a separate fallback.

# Build from source

Requirements: Termux or a Linux host with Clang, CMake, Ninja, git, patchelf,
llvm-strip, and an Android aarch64 sysroot. The script defaults to the upstream
`0c27a3a` commit and the patch series in this repository.

```bash
export SYSROOT="$HOME/toolchains/mg-sysroot"
./scripts/build-kona.sh
```

The output is `dist/libmobileglues-2.0.1-0c27a3a-kona.so`. See
[`scripts/build-kona.sh`](scripts/build-kona.sh) for the exact flags and the
`REF`/`OUT` overrides. The APK repack is described in
[`docs/SOURCE.md`](docs/SOURCE.md); the native library is the reproducible part.

# For Shader Developers

1. MobileGlues automatically:
   - Converts desktop GLSL → GLSL ES
   - Removes `layout(binding)` syntax
   - Handles version directives
   - Always declares precision explicitly:

     ```glsl
     precision highp float;
     precision highp int;
     ```

2. MobileGlues (since V1.2.6) injects these macros into your shaders:

   ```glsl
   #define MG_MOBILEGLUES                   // Indicates MobileGlues environment
   #define MG_MOBILEGLUES_VERSION 2000      // Version number (e.g. 2000 = V2.0.0)
   ```

   Use these macros for platform-specific logic:

   ```glsl
   #ifdef MG_MOBILEGLUES
       #if MG_MOBILEGLUES_VERSION >= 2000
           // Logic for MobileGlues (version >= V2.0.0)
       #else
           // Logic for MobileGlues (version < V2.0.0)
       #endif
   #else
       // ...
   #endif
   ```

3. If you hit a shader/program error, enable `Ignore shader/program error` and check
   `/sdcard/MG/latest.log`. On this fork, include the Kona version and the base
   commit in any report.

# Signature and verification

The official MobileGlues APK is signed by `CN=MGDev`. This fork is **not**. Do not
expect `apksigner verify --print-certs` to match the upstream fingerprint. Verify the
file hash against the `SHA256SUMS` asset in the release, and treat any APK from
another source as untrusted.

# Upstream and license

This is a fork of [MobileGlues](https://github.com/MobileGL-Dev/MobileGlues). The
upstream release page is
[MobileGlues-release](https://github.com/MobileGL-Dev/MobileGlues-release). The
SimpleFPEWrapper is [MobileGL-Dev/SimpleFPEWrapper](https://github.com/MobileGL-Dev/SimpleFPEWrapper).

MobileGlues and its plugin application are licensed under the **GNU LGPL-2.1
License**. See [`LICENSE`](LICENSE). The Kona patches are provided under the same
license. Third-party components retain their own licenses; see
[`docs/SOURCE.md`](docs/SOURCE.md) and the upstream
[third-party list](https://github.com/MobileGL-Dev/MobileGlues-release#third-party-components).

# Third-party components

The upstream third-party list applies. The main ones are:

- **SPIRV-Cross** by KhronosGroup — Apache License 2.0.
- **glslang** by KhronosGroup — various licenses.
- **cJSON** by DaveGamble — MIT License.
- **FidelityFX-FSR** by AMD — MIT License.
- **Perfetto** by Google — Apache License 2.0.
- **xxHash** by Yann Collet — BSD 2-Clause License.
- **flat_hash_map** by Malte Skarupke — Boost Software License 1.0.
- **Miuix**, **Jetpack Compose**, **AndroidX**, **kotlinx.coroutines**, **Gson** —
  Apache License 2.0.

No support is offered for this fork by the upstream authors. Upstream issues should
be filed only against an unmodified upstream build.
