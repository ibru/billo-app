#!/usr/bin/env bash
#
# Captures the macOS (Mac Catalyst) App Store shot set, one locale at a time.
#
# Mirrors the iPad set: the same four states and file names (2-bills-list,
# 3-calendar, 4-bill-detail, 5-charts), so the Figma job rules stay parallel
# across devices. Each shot is a fresh launch — the Screenshots build seeds an
# in-memory store, and `-billsDefaultView` (NSArgumentDomain, outranks the
# @AppStorage-persisted value) picks the home view. Everything else is driven
# by input events against a window pinned to a known origin and size, so
# element coordinates are constants rather than something to re-derive per run.
#
# Every capture asserts the window body landed at exactly the expected pixel
# offset, which catches an unfocused, moved, or (Catalyst state restoration)
# resized window before it reaches the design.
#
# See docs/appstore-shots.md for the shot catalogue and the platform traps.

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$PROJECT_DIR/Billo.xcodeproj"
SCHEME="BilloScreenshots"
CONFIGURATION="Screenshots"
BUNDLE_ID="com.jiriurbasek.Billo"
APP_NAME="Billo"

DEFAULT_OUT="$PROJECT_DIR/../appstore/v1.0.2/screenshots"
DEFAULT_LOCALES="en it es-ES es-MX pt-BR"

# The Billo Catalyst window IS resizable (unlike some Catalyst apps), and it
# restores its last frame on launch — so the script pins position AND size on
# every launch, by window id (set-bounds by app name can silently mis-target
# when a stale debugger-attached instance shares the name).
WIN_X=100
WIN_Y=80
WIN_W=928    # the product's default Mac window size (portrait-ish split view);
WIN_H=792    # the Figma design composites the window onto the 2560x1600 canvas

# A focused window's shadow is larger than an unfocused one's. Asserting the
# focused geometry is therefore also an assertion that the app was frontmost,
# which is the difference between coloured and grey traffic lights.
EXPECT_SIZE="2080x1808"
EXPECT_BBOX="1856x1584+112+76"
MIN_PNG_BYTES=200000

LAUNCH_SETTLE=8
ACTION_SETTLE=2.5

# Wheel events are linear at 1 wheel pixel == 1 point — but only as a series
# of small events. One large event accelerates unpredictably.
SCROLL_TICK=20

# --- Shot catalogue ---------------------------------------------------------
#
# Click coordinates are WINDOW-RELATIVE points (peekaboo treats --coords as
# window-relative whenever --pid is supplied). The wheel/click Swift helpers
# take GLOBAL screen points, since they post events at the cursor.
#
# Nothing here is language-dependent: targets are full-width rows, fixed
# toolbar buttons, or menu items whose position doesn't move with label width.
# The seed datasets share one day-of-month spread (1,3,5,8,9,12,15,18,20,22,
# 25,27), so row indexes hold across markets.

SHOT_IDS=(2-bills-list 3-calendar 4-bill-detail 5-charts)

shot_description() {
  case "$1" in
    2-bills-list)  echo "Split view, bills list scrolled to Next 7 Days, electric bill (day 15) selected" ;;
    3-calendar)    echo "July grid + list at month boundary (income row, August sums), day-1 bill selected" ;;
    4-bill-detail) echo "Same sidebar as 2, the due-in-2-days bill (day 1) selected" ;;
    5-charts)      echo "Charts detail scrolled so Spending by Category tops the pane, sidebar at top" ;;
    *)             echo "unknown shot" ;;
  esac
}

shot_view_mode() {
  case "$1" in
    3-calendar) echo "calendar" ;;
    *)          echo "list" ;;
  esac
}

# Capture-pixel regions (window body starts at +112+76, 2 px per point) used
# to verify that a click actually landed: the calendar month label, and the
# detail pane where a row selection replaces the placeholder.
MONTH_LABEL_REGION="500x80+232+192"
DETAIL_PANE_REGION="800x600+912+376"

