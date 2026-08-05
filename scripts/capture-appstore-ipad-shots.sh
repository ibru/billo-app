#!/usr/bin/env bash
#
# Captures the iPad App Store shot set on the iPad (A16) simulator in
# LANDSCAPE: 2-bills-list, 3-calendar, 4-bill-detail, 5-charts — the same
# states and file names as the Mac set, with a bill ALWAYS selected in the
# detail pane. Output 2360x1640, iOS 26+ runtime (Liquid Glass required).
#
# Landscape on a headless simulator is its own minefield (all verified):
#   - simctl/AXe cannot rotate a simulator, and Simulator.app menu clicks
#     don't work windowless. The Screenshots build config sets
#     INFOPLIST_KEY_UIRequiresFullScreen + an orientation-mask delegate, so
#     the `-screenshotLandscape` launch argument locks the app landscape.
#   - The FRAMEBUFFER stays portrait — captures need `sips -r 270`.
#   - describe-ui returns app-space (landscape) coordinates, but taps and
#     swipes take DEVICE-portrait coordinates: dev_x = 820 - app_y,
#     dev_y = app_x (iPad A16 is 820x1180 pt portrait).
#   - iPadOS 26 launches apps WINDOWED on the home screen by default, which
#     breaks everything (describe-ui sees only DockFolderViewService). Fix
#     ONCE per simulator: Settings -> Multitasking & Gestures -> Full
#     Screen Apps. The script detects the windowed state and tells you.
#
# Locale switching, seed-data shape, and the closed-loop due-today-row
# anchor are identical to capture-appstore-iphone-shots.sh — see that
# script and docs/appstore-shots.md.

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$PROJECT_DIR/Billo.xcodeproj"
SCHEME="BilloScreenshots"
CONFIGURATION="Screenshots"
BUNDLE_ID="com.jiriurbasek.Billo"
DEVICE_NAME="iPad (A16)"

DEFAULT_OUT="$PROJECT_DIR/../appstore/v1.0.2/screenshots"
DEFAULT_LOCALES="en it es-ES es-MX pt-BR"

EXPECT_SIZE="2360x1640"
MIN_PNG_BYTES=200000
LAUNCH_SETTLE=7

# Device-portrait width in points; the app-space -> device-space transform
# pivots on it.
DEVICE_PORTRAIT_WIDTH=820

# --- Shot catalogue ---------------------------------------------------------

SHOT_IDS=(2-bills-list 3-calendar 4-bill-detail 5-charts)

shot_description() {
  case "$1" in
    2-bills-list)  echo "Split view, bills list at rest (hero card visible), due-today bill selected" ;;
    3-calendar)    echo "Current-month grid (today circled), list with the due-today row second from the bottom and selected" ;;
    4-bill-detail) echo "Same sidebar at rest, the 6-day electricity bill selected" ;;
    5-charts)      echo "Charts detail scrolled so Spending by Category tops the pane, sidebar at top" ;;
    *)             echo "unknown shot" ;;
  esac
}

locale_language() {
  case "$1" in
    en) echo "en" ;; it) echo "it" ;;
    es-ES|es-MX) echo "es" ;;
    pt-BR) echo "pt-BR" ;;
    *) echo "$1" ;;
  esac
}

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

charts_menu_label() {
  case "$1" in
    en) echo "Charts" ;; it) echo "Grafici" ;;
    es-ES|es-MX) echo "Gráficos" ;; pt-BR) echo "Gráficos" ;;
  esac
}

category_card_label() {
  case "$1" in
    en) echo "Spending by category for" ;; it) echo "Spese per categoria di" ;;
    es-ES|es-MX) echo "Gastos por categoría de" ;; pt-BR) echo "Gastos por categoria de" ;;
  esac
}

electric_bill_label() {
  case "$1" in
    en) echo "Electric Bill" ;; it) echo "Bolletta luce" ;;
    es-ES) echo "Recibo de luz" ;; es-MX) echo "Luz — CFE" ;;
    pt-BR) echo "Conta de luz" ;;
  esac
}

