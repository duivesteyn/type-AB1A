# What changed

## 1.1 — 11 November 2026

### The widget moves again

The desktop widget had been frozen since 14 October. macOS's widget logs showed why:

- **Two copies were registered.** `build/Type AB1.app` and `/Applications/Type AB1.app` both carried the same widget with the same build number (3), which never changed between builds. macOS kept the timeline it had saved from the first `build/` copy and logged *"Ignoring reloading contents … exact same as we already have loaded"*, so it never asked for a new one.
- **An older Large widget was still on the desktop.** Version 1.0 supported only Small, so macOS had no way to refresh it.
- **One hour of minute positions, refreshed only at the very end**, meant any late refresh stopped the hands.

Fixes:

- `Scripts/build.sh` stamps a new build number (`YYYYMMDD.HHMM`) on the app and widget every time, so macOS always treats a new build as new.
- New `Scripts/install.sh` builds, installs the only registered copy in `/Applications`, unregisters the `build/` copy, and launches the app, which asks macOS for a fresh timeline.
- The widget now plans **three hours** of minute positions and asks for the next timeline after the first hour, leaving two hours of slack.
- The widget supports **Small and Large** again (both square, so the clock fills them properly).
- The app also refreshes widget timelines when the Mac's clock is set or synced, not only on launch, wake and time-zone change.

Checked on this Mac after installing: macOS rebuilt both widgets' timelines (*"entry count: 180"*, three hours ahead) from `/Applications`, and the widget is shown live.

### Artwork, drawn in code

The clock body used to be one AI-generated 1254-pixel bitmap with heavy, slightly uneven numerals, plus PNG hands for the widget and separately drawn hands for the desktop. It is now drawn entirely in Core Graphics from one set of measurements in `Sources/Shared/ClockDesign.swift`, modelled on a photograph of a real AB1A:

- **Housing:** matte black with a fine moulded grain, a soft sheen from the upper left, a lit top lip and a darker lower edge.
- **Dial:** a chamfered recess (shaded at the top, catching light at the bottom), a clear crystal edge, and the housing lip's shadow falling across the top of the dial.
- **Ticks and numerals:** 60 precise ticks with longer hour marks; light Helvetica Neue numerals, each placed so its nearest edge keeps the same distance from the ticks.
- **Hands:** longer, slimmer white hands, as on the real clock (the minute hand reaches the ticks); a thin yellow seconds hand with the real clock's **round counterweight**; a domed yellow hub.
- **Alarm hand:** while an alarm is armed, a slim dark hand with a green tip points to the alarm time, like the original.
- **Top button:** seen from the front, standing proud of the housing, with its printed green mark on top. It rises 36 units when armed.
- **Glass:** a soft crescent reflection and a polished rim drawn over the hands, so the hands sit under the crystal.
- **Shadows:** hands and hub cast soft shadows straight down, with higher parts casting longer ones. The light stays put as the hands turn.

Every surface draws from the same code: the desktop clock, the widget, the About window, the app icon and the browser preview. The eight PNG layers in `Resources/Artwork/` are no longer used and have been removed (they remain in git history, and the original package is still in `art/`).

### App icon

Regenerated from the new artwork at 10:10:30 and sized to the macOS icon grid (an 824-pixel body on a 1024 canvas, with a soft shadow), so it no longer looks oversized next to other Dock icons. Regenerate with `./Scripts/make-icon.sh`.

### Desktop clock

- Stops ticking while fully covered or on another Space, and catches up on the real time as soon as it is visible.
- Redraws immediately with the real time after wake, a time-zone change, or a clock change.
- Idle memory: **16 MB** (was 17.2 MB); CPU about 0.4% of one core.
- "Show on All Spaces" off now really means one Space: the clock no longer jumps to whichever Space you switch to when the app activates.
- The size menu and setting are now called **Clock Size**, not "Widget Size", since they size the desktop clock, not the widget.
- The "Always on top" hint no longer claims the clock sits behind other windows; it sits among them.
- Uses the current `NSApp.activate()` API.

### Also in this release (carried over from uncommitted work)

- Type AB1 now lives in the **Dock**, with a Dock menu. The menu-bar icon is optional (Settings → Show in menu bar).
- One shared menu for the Dock, the right-click menu and the menu bar, including arm/disarm alarm.
- "Show on All Spaces" is now applied to the window (it was saved but had no effect).

### Tools and docs

- `Scripts/render-previews.sh` renders the desktop clock, the armed state, a 64-pixel version and the widget into `build/Previews`.
- `Scripts/make-preview-html.py` regenerates `art/Clock-Live-Preview.html` from the app's own artwork, reading hand and button sizes from `ClockDesign.swift` so the two cannot drift. The page now follows light and dark mode, and its hand shadows stay fixed as the hands turn.
- `Scripts/generate-project.py` no longer references the removed bitmaps.
- App and widget versions now match: **1.1 (4)**.
- New layout tests check that the housing and raised button fit the visible square, that hands stay inside the ticks, the pivot, and that the artwork renders with transparent corners and an opaque dial. The time tests now cover the three-hour widget timeline.
- `Clock-Codex-Handoff.md` is marked as the historical brief.

### Not verified

- The Xcode build (with per-widget city selection) could not be built here because Xcode is not installed. Its code typechecks with the compiler.
- Long-run widget refreshes across sleep and over several hours: macOS controls when they happen. The three-hour timeline is there to cover delays.
