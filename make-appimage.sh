#!/bin/sh

set -eu

ARCH=$(uname -m)
export ARCH
export OUTPATH=./dist
export ADD_HOOKS="self-updater.hook"
export UPINFO="gh-releases-zsync|${GITHUB_REPOSITORY%/*}|${GITHUB_REPOSITORY#*/}|latest|*$ARCH.AppImage.zsync"
export ICON=/usr/share/icons/hicolor/scalable/apps/org.zrythm.Zrythm.svg
export DEPLOY_PIPEWIRE=1
export PATH_MAPPING='/usr/share/zrythm:${SHARUN_DIR}/share/zrythm'

# Deploy dependencies
quick-sharun /usr/bin/zrythm /usr/share/zrythm

# Turn AppDir into AppImage
quick-sharun --make-appimage

# Test the app for 12 seconds, if the test fails due to the app
# having issues running in the CI use --simple-test instead
quick-sharun --simple-test ./dist/*.AppImage
