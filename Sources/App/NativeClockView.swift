import AppKit
import Combine

/// The desktop clock. Draws straight into AppKit with Core Graphics: the static body is
/// rendered once per size by `ClockRaster`; button, hands, hub and glass are vectors
/// redrawn each tick. No SwiftUI hosting tree, so the idle clock stays small.
@MainActor final class NativeClockView: NSView {
    let model: ClockModel
    private var timer: Timer?
    private var changes: AnyCancellable?
    private var buttonProgress: Double
    private var buttonAnimation: ButtonTravel?
    private var armedPreviously: Bool
    private var body: CGImage?
    private var bodyPixels = 0
    private var occlusionObserver: NSObjectProtocol?
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
        super.viewDidMoveToWindow()
        if let occlusionObserver { NotificationCenter.default.removeObserver(occlusionObserver) }
        occlusionObserver = nil
        guard let window else { stopTicking(); return }
        // Stop ticking while the clock is fully covered or on another Space.
        occlusionObserver = NotificationCenter.default.addObserver(forName: NSWindow.didChangeOcclusionStateNotification, object: window, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateTicking() }
        }
        updateTicking()
    }
    private func updateTicking() {
        if window?.occlusionState.contains(.visible) == true { startTicking() } else { stopTicking() }
    }
    private func startTicking() {
        guard timer == nil else { return }
        date = Date(); needsDisplay = true
        // Align ticks to whole system seconds; each tick reads the real time again.
        let next = Date(timeIntervalSince1970: floor(Date().timeIntervalSince1970) + 1)
        let timer = Timer(fire: next, interval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        timer.tolerance = 0.05; RunLoop.main.add(timer, forMode: .common); self.timer = timer
    }
    private func stopTicking() { timer?.invalidate(); timer = nil }
    func tick() { date = Date(); model.checkExpiration(); needsDisplay = true }
    deinit {
        timer?.invalidate()
        if let occlusionObserver { NotificationCenter.default.removeObserver(occlusionObserver) }
    }
    private var side: CGFloat { min(bounds.width, bounds.height) }
    private var clockOrigin: CGPoint { CGPoint(x: (bounds.width - side) / 2, y: (bounds.height - side) / 2) }
    /// Artboard point to view point (the view is y-up).
    private func viewPoint(_ point: CGPoint) -> CGPoint {
        let scale = side / ClockGeometry.cropSide
        return CGPoint(x: clockOrigin.x + (point.x - ClockGeometry.cropX) * scale,
                       y: clockOrigin.y + side - (point.y - ClockGeometry.cropY) * scale)
    }
    /// The cap at full lift down to the housing lip, at least 44 × 24 points.
    private var buttonRect: CGRect {
        let cap = ClockDesign.buttonRect(progress: 1)
        let topLeft = viewPoint(CGPoint(x: cap.minX, y: cap.minY))
        let bottomRight = viewPoint(CGPoint(x: cap.maxX, y: ClockDesign.housing.minY + 30))
        let rect = CGRect(x: topLeft.x, y: bottomRight.y, width: bottomRight.x - topLeft.x, height: topLeft.y - bottomRight.y)
        return rect.insetBy(dx: min(0, (rect.width - 44) / 2), dy: min(0, (rect.height - 24) / 2))
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
        if let delegate = NSApp.delegate as? ClockDelegate {
            let menu = NSMenu()
            delegate.populateMenu(menu, context: .clockContext)
            NSMenu.popUpContextMenu(menu, with: event, for: self)
        }
    }
    override func accessibilityValue() -> Any? { date.formatted(Date.FormatStyle(date: .omitted, time: .standard, timeZone: model.zone)) }
    override func accessibilityChildren() -> [Any]? { [alarmAccessibility] }
    fileprivate var alarmFrame: CGRect { window?.convertToScreen(convert(buttonRect, to: nil)) ?? .zero }

    override func viewDidChangeBackingProperties() { super.viewDidChangeBackingProperties(); bodyPixels = 0; needsDisplay = true }

    override func draw(_ dirtyRect: NSRect) {
        guard side > 0, let context = NSGraphicsContext.current?.cgContext else { return }
        let backing = window?.backingScaleFactor ?? 2
        let pixels = ClockRaster.bucket(side * backing)
        if bodyPixels != pixels { body = ClockRaster.image(.body(buttonProgress: nil), pixels: pixels); bodyPixels = pixels }
        context.saveGState()
        context.interpolationQuality = .high
        ClockRaster.mapArtboard(context, into: CGRect(origin: clockOrigin, size: CGSize(width: side, height: side)))
        // The cap sits in a slot behind the housing's top edge, so it goes first.
        ClockDesign.drawButton(context, progress: buttonProgress)
        if let body { ClockRaster.drawLayer(body, in: context) }
        let alarmAngle = model.armed ? 30 * (Double(model.alarmHour % 12) + Double(model.alarmMinute) / 60) : nil
        // Shadows are set in base space, which here is view points.
        ClockDesign.drawMovingParts(context, angles: HandAngles.at(date, zone: model.zone), showSeconds: true,
                                    alarmAngle: alarmAngle, shadowScale: side / ClockGeometry.cropSide)
        ClockDesign.drawGlass(context)
        context.restoreGState()
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
