#!/bin/sh

set -eu

ARCH=$(uname -m)

echo "Installing package dependencies..."
echo "---------------------------------------------------------------"
pacman -Syu --noconfirm   \
    boost                 \
    cmake                 \
    chromaprint           \
    doxygen               \
    fluidsynth            \
    fmt                   \
    gtksourceview5        \
    help2man              \
    hicolor-icon-theme    \
    json-schema-validator \
    kvantum               \
    libadwaita            \
    libbacktrace          \
    libcyaml              \
    liblo                 \
    libpanel              \
    lxqt-qtplugin         \
    onetbb                \
    pipewire-audio        \
    pipewire-jack         \
    qt6-canvaspainter     \
    qt6-declarative       \
    qt6-svg               \
    qt6-tools             \
    qt6ct                 \
    rtaudio               \
    rtmidi                \
    rubberband            \
    sdl2-compat           \
    spdlog                \
    vamp-plugin-sdk       \
    xdg-utils             \
    yyjson

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

echo "Building Carla..."
echo "---------------------------------------------------------------"
REPO="https://github.com/falkTX/Carla"
git clone --depth 1 "$REPO" ./Carla

cd ./Carla
make features
make -j$(nproc) DEFAULT_QT=6 HAVE_QT4=false PREFIX=/usr
make install
cd ../

echo "Building Zrythm dependencies..."
echo "---------------------------------------------------------------"
# These have no Arch package, so they are built from source and installed
# into /usr. (xxhash, zstd, nlohmann-json, fmt, spdlog, boost come from pacman)
DEPS_SRC="$PWD/zrythm-deps"
mkdir -p "$DEPS_SRC"

# build_dep <name> <git url> <ref> [extra cmake args...]
build_dep () {
    dep_name="$1"
    dep_src="$DEPS_SRC/$dep_name"
    if [ ! -d "$dep_src/.git" ]; then
        git clone --depth 1 --branch "$3" "$2" "$dep_src"
    fi
    shift 3
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
build_dep scn https://github.com/eliaskosunen/scnlib v4.0.1 -DSCN_TESTS=OFF -DSCN_DOCS=OFF -DSCN_EXAMPLES=OFF -DSCN_INSTALL=ON -DSCN_USE_EXTERNAL_FAST_FLOAT=OFF

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
if [ ! -d "$DEPS_SRC/nlohmann_json/.git" ]; then
    git clone --depth 1 https://github.com/nlohmann/json "$DEPS_SRC/nlohmann_json"
    git -C "$DEPS_SRC/nlohmann_json" fetch --depth 1 origin 230bfd15a2bb7f01ebb3fcd3cf898b697ef43c48
    git -C "$DEPS_SRC/nlohmann_json" checkout -q FETCH_HEAD
fi
echo "==> nlohmann_json"
cmake -S "$DEPS_SRC/nlohmann_json" -B "$DEPS_SRC/nlohmann_json/build" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DCMAKE_PREFIX_PATH=/usr \
    -DJSON_BuildTests=OFF \
    -DJSON_SystemInclude=ON
cmake --build "$DEPS_SRC/nlohmann_json/build" -j$(nproc)
cmake --install "$DEPS_SRC/nlohmann_json/build"

echo "Building Zrythm..."
echo "---------------------------------------------------------------"
REPO="https://gitlab.zrythm.org/zrythm/zrythm"
VERSION="$(git ls-remote "$REPO" HEAD | cut -c 1-9 | head -1)"
git clone --depth 1 "$REPO" ./zrythm
echo "$VERSION" > ~/version

# The man page target runs the zrythm binary in a headless CI container,
# where no X/Wayland display exists and libxcb-cursor is missing
export QT_QPA_PLATFORM=offscreen

cmake -S ./zrythm -B build \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DCMAKE_PREFIX_PATH=/usr \
    -DZRYTHM_WITH_JACK=ON \
    -DCMAKE_MODULE_PATH="$(pwd)/cmake-shims" \
    -DCMAKE_INCLUDE_PATH=/usr/include \
    -DCMAKE_LIBRARY_PATH=/usr/lib \
    -DQT_DEPLOY_FORCE_ADJUST_RPATHS=OFF
cmake --build build --config Release -j$(nproc)
cmake --install build
