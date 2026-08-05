#!/usr/bin/env bash
#
# Captures the iPhone App Store shot set on the iPhone 17 Pro simulator,
# one locale at a time: 2-bills-list, 3-calendar, 4-bill-detail, 5-charts,
# 6-notifications (lock screen). Portrait, 1206x2622, iOS 26+ runtime
# (Liquid Glass chrome is required — an 18.x runtime makes captures unusable).
#
# Locale = language + region + market in one: the simulator's OWN
# AppleLanguages/AppleLocale are set (system chrome — lock screen, alerts —
# must be localized too, which per-app launch arguments cannot do), which
# requires a reboot per locale. The seed dataset market comes from the
# region, with SCREENSHOT_MARKET passed explicitly as well.
#
# The seed data (ScreenshotMockData) anchors every bill to the launch date
# via dueInDays offsets (0,3,6,9,…,30), so the list shape — and every tap
# coordinate — is identical across locales AND capture dates: one bill due
# today (Spotify Premium — a brand name, identical in every market, which
# the calendar closed-loop uses as its anchor), two in the next 7 days,
# the rest in the next 30.
#
# See docs/appstore-shots.md for the shot catalogue and platform traps.

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$PROJECT_DIR/Billo.xcodeproj"
SCHEME="BilloScreenshots"
CONFIGURATION="Screenshots"
BUNDLE_ID="com.jiriurbasek.Billo"
DEVICE_NAME="iPhone 17 Pro"

DEFAULT_OUT="$PROJECT_DIR/../appstore/v1.0.2/screenshots"
DEFAULT_LOCALES="en it es-ES es-MX pt-BR"

EXPECT_SIZE="1206x2622"
MIN_PNG_BYTES=200000
LAUNCH_SETTLE=6

# --- Shot catalogue ---------------------------------------------------------

SHOT_IDS=(2-bills-list 3-calendar 4-bill-detail 5-charts 6-notifications)

shot_description() {
  case "$1" in
    2-bills-list)     echo "Bills list at rest: hero card, Today, Next 7 Days, Next 30 Days" ;;
    3-calendar)       echo "Current-month grid (today circled), list with the due-today row second from the bottom" ;;
    4-bill-detail)    echo "Detail of the 6-day electricity bill (account ID, occurrences, payments)" ;;
    5-charts)         echo "Charts scrolled so Spending by Category tops the screen" ;;
    6-notifications)  echo "Lock screen with the localized digest + reminder pushes" ;;
    *)                echo "unknown shot" ;;
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

# Localized UI labels the automation needs to find. Keep in sync with
# Billo/Localizable.xcstrings.
charts_menu_label() {
  case "$1" in
    en) echo "Charts" ;; it) echo "Grafici" ;;
    es-ES|es-MX) echo "Gráficos" ;; pt-BR) echo "Gráficos" ;;
  esac
}

# Prefix of the category card's ACCESSIBILITY label (a full sentence —
# "Spending by category for July 2026. Total: …"), not the visual title.
category_card_label() {
  case "$1" in
    en) echo "Spending by category for" ;; it) echo "Spese per categoria di" ;;
    es-ES|es-MX) echo "Gastos por categoría de" ;; pt-BR) echo "Gastos por categoria de" ;;
  esac
}

# The electricity bill's name per market (= the offset-6 row). Row labels
# concatenate "N days, name, category, amount, date", so a name substring
# finds the row.
electric_bill_label() {
  case "$1" in
    en) echo "Electric Bill" ;; it) echo "Bolletta luce" ;;
    es-ES) echo "Recibo de luz" ;; es-MX) echo "Luz — CFE" ;;
    pt-BR) echo "Conta de luz" ;;
  esac
}

allow_button_label() {
  case "$1" in
    en) echo "Allow" ;; it) echo "Consenti" ;;
    es-ES|es-MX) echo "Permitir" ;; pt-BR) echo "Permitir" ;;
  esac
}

# --- Notification payload copy ----------------------------------------------
#
# Mirrors what the app actually sends (NotificationContentBuilder): a digest
# ("3 bills due in next 7 days" + one "name — amount — date" line per bill)
# and a single reminder ("<amount> is due today"). Translations match
# Billo/Localizable.xcstrings; amounts match ScreenshotMockData.