region_hash() {
  screencapture -x -r -t png -l "$WINDOW_ID" "$WORKDIR/probe.png" 2>/dev/null || return 1
  magick "$WORKDIR/probe.png" -crop "$1" +repage -format "%#" info: 2>/dev/null
}

# click_verified <wr-x> <wr-y> <region> — clicks (real CGEvents; peekaboo's
# window-targeted delivery occasionally misses without any error) until the
# region's pixels change, max 3 attempts.
click_verified() {
  local x="$1" y="$2" region="$3" base after attempt
  base="$(region_hash "$region")" || return 1
  for attempt in 1 2 3; do
    swift "$CLICK_SWIFT" $((WIN_X + x)) $((WIN_Y + y)) >/dev/null 2>&1 || true
    sleep 1.8
    after="$(region_hash "$region")" || return 1
    [[ "$after" != "$base" ]] && return 0
  done
  return 1
}

# Post-launch input, per shot. Selection clicks happen at the at-rest scroll
# position; scrolls come after, so every coordinate is measured against a
# freshly launched window.
shot_actions() {
  case "$1" in
    2-bills-list)
      # Electric bill row (day 15, "Next 30 Days" section) at rest, then pull
      # the list up so the first "Next 7 Days" row sits under the toolbar.
      peekaboo click --pid "$APP_PID" --coords 184,588 >/dev/null 2>&1 || true
      sleep 1.5
      swift "$WHEEL_SWIFT" $((WIN_X + 240)) $((WIN_Y + 420)) 7 -"$SCROLL_TICK" >/dev/null 2>&1 || true
      ;;
    4-bill-detail)
      # First "Next 7 Days" row (day-1 bill, due in 2 days), same scroll as 2.
      peekaboo click --pid "$APP_PID" --coords 184,240 >/dev/null 2>&1 || true
      sleep 1.5
      swift "$WHEEL_SWIFT" $((WIN_X + 240)) $((WIN_Y + 420)) 7 -"$SCROLL_TICK" >/dev/null 2>&1 || true
      ;;
    3-calendar)
      # ">" anchors the list at next month's top — a deterministic scroll
      # anchor (grid-day clicks open the DayDetail sheet instead; avoid
      # sheets, Catalyst can't dismiss them cleanly). Select the day-1 bill
      # there, "<" back to the current month (today stays circled), then
      # scroll the list 720pt (~10 rows) to the month boundary: tail bills,
      # income row, next month's header with sums, and the selected bill.
      #
      # Every click is verified against a region that must change (a missed
      # month-nav click otherwise cascades: the selection still lands via the
      # current month's list, "<" then steps into the PREVIOUS month, and the
      # capture passes every whole-shot assertion while showing June).
      click_verified 334 85 "$MONTH_LABEL_REGION" \
        || { FAILURES+=("$locale/$shot: '>' month-nav click never registered"); return 0; }
      click_verified 250 419 "$DETAIL_PANE_REGION" \
        || { FAILURES+=("$locale/$shot: day-1 row click never registered"); return 0; }
      click_verified 28 85 "$MONTH_LABEL_REGION" \
        || { FAILURES+=("$locale/$shot: '<' month-nav click never registered"); return 0; }
      sleep 1
      swift "$WHEEL_SWIFT" $((WIN_X + 240)) $((WIN_Y + 420)) 36 -"$SCROLL_TICK" >/dev/null 2>&1 || true
      ;;
    5-charts)
      # Charts lives in the sidebar's ellipsis menu. A synthetic click only
      # HIGHLIGHTS a Catalyst menu item (the up event never activates it), so
      # the click parks the cursor on "Charts" and Return commits it. Then
      # scroll the detail pane so Spending by Category tops it (skipping the
      # Monthly Cash Flow card): card top rests at ~420pt, target ~80pt —
      # right under the toolbar blur, so only a sliver of the previous card
      # shows through it.
      peekaboo click --pid "$APP_PID" --coords 30,48 >/dev/null 2>&1 || true
      sleep 1.5
      swift "$CLICK_SWIFT" $((WIN_X + 69)) $((WIN_Y + 101)) >/dev/null 2>&1 || true
      sleep 1
      swift "$KEY_SWIFT" 36 >/dev/null 2>&1 || true   # Return
      sleep 2.5
      swift "$WHEEL_SWIFT" $((WIN_X + 600)) $((WIN_Y + 400)) 17 -"$SCROLL_TICK" >/dev/null 2>&1 || true
      ;;
  esac
  return 0
}

