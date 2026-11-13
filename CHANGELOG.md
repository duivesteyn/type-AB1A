# What changed

## Unreleased

- Arch and Wall now share the cube's solid yellow centre knob, with a seconds counterweight, in place of a ring and dark pin. The hands' back ends tuck under it.
- Widgets declare their background non-removable, so macOS no longer turns them into see-through glass.
- Thicker hour, minute and seconds hands on every clock, matched to the real Type AB1. The cube's hour hand is now 30 units wide (was 25), its minute hand 26 (was 20) and its seconds hand 8 (was 6). The arch and wall hands are thicker in the same proportion. The hands now read clearly at widget size.
- When the desktop dims widgets in the background, the widget flattens its layers before macOS dims them, so the hands no longer show through the yellow hub.
- The Settings window is titled after its tab instead of "Untitled", and every tab is the same width.
- About shows the current icon, read from the app bundle rather than the Dock's cache.
- Settings and alarm text now fits every clock family. The alarm notification names the city.

## 2.0 — 12 November 2026

### Styles

Type AB1 is now three clocks, each drawn in full detail, with the clock styles first developed for the Zeitbuch app brought across and de-branded:

- **Cube**: the original square desk alarm clock, now in **Black**, **White** and **Lagoon** (a white case with a glossy teal-blue dial).
- **Arch**: a round-topped desk alarm clock (width to height 1 : 1.133), with a dial concentric with the arch, a fine engraved line above its base, and an **alarm slider** in the base that slides across to uncover signal green when armed. Black or White.
- **Wall**: a round wall clock with a broad moulded rim, a stepped bezel and a large, airy dial. White or Black.

Every finish can also **Match appearance**: black in Dark Mode, white in Light.

On every clock:

- **Numerals:** 1 – 12, 5 – 60 (minutes), Roman, 12 · 3 · 6 · 9, or none. Each numeral keeps the same gap from the hour ticks, whatever its width.
- **Hands:** Classic, Luminous (a pale mint strip in the hour and minute hands), Red minute, Red seconds, All red, or Monochrome. The hub takes the seconds hand's colour.
- **Seconds:** Tick, Sweep or Off.
- **Details:** a date window in place of the 3, "quartz" on the dial, and the crystal reflection.

Nine presets to start from: Type AB1, Type AB1 White, Lagoon, Arch Night, Arch Day, Stopwatch, Station, Studio and Salon. Pick them from the new **Style** tab in Settings (a live preview, a gallery and every option), or from **Style** in the right-click and Dock menus.

### Tick or sweep, for each clock

Seconds motion is remembered separately for each family. Your wall clock can sweep while your cube ticks, and switching presets keeps the choice for that family. It's in the Style tab and in a new **Seconds** submenu in the right-click and Dock menus.

### The desktop clock, rebuilt on Core Animation

The case and dial are one cached image; each hand, the hub, the glass, the date window and the alarm control are small images in their own layers. Ticking just turns the layers once a second. **Sweep** is a single continuous turn run by macOS, so it costs the app next to nothing: **0.0% CPU** measured, against 20% for a first version that redrew everything 30 times a second. Hand shadows stay fixed as the hands turn. Idle memory is about 18 MB.

### Sits on the bottom of the screen

Every clock now stands on the bottom edge of its window (no transparent margin under the case), and the window can be placed right against the bottom of the screen.

### Widgets that keep themselves on time

The desktop widget froze again, at 1:55: the end of a timeline written at 22:55 the night before. macOS's logs showed why. The refresh due an hour later was missed while the Mac slept. When the app asked again on waking at 11:18, the widget system logged an internal error and ignored it, because it was still holding a broken connection to the previous day's widget process. Only restarting that process brought refreshes back.

So the app now looks after its widgets (`Sources/App/WidgetKeeper.swift`): at launch, on every wake (system, screen and session), and every third hour, it restarts its own widget process and asks for fresh timelines, with a plain refresh in the hours between. It only ever touches its own widget executable. `Scripts/install.sh` also stops any widget process left running the previous build. Checked: relaunching the app restarts the widget, both timelines are rewritten within seconds, and macOS schedules the next refresh an hour later.

Three widgets: **Type AB1** (the cube, keeping its original identifier so placed widgets stay put), **Type AB1 Arch** and **Type AB1 Wall**, each in Small and Large. They follow the Mac's appearance.

### Also

