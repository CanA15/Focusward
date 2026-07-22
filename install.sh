#!/bin/zsh
set -euo pipefail

readonly app_name="Focusward"
readonly repo_root="${0:A:h}"
readonly output_root="$repo_root/dist"
readonly output_dmg="$output_root/$app_name.dmg"
readonly launch_services="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

open_dmg=true
if (( $# > 1 )); then
  print -u2 "Usage: ./install.sh [--no-open]"
  exit 2
fi
case "${1:-}" in
  "") ;;
  --no-open) open_dmg=false ;;
  *)
    print -u2 "Usage: ./install.sh [--no-open]"
    exit 2
    ;;
esac

developer_dir="${DEVELOPER_DIR:-}"
if [[ -z "$developer_dir" ]]; then
  developer_dir=$(/usr/bin/xcode-select -p 2>/dev/null || true)
fi
if [[ ! -x "$developer_dir/usr/bin/xcodebuild" && -x "/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild" ]]; then
  developer_dir="/Applications/Xcode.app/Contents/Developer"
fi
readonly developer_dir
readonly xcodebuild="$developer_dir/usr/bin/xcodebuild"

if [[ -z "$developer_dir" || ! -x "$xcodebuild" ]]; then
  print -u2 "Focusward requires Xcode to build from source. Install Xcode, then try again."
  exit 1
fi

if /usr/bin/pgrep -x "$app_name" >/dev/null 2>&1; then
  print -u2 "Quit Focusward before creating its installer."
  exit 1
fi

work_dir=$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/focusward-dmg.XXXXXX")
readonly work_dir
readonly derived_data="$work_dir/DerivedData"
readonly built_app="$derived_data/Build/Products/Release/$app_name.app"
readonly staging_root="$work_dir/Installer"
readonly temporary_dmg="$work_dir/$app_name.dmg"

cleanup() {
  [[ -d "$built_app" ]] && "$launch_services" -u "$built_app" >/dev/null 2>&1 || true
  /bin/rm -rf "$work_dir"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

print "Building a universal Focusward Release…"
"$xcodebuild" \
  -project "$repo_root/Focusward.xcodeproj" \
  -scheme Focusward \
  -configuration Release \
  -derivedDataPath "$derived_data" \
  -destination "generic/platform=macOS" \
  ARCHS="arm64 x86_64" \
  ONLY_ACTIVE_ARCH=NO \
  -quiet \
  build

/usr/bin/codesign --verify --deep --strict "$built_app"
/usr/bin/lipo "$built_app/Contents/MacOS/$app_name" -verify_arch arm64 x86_64

/bin/mkdir -p "$staging_root" "$output_root"
/usr/bin/ditto "$built_app" "$staging_root/$app_name.app"
/bin/ln -s /Applications "$staging_root/Applications"

print "Creating $app_name.dmg…"
/usr/bin/hdiutil create \
  -volname "$app_name" \
  -srcfolder "$staging_root" \
  -format UDZO \
  -ov \
  "$temporary_dmg" >/dev/null
/usr/bin/hdiutil verify "$temporary_dmg" >/dev/null
/bin/mv -f "$temporary_dmg" "$output_dmg"

for old_build in \
  "$repo_root/build/DerivedData/Build/Products/Debug/$app_name.app" \
  "$repo_root/build/DerivedData/Build/Products/Release/$app_name.app"; do
  if [[ -d "$old_build" ]]; then
    "$launch_services" -u "$old_build" >/dev/null 2>&1 || true
    /bin/rm -rf "$old_build"
  fi
done

print "Created $output_dmg"
if [[ "$open_dmg" == true ]]; then
  /usr/bin/open "$output_dmg"
  print "Drag Focusward onto Applications in the Finder window."
fi
