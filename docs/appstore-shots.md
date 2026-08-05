# App Store shot catalogue

The exact screen states the App Store screenshot designs need, per device, so a
re-capture for a new locale lands the same pixels as the existing set. Companion to
`ai-rules/localization.md` (Phase 5 drives the capture → Figma flow). Modeled on the
same playbook in the Savemo repo (`../Savemo/savemo-app/docs/appstore-shots.md`),
which pioneered the macOS pipeline.

Captures land in `../appstore/v<version>/screenshots/<locale>/<device>/<name>.png`
and are consumed by the Figma Shot Localizer `job*.json` image rules.

## Devices & scripts

| Device | Simulator / host | Pixels | Script |
|---|---|---|---|
| iPhone | iPhone 17 Pro, **iOS 26+**, portrait | 1206 × 2622 | `scripts/capture-appstore-iphone-shots.sh` |
| iPad | iPad (A16), **iOS 26+**, landscape | 2360 × 1640 | `scripts/capture-appstore-ipad-shots.sh` |
| macOS | Mac Catalyst on the host Mac | 2080 × 1808 raw (window 928×792 + shadow) | `scripts/capture-appstore-mac-shots.sh` |

All three: `--all` for the full locale set, `--only <shot>` / `--locales <list>`
for re-shoots, `--list` for the catalogue, `--skip-build` to reuse a build.
Liquid Glass chrome is required on iOS — an 18.x runtime makes a capture unusable.
Every run uses the `Screenshots` build configuration (the `SCREENSHOTS` flag seeds
the in-memory demo data) and light appearance; iOS runs pin the status bar to 9:41
(cleared for the lock-screen shot — the override corrupts the lock-screen date).

## The dataset shape (evergreen AND capture-date-invariant)

`ScreenshotMockData` anchors every bill to the launch date via `dueInDays`
offsets — one shared spread (0, 3, 6, 9, 11, 13, 16, 18, 23, 25, 27, 30) across
all market datasets. Every capture, on any date, in any locale, renders the same
bills-list shape:

