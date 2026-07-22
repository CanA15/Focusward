#!/bin/zsh
set -euo pipefail

readonly app_name="Focusward"
readonly repo_root="${0:A:h}"
readonly install_root="/Applications"
readonly destination="$install_root/$app_name.app"
readonly staging_destination="$install_root/.$app_name.installing.app"
readonly backup_destination="$install_root/.$app_name.previous.app"
readonly launch_services="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
install_in_progress=false
owns_staging=false
temporary_work_dir=""
temporary_built_app=""

recover_destination() {
  if [[ "$install_in_progress" == true ]]; then
    if [[ -e "$backup_destination" ]] && { [[ ! -e "$destination" ]] || ! /usr/bin/codesign --verify --deep --strict "$destination" 2>/dev/null; }; then
      /bin/rm -rf "$destination"
      /bin/mv "$backup_destination" "$destination"
    elif [[ -e "$backup_destination" ]]; then
      /bin/rm -rf "$backup_destination"
    elif [[ -e "$destination" ]] && ! /usr/bin/codesign --verify --deep --strict "$destination" 2>/dev/null; then
      /bin/rm -rf "$destination"
    fi
  fi
  [[ "$owns_staging" == true ]] && /bin/rm -rf "$staging_destination"
}

cleanup() {
  recover_destination
  [[ -d "$temporary_built_app" ]] && "$launch_services" -u "$temporary_built_app" >/dev/null 2>&1 || true
  [[ -n "$temporary_work_dir" ]] && /bin/rm -rf "$temporary_work_dir"
}

trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

install_app() {
  local source_app="$1"

  if [[ -e "$backup_destination" && ! -e "$destination" ]]; then
    /bin/mv "$backup_destination" "$destination"
  fi
  owns_staging=true
  /bin/rm -rf "$staging_destination" "$backup_destination"
  /usr/bin/ditto "$source_app" "$staging_destination"
  /usr/bin/codesign --verify --deep --strict "$staging_destination"

  install_in_progress=true
  [[ -e "$destination" ]] && /bin/mv "$destination" "$backup_destination"
  /bin/mv "$staging_destination" "$destination"
  /usr/bin/codesign --verify --deep --strict "$destination"
  /bin/rm -rf "$backup_destination"
  install_in_progress=false
}

if [[ "${1:-}" == "--install-built-app" ]]; then
  [[ $# == 2 && -d "$2" ]] || exit 2
  install_app "$2"
  exit
elif (( $# > 0 )); then
  print -u2 "Usage: ./install.sh"
  exit 2
fi

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
  print -u2 "Quit Focusward before installing or updating it."
  exit 1
fi

temporary_work_dir=$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/focusward-install.XXXXXX")
readonly temporary_work_dir
readonly derived_data="$temporary_work_dir/DerivedData"
temporary_built_app="$derived_data/Build/Products/Release/$app_name.app"
readonly temporary_built_app

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

/usr/bin/codesign --verify --deep --strict "$temporary_built_app"
/usr/bin/lipo "$temporary_built_app/Contents/MacOS/$app_name" -verify_arch arm64 x86_64

if [[ -w "$install_root" ]]; then
  install_app "$temporary_built_app"
else
  print "Administrator authorization is required to install in /Applications."
  /usr/bin/osascript - "$repo_root/install.sh" "$temporary_built_app" <<'APPLESCRIPT'
on run arguments
    set helperPath to item 1 of arguments
    set sourcePath to item 2 of arguments
    do shell script quoted form of helperPath & " --install-built-app " & quoted form of sourcePath with administrator privileges
end run
APPLESCRIPT
fi

/usr/bin/codesign --verify --deep --strict "$destination"
/usr/bin/lipo "$destination/Contents/MacOS/$app_name" -verify_arch arm64 x86_64
"$launch_services" -f "$destination"
print "Installed Focusward at $destination"
