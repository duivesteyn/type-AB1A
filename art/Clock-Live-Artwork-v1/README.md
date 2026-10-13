# Live clock artwork — vector mechanism edition

Prepared 13 October 2026. This is an artwork/handoff package for the native Mac clock, not the application itself.

**The clock body and dial are one fixed raster image. All moving parts are vectors.** The hour/minute hands, yellow seconds hand, yellow centre cap, optional green alarm pointer and complete top-button mechanism are editable SVG artwork. The full clock is a hybrid; the case texture and numerals have not been vector-traced.

## Start here

Open `Preview/Live-Artwork.html` in a browser. It works offline, ticks from real system time, allows time-zone selection and animates the button. Click the actual top button or the control below the clock. This is a visual demonstration: it does not schedule an alarm or play a sound.

Hand off `Documentation/Codex-Handoff.md`, `layout.json`, `Vectors` and `Assets.xcassets` to Codex on the Mac. The native app should reproduce the paths directly for resolution-independent motion; PNG fallbacks are also supplied.

## Button meaning

- **Up = alarm armed / set.** The cap lifts 36 master pixels, exposing its sidewall.
- **Down = alarm off.** The cap is flush with the top plane.
- The small green ellipse is printed paint on the cap. It moves with the cap; it is not an LED that needs to glow or switch off.
- Recommended transition: 160 ms ease-in-out. With Reduce Motion, change state immediately.

The button is rendered from the same geometry at every position. We are no longer switching between independently generated images, so the texture of the case and dial cannot drift during the button movement.

## Files

| Folder/file | Contents |
|---|---|
| `Master/ClockBody-1254.png` | Shared hand-free body/dial; original flush button is covered by the opaque vector well at runtime |
| `Vectors/HourHand.svg` | White short hand, pointing at 12 |
| `Vectors/MinuteHand.svg` | White long hand, pointing at 12 |
| `Vectors/SecondHand.svg` | Yellow seconds hand and rear counterweight, pointing at 12 |
| `Vectors/CentreHub.svg` | Fixed yellow centre cap |
| `Vectors/AlarmPointer.svg` | Optional green alarm-time pointer |
| `Vectors/ButtonWell.svg` | Static opaque recess covering the original baked button |
| `Vectors/ButtonCap.svg` | Separate black cap, edge highlights and green ellipse in the down position |
| `Vectors/ButtonAssembly-Down.svg`, `ButtonAssembly-Up.svg` | Complete button assemblies with well, cap and sidewall |
| `Vectors/AnimationFrames` | Nine vector button positions, progress 0 through 1 |
| `Vectors/ClockFace-AlarmOff.svg`, `ClockFace-AlarmOn.svg` | Hand-free composite faces; embed the shared raster body plus the vector button |
| `Layers` | Transparent 1254 px PNG component exports and nine button frames |
| `Assets.xcassets` | Twelve standard image sets, 512 px at 1x / 1024 px at 2x |
| `Preview` | Offline interactive preview, assembled SVG/PNG, aligned state sheet and animation GIF |
| `layout.json` | Exact pivots, dimensions, button travel and rendering order |
| `vector-parts.json` | SVG definitions and local path fragments for code porting |
| `Documentation` | Codex brief, provenance and validation report |

## Alignment rules

Keep every full-canvas component on the same square artboard. The source canvas is **1254 × 1254 px**, and the hand pivot is **(627, 677)**, not the image centre. In normalised coordinates it is `(0.5, 0.5398724083)`.

All hands point to 12 at zero degrees. Rotate clockwise around that pivot. Never auto-trim the individual PNG/SVG components or rotate them around `(0.5, 0.5)`. Uniformly scale the entire artboard to the app's view size.

Render the body first, then the button well, sidewall and cap, followed by optional alarm pointer, hour hand, minute hand, seconds hand and centre cap. Apply a small shadow to hands in native rendering if desired; it should not rotate the light source.

## What was changed for quality

Imagegen created the hand-free body. A separately generated raised-button image was useful as a visual reference but is superseded and is not used by the final animation. The button and hands were reconstructed as geometric vectors; they match the approved design direction rather than being claimed as a lossless vector tracing of the raster.

The fixed body's original depressed button remains under the vector well. Always render that opaque well; drawing just the cap over the raster would expose the old button during travel. The dial is genuinely hand-free: it contains no yellow hub, moving hands, baked hand shadows, centre dot or green alarm marker.

This package supplements the previously delivered application-icon pack. It does not overwrite the static Dock/AppIcon identity. No Xcode project, signed application or native alarm engine is included.
