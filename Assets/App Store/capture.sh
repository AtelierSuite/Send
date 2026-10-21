#!/bin/zsh
# Captures raw App Store screenshots into Raw/<device>/<language>/.
# Usage: ./capture.sh [languages...]   (defaults to en ja)
#        DEVICES=iPad ./capture.sh    (defaults to both iPhone and iPad)
#
# A debug build launched with -ScreenshotStage skips discovery and stages the
# sample devices itself (Apple/Wooosh/Core/ScreenshotStage.swift). Run
# compose.swift afterwards to frame the captures.
set -e

SCRIPT_DIR=${0:A:h}
PROJECT_DIR=${SCRIPT_DIR:h:h}/Apple
BUNDLE_ID=com.tsubuzaki.Wooosh
DERIVED_DATA=/tmp/send-screenshots-dd
LANGUAGES=($@)
(( $# )) || LANGUAGES=(en ja)
typeset -A DEVICE_TYPES=(
  iPhone com.apple.CoreSimulator.SimDeviceType.iPhone-18-Pro-Max
  iPad com.apple.CoreSimulator.SimDeviceType.iPad-Pro-13-inch-M5-12GB
)
# Each shot: name, then the stage it launches into and the appearance.
SHOTS=(01-devices:devices:light 02-offer:offer:light 03-transfer:transfer:light
  04-pair:pair:light 05-dark:devices:dark 06-settings:settings:light)

# MARK: - Simulators

simulator() {
  local name="Send Screenshots $1" udid
  udid=$(xcrun simctl list devices available | grep "$name (" | head -1 | grep -oE '[0-9A-F-]{36}' || true)
  if [[ -z $udid ]]; then
    udid=$(xcrun simctl create "$name" $DEVICE_TYPES[$1] com.apple.CoreSimulator.SimRuntime.iOS-27-0)
  fi
  echo $udid
}

# The status bar's date follows the system language, not the app's, so the whole
# simulator is switched and restarted for each language. The preferences are
# edited while it is shut down: a `defaults write` through simctl spawn does not
# survive the restart.
boot() {
  local locale=$([[ $2 == ja ]] && echo ja_JP || echo en_US)
  local preferences=~/Library/Developer/CoreSimulator/Devices/$1/data/Library/Preferences/.GlobalPreferences.plist
  # The first boot is what creates the preferences.
  xcrun simctl boot $1 2>/dev/null || true
  xcrun simctl bootstatus $1 -b >/dev/null
  xcrun simctl shutdown $1
  plutil -replace AppleLanguages -json "[\"$2\"]" "$preferences"
  plutil -replace AppleLocale -string $locale "$preferences"
  xcrun simctl boot $1
  xcrun simctl bootstatus $1 -b >/dev/null
  xcrun simctl status_bar $1 override --time 9:41 \
    --batteryState discharging --batteryLevel 100 \
    --cellularMode active --cellularBars 4 --wifiBars 3 --operatorName ""
}

# MARK: - Build

xcodebuild build -project "$PROJECT_DIR/Wooosh.xcodeproj" -scheme Wooosh -configuration Debug \
  -destination "generic/platform=iOS Simulator" -derivedDataPath $DERIVED_DATA -quiet
APP=$DERIVED_DATA/Build/Products/Debug-iphonesimulator/Send.app

# MARK: - Capture

capture() {
  local device=$1 udid=$(simulator $1) language shot name stage appearance
  for language in $LANGUAGES; do
    boot $udid $language
    # A fresh install, so no settings survive from an earlier run.
    xcrun simctl uninstall $udid $BUNDLE_ID 2>/dev/null || true
    xcrun simctl install $udid $APP
    raw_dir="$SCRIPT_DIR/Raw/$device/$language"
    mkdir -p "$raw_dir"
    locale=$([[ $language == ja ]] && echo ja_JP || echo en_US)
    name=$([[ $language == ja ]] && echo "先生の$device" || echo "Sensei's $device")
    for shot in $SHOTS; do
      IFS=: read name_ stage appearance <<< $shot
      xcrun simctl ui $udid appearance $appearance
      xcrun simctl terminate $udid $BUNDLE_ID 2>/dev/null || true
      xcrun simctl launch $udid $BUNDLE_ID -ScreenshotStage $stage \
        -AppleLanguages "($language)" -AppleLocale $locale -displayName "$name" >/dev/null
      # Long enough for the core to start and any sheet to finish sliding in.
      sleep 6
      xcrun simctl io $udid screenshot "$raw_dir/$name_.png" >/dev/null 2>&1
    done
    xcrun simctl terminate $udid $BUNDLE_ID 2>/dev/null || true
    xcrun simctl ui $udid appearance light
    echo "captured $device/$language"
  done
}

for device in ${=DEVICES:-iPhone iPad}; do
  capture $device &
done
wait