- `typeab1://style` opens the Style tab; `typeab1://style?preset=station` switches straight to a preset.
- A split-flap "Flip" clock was tried during development and dropped.
- New tests cover every family's geometry, that each case reaches the bottom edge, style saving and loading (including unknown values), and rendering all nine presets in Light and Dark.
- README: a style gallery that follows GitHub's light and dark themes, a styles section, all three widgets, new Settings screenshots, and updated notes for tinkerers.
- App and widget versions are now **2.0 (8)**.

## 1.4 — 12 November 2026

### Dock only

Type AB1 no longer offers a menu-bar icon, so it adds nothing to your menu bar. Everything it did is in the Dock menu and the clock's right-click menu: Settings, time zone, size, placement, alarm, About and Quit. Its standard app menus still appear in the menu bar while it is the active app, as with any Mac app.

- Removed the **Show icon in menu bar** setting and menu item, and the code behind them. The saved preference is cleared on first launch.
- The Clock settings tab is shorter to match; its README screenshot is retaken.
- **Always on Top** is back under its familiar name in the right-click and Dock menus (and "Always on top" in Settings), after 1.3 briefly called it "Keep Above Other Windows".
- About, the README and the browser preview no longer name the original maker. About keeps a single credit line (the AB 1, designed by Dietrich Lubs in 1987) and a link to the source code; the browser preview's About box drops the poem to match.
- App links now start `typeab1://` (`typeab1://settings`, `typeab1://alarm`, `typeab1://about`, `typeab1://show`). The widget's internal identifier is unchanged, so widgets already on the desktop stay put.
- App and widget versions are now **1.4 (7)**.

## 1.3 — 12 November 2026

### Settings, rebuilt

Settings was one long form with loose notes between rows and two separate hour and minute menus. It is now a standard Mac settings window with toolbar tabs, titled after the selected tab:

- **Clock**: time zone (shown as city names, such as "Adelaide" or "New York", instead of "Australia/Adelaide"), clock size as a Small / Medium / Large switch with the exact size shown underneath, which widgets to match, and placement toggles. Each group has one short note beneath it.
- **Alarm**: a status row (Off, Arming…, or Armed with the day and time it rings) with a single **Arm** / **Disarm** button, a proper time field, and the city it rings in. Any problem, such as notifications being turned off, appears in its own row.
- Clicking the clock's top button opens the Alarm tab directly.
- The menus say **Settings…** (the current macOS wording), list cities by name, and match the new labels: **Keep Above Other Windows**, **Show Icon in Menu Bar**.

### About, simplified

- The poem is gone from About (it stays in the README).
- The real app icon, name, version and build, the tagline, one line of credit, and links to the original clock and the source code.
- A clean title bar with no title text, sized to its content.
- The "Idle use" measurement has been removed.

### Also

- New links open the app where you need it: `braunclock://settings`, `braunclock://alarm` and `braunclock://about`, alongside `braunclock://show`.
- README: a new Settings and About section with screenshots, updated alarm steps and labels, and the version bumped.
- App and widget versions are now **1.3 (6)**.

## 1.2 — 12 November 2026

### App icon that fits macOS 26

On macOS 26 the 1.1 icon was shrunk onto a grey tile, because it didn't fill the system's rounded-square icon shape. The clock sat at about half size, next to Clock and Calendar at full size.

The AB1's housing is already a rounded square, so the icon is now the housing itself, filling Apple's icon shape: an 824-point continuous-corner ("squircle") square on a 1024 canvas, with a soft shadow. macOS now shows it at full size. The dial fills about 80% of the icon.

- Drawn from the same code as the clock (`ClockDesign.drawHousingSurface` was split out so the icon can reuse the housing material).
- At 16 and 32 pixels the numerals and minute ticks give way to heavier hands, so the time still reads.
- Checked on macOS 26.5.2 after installing: the system-rendered icon (as Finder and the Dock draw it) is full size, not on a grey tile.
- Three directions were compared (housing as icon, the whole clock on an ivory tile, and a simplified bold dial); the housing version was chosen.

### README

- A hero picture: the photographed AB1A beside Type AB1, set to the same moment, alarm hand and all.
- New pictures of the button down and armed, and of the Small and Large widgets, rendered from the app's own artwork by the new `Scripts/make-readme-images.sh` into `docs/images`.
- A one-line install at the top, a "Getting along with it" table of controls and shortcuts, and a "When something seems off" section (stuck widget, silent alarm, missing clock).
- Clearer alarm steps, a privacy line, and notes on the icon for tinkerers.

App and widget versions are now **1.2 (5)**.

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