locale_language() {
  case "$1" in
    en) echo "en" ;; it) echo "it" ;;
    es-ES|es-MX) echo "es" ;;
    pt-BR) echo "pt-BR" ;;
    *) echo "$1" ;;
  esac
}

# Number grouping and currency follow the REGION; the region also selects the
# ScreenshotMockData market dataset. SCREENSHOT_MARKET is set as well so the
# dataset never depends on locale parsing.
locale_region() {
  case "$1" in
    en) echo "en_US" ;; it) echo "it_IT" ;; es-ES) echo "es_ES" ;;
    es-MX) echo "es_MX" ;; pt-BR) echo "pt_BR" ;; *) echo "$1" ;;
  esac
}

locale_market() {
  case "$1" in
    en) echo "us" ;; it) echo "it" ;; es-ES) echo "es" ;;
    es-MX) echo "mx" ;; pt-BR) echo "br" ;; *) echo "us" ;;
  esac
}

# --- CLI --------------------------------------------------------------------

usage() {
  cat <<'EOF'
Capture the macOS App Store shot set.

USAGE
  capture-appstore-mac-shots.sh --all                     every shot, every locale
  capture-appstore-mac-shots.sh --locales es-ES,pt-BR     only these locales
  capture-appstore-mac-shots.sh --only 5-charts           only these shots (re-shoots)
  capture-appstore-mac-shots.sh --list                    print the catalogue and exit

OPTIONS
  --locales <list>   comma-separated (default: en,it,es-ES,es-MX,pt-BR)
  --only <list>      comma-separated shot ids
  --out <dir>        screenshots root (default: ../appstore/v1.0.2/screenshots)
  --skip-build       reuse the already-built app
  -h, --help         this text

OUTPUT
  <out>/<locale>/mac/<shot>.png       window capture WITH drop shadow, native 2x,
                                      alpha preserved for compositing in Figma

Requires the display to be awake and unlocked — macOS cannot capture a sleeping
display. The script holds a display-sleep assertion for its own duration.
Close any Xcode debug session of Billo first: a debugger-suspended instance
keeps its windows on screen and cannot be killed.
EOF
}

MODE=""
ONLY=""
LOCALES="$DEFAULT_LOCALES"
OUT=""
SKIP_BUILD=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all)        MODE="all"; shift ;;
    --only)       MODE="all"; ONLY="${2:?--only needs a comma-separated shot list}"; shift 2 ;;
    --locales)    LOCALES="$(echo "${2:?--locales needs a comma-separated list}" | tr ',' ' ')"; shift 2 ;;
    --list)       MODE="list"; shift ;;
    --out)        OUT="${2:?--out needs a directory}"; shift 2 ;;
    --skip-build) SKIP_BUILD=1; shift ;;
    -h|--help)    usage; exit 0 ;;
    *)            echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

[[ -z "$MODE" ]] && { usage >&2; exit 2; }

if [[ "$MODE" == "list" ]]; then
  printf '%-16s  %-9s  %s\n' ID VIEW DESCRIPTION
  for id in "${SHOT_IDS[@]}"; do
    printf '%-16s  %-9s  %s\n' "$id" "$(shot_view_mode "$id")" "$(shot_description "$id")"
  done
  echo
  echo "Locales: $DEFAULT_LOCALES"
  exit 0
