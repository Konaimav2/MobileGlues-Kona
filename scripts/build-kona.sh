#!/usr/bin/env bash
#
# build-kona - build the Kona MobileGlues library from upstream + patches.
#
# Repo layout expected:
#   patches/0001-*.patch, 0002-*.patch, 0003-*.patch
#
# Environment overrides:
#   REF       upstream commit or ref (default: 0c27a3a)
#   UPSTREAM  git URL (default: https://github.com/MobileGL-Dev/MobileGlues)
#   BASE      work directory (default: $HOME/tmp)
#   SYSROOT   Android aarch64 sysroot (default: $HOME/toolchains/mg-sysroot)
#   OUT       output directory (default: ./dist)
#   JOBS      ninja jobs (default: 3)
#
# The sysroot must contain libc++_static.a, libc++abi.a and libunwind.a.
# This is the Termux setup used for the Kona 2.9.9 build; a standard Android
# NDK sysroot works too if the paths below are adjusted.

set -euo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
REF="${REF:-0c27a3a}"
UPSTREAM="${UPSTREAM:-https://github.com/MobileGL-Dev/MobileGlues}"
BASE="${BASE:-$HOME/tmp}"
SYSROOT="${SYSROOT:-$HOME/toolchains/mg-sysroot}"
OUT="${OUT:-$HERE/dist}"
JOBS="${JOBS:-3}"
PATCHES="$HERE/patches"
REPO="$BASE/mg-build-kona"

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
step() { printf '\n== %s\n' "$*"; }

step "checking toolchain"
for t in clang clang++ cmake ninja git patchelf llvm-strip; do
    command -v "$t" >/dev/null || die "missing $t"
done
[ -f "$SYSROOT/usr/lib/aarch64-linux-android/libc++_static.a" ] \
    || die "sysroot missing libc++_static.a: $SYSROOT"
[ -f "$SYSROOT/libunwind/libunwind.a" ] \
    || die "sysroot missing libunwind.a: $SYSROOT"
[ -d "$PATCHES" ] || die "patches directory missing: $PATCHES"

step "fetching $UPSTREAM ($REF)"
if [ ! -d "$REPO/.git" ]; then
    git clone -q --filter=blob:none \
        -c submodule.MobileGlues-cpp/3rdparty/perfetto.update=none \
        "$UPSTREAM" "$REPO"
fi
git -C "$REPO" fetch -q --depth 1 origin "$REF"
SHA="$(git -C "$REPO" rev-parse --short FETCH_HEAD)" || die "cannot resolve $REF"
VER="$(git -C "$REPO" show FETCH_HEAD:MobileGlues-cpp/version.h |
    awk -F'[ ]' '/^#define (MAJOR|MINOR|REVISION)/ {printf "%s%s", sep, $3; sep="."}')"
WT="$BASE/mg-build-$SHA-kona"
step "source: $SHA, version $VER"

if [ -d "$WT" ]; then
    git -C "$REPO" worktree remove --force "$WT" 2>/dev/null || rm -rf "$WT"
fi
git -C "$REPO" worktree add -q --detach "$WT" FETCH_HEAD
git -C "$WT" submodule update -q --init --recursive --depth 1 \
    MobileGlues-cpp/3rdparty/glslang \
    MobileGlues-cpp/3rdparty/SPIRV-Cross \
    MobileGlues-cpp/3rdparty/xxhash \
    MobileGlues-cpp/include/ska

step "applying Kona patches"
shopt -s nullglob
series=("$PATCHES"/0*.patch)
[ ${#series[@]} -gt 0 ] || die "no patches found in $PATCHES"
for p in "${series[@]}"; do
    git -C "$WT" apply --check "$p" 2>/dev/null \
        || die "patch no longer applies: $(basename "$p") (worktree: $WT)"
    git -C "$WT" apply "$p"
    printf '  %s\n' "$(basename "$p")"
done

step "building $VER ($SHA)"
TARGET="--target=aarch64-linux-android24 --sysroot=$SYSROOT"
LINK="$TARGET -nostdlib++ -L$SYSROOT/libunwind \
 $SYSROOT/usr/lib/aarch64-linux-android/libc++_static.a \
 $SYSROOT/usr/lib/aarch64-linux-android/libc++abi.a \
 -L$SYSROOT/usr/lib/aarch64-linux-android/24 -llog -landroid -ldl -lm"

cmake -S "$WT/MobileGlues-cpp" -B "$WT/build" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ \
    -DCMAKE_C_FLAGS="$TARGET" -DCMAKE_CXX_FLAGS="$TARGET" \
    -DCMAKE_EXE_LINKER_FLAGS="$LINK" -DCMAKE_SHARED_LINKER_FLAGS="$LINK" \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 >"$WT/cmake.log" 2>&1 \
    || { tail -20 "$WT/cmake.log"; die "cmake configure failed"; }

cmake --build "$WT/build" --target mobileglues -j "$JOBS" >"$WT/build.log" 2>&1 \
    || { tail -40 "$WT/build.log"; die "build failed"; }

SO="$WT/build/libmobileglues.so"
llvm-strip --strip-unneeded "$SO"
patchelf --remove-rpath "$SO"

step "verifying"
readelf -h "$SO" | grep AArch64 >/dev/null || die "not an AArch64 library"
for dep in liblog.so libc.so; do
    readelf -d "$SO" | grep "\[$dep\]" >/dev/null || die "missing dependency $dep"
done
readelf -d "$SO" | grep RUNPATH >/dev/null && die "RUNPATH still present"
readelf -d "$SO" | grep libc++_shared >/dev/null && die "links libc++_shared"

mkdir -p "$OUT"
NAME="libmobileglues-${VER}-${SHA}-kona.so"
cp "$SO" "$OUT/$NAME"
chmod 644 "$OUT/$NAME"

printf '\nbuilt %s (%s, %s)\n' "$NAME" "$(du -h "$OUT/$NAME" | cut -f1)" \
    "$(sha256sum "$OUT/$NAME" | cut -c1-12)"