# The due-today bill is Spotify Premium in every market (brand name, never
# translated) — the offset-0 row in the bills list.
DUE_TODAY_LABEL="Spotify Premium"

# --- CLI --------------------------------------------------------------------

usage() {
  cat <<'EOF'
Capture the iPad App Store shot set (landscape).

USAGE
  capture-appstore-ipad-shots.sh --all                     every shot, every locale
  capture-appstore-ipad-shots.sh --locales es-ES,pt-BR     only these locales
  capture-appstore-ipad-shots.sh --only 5-charts           only these shots (re-shoots)
  capture-appstore-ipad-shots.sh --list                    print the catalogue and exit

OPTIONS
  --locales <list>   comma-separated (default: en,it,es-ES,es-MX,pt-BR)
  --only <list>      comma-separated shot ids
  --out <dir>        screenshots root (default: ../appstore/v1.0.2/screenshots)
  --udid <udid>      simulator UDID (default: newest iOS 26+ "iPad (A16)")
  --skip-build       reuse the already-built app
  -h, --help         this text

OUTPUT
  <out>/<locale>/ipad/<shot>.png      2360x1640 landscape PNG (sips-rotated)

One-time simulator prep: Settings -> Multitasking & Gestures -> Full Screen
Apps (iPadOS 26 otherwise launches the app windowed and automation breaks;
the script detects this and aborts the locale).
EOF
}

MODE=""
ONLY=""
LOCALES="$DEFAULT_LOCALES"
OUT=""
UDID="${IPAD_UDID:-}"
SKIP_BUILD=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all)        MODE="all"; shift ;;
    --only)       MODE="all"; ONLY="${2:?--only needs a comma-separated shot list}"; shift 2 ;;
    --locales)    LOCALES="$(echo "${2:?--locales needs a comma-separated list}" | tr ',' ' ')"; shift 2 ;;
    --list)       MODE="list"; shift ;;
    --out)        OUT="${2:?--out needs a directory}"; shift 2 ;;
    --udid)       UDID="${2:?--udid needs a simulator UDID}"; shift 2 ;;
    --skip-build) SKIP_BUILD=1; shift ;;
    -h|--help)    usage; exit 0 ;;
    *)            echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

[[ -z "$MODE" ]] && { usage >&2; exit 2; }

if [[ "$MODE" == "list" ]]; then
  printf '%-16s  %s\n' ID DESCRIPTION
  for id in "${SHOT_IDS[@]}"; do
    printf '%-16s  %s\n' "$id" "$(shot_description "$id")"
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

for tool in axe python3 magick sips xcodebuild xcrun; do
  command -v "$tool" >/dev/null 2>&1 || { echo "required tool '$tool' is not on PATH" >&2; exit 1; }
done

if [[ -z "$UDID" ]]; then
  UDID="$(xcrun simctl list devices available -j | python3 -c "
import json, sys
data = json.load(sys.stdin)
best = None
for runtime, devices in data['devices'].items():
    if 'iOS' not in runtime:
        continue
    version = runtime.split('iOS-')[-1].replace('-', '.')
    if int(version.split('.')[0]) < 26:
        continue
    for device in devices:
        if device['name'] == '$DEVICE_NAME':
            key = tuple(int(p) for p in version.split('.'))
            if best is None or key > best[0]:
                best = (key, device['udid'])
if best is None:
    raise SystemExit(1)
print(best[1])
")" || { echo "no iOS 26+ '$DEVICE_NAME' simulator found" >&2; exit 1; }
fi
echo "==> simulator: $UDID"

OUT="${OUT:-$DEFAULT_OUT}"
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"
echo "==> output: $OUT"

WORKDIR="$(mktemp -d -t billo-ipad-shots)"
cleanup() { rm -rf "$WORKDIR"; }
trap cleanup EXIT

# --- Build ------------------------------------------------------------------

