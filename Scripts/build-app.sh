#!/bin/zsh
set -euo pipefail

cd "${0:A:h}/.."
if [[ -z "${SDKROOT:-}" && -d /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk ]]; then
  export SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk
fi
export SDKROOT="${SDKROOT:-$(xcrun --show-sdk-path)}"
export CLANG_MODULE_CACHE_PATH="${TMPDIR:-/private/tmp}/spotmenu-clang-cache"

version="$(<VERSION)"
build_number="$(<BUILD_NUMBER)"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Invalid VERSION" >&2; exit 1; }
[[ "$build_number" =~ ^[0-9]+$ ]] || { echo "Invalid BUILD_NUMBER" >&2; exit 1; }

./Scripts/build-icon.sh
swift build --disable-sandbox --scratch-path .build -c release -debug-info-format none
binary_dir="$(swift build --disable-sandbox --scratch-path .build -c release --show-bin-path)"
app="${PWD}/dist/SpotMenu.app"
stage="$(mktemp -d "${TMPDIR:-/private/tmp}/spotmenu-bundle.XXXXXX")"
trap 'rm -rf -- "$stage"' EXIT
bundle="${stage}/SpotMenu.app"
mkdir -p "${bundle}/Contents/MacOS" "${bundle}/Contents/Resources"
cp "${binary_dir}/SpotMenu" "${bundle}/Contents/MacOS/SpotMenu"
cp Resources/SpotMenu.icns "${bundle}/Contents/Resources/SpotMenu.icns"
cp LICENSE "${bundle}/Contents/Resources/LICENSE.txt"
cat > "${bundle}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>SpotMenu</string>
  <key>CFBundleDisplayName</key><string>SpotMenu</string>
  <key>CFBundleIdentifier</key><string>com.spotmenu.app</string>
  <key>CFBundleExecutable</key><string>SpotMenu</string>
  <key>CFBundleIconFile</key><string>SpotMenu.icns</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${version}</string>
  <key>CFBundleVersion</key><string>${build_number}</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSAppleEventsUsageDescription</key><string>SpotMenu controls playback in Spotify when Spotify's Web API cannot reach the active device.</string>
</dict></plist>
PLIST
plutil -lint "${bundle}/Contents/Info.plist"
codesign --force --sign - "${bundle}"
codesign --verify --strict --verbose=2 "${bundle}"
mkdir -p "${PWD}/dist"
rm -rf -- "${app}"
mv "${bundle}" "${app}"
# Finder can keep a cached icon when only files inside an existing app change.
touch "${app}"
registrar="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
if [[ "${SPOTMENU_REGISTER_APP:-1}" == 1 && -x "${registrar}" ]]; then
  "${registrar}" -f "${app}" || echo "Finder registration unavailable; the app bundle was built successfully." >&2
fi
echo "Built ${app}"
