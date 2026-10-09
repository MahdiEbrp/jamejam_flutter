#!/usr/bin/env bash
# Cuts the rendered icon (see `render_icon_test.dart`) into every platform's icon set.
#
#   flutter test --no-pub --update-goldens tool/icon/render_icon_test.dart   # render it
#   tool/icon/install_icons.sh                                               # install it
#
# The sizes below are the ones the generated projects ask for: Android's five mipmap buckets,
# iOS's 19 named slots (20 pt through 1024 px), macOS's ten, and Windows' multi-size `.ico`.
# Linux desktop takes its icon from the packaged desktop file at distribution time; the PNG
# beside this script is what a packager points at.

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../.." && pwd)"
src="$here/jamejam-icon-1024.png"

[ -f "$src" ] || {
  echo "missing $src — render it first:" >&2
  echo "  flutter test --no-pub --update-goldens tool/icon/render_icon_test.dart" >&2
  exit 2
}

resize() { # size, destination
  magick "$src" -resize "${1}x${1}" -strip "$2"
}

echo "Android"
for bucket in mdpi:48 hdpi:72 xhdpi:96 xxhdpi:144 xxxhdpi:192; do
  dir="${bucket%%:*}"
  size="${bucket##*:}"
  resize "$size" "$root/android/app/src/main/res/mipmap-$dir/ic_launcher.png"
done

echo "iOS"
for png in "$root"/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-*.png; do
  name="$(basename "$png" .png)"          # Icon-App-83.5x83.5@2x
  points="${name#Icon-App-}"              # 83.5x83.5@2x
  scale="${points##*@}"                   # 2x
  scale="${scale%x}"
  points="${points%%@*}"                  # 83.5x83.5
  side="${points%%x*}"                    # 83.5
  px="$(magick -size 1x1 xc: -format "%[fx:round($side*$scale)]" info:)"
  resize "$px" "$png"
done

echo "macOS"
for png in "$root"/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_*.png; do
  px="$(basename "$png" .png)"
  px="${px##*_}"
  resize "$px" "$png"
done

echo "Windows"
magick "$src" -define icon:auto-resize=256,128,64,48,32,16 -strip \
  "$root/windows/runner/resources/app_icon.ico"

echo "done — $(magick identify -format '%wx%h' "$src") source, $(find "$root/android" "$root/ios" "$root/macos" "$root/windows" -name 'ic_launcher.png' -o -name 'Icon-App-*.png' -o -name 'app_icon_*.png' -o -name 'app_icon.ico' | wc -l) files written"
