#!/bin/sh

set -eu

ARCH=$(uname -m)

echo "Installing package dependencies..."
echo "---------------------------------------------------------------"
pacman -Syu --noconfirm   \
    boost                 \
    cmake                 \
    fmt                   \
    json-schema-validator \
    kvantum               \
    lxqt-qtplugin         \
    onetbb                \
    pipewire-audio        \
    pipewire-jack         \
    qt6-canvaspainter     \
    qt6-declarative       \
    qt6-svg               \
    qt6-tools             \
    qt6ct                 \
    spdlog

echo "Installing debloated packages..."
echo "---------------------------------------------------------------"
get-debloated-pkgs --add-common --prefer-nano

echo "Building lsp-dsp-lib..."
echo "---------------------------------------------------------------"
REPO="https://github.com/sadko4u/lsp-dsp-lib"
git clone --depth 1 "$REPO" ./lsp-dsp-lib

cd ./lsp-dsp-lib
make config PREFIX=/usr
cat ./.config.mk
make fetch
make -j$(nproc) install
cd ../

echo "Building Zrythm dependencies..."
echo "---------------------------------------------------------------"
# These have no Arch package, so they are built from source and installed
# into /usr. (xxhash, zstd, fmt, spdlog, boost come from pacman)
DEPS_SRC="$PWD/zrythm-deps"
mkdir -p "$DEPS_SRC"

# build_dep <name> <git url> <ref> [extra cmake args...]
build_dep () {
    dep_name="$1"
    dep_url="$2"
    dep_ref="$3"
    shift 3
    dep_src="$DEPS_SRC/$dep_name"
    if [ ! -d "$dep_src/.git" ]; then
        git clone --depth 1 "$dep_url" "$dep_src"
        git -C "$dep_src" fetch --depth 1 origin "$dep_ref"
        git -C "$dep_src" checkout -q FETCH_HEAD
    fi
    echo "==> $dep_name"
    cmake -S "$dep_src" -B "$dep_src/build" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr \
        -DCMAKE_PREFIX_PATH=/usr \
        -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
        "$@"
    cmake --build "$dep_src/build" -j$(nproc)
    cmake --install "$dep_src/build"
}

build_dep mpmcqueue https://github.com/rigtorp/MPMCQueue v1.0
build_dep magic_enum https://github.com/Neargye/magic_enum v0.9.7 -DMAGIC_ENUM_OPT_BUILD_TESTS=OFF
build_dep gsl-lite https://github.com/gsl-lite/gsl-lite v1.0.1
build_dep debug_assert https://github.com/foonathan/debug_assert v1.3.4
build_dep au https://github.com/aurora-opensource/au 0.5.1 -DAU_EXCLUDE_GTEST_DEPENDENCY=ON -DBUILD_TESTING=OFF
build_dep scn https://github.com/eliaskosunen/scnlib v4.0.1 -DSCN_TESTS=OFF -DSCN_DOCS=OFF -DSCN_EXAMPLES=OFF -DSCN_BENCHMARKS=OFF -DSCN_BENCHMARKS_BUILDTIME=OFF -DSCN_BENCHMARKS_BINARYSIZE=OFF -DSCN_INSTALL=ON -DSCN_USE_EXTERNAL_FAST_FLOAT=OFF

# type_safe installs its targets without a namespace, but Zrythm links
# type_safe::type_safe, so patch the export before building it
if [ ! -d "$DEPS_SRC/type_safe/.git" ]; then
    git clone --depth 1 --branch v0.2.4 --recurse-submodules https://github.com/foonathan/type_safe "$DEPS_SRC/type_safe"
fi
if ! grep -q "NAMESPACE type_safe::" "$DEPS_SRC/type_safe/CMakeLists.txt"; then
    sed -i 's|install( EXPORT type_safe-targets|install( EXPORT type_safe-targets NAMESPACE type_safe::|' "$DEPS_SRC/type_safe/CMakeLists.txt"
fi
build_dep type_safe https://github.com/foonathan/type_safe v0.2.4

# Arch's nlohmann-json (3.12.0) has no std::optional support, which Zrythm
# uses, so install a post-3.12.0 commit over it
build_dep nlohmann_json https://github.com/nlohmann/json 230bfd15a2bb7f01ebb3fcd3cf898b697ef43c48 -DJSON_BuildTests=OFF -DJSON_SystemInclude=ON

echo "Building Zrythm..."
echo "---------------------------------------------------------------"
REPO="https://gitlab.zrythm.org/zrythm/zrythm"
VERSION="$(git ls-remote "$REPO" HEAD | cut -c 1-9 | head -1)"
git clone --depth 1 "$REPO" ./zrythm
echo "$VERSION" > ~/version

# The AppImage ships neither the man page nor the shell completions, so
# skip both targets (ZRYTHM_MANPAGE also gates the completions).
cmake -S ./zrythm -B build \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DCMAKE_PREFIX_PATH=/usr \
    -DZRYTHM_WITH_JACK=ON \
    -DZRYTHM_MANPAGE=OFF \
    -DZRYTHM_SHELL_COMPLETIONS=OFF \
    -DCMAKE_MODULE_PATH="$(pwd)/cmake-shims" \
    -DCMAKE_INCLUDE_PATH=/usr/include \
    -DCMAKE_LIBRARY_PATH=/usr/lib \
    -DQT_DEPLOY_FORCE_ADJUST_RPATHS=OFF \
    -DCMAKE_PROJECT_INCLUDE="$(pwd)/cmake-shims/system-harfbuzz-zlib.cmake"

# JUCE has no switch to use the system HarfBuzz, so drop its bundled copy from
# the checkout CPM fetched and link the shared one the AppImage already ships.
patch -d build/_deps/juce-src -p1 -i "$PWD/patches/juce-no-bundled-harfbuzz.patch"

cmake --build build --config Release -j$(nproc)
cmake --install build
