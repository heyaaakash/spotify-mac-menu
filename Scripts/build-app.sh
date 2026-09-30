#!/bin/zsh
set -euo pipefail

cd "${0:A:h}/.."
if [[ -z "${SDKROOT:-}" && -d /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk ]]; then
  export SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk
fi
export CLANG_MODULE_CACHE_PATH="${TMPDIR:-/private/tmp}/spotmenu-clang-cache"

./Scripts/build-icon.sh
swift build --disable-sandbox --scratch-path .build -c release -debug-info-format none
app="${PWD}/dist/SpotMenu.app"
mkdir -p "${app}/Contents/MacOS" "${app}/Contents/Resources"
cp .build/out/Products/Release/SpotMenu "${app}/Contents/MacOS/SpotMenu"
cp Resources/SpotMenu.icns "${app}/Contents/Resources/SpotMenu.icns"
cat > "${app}/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>SpotMenu</string>
  <key>CFBundleDisplayName</key><string>SpotMenu</string>
  <key>CFBundleIdentifier</key><string>com.spotmenu.app</string>
  <key>CFBundleExecutable</key><string>SpotMenu</string>
  <key>CFBundleIconFile</key><string>SpotMenu.icns</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.3.0</string>
  <key>CFBundleVersion</key><string>4</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSAppleEventsUsageDescription</key><string>SpotMenu controls playback in Spotify when Spotify's Web API cannot reach the active device.</string>
</dict></plist>
PLIST
codesign --force --sign - "${app}"
# Finder can keep a cached icon when only files inside an existing app change.
touch "${app}"
registrar="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
if [[ -x "${registrar}" ]]; then
  "${registrar}" -f "${app}" || echo "Finder registration unavailable; the app bundle was built successfully." >&2
fi
echo "Built ${app}"
