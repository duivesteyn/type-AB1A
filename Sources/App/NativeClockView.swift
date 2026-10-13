import AppKit
import Combine

/// The idle desktop clock never creates a SwiftUI hosting tree or raster hand layers.
@MainActor final class NativeClockView: NSView {
    let model: ClockModel
    private var timer: Timer?
    private var changes: AnyCancellable?
    private var buttonProgress: Double
    private var buttonAnimation: ButtonTravel?
    private var armedPreviously: Bool
    private var layers: [String: NSImage] = [:]
    private var decodedPixels = 0
    private var date = Date()
    private lazy var alarmAccessibility = AlarmAccessibility(clock: self)

    init(model: ClockModel) {
        self.model = model; buttonProgress = model.armed ? 1 : 0; armedPreviously = model.armed
        super.init(frame: .zero)
        changes = model.objectWillChange.sink { [weak self] in
            DispatchQueue.main.async { self?.modelChanged() }
        }
        setAccessibilityElement(true); setAccessibilityRole(.group)
        setAccessibilityLabel("Analog clock")
    }
    required init?(coder: NSCoder) { fatalError("Use init(model:)") }
    override var acceptsFirstResponder: Bool { true }
    override var isOpaque: Bool { false }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow(); timer?.invalidate()
        guard window != nil else { timer = nil; return }
        let next = Date(timeIntervalSince1970: floor(Date().timeIntervalSince1970) + 1)
        let timer = Timer(fire: next, interval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.date = Date(); self.model.checkExpiration(); self.needsDisplay = true
            }
        }
        timer.tolerance = 0.05; RunLoop.main.add(timer, forMode: .common); self.timer = timer
    }
    deinit { timer?.invalidate() }
    private var side: CGFloat { min(bounds.width, bounds.height) }
    private var clockOrigin: CGPoint { CGPoint(x: (bounds.width - side) / 2, y: (bounds.height - side) / 2) }
    private var buttonRect: CGRect {
        let scale = side / ClockGeometry.cropSide, origin = clockOrigin
        let width = max(44, 370 * scale), height = max(24, 102 * scale)
        return CGRect(x: origin.x + (627 - ClockGeometry.cropX) * scale - width / 2,
                      y: origin.y + side - (142 - ClockGeometry.cropY) * scale - height / 2,
                      width: width, height: height)
    }
    private func modelChanged() {
        if model.armed != armedPreviously {
            armedPreviously = model.armed; buttonAnimation?.stop()
            let target = model.armed ? 1.0 : 0.0
            if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion { buttonProgress = target }
            else {
                let travel = ButtonTravel(clock: self, from: buttonProgress, to: target)
                buttonAnimation = travel; travel.start()
            }
        }
        needsDisplay = true
    }
    fileprivate func moveButton(_ value: Double) { buttonProgress = value; needsDisplay = true }
    fileprivate func activateAlarm() { if model.armed { model.disarm() } else { model.openSettings?() } }
    override func mouseDown(with event: NSEvent) {
        if buttonRect.contains(convert(event.locationInWindow, from: nil)) { activateAlarm() }
        else { window?.performDrag(with: event) }
    }
    override func keyDown(with event: NSEvent) {
        if event.characters == " " || event.keyCode == 36 { activateAlarm() } else { super.keyDown(with: event) }
    }
    override func rightMouseDown(with event: NSEvent) {
        let menu = NSMenu()
        menu.addItem(item("Type AB1 Settings…", #selector(settings)))
        let zoneItem = NSMenuItem(title: "Time Zone", action: nil, keyEquivalent: "")
        let zones = NSMenu()
        for zone in ["system"] + ClockTime.zones {
            let i = item(zone == "system" ? "System · \(TimeZone.autoupdatingCurrent.identifier)" : zone, #selector(selectZone(_:)))
            i.representedObject = zone; i.state = model.zoneID == zone ? .on : .off; zones.addItem(i)
        }
        zoneItem.submenu = zones; menu.addItem(zoneItem)
        let sizeItem = NSMenuItem(title: "Widget Size", action: nil, keyEquivalent: "")
        let sizes = NSMenu()
        for standard in ClockSizingStandard.allCases {
            let i = item(standard.label, #selector(selectStandard(_:))); i.representedObject = standard.rawValue
            i.state = model.sizingStandard == standard ? .on : .off; sizes.addItem(i)
        }
        sizes.addItem(.separator())
        for size in ClockFootprint.allCases {
            let i = item(size.label(for: model.sizingStandard), #selector(selectSize(_:))); i.representedObject = size.rawValue
            i.state = model.footprint == size ? .on : .off; sizes.addItem(i)
        }
        sizeItem.submenu = sizes; menu.addItem(sizeItem)
        let spaces = item("Show on All Spaces", #selector(toggleSpaces)); spaces.state = model.allSpaces ? .on : .off; menu.addItem(spaces)
        let top = item("Always on Top", #selector(toggleTop)); top.state = model.onTop ? .on : .off; menu.addItem(top)
        if model.armed { menu.addItem(item("Disarm Alarm", #selector(disarm))) }
        menu.addItem(item("About Type AB1…", #selector(about)))
        menu.addItem(.separator()); menu.addItem(item("Quit Type AB1", #selector(quit)))
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }
    private func item(_ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: ""); item.target = self; return item
    }
    @objc private func settings() { model.openSettings?() }
    @objc private func about() { model.openAbout?() }
    @objc private func selectZone(_ item: NSMenuItem) { if let zone = item.representedObject as? String { model.zoneID = zone } }
    @objc private func selectStandard(_ item: NSMenuItem) { if let value = item.representedObject as? String, let standard = ClockSizingStandard(rawValue: value) { model.sizingStandard = standard } }
    @objc private func selectSize(_ item: NSMenuItem) { if let value = item.representedObject as? String, let size = ClockFootprint(rawValue: value) { model.footprint = size } }
    @objc private func toggleSpaces() { model.allSpaces.toggle() }
    @objc private func toggleTop() { model.onTop.toggle() }
    @objc private func disarm() { model.disarm() }
    @objc private func quit() { NSApp.terminate(nil) }
    override func accessibilityValue() -> Any? { date.formatted(Date.FormatStyle(date: .omitted, time: .standard, timeZone: model.zone)) }
    override func accessibilityChildren() -> [Any]? { [alarmAccessibility] }
    fileprivate var alarmFrame: CGRect { window?.convertToScreen(convert(buttonRect, to: nil)) ?? .zero }

    override func draw(_ dirtyRect: NSRect) {
        guard side > 0, let context = NSGraphicsContext.current?.cgContext else { return }
        let pixels = min(1024, max(64, Int(ceil(side * ClockGeometry.canvas / ClockGeometry.cropSide * (window?.backingScaleFactor ?? 2)))))
        if decodedPixels != pixels {
            layers.removeAll()
            for name in ["ClockBody", "ButtonWell", "ButtonCap"] { layers[name] = ArtworkCache.shared.image(name, pixels: pixels) }
            decodedPixels = pixels
        }
        context.saveGState(); context.interpolationQuality = .high
        context.translateBy(x: clockOrigin.x, y: clockOrigin.y + side)
        context.scaleBy(x: side / ClockGeometry.cropSide, y: -side / ClockGeometry.cropSide)
        context.translateBy(x: -ClockGeometry.cropX, y: -ClockGeometry.cropY)
        drawLayer("ClockBody", in: context); drawLayer("ButtonWell", in: context)
        if buttonProgress > 0 {
            let lift = 36 * buttonProgress
            context.setFillColor(NSColor(white: 0.10, alpha: 1).cgColor)
            context.move(to: CGPoint(x: 455, y: 177 - lift)); context.addLine(to: CGPoint(x: 798, y: 177 - lift))
            context.addLine(to: CGPoint(x: 799, y: 178)); context.addQuadCurve(to: CGPoint(x: 454, y: 178), control: CGPoint(x: 627, y: 184)); context.closePath(); context.fillPath()
        }
        context.saveGState(); context.translateBy(x: 0, y: -36 * buttonProgress); drawLayer("ButtonCap", in: context); context.restoreGState()
        let angles = HandAngles.at(date, zone: model.zone)
        if model.armed {
            rotate(context, degrees: 30 * (Double(model.alarmHour % 12) + Double(model.alarmMinute) / 60)) {
                context.setFillColor(NSColor(red: 0.40, green: 0.84, blue: 0.30, alpha: 1).cgColor)
                context.fill(CGRect(x: -6, y: -304, width: 12, height: 36))
            }
        }
        hand(context, angle: angles.hour, width: 26, length: 255, rear: 13)
        hand(context, angle: angles.minute, width: 24, length: 306, rear: 12)
        rotate(context, degrees: angles.second) {
            context.setShadow(offset: CGSize(width: 1.5, height: 3.5), blur: 2.4, color: NSColor.black.withAlphaComponent(0.35).cgColor)
            context.setStrokeColor(NSColor(red: 1, green: 210/255, blue: 3/255, alpha: 1).cgColor)
            context.setFillColor(NSColor(red: 1, green: 210/255, blue: 3/255, alpha: 1).cgColor)
            context.setLineWidth(8); context.setLineCap(.round)
            context.move(to: CGPoint(x: 0, y: -360)); context.addLine(to: CGPoint(x: 0, y: 64)); context.strokePath()
            context.addPath(CGPath(roundedRect: CGRect(x: -12, y: 36, width: 24, height: 45), cornerWidth: 12, cornerHeight: 12, transform: nil)); context.fillPath()
        }
        context.translateBy(x: 627, y: 677)
        context.saveGState(); context.addEllipse(in: CGRect(x: -47, y: -47, width: 94, height: 94)); context.clip()
        let hub = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [color(1, 227/255, 71/255), color(1, 210/255, 3/255), color(234/255, 192/255, 0)] as CFArray, locations: [0, 0.55, 1])!
        context.drawRadialGradient(hub, startCenter: CGPoint(x: -16, y: -23), startRadius: 0, endCenter: .zero, endRadius: 65, options: [.drawsAfterEndLocation]); context.restoreGState()
        context.setStrokeColor(color(232/255,187/255,0)); context.setLineWidth(2); context.strokeEllipse(in: CGRect(x: -47, y: -47, width: 94, height: 94))
        context.restoreGState()
    }
    private func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> CGColor { CGColor(red: r, green: g, blue: b, alpha: 1) }
    private func drawLayer(_ name: String, in context: CGContext) {
        guard let image = layers[name], let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        context.saveGState(); context.translateBy(x: 0, y: 1254); context.scaleBy(x: 1, y: -1)
        context.draw(cg, in: CGRect(x: 0, y: 0, width: 1254, height: 1254)); context.restoreGState()
    }
    private func rotate(_ context: CGContext, degrees: Double, drawing: () -> Void) {
        context.saveGState(); context.translateBy(x: 627, y: 677); context.rotate(by: degrees * .pi / 180); drawing(); context.restoreGState()
    }
    private func hand(_ context: CGContext, angle: Double, width: CGFloat, length: CGFloat, rear: CGFloat) {
        rotate(context, degrees: angle) {
            context.setShadow(offset: CGSize(width: 1.5, height: 3.5), blur: 2.4, color: NSColor.black.withAlphaComponent(0.35).cgColor)
            context.addPath(CGPath(roundedRect: CGRect(x: -width/2, y: -length, width: width, height: length + rear), cornerWidth: width/2, cornerHeight: width/2, transform: nil)); context.clip()
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [color(1,1,1),color(245/255,245/255,242/255),color(220/255,220/255,217/255)] as CFArray, locations: [0,0.5,1])!
            context.drawLinearGradient(gradient, start: CGPoint(x: -width/2, y: 0), end: CGPoint(x: width/2, y: 0), options: [.drawsBeforeStartLocation,.drawsAfterEndLocation])
        }
    }
}

@MainActor private final class AlarmAccessibility: NSAccessibilityElement {
    weak var clock: NativeClockView?
    init(clock: NativeClockView) { self.clock = clock; super.init(); setAccessibilityRole(.button); setAccessibilityEnabled(true); setAccessibilityParent(clock) }
    override func accessibilityLabel() -> String? { clock?.model.armed == true ? "Disarm alarm" : "Set alarm" }
    override func accessibilityValue() -> Any? { clock?.model.armed == true ? "Armed, button up" : "Off, button down" }
    override func accessibilityFrame() -> NSRect { clock?.alarmFrame ?? .zero }
    override func accessibilityPerformPress() -> Bool { clock?.activateAlarm(); return clock != nil }
}

@MainActor private final class ButtonTravel: NSAnimation {
    weak var clock: NativeClockView?
    let from: Double, to: Double
    init(clock: NativeClockView, from: Double, to: Double) {
        self.clock = clock; self.from = from; self.to = to
        super.init(duration: 0.16, animationCurve: .easeInOut); animationBlockingMode = .nonblocking
    }
    required init?(coder: NSCoder) { fatalError("Use init(clock:from:to:)") }
    override var currentProgress: NSAnimation.Progress {
        get { super.currentProgress }
        set { super.currentProgress = newValue; clock?.moveButton(from + (to - from) * Double(currentValue)) }
    }
}