digest_title() {
  case "$1" in
    en)    echo "3 bills due in next 7 days" ;;
    it)    echo "3 bollette in scadenza nei prossimi 7 giorni" ;;
    es-ES) echo "3 recibos vencen en los próximos 7 días" ;;
    es-MX) echo "3 recibos vencen en los próximos 7 días" ;;
    pt-BR) echo "3 contas vencem nos próximos 7 dias" ;;
  esac
}

# The three upcoming bills (offsets 0, 3, 6) as "name|formatted amount".
digest_items() {
  case "$1" in
    en)    printf '%s\n' "Spotify Premium|\$11.99" "Cell Phone — Verizon|\$92.00" "Electric Bill|\$128.40" ;;
    it)    printf '%s\n' "Spotify Premium|10,99 €" "Cellulare — TIM|14,99 €" "Bolletta luce — Enel|96,40 €" ;;
    es-ES) printf '%s\n' "Spotify Premium|10,99 €" "Móvil — Vodafone|22,00 €" "Recibo de luz — Iberdrola|88,30 €" ;;
    es-MX) printf '%s\n' "Spotify Premium|\$129.00" "Celular — Telcel|\$399.00" "Luz — CFE|\$875.00" ;;
    pt-BR) printf '%s\n' "Spotify Premium|R\$ 21,90" "Celular — Claro|R\$ 59,90" "Conta de luz — Enel|R\$ 245,00" ;;
  esac
}

reminder_body() {
  case "$1" in
    en)    echo "\$11.99 is due today" ;;
    it)    echo "10,99 € scade oggi" ;;
    es-ES) echo "10,99 € vence hoy" ;;
    es-MX) echo "\$129.00 vence hoy" ;;
    pt-BR) echo "R\$ 21,90 vence hoje" ;;
  esac
}

# "MMM d"-style date for today+<offset>, per locale (CLDR abbreviations).
digest_date() {
  local locale="$1" offset="$2"
  python3 - "$locale" "$offset" <<'PY'
import sys, datetime
locale, offset = sys.argv[1], int(sys.argv[2])
d = datetime.date.today() + datetime.timedelta(days=offset)
months = {
    'en': ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'],
    'it': ['gen','feb','mar','apr','mag','giu','lug','ago','set','ott','nov','dic'],
    'es': ['ene','feb','mar','abr','may','jun','jul','ago','sep','oct','nov','dic'],
    'pt': ['jan','fev','mar','abr','mai','jun','jul','ago','set','out','nov','dez'],
}
if locale == 'en':
    print(f"{months['en'][d.month-1]} {d.day}")
elif locale.startswith('pt'):
    print(f"{d.day} de {months['pt'][d.month-1]}.")
elif locale.startswith('es'):
    print(f"{d.day} {months['es'][d.month-1]}")
else:
    print(f"{d.day} {months['it'][d.month-1]}")
PY
}

digest_payload() {
  local locale="$1" title body lines item name amt i=0
  title="$(digest_title "$locale")"
  local dates=("$(digest_date "$locale" 0)" "$(digest_date "$locale" 3)" "$(digest_date "$locale" 6)")
  lines=""
  while IFS='|' read -r name amt; do
    [[ -n "$lines" ]] && lines+="\n"
    lines+="$name — $amt — ${dates[$i]}"
    i=$((i+1))
  done < <(digest_items "$locale")
  python3 - "$title" "$(printf '%b' "$lines")" <<'PY'
import json, sys
print(json.dumps({
    "Simulator Target Bundle": "com.jiriurbasek.Billo",
    "aps": {"alert": {"title": sys.argv[1], "body": sys.argv[2]},
            "thread-id": "billo-digest", "sound": ""},
}, ensure_ascii=False))
PY
}

reminder_payload() {
  local locale="$1"
  python3 - "Spotify Premium" "$(reminder_body "$locale")" <<'PY'
import json, sys
print(json.dumps({
    "Simulator Target Bundle": "com.jiriurbasek.Billo",
    "aps": {"alert": {"title": sys.argv[1], "body": sys.argv[2]},
            "thread-id": "billo-reminder", "sound": ""},
}, ensure_ascii=False))
PY
}

# --- CLI --------------------------------------------------------------------

