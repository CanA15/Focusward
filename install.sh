#!/bin/zsh
set -euo pipefail

readonly app_name="Focusward"
readonly repo_root="${0:A:h}"
readonly launch_services="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
readonly install_root="$HOME/Applications"
readonly destination="$install_root/$app_name.app"

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

work_dir=$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/focusward-install.XXXXXX")
readonly work_dir
readonly derived_data="$work_dir/DerivedData"
readonly built_app="$derived_data/Build/Products/Release/$app_name.app"
readonly backup_app="$work_dir/Previous-$app_name.app"
had_previous=false
install_started=false
install_complete=false

rollback_install() {
  if [[ "$install_started" == true && "$install_complete" == false ]]; then
    /bin/rm -rf "$destination"
    [[ "$had_previous" == true ]] && /usr/bin/ditto "$backup_app" "$destination"
    install_started=false
  fi
}

cleanup() {
  rollback_install
  [[ -d "$built_app" ]] && "$launch_services" -u "$built_app" >/dev/null 2>&1 || true
  /bin/rm -rf "$work_dir"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

print "Building Focusward for $(/usr/bin/uname -m)…"
"$xcodebuild" \
  -project "$repo_root/Focusward.xcodeproj" \
  -scheme Focusward \
  -configuration Release \
  -derivedDataPath "$derived_data" \
  -destination "platform=macOS,arch=$(/usr/bin/uname -m)" \
  ONLY_ACTIVE_ARCH=YES \
  -quiet \
  build

/usr/bin/codesign --verify --deep --strict "$built_app"
/bin/mkdir -p "$install_root"

if [[ -e "$destination" ]]; then
  /usr/bin/ditto "$destination" "$backup_app"
  had_previous=true
fi

install_started=true
install_failed=false
/bin/rm -rf "$destination"
/usr/bin/ditto "$built_app" "$destination" || install_failed=true
if [[ "$install_failed" == false ]]; then
  /usr/bin/codesign --verify --deep --strict "$destination" || install_failed=true
fi

if [[ "$install_failed" == true ]]; then
  rollback_install
  print -u2 "Installation failed. The previous copy, if any, was restored."
  exit 1
fi

install_complete=true

for old_build in \
  "$repo_root/build/DerivedData/Build/Products/Debug/$app_name.app" \
  "$repo_root/build/DerivedData/Build/Products/Release/$app_name.app"; do
  if [[ -d "$old_build" ]]; then
    "$launch_services" -u "$old_build" >/dev/null 2>&1 || true
    /bin/rm -rf "$old_build"
  fi
done

"$launch_services" -f "$destination"
print "Installed Focusward at $destination"
print "You can now open it from Spotlight or your Applications folder."