fi

SELECTED=("${SHOT_IDS[@]}")
if [[ -n "$ONLY" ]]; then
  SELECTED=()
  IFS=',' read -r -a requested <<< "$ONLY"
  for id in "${requested[@]}"; do
    id="$(echo "$id" | tr -d '[:space:]')"
    if [[ " ${SHOT_IDS[*]} " != *" $id "* ]]; then
      echo "unknown shot id: $id (try --list)" >&2
      exit 2
    fi
    SELECTED+=("$id")
  done
fi

# --- Preflight --------------------------------------------------------------

for tool in peekaboo python3 magick screencapture swift xcodebuild osascript; do
  command -v "$tool" >/dev/null 2>&1 || { echo "required tool '$tool' is not on PATH" >&2; exit 1; }
done

OUT="${OUT:-$DEFAULT_OUT}"
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"
echo "==> output: $OUT"

WORKDIR="$(mktemp -d -t billo-mac-shots)"
WHEEL_SWIFT="$WORKDIR/wheel.swift"
CLICK_SWIFT="$WORKDIR/click.swift"
KEY_SWIFT="$WORKDIR/key.swift"

cat > "$WHEEL_SWIFT" <<'SWIFT'
import CoreGraphics
import Foundation

// <x> <y> <ticks> <deltaPerTick>, global screen points.
let args = CommandLine.arguments
let point = CGPoint(x: Double(args[1]) ?? 0, y: Double(args[2]) ?? 0)
let ticks = Int(args[3]) ?? 10
let delta = Int32(args[4]) ?? -40

CGWarpMouseCursorPosition(point)
usleep(200_000)
for _ in 0..<ticks {
    guard let event = CGEvent(scrollWheelEvent2Source: nil, units: .pixel,
                              wheelCount: 1, wheel1: delta, wheel2: 0, wheel3: 0) else { continue }
    event.location = point
    event.post(tap: .cghidEventTap)
    usleep(25_000)
}
SWIFT

cat > "$CLICK_SWIFT" <<'SWIFT'
import CoreGraphics
import Foundation

// <x> <y> global screen points — plain left click at the cursor.
let args = CommandLine.arguments
let point = CGPoint(x: Double(args[1]) ?? 0, y: Double(args[2]) ?? 0)
CGWarpMouseCursorPosition(point)
usleep(150_000)
for type in [CGEventType.leftMouseDown, .leftMouseUp] {
    guard let e = CGEvent(mouseEventSource: nil, mouseType: type,
                          mouseCursorPosition: point, mouseButton: .left) else { continue }
    e.post(tap: .cghidEventTap)
    usleep(80_000)
}
SWIFT

cat > "$KEY_SWIFT" <<'SWIFT'
import CoreGraphics
import Foundation

// <keycode> [<keycode>...] — posts keyDown+keyUp for each.
for arg in CommandLine.arguments.dropFirst() {
    guard let code = UInt16(arg) else { continue }
    for down in [true, false] {
        guard let e = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(code),
                              keyDown: down) else { continue }
        e.post(tap: .cghidEventTap)
        usleep(60_000)
    }
    usleep(150_000)
}
SWIFT

# macOS refuses to capture a sleeping display, and an idle Mac will sleep
# mid-batch. Held only for this run.
caffeinate -d -u -t 7200 &
CAFFEINATE_PID=$!
cleanup() {
  kill "$CAFFEINATE_PID" 2>/dev/null || true
  [[ -n "${APP_PID:-}" ]] && kill "$APP_PID" 2>/dev/null || true
  rm -rf "$WORKDIR"
}
trap cleanup EXIT

# A debugger-suspended Billo (Xcode) survives kill -9 and keeps windows on
# screen; it also breaks app-name targeting. Everything below targets OUR
# instance by PID, but warn up front so a stray window doesn't end up on top.
if pgrep -fl "$APP_NAME.app/Contents/MacOS/$APP_NAME" | grep -v AppleLanguages >/dev/null 2>&1; then
  echo "WARNING: another Billo instance is running (Xcode debug session?)." >&2
  echo "         Its window can overlap the captures — stop it if shots fail." >&2
