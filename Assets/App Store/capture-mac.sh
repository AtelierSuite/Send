#!/bin/zsh
# Captures raw Mac App Store screenshots into Raw/Mac/<language>/.
# Usage: ./capture-mac.sh [languages...]   (defaults to en ja)
#
# Launches a debug build of Send with -ScreenshotStage, which stages the sample
# devices itself, then captures its window. A sheet is a window of its own, so it
# is captured separately with its offset in <shot>-sheet.txt, and compose.swift
# lays it back over the window. Needs an unlocked session, as the core reads its
# identity from the keychain, and a Retina display, so captures are at 2x.
set -e

SCRIPT_DIR=${0:A:h}
PROJECT_DIR=${SCRIPT_DIR:h:h}/Apple
DERIVED_DATA=/tmp/send-mac-screenshots-dd
LANGUAGES=($@)
(( $# )) || LANGUAGES=(en ja)
WORK=$(mktemp -d /tmp/send-mac-screenshots.XXXXXX)
trap 'rm -rf $WORK' EXIT
SHOTS=(01-devices:devices 02-offer:offer 03-transfer:transfer 04-pair:pair)

# MARK: - Build

# Signed to run locally only; the sandbox is left out, as an ad-hoc signed
# sandboxed app can't start outside /Applications.
xcodebuild build -project "$PROJECT_DIR/Wooosh.xcodeproj" -scheme Wooosh -configuration Debug \
  -destination "platform=macOS" -derivedDataPath $DERIVED_DATA \
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= CODE_SIGN_ENTITLEMENTS= -quiet
APP=$DERIVED_DATA/Build/Products/Debug/Send.app
swiftc -O "$SCRIPT_DIR/windows.swift" -o $WORK/windows

# MARK: - Capture

for language in $LANGUAGES; do
  raw_dir="$SCRIPT_DIR/Raw/Mac/$language"
  mkdir -p "$raw_dir"
  locale=$([[ $language == ja ]] && echo ja_JP || echo en_US)
  name=$([[ $language == ja ]] && echo "先生のMacBook Pro" || echo "Sensei's MacBook Pro")

  for shot in $SHOTS; do
    IFS=: read shot_name stage <<< $shot
    $APP/Contents/MacOS/Send -ScreenshotStage $stage -displayName "$name" \
      -AppleLanguages "($language)" -AppleLocale $locale \
      -ApplePersistenceIgnoreState YES -NSQuitAlwaysKeepsWindows NO >/dev/null 2>&1 &
    pid=$!
    # Long enough for the core to start and a sheet to finish sliding in.
    sleep 7

    window="" sheet="" window_x=0 window_y=0 window_w=0
    while IFS=$'\t' read -r id x y w h title; do
      if [[ $title == Send && -z $window ]]; then
        window=$id window_x=$x window_y=$y window_w=$w
      elif [[ -z $sheet ]]; then
        sheet="$id $x $y"
      fi
    done < <($WORK/windows $pid)
    if [[ -z $window ]]; then
      echo "no window for $shot_name ($language)" >&2
      kill $pid 2>/dev/null || true
      exit 1
    fi
    # Without the system's shadow: compose.swift draws its own.
    screencapture -o -l $window "$raw_dir/$shot_name.png"
    rm -f "$raw_dir/$shot_name-sheet.png" "$raw_dir/$shot_name-sheet.txt"
    if [[ -n $sheet ]]; then
      read sheet_id sheet_x sheet_y <<< $sheet
      screencapture -o -l $sheet_id "$raw_dir/$shot_name-sheet.png"
      echo "$(( sheet_x - window_x )) $(( sheet_y - window_y )) $window_w" > "$raw_dir/$shot_name-sheet.txt"
    fi
    kill $pid 2>/dev/null || true
    wait $pid 2>/dev/null || true
    echo "captured Mac/$language/$shot_name"
  done
done