if [[ "$SKIP_BUILD" -eq 0 ]]; then
  echo "==> building $SCHEME ($CONFIGURATION, iOS Simulator)"
  xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration "$CONFIGURATION" \
    -destination "platform=iOS Simulator,name=$DEVICE_NAME,OS=latest" build >/dev/null
fi

APP_PATH="$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration "$CONFIGURATION" \
  -destination "platform=iOS Simulator,name=$DEVICE_NAME,OS=latest" -showBuildSettings 2>/dev/null \
  | awk -F' = ' '/ TARGET_BUILD_DIR = /{d=$2} / FULL_PRODUCT_NAME = /{n=$2} END{print d"/"n}')"
[[ -d "$APP_PATH" ]] || { echo "built app not found at '$APP_PATH'" >&2; exit 1; }
echo "==> app: $APP_PATH"

# --- Simulator helpers ------------------------------------------------------

FAILURES=()

boot_locale() {
  local locale="$1"
  local lang region
  lang="$(locale_language "$locale")"
  region="$(locale_region "$locale")"

  echo "==> $locale: rebooting simulator as $lang / $region"
  xcrun simctl shutdown "$UDID" >/dev/null 2>&1 || true
  local prefs="$HOME/Library/Developer/CoreSimulator/Devices/$UDID/data/Library/Preferences/.GlobalPreferences.plist"
  /usr/libexec/PlistBuddy -c "Delete :AppleLanguages" "$prefs" >/dev/null 2>&1 || true
  /usr/libexec/PlistBuddy -c "Add :AppleLanguages array" "$prefs"
  /usr/libexec/PlistBuddy -c "Add :AppleLanguages:0 string $lang" "$prefs"
  /usr/libexec/PlistBuddy -c "Delete :AppleLocale" "$prefs" >/dev/null 2>&1 || true
  /usr/libexec/PlistBuddy -c "Add :AppleLocale string $region" "$prefs"

  xcrun simctl bootstatus "$UDID" -b >/dev/null
  sleep 3
  xcrun simctl install "$UDID" "$APP_PATH"
  xcrun simctl status_bar "$UDID" override --time "9:41" \
    --dataNetwork wifi --wifiMode active --wifiBars 3 \
    --batteryState charged --batteryLevel 100 >/dev/null 2>&1 || true
}

launch_app() {
  local locale="$1" view="$2"
  local market
  market="$(locale_market "$locale")"
  SIMCTL_CHILD_SCREENSHOT_MARKET="$market" xcrun simctl launch --terminate-running-process \
    "$UDID" "$BUNDLE_ID" -billsDefaultView "$view" -screenshotLandscape >/dev/null
  sleep "$LAUNCH_SETTLE"
}

# Raw portrait-framebuffer capture, rotated to landscape.
capture_landscape() {
  local png="$1"
  xcrun simctl io "$UDID" screenshot --type png "$WORKDIR/raw.png" >/dev/null 2>&1 || return 1
  sips -r 270 "$WORKDIR/raw.png" --out "$png" >/dev/null 2>&1
}

# App-space (landscape) tap: dev_x = 820 - app_y, dev_y = app_x.
tap_app() {
  local x="$1" y="$2"
  axe tap -x "$((DEVICE_PORTRAIT_WIDTH - y))" -y "$x" --udid "$UDID" >/dev/null 2>&1
}

# App-space vertical swipe at app-x 200: from app-y y1 to app-y y2. The
# post-delay holds the finger at the end point before lifting — release
# velocity zero, NO momentum — so scroll distances are exact and paging
# can never jump over the row the closed loop is looking for.
swipe_app_vertical() {
  local x="$1" y1="$2" y2="$3"
  axe swipe --start-x "$((DEVICE_PORTRAIT_WIDTH - y1))" --start-y "$x" \
    --end-x "$((DEVICE_PORTRAIT_WIDTH - y2))" --end-y "$x" \
    --duration 1.2 --post-delay 0.6 --udid "$UDID" >/dev/null 2>&1
}

