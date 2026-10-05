#!/bin/bash
set -euo pipefail
mkdir -p build/screenshots
xcodebuild -version
xcodebuild -showsdks
xcrun simctl list runtimes
swift test --package-path Packages/GitHubKit
xcodegen generate
xcodebuild -resolvePackageDependencies -project Trellis.xcodeproj -scheme Trellis
RUNTIME=$(xcrun simctl list runtimes --json | python3 -c 'import json,sys; r=[x for x in json.load(sys.stdin)["runtimes"] if x.get("isAvailable") and x["identifier"].startswith("com.apple.CoreSimulator.SimRuntime.iOS-")]; r.sort(key=lambda x:tuple(map(int,x["version"].split(".")))); assert r,"No available iOS simulator runtime"; print(r[-1]["identifier"])')
DEVICE=$(xcrun simctl create 'Trellis iPhone 13' com.apple.CoreSimulator.SimDeviceType.iPhone-13 "$RUNTIME")
xcrun simctl boot "$DEVICE"
xcrun simctl bootstatus "$DEVICE" -b
xcrun simctl status_bar "$DEVICE" override --time '9:41' --dataNetwork wifi --wifiMode active --wifiBars 3 --batteryState charged --batteryLevel 100
BUILD_SETTINGS=(CODE_SIGN_IDENTITY= CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO "GH_CLIENT_ID=${GH_CLIENT_ID:-}" "CURRENT_PROJECT_VERSION=${GITHUB_RUN_NUMBER:-1}")
xcodebuild test -project Trellis.xcodeproj -scheme Trellis -configuration Debug -destination "platform=iOS Simulator,id=$DEVICE" -derivedDataPath build/DerivedData -resultBundlePath build/Tests.xcresult "${BUILD_SETTINGS[@]}" > build/test.log 2>&1 || { tail -n 100 build/test.log; exit 1; }
xcrun xcresulttool export attachments --path build/Tests.xcresult --output-path build/screenshots
# Include a dark appearance capture independently of UI-test attachments.
xcrun simctl ui "$DEVICE" appearance dark
xcrun simctl launch "$DEVICE" dev.trellis.client --demo
xcrun simctl io "$DEVICE" screenshot build/screenshots/08-dark.png
archive() { xcodebuild archive -project Trellis.xcodeproj -scheme Trellis -configuration Release -destination 'generic/platform=iOS' -archivePath build/Trellis.xcarchive "${BUILD_SETTINGS[@]}" > build/archive.log 2>&1; }
if ! archive; then
  if rg -q 'MetalToolchain|Metal toolchain|metal.*not found' build/archive.log; then xcodebuild -downloadComponent MetalToolchain; archive; else tail -n 100 build/archive.log; exit 1; fi
fi
mkdir -p build/ipa/Payload
cp -R build/Trellis.xcarchive/Products/Applications/Trellis.app build/ipa/Payload/
(cd build/ipa && zip -qry ../Trellis.ipa Payload)
unzip -l build/Trellis.ipa > build/ipa-contents.txt
python3 scripts/verify-ipa.py build/Trellis.ipa
xcrun simctl shutdown "$DEVICE"
