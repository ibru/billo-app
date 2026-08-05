# Adding a New Locale — End-to-End Playbook

The complete workflow for shipping a new language: market research → App Store listing →
in-app translation → screenshot pipeline → Figma designs → App Store Connect. Follow the
phases in order; each produces artifacts the next one consumes. Existing locales
(it, es-ES, es-MX, en-GB, pt-BR, shipped with v1.0.2) are the reference implementations —
copy their structure, not just their spirit.

## File structure (`../appstore/`, sibling of the app repo, NOT a git repo)

```
appstore/
  v1/                              # original US launch assets (screenshots/en/{iphone,ipad}/ + export/ + upload/)
  v<version>/                      # one folder per metadata release (e.g. v1.0.2)
    appstore-listing-<CC>.md       # per-locale research + strategy doc (IT, ES, MX, GB, BR…)
    screenshot-captions.md         # caption translations for ALL locales + production notes
    job.json / job-ipad.json       # Figma Shot Localizer configs (iPhone / iPad)
    metadata/                      # canonical asc files — the source of truth pushed to ASC
      app-info/<locale>.json       # name (30), subtitle (30), privacyPolicyUrl
      version/<version>/<locale>.json  # description (4000), keywords (100), promo (170), whatsNew, URLs
    screenshots/<locale>/{iphone,ipad}/NN-name.png   # raw localized captures (2-bills-list, 3-calendar,
                                                     # 4-bill-detail, 5-charts, 6-notifications — iPhone only)
```

## Phase 1 — Market & keyword research (decides GO/NO-GO)

- Tools: **astro MCP** (`get_app_keywords`, `add_keywords`, `search_app_store`,
  `get_keyword_suggestions` — popularity/difficulty/rank per storefront) and **`/aso`**
  (`~/bin/aads-aso hints|popscore|recommend`, cookie in `~/.aads/app_ads_cookie.txt`).
- **Apple popscore AND recommend floor non-English terms at 5** — useless outside en.
  Trust instead: astro popularity, live autocomplete (`hints` — a verbatim autocomplete
  = real demand), appsCount per keyword, and SERP analysis (`search_app_store`: a huge
  finance market + <10-rating niche apps on the exact phrase = unserved demand).
- Storefront indexing rules (verified via AppTweak/AppFollow): each storefront indexes its
  primary localization + an English secondary — **en-GB serves UK, AU, IT, ES; en-US only
  US (+es-MX as US secondary keyword field)**. Never spend localized keyword chars on
  English terms already in the English name/subtitle/keywords.