fi

# --- Build ------------------------------------------------------------------

if [[ "$SKIP_BUILD" -eq 0 ]]; then
  echo "==> building $SCHEME ($CONFIGURATION, Mac Catalyst)"
  xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration "$CONFIGURATION" \
    -destination 'platform=macOS,arch=arm64,variant=Mac Catalyst' build >/dev/null
fi

APP_PATH="$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration "$CONFIGURATION" \
  -destination 'platform=macOS,arch=arm64,variant=Mac Catalyst' -showBuildSettings 2>/dev/null \
  | awk -F' = ' '/ TARGET_BUILD_DIR = /{d=$2} / FULL_PRODUCT_NAME = /{n=$2} END{print d"/"n}')"
[[ -d "$APP_PATH" ]] || { echo "built app not found at '$APP_PATH'" >&2; exit 1; }
echo "==> app: $APP_PATH"

# --- Capture ----------------------------------------------------------------

FAILURES=()
APP_PID=""
WINDOW_ID=""

# Catalyst apps expose extra small auxiliary UINSWindows (a 500x500 offscreen
# one shows up on every launch); filter to the real standard window.
main_window_id() {
  peekaboo window list --pid "$APP_PID" --json-output 2>/dev/null | python3 -c "
import json, sys
try:
    windows = json.load(sys.stdin)['data']['windows']
except Exception:
    raise SystemExit(1)
windows = [w for w in windows
           if w.get('layer') == 0 and w.get('subrole') == 'AXStandardWindow'
           and w['bounds']['height'] > 600]
if not windows:
    raise SystemExit(1)
windows.sort(key=lambda w: -w['bounds']['width'] * w['bounds']['height'])
print(windows[0]['window_id'])
"
}

focus_app() {
  osascript -e "tell application \"System Events\" to set frontmost of (first process whose unix id is $APP_PID) to true" >/dev/null 2>&1 || true
}

