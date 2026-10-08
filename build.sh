#!/usr/bin/env bash
# Builds release packages into dist/ (run on Linux):
#   dist/RoundsClone-x86_64.AppImage     Linux: one self-contained executable
#   dist/RoundsClone-windows-x64.zip     Windows: RoundsClone.exe + DLLs, unzip and run
#
# Usage: ./build.sh [all|linux|windows|love]     (default: all)
#   love = only build dist/RoundsClone.love (runs anywhere with `love RoundsClone.love`)
#
# Needs: curl, zip, unzip. The LÖVE runtimes and appimagetool are downloaded on the
# first build into build/cache/ (gitignored).
set -euo pipefail

NAME="RoundsClone"
TITLE="Rounds Clone"
LOVE_VERSION="11.5"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD="$ROOT/build"
CACHE="$BUILD/cache"
DIST="$ROOT/dist"
TARGET="${1:-all}"

LOVE_URL="https://github.com/love2d/love/releases/download/$LOVE_VERSION"
APPIMAGETOOL_URL="https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage"

log() { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

for tool in curl zip unzip; do
  command -v "$tool" >/dev/null || die "'$tool' is required (e.g. sudo pacman -S $tool)"
done

# download URL FILE: fetch once into the cache.
download() {
  local url="$1" dest="$CACHE/$2"
  if [ ! -s "$dest" ]; then
    log "Downloading $2" >&2
    curl -fL --retry 3 --progress-bar -o "$dest.part" "$url" || die "download failed: $url"
    mv "$dest.part" "$dest"
  fi
  printf '%s' "$dest"
}

# The game itself: every file in the repo except tooling, docs, native libraries (lib/) and build output.
build_love() {
  local out="$DIST/$NAME.love"
  log "Packing $NAME.love"
  rm -f "$out"
  (cd "$ROOT" && zip -9 -q -r "$out" . \
    -x '.git/*' '.claude/*' 'build/*' 'dist/*' 'lib/*' '*.md' '*.sh' '.gitignore' 'steam_appid.txt')
  local files
  files="$(unzip -Z1 "$out")"
  grep -qx 'main.lua' <<<"$files" || die "$NAME.love has no main.lua"
}

build_linux() {
  local appimage tool appdir
  appimage="$(download "$LOVE_URL/love-$LOVE_VERSION-x86_64.AppImage" "love-$LOVE_VERSION-x86_64.AppImage")"
  tool="$(download "$APPIMAGETOOL_URL" "appimagetool-x86_64.AppImage")"
  chmod +x "$appimage" "$tool"

  log "Building Linux AppImage"
  rm -rf "$BUILD/linux"
  mkdir -p "$BUILD/linux"
  (cd "$BUILD/linux" && "$appimage" --appimage-extract >/dev/null)
  appdir="$BUILD/linux/squashfs-root"

  # LÖVE's AppRun runs "$FUSE_PATH" as a fused game when it is set. The Steam libraries
  # sit next to the .love, which is where steam.lua looks for them in a fused build.
  cp "$DIST/$NAME.love" "$appdir/$NAME.love"
  cp "$ROOT/lib/linux/libsteam_api.so" "$ROOT/lib/linux/luasteam.so" "$ROOT/steam_appid.txt" "$appdir/"
  sed -i "s|^#FUSE_PATH=\"\$APPDIR/my_game.love\"|FUSE_PATH=\"\$APPDIR/$NAME.love\"|" "$appdir/AppRun"
  grep -q "^FUSE_PATH=" "$appdir/AppRun" || die "could not set FUSE_PATH in AppRun"

  rm -f "$appdir"/*.desktop
  cat > "$appdir/$NAME.desktop" <<EOF
[Desktop Entry]
Name=$TITLE
Comment=2D duel game: lose a round, pick a card
Exec=$NAME
Icon=love
Type=Application
Categories=Game;
Terminal=false
EOF

  rm -f "$DIST/$NAME-x86_64.AppImage"
  if ! ARCH=x86_64 APPIMAGE_EXTRACT_AND_RUN=1 "$tool" --no-appstream "$appdir" "$DIST/$NAME-x86_64.AppImage" \
    > "$BUILD/linux/appimagetool.log" 2>&1; then
    cat "$BUILD/linux/appimagetool.log" >&2
    die "appimagetool failed"
  fi
  chmod +x "$DIST/$NAME-x86_64.AppImage"
}

build_windows() {
  local zipfile src out
  zipfile="$(download "$LOVE_URL/love-$LOVE_VERSION-win64.zip" "love-$LOVE_VERSION-win64.zip")"

  log "Building Windows package"
  rm -rf "$BUILD/windows"
  mkdir -p "$BUILD/windows"
  unzip -q "$zipfile" -d "$BUILD/windows/runtime"
  src="$(dirname "$(find "$BUILD/windows/runtime" -name love.exe | head -n 1)")"
  [ -f "$src/love.exe" ] || die "love.exe not found in $zipfile"

  # A fused exe is love.exe with the .love appended. Steam DLLs go next to it.
  out="$BUILD/windows/$NAME"
  mkdir -p "$out"
  cat "$src/love.exe" "$DIST/$NAME.love" > "$out/$NAME.exe"
  cp "$src"/*.dll "$src/license.txt" "$out/"
  cp "$ROOT/lib/windows/steam_api64.dll" "$ROOT/lib/windows/luasteam.dll" "$ROOT/steam_appid.txt" "$out/"

  rm -f "$DIST/$NAME-windows-x64.zip"
  (cd "$BUILD/windows" && zip -9 -q -r "$DIST/$NAME-windows-x64.zip" "$NAME")
}

mkdir -p "$CACHE" "$DIST"
case "$TARGET" in
  all) build_love; build_linux; build_windows ;;
  linux) build_love; build_linux ;;
  windows) build_love; build_windows ;;
  love) build_love ;;
  *) die "unknown target '$TARGET' (use all, linux, windows or love)" ;;
esac

log "Done:"
ls -lh "$DIST"