- **Today** — exactly one bill: **Spotify Premium** (offset 0; a brand name,
  identical in every market — the automation's universal due-today anchor).
- **Next 7 Days** — two bills: the cell-phone bill (3) and the electricity
  bill (6).
- **Next 30 Days** — everything else (9…30), plus the yearly Amazon Prime (11).

Amounts, dates, and month names still follow the capture date and locale, so
shots stay evergreen. Incomes: en/es-MX pay a biweekly-Friday paycheck (it lands
ON today only when the capture day is a Friday — the calendar shot's today group
then has an extra income row; the closed-loop positioning absorbs this), the
other markets pay monthly via the same offset mechanism.

## Shot states (all devices share the same story)

| Shot | State |
|---|---|
| `2-bills-list` | Bills list **at rest — never scrolled**: the hero summary card (This Week / This Month) fully visible, then Today + Next 7 Days (+ Next 30 Days as space allows). iPad/Mac: the due-today bill selected in the detail pane ("Due Today" banner). |
| `3-calendar` | Current-month grid with today circled; the list scrolled so the **due-today row sits second from the bottom** (its row clipped by the bottom edge on iPhone) — the month's paid history and the today pill above it. iPad/Mac: the due-today row selected. |
| `4-bill-detail` | The **electricity bill** (offset 6 — the richest detail: account ID). iPhone: full detail screen. iPad/Mac: sidebar at rest, electricity row selected. |
| `5-charts` | Charts scrolled so **Spending by Category tops the pane**, with On-Time Payments and the 6-Month Trend header below. |
| `6-notifications` (iPhone only) | Lock screen, real (non-9:41) time: localized digest push expanded ("3 bills due in next 7 days" + name — amount — date lines) with the compact due-today reminder beneath. |

**Do not scroll the bills list in any shot** — an older set had it scrolled to the
bottom sections; the hero card must stay visible (user decision, 2026-07-31).

## How the closed loops work (all three scripts)

- **Due-today row anchor**: the due-today row is the only row whose left accent
  bar is SALMON (paid history = green, upcoming = orange/amber, today pill =
  amber but offset right). The scripts scan the sidebar/list gutter column of a
  capture for `r>210 && r−g≥70 && |g−b|≤25` and scroll until the bar reaches the
  target position — locale-independent, layout-independent. (Label matching is
  NOT reliable here: "Spotify Premium" also appears in the previous month's paid
  history and next month's upcoming rows.)
- **Charts framing**: find the category card by its ACCESSIBILITY label prefix
  (a full sentence — "Spending by category for …", localized per market, mapped
  in the scripts), scroll its center to the target y.
- **Menus**: toolbar buttons are invisible to describe-ui — fixed coordinates
  (iPhone more-menu (38,84); iPad app-space (40,54)); menu ITEMS are exposed by
  label once open ("Charts"/"Grafici"/"Gráficos").

## iPhone — 5 captures

Fully scripted: `scripts/capture-appstore-iphone-shots.sh --all`. Per locale the
script reboots the simulator with system-level `AppleLanguages`/`AppleLocale`
(the lock screen and permission alerts must be localized too — per-app launch
args can't do that; plist edited while shut down, then `bootstatus -b`), installs
the app, pins the 9:41 status bar, and drives each shot from a fresh launch
(`--terminate-running-process` re-seeds the in-memory store).

Gotchas the script already handles:
- **AXe swipes MUST pass `--post-delay 0.6`** (finger held at the endpoint before
  lifting → zero release velocity → no momentum). Without it, scroll distances
  are unpredictable and paging jumps clean over the row the closed loop wants.
- Row a11y labels concatenate "N days, name, category, amount, date" — a name
  substring finds a row; take the FIRST match in document order (lazy lists
  materialize rows past the viewport; later sections repeat the same names).
- `6-notifications`: clear the status-bar override first (a time override makes
  the lock-screen date render as Jan 1); `-screenshotRealNotifications` launch,
  tap the localized Allow button when the authorization alert appears;
  `axe button lock`; push the REMINDER first, then the digest — the newest push
  renders expanded on top. Distinct `thread-id`s or iOS stacks them into one
  card. Payload copy lives in the script and mirrors
  `NotificationContentBuilder` + `Localizable.xcstrings` — keep in sync.
- **Revealing BOTH cards fully** (the reminder otherwise renders compact): a
  short upward drag (~80 pt) scrolls the notification stack — but ONLY when
  the display wakes from true sleep. On the push-woken (dimmed-but-awake)
  lock screen the same drag is swallowed no matter how long the stack has
  settled (verified at 2.5/7/15/35 s). Press lock once more to put the
  display to sleep, then drag — one gesture wakes AND scrolls. Wait ~8 s
  after the drag for the "Swipe up to open" hint to fade before capturing.
- **Delivered notifications persist per app install** — without the script's
  uninstall-before-install in `boot_locale`, an earlier locale's pushes stack
  into the next locale's shot as "Spotify Premium N notifications".
- **The Allow tap must be an EXACT label match**: pt-BR's deny button is
  "Não Permitir" (capital P), so a substring match for "Permitir" taps DENY
  first and the locale silently captures an empty lock screen.

## iPad — 4 captures (landscape)

Fully scripted: `scripts/capture-appstore-ipad-shots.sh --all`. Same locale
reboot flow as iPhone. A bill is ALWAYS selected in the detail pane (never ship
the empty "Select a bill" placeholder).

Landscape-on-headless-simulator traps (all handled in the script):
- simctl/AXe cannot rotate a simulator; the Screenshots config sets
  `INFOPLIST_KEY_UIRequiresFullScreen` + an orientation-mask delegate so
  `-screenshotLandscape` locks the app landscape. The FRAMEBUFFER stays
  portrait — every capture is rotated with `sips -r 270`.
- describe-ui returns app-space (landscape) coordinates; taps/swipes take
  DEVICE-portrait coordinates: `dev_x = 820 − app_y; dev_y = app_x` (iPad A16
  is 820×1180 pt portrait).
- **iPadOS 26 launches apps WINDOWED by default**, which breaks everything
  (describe-ui sees only DockFolderViewService). One-time fix per simulator:
  Settings → Multitasking & Gestures → **Full Screen Apps**. The script detects
  the windowed state and fails the locale with instructions.
- The sticky month headers pin over the calendar list, leaving only ~300 pt of
  actually visible rows — the due-today coarse search pages 200 pt at a time so
  it can't step over the salmon bar between checks.

## macOS — 4 captures, same states as iPad

```bash
scripts/capture-appstore-mac-shots.sh --all                    # en + it, es-ES, es-MX, pt-BR
scripts/capture-appstore-mac-shots.sh --only 5-charts --locales pt-BR
```

Output: `<locale>/mac/<shot>.png`, native 2x window captures **with the drop
shadow and alpha** for compositing in Figma.

| File | Launch | Post-launch input |
|---|---|---|
| `2-bills-list` | `-billsDefaultView list` | click due-today row (184, 240) — NO scroll |
| `3-calendar` | `-billsDefaultView calendar` | closed-loop scroll: salmon bar center → 700 pt, click it |
| `4-bill-detail` | `-billsDefaultView list` | click electricity row (184, 381) — NO scroll |
| `5-charts` | `-billsDefaultView list` | ellipsis menu → Charts, wheel detail −340 pt (Spending by Category tops the pane) |

The window is pinned to **928 × 792 at (100, 80)** — the app's default Mac window
size (`MacWindowDefaults.defaultSize`; keep the two in sync). Focused capture is
2080 × 1808 with the body at `+112+76`; the script asserts that bbox, which pins
position, size, AND activation (grey vs coloured traffic lights) in one check.
All click coordinates are measured against the pinned 928×792 window; if the
window size or the dataset offsets ever change, re-measure everything.

**Things that bite, all handled in the script:**

- **`-billsDefaultView` must be passed on EVERY launch** — it's `@AppStorage`-backed,
  so a run otherwise inherits whichever view the previous shot (or a manual session)
  left behind. NSArgumentDomain outranks the persisted value.
- **The window restores its previous frame on launch** (and the app now applies a
  first-launch default via `MacWindowDefaults`), so the script pins bounds by
  **window id** on every launch and reads them back — `set-bounds` targeted by app
  name can silently mis-target, and an ignored resize only surfaces as a wrong
  capture size.
- **An Xcode-debugged Billo instance breaks app-name targeting**: it survives
  `kill -9` (traced state), keeps windows on screen, and makes peekaboo's
  `--app Billo` calls time out. Everything targets by **PID** of the instance the
  script launched. Stop the debug session before a capture run (to force-detach:
  kill the `debugserver` tracing it, then the app).
- **Catalyst menus ignore synthetic clicks**: a CGEvent click on a menu item only
  *highlights* it — the mouse-up never activates. Click to park the cursor on the
  item, then send **Return** to commit it. peekaboo's window-targeted click can't
  reach the menu at all (the menu is its own window).
- **Clicking a calendar grid day opens the DayDetail sheet** — and Catalyst sheet
  dismissal is broken (see AGENTS.md), so the pipeline never opens sheets; the
  calendar selection clicks the due-today LIST row instead.
- **Wheel events are linear at 1 wheel pixel = 1 point**, but only as a series of
  small events (20 px ticks, 25 ms apart) — a single large delta accelerates
  unpredictably. Post real CGEvents at the cursor; peekaboo's scroll does not reach
  the Catalyst scroll view.
- **The red traffic light matches a naive "red bar" scan** — the salmon detection
  is restricted to the list area (pt ≥ 340) and discriminates salmon from the
  orange upcoming bars by `|g−b| ≤ 25`.
- **Catalyst exposes extra auxiliary windows** (a 500×500 offscreen `UINSWindow` on
  every launch) — filter on layer 0, `AXStandardWindow` subrole, height > 600.
- **An input event that lands on nothing still produces a valid-looking capture.**
  The script shoots a pre-action frame and fails the shot if the actions changed
  no pixels; selection clicks are verified against a detail-pane region hash.
- **The display must be awake and unlocked** — macOS cannot capture a sleeping
  display. The script holds a `caffeinate -d -u` assertion for its own duration.

**Capture the window by id, with its drop shadow:**

```bash
screencapture -x -r -t png -l "$WINDOW_ID" shot.png
```

The Figma designs composite the Mac window over the panel background *with* the
macOS drop shadow, so omit `-o` (it would strip the shadow) and keep the alpha
channel. Alpha is only flattened on the *final* Figma exports
(`magick … -background white -alpha remove -alpha off`) — App Store Connect rejects
alpha (error 90717), but flattening the raw captures early would bake a halo into
the design. `-t png` is not optional on macOS 26: screenshots default to HEIC/HDR
on XDR displays. Window ids come from the AX/CG window list and are invalidated on
every relaunch — re-fetch per shot.

**Locale = language + region + market in one launch:**

```bash
SCREENSHOT_MARKET=mx Billo.app/Contents/MacOS/Billo \
  -AppleLanguages "(es)" -AppleLocale "es_MX" -billsDefaultView list
```

es-ES and es-MX share the `es` in-app localization; the region drives number/
currency formatting and (with the env var as the explicit signal) the
`ScreenshotMockData` market dataset. On the simulators the scripts set the
system-level locale instead (the lock screen must be localized too) and pass
`SIMCTL_CHILD_SCREENSHOT_MARKET` explicitly.