usage() {
  cat <<'EOF'
Capture the iPhone App Store shot set.

USAGE
  capture-appstore-iphone-shots.sh --all                     every shot, every locale
  capture-appstore-iphone-shots.sh --locales es-ES,pt-BR     only these locales
  capture-appstore-iphone-shots.sh --only 5-charts           only these shots (re-shoots)
  capture-appstore-iphone-shots.sh --list                    print the catalogue and exit

OPTIONS
  --locales <list>   comma-separated (default: en,it,es-ES,es-MX,pt-BR)
  --only <list>      comma-separated shot ids
  --out <dir>        screenshots root (default: ../appstore/v1.0.2/screenshots)
  --udid <udid>      simulator UDID (default: newest iOS 26+ "iPhone 17 Pro")
  --skip-build       reuse the already-built app
  -h, --help         this text

OUTPUT
  <out>/<locale>/iphone/<shot>.png    1206x2622 portrait PNG

Each locale reboots the simulator (system-level language switch), sets the
9:41 status bar, and captures each shot from a fresh app launch. The
6-notifications shot clears the time override (it corrupts the lock-screen
date), locks the device, and drives `simctl push` with localized payloads.
EOF
}

MODE=""
ONLY=""
LOCALES="$DEFAULT_LOCALES"
OUT=""
UDID="${IPHONE_UDID:-}"
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

for tool in axe python3 magick xcodebuild xcrun; do
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

WORKDIR="$(mktemp -d -t billo-iphone-shots)"
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
  # Editing the plist while the device is shut down is the reliable path
  # (defaults-write via spawn requires a booted device and races the reboot).
  local prefs="$HOME/Library/Developer/CoreSimulator/Devices/$UDID/data/Library/Preferences/.GlobalPreferences.plist"
  /usr/libexec/PlistBuddy -c "Delete :AppleLanguages" "$prefs" >/dev/null 2>&1 || true
  /usr/libexec/PlistBuddy -c "Add :AppleLanguages array" "$prefs"
  /usr/libexec/PlistBuddy -c "Add :AppleLanguages:0 string $lang" "$prefs"
  /usr/libexec/PlistBuddy -c "Delete :AppleLocale" "$prefs" >/dev/null 2>&1 || true
  /usr/libexec/PlistBuddy -c "Add :AppleLocale string $region" "$prefs"

  xcrun simctl bootstatus "$UDID" -b >/dev/null
  sleep 3
  # Uninstall first: delivered notifications persist per install, so an
  # earlier locale's pushes would otherwise stack into the new locale's
  # lock-screen shot as "Spotify Premium N notifications". The permission
  # alert re-appears after reinstall — the shot flow taps the localized
  # Allow button.
  xcrun simctl uninstall "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
  xcrun simctl install "$UDID" "$APP_PATH"
  set_status_bar
}

set_status_bar() {
  xcrun simctl status_bar "$UDID" override --time "9:41" \
    --dataNetwork wifi --wifiMode active --wifiBars 3 \
    --cellularMode active --cellularBars 4 \
    --batteryState charged --batteryLevel 100 >/dev/null 2>&1 || true
}

launch_app() {
  local locale="$1" view="$2"; shift 2
  local market
  market="$(locale_market "$locale")"
  SIMCTL_CHILD_SCREENSHOT_MARKET="$market" xcrun simctl launch --terminate-running-process \
    "$UDID" "$BUNDLE_ID" -billsDefaultView "$view" "$@" >/dev/null
  sleep "$LAUNCH_SETTLE"
}

capture() {
  local png="$1"
  xcrun simctl io "$UDID" screenshot --type png "$png" >/dev/null 2>&1
}

# Prints "label|x|y|w|h" lines for every labeled element, walking the whole
# describe-ui tree.
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

# element_center <label substring> — "x y" center (points) of the FIRST
# match in document order. First matters: lazy lists materialize rows well
# past the viewport, and later sections repeat the same bill names (the
# bills list "Later" section, the calendar's next month).
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

element_center_y() {
  local center
  center="$(element_center "$1")" || return 1
  echo "${center#* }"
}

tap_element() {
  local needle="$1" center
  center="$(element_center "$needle")" || return 1
  axe tap -x "${center%% *}" -y "${center#* }" --udid "$UDID" >/dev/null 2>&1
}

# Exact whole-label match — REQUIRED for the notification Allow button:
# pt-BR's deny button is "Não Permitir" (capital P), so a substring match
# for "Permitir" taps DENY first.
element_center_exact() {
  local label="$1"
  ui_elements | python3 -c "
import sys
label = sys.argv[1]
for line in sys.stdin:
    parts = line.rstrip('\n').split('|')
    if len(parts) == 5 and parts[0] == label:
        print(int(float(parts[1]) + float(parts[3]) / 2), int(float(parts[2]) + float(parts[4]) / 2))
        break
else:
    raise SystemExit(1)
" "$label"
}

