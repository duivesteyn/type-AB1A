<div align="center">

<img src="Resources/icon-256.png" width="128" alt="Type AB1 app icon">

# Type AB1

**A little square. A yellow second. A quieter desktop.**

An analog clock for your very digital Mac.<br>
Three hands, a green button, and excellent manners.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-black)
![Apple Silicon](https://img.shields.io/badge/Apple_Silicon-required-black)
![License: MIT](https://img.shields.io/badge/License-MIT-black)

</div>

---

Put it in a nice corner. Let the yellow hand take its little walks. Occasionally discover that it is, somehow, already lunchtime.

No batteries required. One Mac recommended.

## Contents

- [A small ode to a small square](#a-small-ode-to-a-small-square)
- [The little square that started it](#the-little-square-that-started-it)
- [Meet your new desk companion](#meet-your-new-desk-companion)
- [A cousin in the widget gallery](#a-cousin-in-the-widget-gallery)
- [Get ticking](#get-ticking)
- [A clock that lives in a tab, too](#a-clock-that-lives-in-a-tab-too)
- [Light on its feet](#light-on-its-feet)
- [For fellow tinkerers](#for-fellow-tinkerers)
- [Made with a fondness for useful things](#made-with-a-fondness-for-useful-things)
- [What changed](CHANGELOG.md)

## A small ode to a small square

> O little square of sensible things,\
> with yellow feet and minute wings,\
> no feed to scroll, no world to save —\
> just time, behaving. Mostly. Brave.

Type AB1 is an independent digital tribute to the **Braun AB 1**, designed by **Dietrich Lubs in 1987**, and to the clarity of Braun’s design tradition under **Dieter Rams**. A small thank-you to an object that knew when to stop designing.

The [Bröhan Museum’s Braun 100 exhibition catalogue](https://www.broehan-museum.de/wp-content/uploads/Bildliste_Braun100.pdf) credits the original. Our artwork is a reimagining of that clock family. Braun’s name and original design belong to their owners; this project has no affiliation or endorsement.

## The little square that started it

<div align="center">

<img src="20261014_Braun_AB1A_Type3885_BMD.jpeg" width="600" alt="Benjamin’s own Braun AB1A clock on his desk">

*My own Braun AB1A — photographed by Benjamin Duivesteyn, 14 October 2026.*

</div>

This is the real desk companion behind the digital one. The yellow hand has been doing its rounds long before this app had a bundle identifier. Type AB1 is my way of giving it a small, pixel-powered cousin.

## Meet your new desk companion

- **Purely analog.** White hour and minute hands, a yellow ticking second hand with its round counterweight, and a tactile little top button. The time stays on the dial.
- **Drawn, not pasted.** Housing, dial, numerals, hands and crystal are all drawn in code from one set of measurements, taken from the real clock pictured above. Matte grained plastic, a recessed dial under clear glass, shadows that fall the way the light does. Sharp at 16 pixels and at full screen; the app, widget, icon and browser preview all share it.
- **Your Mac keeps the time.** System time zone is the default. Choose a city in settings to look elsewhere in the world; macOS handles daylight saving and those delightfully awkward half-hour offsets.
- **A size that gets along with its neighbours.** The default **Match Calendar** reference uses **170 × 170**, **364 × 170** and **364 × 382** points. Choose **Native Mac** for **164 × 164**, **344 × 164** and **344 × 344**. The whole visible clock, raised button included, stays inside its footprint. Wide layouts centre the analog clock; Retina pixels do their own thing underneath.

  The artwork keeps its industrial corners and original proportions. Type AB1 does not add an Apple-style enclosure or stretch the clock into a different shape. The real system widget fits the bounds supplied by WidgetKit automatically.
- **Drag it somewhere pleasant.** Grab the housing to move it. Right-click or use the Dock menu for settings, city, size, Spaces, and alarm controls.
- **A button with a job.** Click the top control to set a one-time alarm. Up means armed; down means off, and a slim green-tipped alarm hand marks the time while it is set. Click again to disarm. Reduce Motion keeps the button’s travels brief: it simply snaps into place.
- **Dock and right-click first.** Lives in your Dock with a full right-click context menu. An optional menu bar icon can be enabled in settings if preferred.

> [!NOTE]
> The clock reads actual system time on every tick. It follows your Mac’s Date & Time settings; choosing a city changes the display, not your Mac or Apple Clock’s World Clock list.

> [!IMPORTANT]
> Alarms use macOS notifications and the default notification sound. Grant notification permission before arming one. Focus, sleep and notification settings can delay or silence delivery, so treat it as a friendly reminder rather than your sole defence against missing a flight. Changing time zone disarms the alarm so you can set it for the new city.

## A cousin in the widget gallery

The native **Type AB1 widget** brings the same little square to macOS’s desktop and Notification Centre, in **Small** and **Large**.

It is purely analog, with hour and minute hands. The seconds hand takes a well-earned holiday: WidgetKit supplies snapshots, and **macOS decides when to display updates**. Three hours of minute positions are prepared ahead of time, without a continuously running timer, and macOS is asked for fresh ones after the first hour. A late or skipped refresh therefore never stops the hands. [Apple explains the refresh rules here](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date).

The command-line build’s widget follows your **system time zone**. The Xcode build also enables per-widget city selection through App Intents. Once the app is installed and discovered by macOS, open **Edit Widgets** and look for **Type AB1**.

> [!TIP]
> **Widget stuck on an old time?** That usually means macOS knows about more than one copy of the app and is holding on to an old timeline. Run `./Scripts/install.sh`: it builds, installs the only registered copy into `/Applications`, and launches it, which asks macOS for a fresh timeline. Every build now carries a new build number, so macOS never mistakes it for the previous one.

## Get ticking

**Requires macOS 14 or later.** The command-line build targets **Apple silicon**.

If you have a downloaded build, unzip it and open **Type AB1.app**. The app contains its native widget extension; the widget is not a separate app to double-click.

**Build and install from source** (replaces `/Applications/Type AB1.app`):

```sh
./Scripts/install.sh
```

**Just build**, to try it from the `build` folder:

```sh
./Scripts/build.sh
open "build/Type AB1.app"
```

Keep one copy around: if you run the `build` copy and an installed one, macOS sees two widgets with the same identity.

**Prefer Xcode?** Open `Clock.xcodeproj`, select the **Clock** scheme, choose your Apple development team for both targets, and run. The scheme’s internal name is Clock; the built app is Type AB1.

> [!TIP]
> The command-line build is ad-hoc signed for local use. Distribution signing and notarization are separate steps. Configurable widgets use Xcode’s App Intents metadata processing.

**Added a source file?** Regenerate the project:

```sh
python3 Scripts/generate-project.py
```

## A clock that lives in a tab, too

Open `art/Clock-Live-Preview.html` in a browser. Its artwork is embedded, so it works offline. Pick a city, watch the hands, and give the button a little click.

The browser button demonstrates the mechanism; it does **not** schedule an alarm. The About panel contains the same ode and icon. A small museum exhibit, with unusually accurate opening hours.

## Light on its feet

The desktop clock uses **AppKit** and Core Graphics, one tick per second, and pauses entirely while it is covered or on another Space. The static housing and dial are drawn once for the size on screen; only the hands, button and glass are redrawn each second. No accounts, analytics, network requests, bundled bitmaps or third-party runtime dependencies.

At a 170-point clock height, an idle run on 11 November 2026 measured **16 MB physical memory footprint** and **0.4% of one CPU core**. The **20 MB goal applies to the idle desktop clock**; larger sizes, Settings and About can use more. The system widget runs in a separate macOS host.

> [!TIP]
> Curious? About → **Measure idle use** shows a ten-second CPU sample and the current memory footprint. Opening About counts as activity — even a little clock notices when you admire it.

## For fellow tinkerers

| Where | What lives there |
| --- | --- |
| `Sources/App/` | Native desktop view, settings, alarms and the small ode |
| `Sources/Widget/` | Widget configuration and timeline provider |
| `Sources/Shared/ClockDesign.swift` | **The artwork**: every measurement, colour and drawing step |
| `Sources/Shared/ClockRaster.swift` | Renders and caches the still parts per size |
| `Sources/Shared/` (others) | Clock maths, sizes, and the SwiftUI layers for widget and About |
| `Scripts/` | Build, install, icon, preview and Xcode-project tools |
| `art/Clock-Live-Preview.html` | Browser preview, regenerated from the app’s artwork |
| `art/Clock-Live-Artwork-v1/` | The original raster artwork package, kept for reference |
| `Config/` | Bundle details and entitlements |

All artwork shares a **1254 × 1254** artboard. The hands turn around **(627, 677)**. Please keep that pivot: a clock with wandering elbows is a different project entirely. Renderers show the square from **(76, 98)**, **1102** units on a side, which holds the housing and the fully raised button.

Changed something in `ClockDesign.swift`? Refresh everything that is drawn from it:

```sh
./Scripts/render-previews.sh        # PNGs of the clock and widget in build/Previews
./Scripts/make-icon.sh              # Resources/icon-*.png and Clock.icns
python3 Scripts/make-preview-html.py && node Scripts/check-html.js
```

The icon is set to **10:10**. It likes to look cheerful for photographs.

<details>
<summary><strong>Run the checks</strong></summary>

```sh
swiftc -parse-as-library -module-cache-path build/module-cache \
  Sources/Shared/ClockTime.swift Tests/ClockTimeTests.swift -o build/ClockTimeTests
build/ClockTimeTests

swiftc -parse-as-library -module-cache-path build/module-cache \
  Sources/Shared/ClockTime.swift Sources/Shared/ClockLayout.swift Sources/Shared/ClockDesign.swift \
  Sources/Shared/ClockRaster.swift Tests/ClockLayoutTests.swift -o build/ClockLayoutTests
build/ClockLayoutTests
```

The first covers midnight rollover, Adelaide’s half-hour offset, daylight-saving transitions, next-alarm scheduling and the widget’s three-hour timeline. The second covers the size references, that the housing and raised button fit the visible square, hand reach, the pivot, and that the artwork renders. Live widget updates, alarm delivery across sleep/reboot, and Spaces behaviour still need device testing.

</details>

## Made with a fondness for useful things

By **Benjamin Duivesteyn**. Source and included project artwork are released under the **[MIT license](LICENSE)**, with the original design credited to its owners.

| | |
| --- | --- |
| **App** | Type AB1 1.1 · `com.duivesteyn.typeab1` |
| **Executable** | `TypeAB1` |
| **Widget** | `TypeAB1Widget.appex` · `com.duivesteyn.typeab1.widget` |

<div align="center">

*Wind nothing. Enjoy the tick.*

</div>
