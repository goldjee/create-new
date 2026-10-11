#!/bin/bash
# Builds "Create New.app" (arm64, ad-hoc signed) into build/.
#   --test  run the self-test first
#   --dmg   also package build/CreateNew.dmg
# VERSION=v1.2.3 stamps that version into both bundles (CI sets it from the release tag).
set -euo pipefail
cd "$(dirname "$0")"

APP="build/Create New.app"
APPEX="$APP/Contents/PlugIns/CreateNewExtension.appex"
SWIFTC=(xcrun swiftc -target arm64-apple-macos13 -O -parse-as-library)

rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APPEX/Contents/MacOS" "$APPEX/Contents/Resources"

if [[ " $* " == *" --test "* ]]; then
  "${SWIFTC[@]}" Sources/Shared/*.swift Tests/*.swift -o build/selftest
  build/selftest
fi

"${SWIFTC[@]}" -module-name CreateNew Sources/Shared/*.swift Sources/App/*.swift \
  -o "$APP/Contents/MacOS/CreateNew"
"${SWIFTC[@]}" -module-name CreateNewExtension -application-extension \
  Sources/Shared/*.swift Sources/Extension/*.swift \
  -Xlinker -e -Xlinker _NSExtensionMain \
  -o "$APPEX/Contents/MacOS/CreateNewExtension"

cp Resources/App-Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/"
cp Resources/Extension-Info.plist "$APPEX/Contents/Info.plist"
cp -R Resources/Templates "$APPEX/Contents/Resources/"
cp -R Resources/*.lproj "$APP/Contents/Resources/"
cp -R Resources/*.lproj "$APPEX/Contents/Resources/"
if [[ -n "${VERSION:-}" ]]; then
  for plist in "$APP/Contents/Info.plist" "$APPEX/Contents/Info.plist"; do
    plutil -replace CFBundleShortVersionString -string "${VERSION#v}" "$plist"
    plutil -replace CFBundleVersion -string "${VERSION#v}" "$plist"
  done
fi

# Inside-out ad-hoc signing: the extension needs its sandbox entitlements, the app needs none.
codesign --force --sign - --entitlements Resources/Extension.entitlements "$APPEX"
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"
# Finder caches icons by path; re-register so a rebuilt app in build/ shows its current icon.
touch "$APP"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP"
echo "Built $APP"

if [[ " $* " == *" --dmg "* ]]; then
  mkdir build/dmg
  cp -R "$APP" build/dmg/
  ln -s /Applications build/dmg/Applications
  hdiutil create -volname "Create New" -srcfolder build/dmg -ov -format UDZO build/CreateNew.dmg
  rm -rf build/dmg
  echo "Built build/CreateNew.dmg"
fi
