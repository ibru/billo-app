# App Store shot catalogue

The exact screen states the App Store screenshot designs need, per device, so a
re-capture for a new locale lands the same pixels as the existing set. Companion to
`ai-rules/localization.md` (Phase 5 drives the capture → Figma flow). Modeled on the
same playbook in the Savemo repo (`../Savemo/savemo-app/docs/appstore-shots.md`),
which pioneered the macOS pipeline.

Captures land in `../appstore/v<version>/screenshots/<locale>/<device>/<name>.png`
and are consumed by the Figma Shot Localizer `job*.json` image rules.

## Devices

| Device | Simulator / host | Pixels | Orientation |
|---|---|---|---|
| iPhone | iPhone 17 Pro, **iOS 26+** | 1206 × 2622 | portrait |
| iPad | iPad (A16), **iOS 26.5** | 2360 × 1640 | landscape (`-screenshotLandscape` + `sips -r 270`) |
| macOS | Mac Catalyst on the host Mac | 2080 × 1808 raw (window 928×792 + shadow) | — |

Liquid Glass chrome is required on iOS, so an 18.x runtime makes a capture unusable.
Every run uses the `Screenshots` build configuration (the `SCREENSHOTS` flag seeds the
in-memory demo data) and light appearance; iOS runs pin the status bar to 9:41.

**The dataset is evergreen** — `ScreenshotMockData` anchors every date on the capture
date, so amounts, day counters, and month names are a function of when a shot is
taken. Capture every device × every locale of one App Store set in a single session,
and re-capture en alongside the translated locales rather than mixing an old en row
with fresh localized ones.

## iPhone — 5 captures

`2-bills-list`, `3-calendar`, `4-bill-detail` (the electricity bill), `5-charts`
(scrolled to the category card), `6-notifications` (lock screen, localized pushes).
Simulator/AXe recipes and all gotchas live in the `billo-screenshot-automation`
auto-memory and `ai-rules/localization.md` Phase 5.

## iPad — 4 captures

Same names minus `6-notifications`; split view with a bill ALWAYS selected in the
detail pane (never ship the empty "Select a bill" placeholder).

| File | State |
|---|---|
| `2-bills-list.png` | List sidebar scrolled to the Next-7-Days rows, electricity bill (day 15) selected |
| `3-calendar.png` | Current-month grid (today circled), list at the month boundary with an income row, the due-soon bill selected |
| `4-bill-detail.png` | Same sidebar scroll as 2, the due-in-2-days bill selected |
| `5-charts.png` | Charts detail scrolled to the Spending by Category card, sidebar at top |

## macOS — 4 captures, same states as iPad

```bash
scripts/capture-appstore-mac-shots.sh --all                    # en + it, es-ES, es-MX, pt-BR
scripts/capture-appstore-mac-shots.sh --list
scripts/capture-appstore-mac-shots.sh --only 5-charts --locales pt-BR
```

Same file names as the iPad set, so the Figma job rules stay parallel across
devices. Output: `<locale>/mac/<shot>.png`, native 2x window captures **with the
drop shadow and alpha** for compositing in Figma.

| File | Launch | Post-launch input |
|---|---|---|
| `2-bills-list` | `-billsDefaultView list` | click electric-bill row (day 15), wheel sidebar −140 pt |
| `3-calendar` | `-billsDefaultView calendar` | `>` next month → click day-1 bill row → `<` back → wheel list −720 pt |
| `4-bill-detail` | `-billsDefaultView list` | click day-1 bill row, wheel sidebar −140 pt |
| `5-charts` | `-billsDefaultView list` | ellipsis menu → Charts, wheel detail −340 pt (Spending by Category tops the pane) |

The window is pinned to **928 × 792 at (100, 80)** — the app's default Mac window
size (`MacWindowDefaults.defaultSize`; keep the two in sync). Focused capture is
2080 × 1808 with the body at `+112+76`; the script asserts that bbox, which pins
position, size, AND activation (grey vs coloured traffic lights) in one check.

**Why these inputs work everywhere:** every seed dataset shares one day-of-month
spread (1, 3, 5, 8, 9, 12, 15, 18, 20, 22, 25, 27), so row indexes — and therefore
click y-coordinates — hold across markets; targets are full-width rows or fixed
toolbar buttons, so label width doesn't matter. All coordinates are measured
against the pinned 928×792 window; if the window size ever changes, re-measure
everything.

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
  script launched. Stop the debug session before a capture run.
- **Catalyst menus ignore synthetic clicks**: a CGEvent click on a menu item only
  *highlights* it — the mouse-up never activates. Click to park the cursor on the
  item, then send **Return** to commit it. peekaboo's window-targeted click can't
  reach the menu at all (the menu is its own window).
- **Clicking a calendar grid day opens the DayDetail sheet** — and Catalyst sheet
  dismissal is broken (see AGENTS.md), so the pipeline never opens sheets; each
  shot is a fresh launch. The `>`/`<` month-nav buttons are the deterministic list
  anchor instead: `>` scrolls the list to the next month's top.
- **Wheel events are linear at 1 wheel pixel = 1 point**, but only as a series of
  small events (20 px ticks, 25 ms apart) — a single large delta accelerates
  unpredictably. Post real CGEvents at the cursor; peekaboo's scroll does not reach
  the Catalyst scroll view.
- **Catalyst exposes extra auxiliary windows** (a 500×500 offscreen `UINSWindow` on
  every launch) — filter on layer 0, `AXStandardWindow` subrole, height > 600.
- **An input event that lands on nothing still produces a valid-looking capture.**
  The script shoots a pre-action frame and fails the shot if the actions changed
  no pixels.
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
`ScreenshotMockData` market dataset.
