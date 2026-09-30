#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
export SPOTMENU_REGISTER_APP=0
./Scripts/build-app.sh
version="$(<VERSION)"
app="${PWD}/dist/SpotMenu.app"
architecture="$(lipo -archs "${app}/Contents/MacOS/SpotMenu")"
[[ "$architecture" == arm64 || "$architecture" == x86_64 ]] || { echo "Expected one native architecture, got: $architecture" >&2; exit 1; }
name="SpotMenu-${version}-macos-${architecture}.zip"
archive="${PWD}/dist/${name}"
ditto -c -k --keepParent --norsrc "$app" "$archive"
check_dir="$(mktemp -d "${TMPDIR:-/private/tmp}/spotmenu-package.XXXXXX")"
trap 'rm -rf -- "$check_dir"' EXIT
ditto -x -k "$archive" "$check_dir"
codesign --verify --strict --verbose=2 "${check_dir}/SpotMenu.app"
plutil -lint "${check_dir}/SpotMenu.app/Contents/Info.plist"
[[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "${check_dir}/SpotMenu.app/Contents/Info.plist")" == "$version" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "${check_dir}/SpotMenu.app/Contents/Info.plist")" == "$(<BUILD_NUMBER)" ]]
cmp "$app/Contents/MacOS/SpotMenu" "${check_dir}/SpotMenu.app/Contents/MacOS/SpotMenu"
# A distribution ZIP contains only the app executable, icon, license, plist, and signature.
expected="Contents/Info.plist Contents/MacOS/SpotMenu Contents/Resources/SpotMenu.icns Contents/Resources/LICENSE.txt Contents/_CodeSignature/CodeResources"
for file in "${check_dir}/SpotMenu.app"/**/*(.N); do
  relative="${file#${check_dir}/SpotMenu.app/}"
  [[ " $expected " == *" $relative "* ]] || { echo "Unexpected package file: $relative" >&2; exit 1; }
done
(cd dist; shasum -a 256 "$name" > "${name}.sha256"; shasum -a 256 -c "${name}.sha256")
echo "Packaged ${archive} (ad-hoc signed; not notarized)"