ui_elements() {
  axe describe-ui --udid "$UDID" 2>/dev/null | python3 -c "
import json, sys

def walk(node):
    if isinstance(node, dict):
        label = node.get('AXLabel') or node.get('label')
        frame = node.get('frame') or {}
        if label and frame.get('width'):
            print(f\"{label}|{frame['x']}|{frame['y']}|{frame['width']}|{frame['height']}\")
        for value in node.values():
            walk(value)
    elif isinstance(node, list):
        for item in node:
            walk(item)

walk(json.load(sys.stdin))
"
}

# App-space center of the FIRST label match (lazy lists materialize rows
# past the viewport, and later sections repeat bill names).
element_center() {
  local needle="$1"
  ui_elements | python3 -c "
import sys
needle = sys.argv[1]
for line in sys.stdin:
    parts = line.rstrip('\n').split('|')
    if len(parts) == 5 and needle in parts[0]:
        print(int(float(parts[1]) + float(parts[3]) / 2), int(float(parts[2]) + float(parts[4]) / 2))
        break
else:
    raise SystemExit(1)
" "$needle"
}

tap_element() {
  local needle="$1" center
  center="$(element_center "$needle")" || return 1
  tap_app "${center%% *}" "${center#* }"
}

# Guard against iPadOS 26 windowed launches (Full Screen Apps disabled):
# a windowed app's tree has no full-width Billo root.
assert_fullscreen() {
  ui_elements | grep -q "^Billo|" && return 0
  return 1
}

# The due-today row's SALMON accent bar in the sidebar gutter of the
# ROTATED capture (locale-independent anchor; same rule as the iPhone and
# Mac scripts). Prints the bar's topmost y in app-space points.
find_due_today_bar_top() {
  capture_landscape "$WORKDIR/gutter.png" || return 1
  magick "$WORKDIR/gutter.png" -crop "4x1640+28+0" +repage -resize "1x820!" -depth 8 txt:- 2>/dev/null \
    | python3 -c "
import sys, re
ys = []
for line in sys.stdin:
    m = re.match(r'0,(\d+):\s*\((\d+),(\d+),(\d+)', line)
    if not m:
        continue
    y, r, g, b = map(int, m.groups())
    if r > 210 and r - g >= 70 and abs(g - b) <= 25:
        ys.append(y)
if not ys:
    raise SystemExit(1)
print(min(ys))
"
}

# Scrolls the calendar list until the due-today row sits second from the
# bottom of the 820 pt viewport, then leaves its position in TODAY_ROW_Y.
DUE_TODAY_BAR_TARGET=660
TODAY_ROW_Y=""
position_due_today_row() {
  local y diff attempt
  # Small pages: the sticky month headers pin over the list, leaving only
  # ~300 pt of actually visible rows under the grid — a bigger page can
  # step clean over the due-today row between two checks.
  for attempt in $(seq 1 24); do
    y="$(find_due_today_bar_top)" && break
    swipe_app_vertical 200 550 350
    sleep 1.2
  done
  [[ -z "${y:-}" ]] && return 1
  local move
  for attempt in 1 2 3 4 5 6 7 8; do
    diff=$(( DUE_TODAY_BAR_TARGET - y ))
    # Sub-45pt swipes are eaten whole by touch slop — accept within 40 and
    # never swipe less than 45; a slight overshoot lands inside tolerance.
    [[ "${diff#-}" -le 40 ]] && { TODAY_ROW_Y="$y"; return 0; }
    move=$(( diff * 85 / 100 ))
    if [[ "$move" -gt 0 && "$move" -lt 45 ]]; then move=45; fi
    if [[ "$move" -lt 0 && "$move" -gt -45 ]]; then move=-45; fi
    swipe_app_vertical 200 450 $(( 450 + move ))
    sleep 1.5
    y="$(find_due_today_bar_top)" || return 1
  done
  return 1
}

# Scrolls the charts detail pane so the element's center reaches target y.
scroll_element_to_y() {
  local needle="$1" target="$2" swipe_x="$3" attempt y diff
  for attempt in 1 2 3 4 5; do
    y="$(element_center "$needle")" || return 1
    y="${y#* }"
    diff=$(( target - y ))
    [[ "${diff#-}" -le 30 ]] && return 0
    swipe_app_vertical "$swipe_x" 400 $(( 400 + diff * 85 / 100 ))
    sleep 1.5
  done
  y="$(element_center "$needle")" || return 1
  y="${y#* }"
  [[ "$(( target - y ))" -le 60 && "$(( y - target ))" -le 60 ]]
}

# --- Shots ------------------------------------------------------------------

shoot() {
  local shot="$1" locale="$2"
  local dir png
  dir="$OUT/$locale/ipad"
  png="$dir/$shot.png"
  mkdir -p "$dir"

  echo "==> $locale/$shot"

  local view="list"
  [[ "$shot" == "3-calendar" ]] && view="calendar"
  launch_app "$locale" "$view"

  if ! assert_fullscreen; then
    FAILURES+=("$locale/$shot: app launched WINDOWED — enable Settings → Multitasking & Gestures → Full Screen Apps on this simulator once")
    return 0
  fi

  local before="$WORKDIR/$locale-$shot-before.png"
  capture_landscape "$before" || true

  case "$shot" in
    2-bills-list)
      tap_element "$DUE_TODAY_LABEL" \
        || { FAILURES+=("$locale/$shot: due-today row not found"); return 0; }
      sleep 2
      ;;
    4-bill-detail)
      tap_element "$(electric_bill_label "$locale")" \
        || { FAILURES+=("$locale/$shot: electricity row not found"); return 0; }
      sleep 2
      ;;
    3-calendar)
      position_due_today_row \
        || { FAILURES+=("$locale/$shot: could not position the due-today row"); return 0; }
      tap_app 200 "$(( TODAY_ROW_Y + 25 ))"
      sleep 2
      ;;
    5-charts)
      # Sidebar more-menu at app-space (40,54); items exposed once open.
      tap_app 40 54
      sleep 1.5
      tap_element "$(charts_menu_label "$locale")" \
        || { FAILURES+=("$locale/$shot: Charts menu item not found"); return 0; }
      sleep 2.5
      # Swipe inside the detail pane (app-x ~700), not the sidebar.
      scroll_element_to_y "$(category_card_label "$locale")" 250 700 \
        || { FAILURES+=("$locale/$shot: could not frame the category card"); return 0; }
      ;;
  esac

  if ! capture_landscape "$png" || [[ ! -f "$png" ]]; then
    FAILURES+=("$locale/$shot: screenshot failed")
    return 0
  fi

  local bytes size
  bytes="$(stat -f%z "$png")"
  if [[ "$bytes" -lt "$MIN_PNG_BYTES" ]]; then
    FAILURES+=("$locale/$shot: PNG is only ${bytes}B")
    return 0
  fi
  size="$(magick identify -format "%wx%h" "$png")"
  if [[ "$size" != "$EXPECT_SIZE" ]]; then
    FAILURES+=("$locale/$shot: is $size, expected $EXPECT_SIZE")
    return 0
  fi

  if [[ -f "$before" ]]; then
    if [[ "$(shasum -a 256 "$before" | cut -d' ' -f1)" == "$(shasum -a 256 "$png" | cut -d' ' -f1)" ]]; then
      FAILURES+=("$locale/$shot: screen unchanged by its actions — a tap or swipe missed")
      return 0
    fi
  fi

  echo "    -> $locale/ipad/$shot.png (${bytes}B, $size)"
}

for locale in $LOCALES; do
  boot_locale "$locale"
  for shot in "${SELECTED[@]}"; do
    shoot "$shot" "$locale"
  done
done

echo
if [[ ${#FAILURES[@]} -gt 0 ]]; then
  echo "FAILED (${#FAILURES[@]}):" >&2
  for failure in "${FAILURES[@]}"; do echo "  - $failure" >&2; done
  exit 1
fi
echo "==> all captures OK"
