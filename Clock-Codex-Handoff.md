# Build the native Mac clock with these assets

## Product

Create a small native SwiftUI/AppKit desktop clock using the approved black instrument design. It is a borderless draggable clock application with actual ticking seconds and selectable named time zones. This handoff supplies the artwork and interaction design; compile and test the app on macOS.

Use the existing static icon resources for the application identity. Use this new live-artwork package for the desktop clock view. Do not animate the static AppIcon PNG or draw moving hands over an image that already contains hands.

## Authoritative artwork

Use `Master/ClockBody-1254.png` as the fixed base. It is the single raster body/dial. Use `Vectors` or the matching image sets for the moving elements. Avoid generating new complete images for animation states: doing that changes the case texture and numeral edges between frames.

The complete clock is deliberately hybrid. The button and hands are vectors; the body, face texture, ticks and numerals are a raster plate. Rebuilding the entire housing/dial in vectors is possible but would require a separately reviewed visual reconstruction and is not necessary for this version.

The self-contained `Preview/Live-Artwork.html` demonstrates the geometry, real-time hand positions, time-zone changes and mechanical button travel. It is a reference, not the production app. It does not schedule notifications or alarms.

## Coordinate contract

- Master artboard: 1254 × 1254. Top-left origin, x to the right, y downward.
- Hand pivot: `(627,677)`, normalised `(0.5,0.5398724083)`.
- Zero-angle hand direction: upward at 12. Positive rotation: clockwise.
- Hour hand: 255 px from pivot to tip, 26 px wide.
- Minute hand: 306 px from pivot to tip, 24 px wide.
- Seconds hand: 360 px from pivot to tip, 8 px wide, rear counterweight extends to 81 px.
- Centre cap: radius 47 px.
- Button cap travel: 36 px vertically upward in source coordinates.
- Button hit target: x 442–812, y 91–193, scaled with the entire artboard. Ensure an accessible click target at the smallest view size.

The exact vector paths and fills are in `vector-parts.json` and the SVGs. Keep the artboard when converting to native shapes or images. A SwiftUI full-canvas image needs `rotationEffect(..., anchor: UnitPoint(x: 0.5, y: 677.0/1254.0))`; do not rotate around the centre of the square.

Render all layers using the same square layout container and uniform scale. Keep shadows in screen coordinates. Do not add an independent crop, aspect-fill or arbitrary centring to any hand.

## Native render stack

1. Fixed `ClockBody` raster.
2. Static opaque vector `ButtonWell`, covering the original down-button image in the body.
3. Button shadow and sidewall.
4. Button cap and printed green ellipse.
5. Optional alarm pointer at its configured time, visible only if useful to the UI.
6. Hour hand.
7. Minute hand.
8. Yellow seconds hand and counterweight.
9. Yellow centre cap.

PNG fallbacks exist for all main components. The nine button frames can support a short sprite animation; native vector interpolation is preferred for arbitrary scale. The endpoint composite faces are conveniences for static previews, not a reason to crossfade the entire clock.

## Button geometry and behaviour

Let `progress` be a value from 0 to 1. Down/off is 0; up/armed is 1. Translate the cap and green mark by `y = -36 * progress`. The black sidewall fills the space between the cap's moving front edge and its fixed seat. Its top edge is at `y = 177 - 36 * progress`, while its lower edge stays approximately at 178. Use the complete paths in the SVG assemblies for corner/seat details.

Use one continuously interpolated progress value rather than swapping generated textures. Suggested motion: 160 ms ease-in-out; snap for Reduce Motion. On reversal during animation, continue from the currently displayed progress. Keep the clock face perfectly still.

**Up means an alarm is armed. Down means no alarm is armed.** The green ellipse remains visible in both states because it represents printed paint. Do not use it as the sole indication of alarm state: expose an accessibility value and an explicit textual status in the menu/settings.

The new alarm semantics supersede the earlier idea that clicking the top button would always open the time-zone picker. Proposed interaction:

- Click top button: arm/disarm the configured alarm.
- If no alarm time exists, open the alarm-setting popover before arming.
- Right-click clock / menu-bar menu: select time zone, alarm time, size and always-on-top setting.
- Drag housing: move the clock. Do not start dragging when clicking the button.

Do not ship a button that claims an alarm is armed unless the app has actually saved and scheduled that alarm. App suspension, sleep, notifications, missed-alarm handling and whether the app must remain open must be designed and tested on the Mac.

## Live clock calculations

Obtain the current time from the system for every displayed tick; never increment a counter as the source of truth. Use `Calendar` configured with a named `TimeZone`, e.g. `Australia/Adelaide`, `Europe/London`, `Pacific/Auckland`. Do not store fixed GMT offsets for named city clocks.

For hour `h`, minute `m`, second `s`, angles clockwise from 12:

```text
hour   = 30 * ((h % 12) + m/60 + s/3600)
minute = 6 * (m + s/60)
second = 6 * s
```

Yellow seconds should tick once per second, without implicit rotation animation. Use a system-time-aligned update and recompute after wake or time-zone changes. If a tick is delayed, the next render uses the actual current second. Do not rotate backwards through 354 degrees at the 59-to-0 transition. A ticking hand can simply set the new angle without interpolation.

For a future sweep mode, calculate a fractional second and use an animation schedule suited to a native app; it is not the default requested behaviour. The HTML reference polls briefly but only changes the second-hand position on whole seconds; native production scheduling should be chosen and measured on the Mac.

## Colours

Canonical sRGB colours remain: white hands `#F5F5F2`, seconds/cap yellow `#FFD203`, top-button mark `#88D672`, optional alarm pointer `#67D64D`, dial `#252626`, housing `#323234`. The SVGs contain additional shading stops for tactile surfaces. The small green printed mark is an ellipse with centre `(626.5,151.5)` and radii `(25,4.5)` in the down position; it moves with the cap.

## First native acceptance checks

- White hour/minute hands and yellow seconds/hub remain visually faithful at all three window sizes.
- Hands rotate about the dial centre with no wobble; seconds tick correctly across minute/hour/day rollover.
- Adelaide and London show correct local time; test a daylight-saving transition and half-hour offsets.
- Button movement affects only the top control. Body, dial texture and numerals stay pixel-stable.
- Up/armed and down/off match persisted state; cancelled alarm setup leaves the button down.
- Reduce Motion removes the travel animation.
- Button activation and dragging do not conflict; keyboard and VoiceOver equivalents work.
- Window location, chosen city and size survive relaunch. Correct time returns after wake.

Reference APIs for the Mac implementation:

- https://developer.apple.com/documentation/swiftui/timelineview
- https://developer.apple.com/documentation/foundation/timezone

The native app must be compiled and tested on macOS. This package validates artwork and the browser reference; it does not claim a native build has been completed.