tap_element_exact() {
  local label="$1" center
  center="$(element_center_exact "$label")" || return 1
  axe tap -x "${center%% *}" -y "${center#* }" --udid "$UDID" >/dev/null 2>&1
}

# Scrolls the view so the element sits at target y. Swipe distances are
# damped (0.85) and slow (1.2 s) to defeat momentum; iterates to converge.
scroll_element_to_y() {
  local needle="$1" target="$2" attempt y delta
  for attempt in 1 2 3 4 5; do
    y="$(element_center_y "$needle")" || return 1
    delta=$(( target - y ))
    [[ "${delta#-}" -le 25 ]] && return 0
    local move=$(( delta * 85 / 100 ))
    axe swipe --start-x 200 --start-y 450 --end-x 200 --end-y $((450 + move)) \
      --duration 1.2 --post-delay 0.6 --udid "$UDID" >/dev/null 2>&1
    sleep 1.5
  done
  y="$(element_center_y "$needle")" || return 1
  [[ "$(( target - y ))" -le 60 && "$(( y - target ))" -le 60 ]]
}

# The due-today row is the only one with a SALMON left accent bar (paid
# history is green, upcoming is orange, the today pill is amber and starts
# further right) — the same locale-independent anchor the Mac script uses.
# Prints the bar's topmost visible y in points. Top, not center: the target
# framing clips the row at the screen bottom, and a clipped run's center
# moves while its top stays put.
find_due_today_bar_top() {
  capture "$WORKDIR/gutter.png" || return 1
  magick "$WORKDIR/gutter.png" -crop "8x2622+14+0" +repage -resize "1x874!" -depth 8 txt:- 2>/dev/null \
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

# Scrolls the calendar list until the due-today row starts at ~811 pt —
# the today pill and the month's paid history above it, the row itself
# clipped by the screen bottom, mirroring the reference design frame.
DUE_TODAY_BAR_TARGET=811
position_due_today_row() {
  local y diff attempt
  # The list starts at the top of the previous month's history — the row
  # can be 3000+ pt down. Page in 450 pt steps until its bar shows up.
  for attempt in 1 2 3 4 5 6 7 8 9 10 11 12; do
    y="$(find_due_today_bar_top)" && break
    axe swipe --start-x 200 --start-y 700 --end-x 200 --end-y 250 \
      --duration 1.2 --post-delay 0.6 --udid "$UDID" >/dev/null 2>&1
    sleep 1.5
  done
  [[ -n "${DEBUG_SHOTS:-}" ]] && echo "    [debug] coarse: attempts=$attempt y=${y:-none}" >&2
  [[ -z "${y:-}" ]] && return 1
  for attempt in 1 2 3 4 5 6 7 8; do
    diff=$(( DUE_TODAY_BAR_TARGET - y ))
    # Sub-45pt swipes are eaten whole by touch slop (verified: eight 28 pt
    # swipes in a row moved the list 0 pt) — accept within 40 and never
    # swipe less than 45; a slight overshoot lands inside the tolerance.
    [[ "${diff#-}" -le 40 ]] && return 0
    local move=$(( diff * 85 / 100 ))
    if [[ "$move" -gt 0 && "$move" -lt 45 ]]; then move=45; fi
    if [[ "$move" -lt 0 && "$move" -gt -45 ]]; then move=-45; fi
    axe swipe --start-x 200 --start-y 450 --end-x 200 --end-y $((450 + move)) \
      --duration 1.2 --post-delay 0.6 --udid "$UDID" >/dev/null 2>&1
    sleep 1.5
    y="$(find_due_today_bar_top)" \
      || { [[ -n "${DEBUG_SHOTS:-}" ]] && echo "    [debug] fine: attempt=$attempt bar LOST after move=$move" >&2; return 1; }
    [[ -n "${DEBUG_SHOTS:-}" ]] && echo "    [debug] fine: attempt=$attempt y=$y move=$move" >&2
  done
  return 1
}

# --- Shots ------------------------------------------------------------------

shoot() {
  local shot="$1" locale="$2"
  local dir png
  dir="$OUT/$locale/iphone"
  png="$dir/$shot.png"
  mkdir -p "$dir"

  echo "==> $locale/$shot"

  case "$shot" in
    2-bills-list)
      launch_app "$locale" list
      ;;

    3-calendar)
      launch_app "$locale" calendar
      position_due_today_row \
        || { FAILURES+=("$locale/$shot: could not position the due-today row"); return 0; }
      ;;

    4-bill-detail)
      launch_app "$locale" list
      # Electricity bill = the offset-6 row (second "Next 7 Days" row).
      local before="$WORKDIR/$locale-$shot-before.png"
      capture "$before"
      tap_element "$(electric_bill_label "$locale")" \
        || { FAILURES+=("$locale/$shot: electricity row not found"); return 0; }
      sleep 2.5
      ;;

    5-charts)
      launch_app "$locale" list
      # Charts lives in the top-left more menu (toolbar buttons are
      # invisible to describe-ui — fixed coords); menu ITEMS are exposed
      # by label once the menu is open.
      axe tap -x 38 -y 84 --udid "$UDID" >/dev/null 2>&1
      sleep 1.5
      tap_element "$(charts_menu_label "$locale")" \
        || { FAILURES+=("$locale/$shot: Charts menu item not found"); return 0; }
      sleep 2.5
      # Card is ~230 pt tall; centering it at 245 puts its top right under
      # the toolbar (~130), with on-time + trend header below — the EN
      # reference framing.
      scroll_element_to_y "$(category_card_label "$locale")" 245 \
        || { FAILURES+=("$locale/$shot: could not frame the category card"); return 0; }
      ;;

    6-notifications)
      # The 9:41 override corrupts the lock-screen date (renders as Jan 1) —
      # clear it for this shot only.
      xcrun simctl status_bar "$UDID" clear >/dev/null 2>&1 || true
      launch_app "$locale" list -screenshotRealNotifications
      # First run per install: authorization alert. Permission persists.
      if tap_element_exact "$(allow_button_label "$locale")"; then
        sleep 1.5
      fi
      axe button lock --udid "$UDID" >/dev/null 2>&1
      sleep 2
      # Newest push renders as the full card — send the reminder first so
      # the digest ends up expanded on top.
      # Distinct thread-ids keep iOS from stacking them into one card.
      reminder_payload "$locale" > "$WORKDIR/reminder.json"
      digest_payload "$locale" > "$WORKDIR/digest.json"
      xcrun simctl push "$UDID" "$WORKDIR/reminder.json" >/dev/null 2>&1
      sleep 1.5
      xcrun simctl push "$UDID" "$WORKDIR/digest.json" >/dev/null 2>&1
      sleep 3
      # Reveal BOTH cards fully (the reminder otherwise renders compact
      # under the digest): a short upward drag scrolls the stack — but ONLY
      # when the display wakes from true sleep. On the push-woken (dimmed
      # but awake) lock screen the same drag is swallowed, no matter how
      # long the stack has settled (verified: 2.5 s, 7 s, 15 s, 35 s all
      # fail). So: press lock once more to put the display to SLEEP, then
      # drag — the drag wakes it and scrolls in one gesture. The trailing
      # sleep lets the "Swipe up to open" hint fade back out.
      axe button lock --udid "$UDID" >/dev/null 2>&1
      sleep 2
      axe swipe --start-x 200 --start-y 700 --end-x 200 --end-y 620 \
        --duration 0.8 --post-delay 0.5 --udid "$UDID" >/dev/null 2>&1
      sleep 8
      ;;
  esac

  if ! capture "$png" || [[ ! -f "$png" ]]; then
    FAILURES+=("$locale/$shot: screenshot failed")
    return 0
  fi

  # 6-notifications leaves the device locked and the status bar bare; put
  # both back for whatever runs next.
  if [[ "$shot" == "6-notifications" ]]; then
    axe button lock --udid "$UDID" >/dev/null 2>&1 || true
    set_status_bar
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

  if [[ "$shot" == "4-bill-detail" && -f "$WORKDIR/$locale-$shot-before.png" ]]; then
    if [[ "$(shasum -a 256 "$WORKDIR/$locale-$shot-before.png" | cut -d' ' -f1)" == "$(shasum -a 256 "$png" | cut -d' ' -f1)" ]]; then
      FAILURES+=("$locale/$shot: screen unchanged — the detail tap missed")
      return 0
    fi
  fi

  echo "    -> $locale/iphone/$shot.png (${bytes}B, $size)"
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