# Pin origin AND size by window id, then read the bounds back. The window is
# resizable and restores its previous frame on launch, so this must both apply
# and verify — a silently ignored set-bounds yields a wrong-sized capture that
# only the bbox assertion would catch, one step too late to retry cheaply.
pin_window() {
  local attempt bounds
  for attempt in 1 2 3; do
    peekaboo window set-bounds --pid "$APP_PID" --window-id "$WINDOW_ID" \
      --x "$WIN_X" --y "$WIN_Y" --width "$WIN_W" --height "$WIN_H" >/dev/null 2>&1 || true
    sleep 1
    bounds="$(peekaboo window list --pid "$APP_PID" --json-output 2>/dev/null | python3 -c "
import json, sys
for w in json.load(sys.stdin)['data']['windows']:
    if w.get('window_id') == $WINDOW_ID:
        b = w['bounds']
        print(f\"{b['x']},{b['y']},{b['width']},{b['height']}\")
" 2>/dev/null)"
    [[ "$bounds" == "$WIN_X,$WIN_Y,$WIN_W,$WIN_H" ]] && return 0
  done
  return 1
}

launch() {
  local shot="$1" locale="$2"
  local lang region market
  lang="$(locale_language "$locale")"
  region="$(locale_region "$locale")"
  market="$(locale_market "$locale")"

  if [[ -n "$APP_PID" ]]; then
    kill "$APP_PID" 2>/dev/null || true
    sleep 1.5
  fi

  SCREENSHOT_MARKET="$market" "$APP_PATH/Contents/MacOS/$APP_NAME" \
    -AppleLanguages "($lang)" -AppleLocale "$region" \
    -billsDefaultView "$(shot_view_mode "$shot")" >/dev/null 2>&1 &
  APP_PID=$!
  disown %% 2>/dev/null || true
  sleep "$LAUNCH_SETTLE"

  kill -0 "$APP_PID" 2>/dev/null || return 1
  focus_app
  WINDOW_ID="$(main_window_id)" || return 1
  pin_window || return 1
  sleep 1
}

shoot() {
  local shot="$1" locale="$2"
  local dir png size bbox bytes
  dir="$OUT/$locale/mac"
  png="$dir/$shot.png"
  mkdir -p "$dir"

  echo "==> $locale/$shot"
  if ! launch "$shot" "$locale"; then
    FAILURES+=("$locale/$shot: app failed to launch, window not found, or bounds would not pin")
    return 0
  fi

  # An input event that lands on nothing leaves a perfectly valid capture of
  # the wrong state, and every geometry check below would still pass. Shoot
  # the pre-action frame and require the actions to have changed something.
  local before="$WORKDIR/$locale-$shot-before.png"
  screencapture -x -r -t png -l "$WINDOW_ID" "$before" 2>/dev/null || true

  shot_actions "$shot"
  sleep "$ACTION_SETTLE"

  # Capture, and re-assert focus if the shot came out at the unfocused size.
  # `set frontmost` is best-effort and loses races against whatever else just
  # activated, which yields a valid capture 44pt smaller on each axis — the
  # smaller unfocused shadow. Retrying here is cheaper than a re-run.
  local attempt
  for attempt in 1 2 3; do
    rm -f "$png"
    if ! screencapture -x -r -t png -l "$WINDOW_ID" "$png" 2>/dev/null || [[ ! -f "$png" ]]; then
      FAILURES+=("$locale/$shot: screencapture failed (display asleep or locked?)")
      return 0
    fi
    [[ "$(magick identify -format "%wx%h" "$png")" == "$EXPECT_SIZE" ]] && break
    [[ "$attempt" -eq 3 ]] && break
    echo "    (unfocused capture, re-activating — attempt $attempt)"
    focus_app
    sleep 2
  done

  bytes="$(stat -f%z "$png")"
  if [[ "$bytes" -lt "$MIN_PNG_BYTES" ]]; then
    FAILURES+=("$locale/$shot: PNG is only ${bytes}B — the window probably never rendered")
    return 0
  fi

  size="$(magick identify -format "%wx%h" "$png")"
  if [[ "$size" != "$EXPECT_SIZE" ]]; then
    FAILURES+=("$locale/$shot: is $size, expected $EXPECT_SIZE")
    return 0
  fi

  # The opaque body's offset inside the shadow differs between a focused and
  # an unfocused window, so this pins geometry and the traffic lights at once.
  bbox="$(magick "$png" -alpha extract -threshold 99% -format "%@" info:)"
  if [[ "$bbox" != "$EXPECT_BBOX" ]]; then
    FAILURES+=("$locale/$shot: window body at $bbox, expected $EXPECT_BBOX (window unfocused, moved, or resized?)")
    return 0
  fi

  if [[ -f "$before" ]]; then
    if [[ "$(shasum -a 256 "$before" | cut -d' ' -f1)" == "$(shasum -a 256 "$png" | cut -d' ' -f1)" ]]; then
      FAILURES+=("$locale/$shot: screen unchanged by its actions — a click or scroll missed")
      return 0
    fi
  fi

  echo "    -> $locale/mac/$shot.png (${bytes}B, $size)"
}

for locale in $LOCALES; do
  for shot in "${SELECTED[@]}"; do
    shoot "$shot" "$locale"
  done
done

[[ -n "$APP_PID" ]] && kill "$APP_PID" 2>/dev/null || true

echo
if [[ ${#FAILURES[@]} -gt 0 ]]; then
  echo "FAILED (${#FAILURES[@]}):" >&2
  for failure in "${FAILURES[@]}"; do echo "  - $failure" >&2; done
  exit 1
fi
echo "==> all captures OK"