- Rejected-market precedents (don't re-research without new evidence): FR/DE (facturas/
  rechnungen = B2B invoice intent, native bill terms Pop 5, German SEPA autopay culture
  kills the reminder need), pt-PT (tiny, pt-BR doesn't index there). See
  `appstore-listing-BR.md` "Why Brazil" for the accepted-market argument template.
- Track the chosen keywords in astro (`add_keywords`) so ranks are monitored from day one.

## Phase 2 — Listing pack (name/subtitle/keywords/description)

- Write `appstore-listing-<CC>.md` following the existing docs' exact section order
  (research summary → name → subtitle → keywords with combos-formed + deliberately-NOT-
  included tables → description → promo → what's new → screenshots → methodology).
- Vocabulary is a strategy decision, not translation: pick the consumer word for "bill"
  per market (bollette / recibos / contas+boletos — NEVER fattura/factura/fatura, which
  read as B2B invoices) and mirror it in the app name, captions, and description.
- Keyword field rules: plurals are deliberate (**Apple does not stem es/pt/it**), plain
  ASCII (agua not água), no spaces after commas, ≤100 chars, no English duplicates.
- Description: translate from the en-US canonical (`metadata/version/<v>/en-US.json`),
  then run a **native-speaker language pass** (subagent per locale: hunt calques, fix
  register, native idioms) and an **independent semantic review via codex CLI**
  (`codex exec --sandbox read-only -m gpt-5.6-sol` — run inside a subagent, background
  Bash kills codex). Past catches to watch for: per-screen context bugs, the
  lifetime-plan pricing ambiguity ("pay once" must scope to the lifetime plan only),
  gendered speaker assumptions in quotes.
- After every copy change, re-sync the quotes inside the listing .md and validate:
  `asc metadata validate --dir metadata --subscription-app`.

## Phase 3 — In-app translation (`Billo/Localizable.xcstrings`)

- Export a worklist (key + en value + comment) from the catalog; translate ALL entries
  with a per-language glossary (bill/due/reminder/paycheck/income terms fixed up front,
  Apple platform terms — es uses Configuración not Ajustes for a neutral locale; "Billo"
  and "Pro" untranslated). **Single neutral `es`** serves Spain + LatAm (user decision):
  tú form, never vosotros, no region-exclusive words (móvil/celular → teléfono).
- Hard invariants: format specifiers match the en multiset (positional `%1$@` reordering
  allowed), `^[…](inflect: true)` wrappers preserved with singular nouns inside, no empty
  values. Merge with a validating script; the catalog file format is exact — Xcode style
  is `" : "` separators, blank line inside empty objects, **no trailing newline**.
- Register the language in `knownRegions` (pbxproj). Validate per language with
  `xcrun xcstringstool compile --language <lang> --dry-run`, then build.
- Run the same codex semantic review on `{key: {en, xx, comment}}` pair files; apply
  CRITICAL + clear ATTENTION items. Verify ambiguous keys against call sites (grep) —
  reviewers disagree, code decides (e.g. the two "Remaining" keys have different meanings).
- Gotchas: new `String(localized:)` strings reach the catalog only via Xcode IDE builds;
  components taking plain `String` (e.g. `BillDetailSectionHeader`) silently skip
  localization — wrap literals in `String(localized:)` at the call site. The per-locale
  screenshot run is the best untranslated-string detector.

## Translation quality bar (applies to Phases 2 & 3 — non-negotiable)

- **Translate the screen, not the string.** Every string is judged in the context of the
  screen it appears on: read the `comment:` in the catalog, and when it's missing or
  ambiguous, grep the call site before translating. The same English word maps to
  different words per context (bill occurrence = "scadenza" on bill screens but
  "registrazione/cobro" on income screens; "Remaining" is a net balance on the calendar
  but an unpaid rest in the payment sheet). A translation that is correct in isolation
  and wrong for its screen is a bug.
- **Natural for the country, not just the language.** Target the register a native
  copywriter would use: local idioms over literal renderings ("llegar justo a fin de
  mes", "salário cair", "toglimi il pensiero"), country-appropriate cultural references
  (post-its on the fridge, Imposto de Renda vs declaración de la renta), correct grammar
  agreement with the app's nouns (bolletta/conta are feminine → "Segna come pagata",
  "Marcar como paga"). Hunt calques explicitly — "paycheck to paycheck", "background
  stress", "private by design" all read machine-translated when copied word-for-word.
  Regionalized pairs (es-ES vs es-MX) must be deliberately different where the countries
  differ (nómina/quincena, añadir/agregar, móvil/celular), and neutral locales (single
  `es`) must avoid BOTH regions' exclusive vocabulary.
- **Separate independent review is mandatory.** The translator never reviews their own
  work. After the translation pass, run a second model as a native QA reviewer —
  **codex CLI** (`codex exec --sandbox read-only -m gpt-5.6-sol "<review prompt>"`,
  wrapped in a subagent since background Bash kills codex) or a **Claude subagent**
  with a fresh context. Feed it compact `{key: {en, xx, comment}}` pair files plus the
  store metadata, and ask for a CRITICAL (wrong meaning) / ATTENTION (unnatural) /
  OK-NOTES (deliberate choices to confirm) report covering: semantic drift, wrong screen
  context, gender/number agreement, format-specifier and inflect-wrapper integrity,
  calques and register, terminology consistency, UI length risks, and country-specific
  semantics (e.g. "antecipar" a bill in Brazil means paying it EARLY). Apply CRITICALs,
  judge ATTENTIONs, and when reviewers disagree, the code's call site decides. Finish
  with an on-device pass per language — screenshots are the best detector of missed
  strings and truncation.

## Phase 4 — Screenshots target seed data

- Add a market dataset to `Billo/App/ScreenshotMockData.swift`: 12 monthly bills + 1
  yearly + 2 incomes with local brands, currency, and pay cadence, keeping the SAME
  `dueInDays` offset spread (0,3,6,9,11,13,16,18,23,25,27,30) and array order so every
  capture — on any date — renders one bill due today (Spotify Premium, the automation's
  brand-name anchor), two in the next 7 days, the rest in the next 30.
  Market selection: `SCREENSHOT_MARKET` env var, fallback = run locale's region — so
  setting the simulator locale picks both language AND dataset.
- Capture-automation launch args (SCREENSHOTS builds; documented in AGENTS.md):
  `-billsDefaultView list|calendar`, `-screenshotRealNotifications`, `-screenshotLandscape`.
- New locale checklists in the capture scripts: add the locale to the label maps in
  `scripts/capture-appstore-{iphone,ipad}-shots.sh` (Charts menu item, category-card
  a11y prefix, electricity bill name, Allow button, notification payload copy).

## Phase 5 — Raw captures + Figma designs

- ALL THREE devices are fully scripted — `scripts/capture-appstore-iphone-shots.sh`,
  `scripts/capture-appstore-ipad-shots.sh`, `scripts/capture-appstore-mac-shots.sh`
  (each: `--all`, or `--only <shot> --locales <list>` for re-shoots). The shot
  catalogue, the required screen states (bills list NEVER scrolled — hero card
  visible; calendar's due-today row second from the bottom; charts framed on the
  category card), and every platform trap are documented in `docs/appstore-shots.md` —
  read it before changing a script or re-shooting.
- Devices and orientation are fixed: **iPhone 17 Pro in portrait** (1206×2622),
  **iPad (A16) in landscape** (2360×1640, via `-screenshotLandscape` + `sips -r 270`),
  and **macOS via Mac Catalyst** on the host Mac (928×792 window, captured with drop
  shadow at 2080×1808). Both simulators MUST run an **iOS 26+ runtime — Liquid Glass
  UI is required**; older runtimes (18.x) render the pre-Liquid-Glass chrome and the
  captures are unusable.
- Frames per locale: iPhone 2-bills-list, 3-calendar, 4-bill-detail (the electricity
  bill), 5-charts, 6-notifications (lock screen, localized push payloads); iPad same
  minus 6, with a bill ALWAYS selected in the detail pane (never ship the empty
  "select a bill" placeholder); macOS mirrors the iPad set (same four states and
  file names, `<locale>/mac/`).
- Drive the capture → captions → job.json → plugin flow with the
  **`/figma-shot-localizer`** skill; extra recipes live in the
  `billo-screenshot-automation` auto-memory.
- Captions: add the locale to `screenshot-captions.md` (aligned with the listing's
  keyword vocabulary, `**accent**` markers mirroring the EN two-tone design, ~10% length
  budget) and to `job.json`/`job-ipad.json`. Serve the version folder with the PLUGIN'S server —
  `python3 ~/Work/projekty/figma-shot-localizer/serve.py 8642 <version-folder>` (plain
  `http.server` lacks the CORS headers and /trigger control plane the plugin needs, and
  its watch mode lets an agent trigger runs via POST /arm and read logs via GET /log).
  **Before every plugin run**: `curl localhost:8642/job.json` and confirm it is THIS
  app's job — a long-lived server from another app's session can still own the port.
  Kill the server when the localization work is done.

## Phase 6 — App Store Connect

- Create the version once the previous one is approved:
  `asc versions create --app 6791054376 --version <v> --platform IOS --copy-metadata-from <prev>`.
- Push: `asc metadata push --app … --version <v> --platform IOS --dir metadata --dry-run`
  first, then for real. **Known gotcha:** creating an app-info localization auto-creates
  the version localization, so the first push fails those creates with "value already
  been…" — just re-run; they resolve as updates. Finish with a dry-run showing "no changes".
- Before submission: real whatsNew notes (`/app-store-changelog`), build upload, and
  optionally `asc screenshots upload` per locale once the Figma exports exist (strip
  alpha first; screenshots are NOT required for a first locale push — en-US fallback works).

## Definition of done for a new locale

listing .md + metadata JSONs (validated) · keywords tracked in astro · in-app catalog
100% translated, reviewed, compiling, `knownRegions` updated · ScreenshotMockData dataset ·
raw captures both devices · captions + job.json entries · ASC pushed clean · memories
(`billo-aso-localization-pack`, `billo-screenshot-automation`) and docs updated.
