import AppKit
import Combine

/// The desktop clock, built from Core Animation layers.
///
/// The still case and dial are one cached image. Each hand, the hub, the glass, the
/// date window and the alarm control are small cached images in their own layers. A
/// ticking clock only updates layer rotations once a second; a sweeping seconds hand is a
/// single continuous rotation run by macOS, so the app does almost no work per frame.
/// No SwiftUI hosting tree, so the idle clock stays small.
@MainActor final class NativeClockView: NSView {
    let model: ClockModel
    private var timer: Timer?
    private var changes: AnyCancellable?
    private var buttonProgress: Double
    private var buttonAnimation: ButtonTravel?
    private var armedPreviously: Bool
    private var styleShown: ClockStyle
    private var occlusionObserver: NSObjectProtocol?
    private var date = Date()
    private var builtKey = ""
    private var shownDay = 0

    private let root = CALayer()
    private let controlLayer = CALayer()
    private let bodyLayer = CALayer()
    private let dateLayer = CALayer()
    private let glassLayer = CALayer()
    /// Each hand sits in an unrotated holder that casts its shadow, so the light stays put as the hand turns.
    private var hands: [ClockDesign.HandKind: (holder: CALayer, hand: CALayer)] = [:]
    private let hubHolder = CALayer()
    private let hubLayer = CALayer()
    private lazy var alarmAccessibility = AlarmAccessibility(clock: self)

    init(model: ClockModel) {
        self.model = model; buttonProgress = model.armed ? 1 : 0; armedPreviously = model.armed
        styleShown = model.style
        super.init(frame: .zero)
        layer = root
        wantsLayer = true
        root.masksToBounds = false
        for kind in [ClockDesign.HandKind.alarm, .hour, .minute, .second] {
            let holder = CALayer(), hand = CALayer()
            holder.addSublayer(hand)
            hands[kind] = (holder, hand)
        }
        hubHolder.addSublayer(hubLayer)
        changes = model.objectWillChange.sink { [weak self] in
            DispatchQueue.main.async { self?.modelChanged() }
        }
        setAccessibilityElement(true); setAccessibilityRole(.group)
        setAccessibilityLabel("Clock")
    }
    required init?(coder: NSCoder) { fatalError("Use init(model:)") }
    override var acceptsFirstResponder: Bool { true }
    override var isOpaque: Bool { false }
    override var wantsUpdateLayer: Bool { true }

    private var style: ClockStyle { model.style }
    private var face: ClockFace.Type { ClockRender.face(style) }
    private var dark: Bool { effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua }
    private var reduceMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
    private var sweeping: Bool { style.seconds == .sweep && !reduceMotion }

    // MARK: Ticking

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
        tick()
        // Align to whole system seconds; every tick reads the real time again.
        let next = Date(timeIntervalSince1970: floor(Date().timeIntervalSince1970) + 1)
        let timer = Timer(fire: next, interval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        timer.tolerance = 0.05
        RunLoop.main.add(timer, forMode: .common); self.timer = timer
    }
    private func stopTicking() {
        timer?.invalidate(); timer = nil
        hands[.second]?.hand.removeAllAnimations()
    }

    func tick() {
        date = Date(); model.checkExpiration()
        if ClockReading.day(date, model.zone) != shownDay { builtKey = "" }
        updateLayers()
    }

    deinit {
        timer?.invalidate()
        if let occlusionObserver { NotificationCenter.default.removeObserver(occlusionObserver) }
    }

    // MARK: Geometry

    /// Where the face's crop sits in the view: as large as fits, centred left to right and
    /// standing on the bottom edge, so the clock can sit right on the bottom of the screen.
    private var content: CGRect { ClockRaster.fit(face.crop(style), in: bounds, standing: true) }
    /// View points per artboard unit.
    private var unit: CGFloat { content.width / face.crop(style).width }
    /// Artboard point to view point (the view is y-up).
    private func viewPoint(_ point: CGPoint) -> CGPoint {
        let crop = face.crop(style), content = content, scale = content.width / crop.width
        return CGPoint(x: content.minX + (point.x - crop.minX) * scale, y: content.maxY - (point.y - crop.minY) * scale)
    }
    /// Artboard rect to view rect.
    private func viewRect(_ rect: CGRect) -> CGRect {
        let a = viewPoint(CGPoint(x: rect.minX, y: rect.minY)), b = viewPoint(CGPoint(x: rect.maxX, y: rect.maxY))
        return CGRect(x: a.x, y: b.y, width: b.x - a.x, height: a.y - b.y)
    }
    /// The face's alarm control, at least 44 × 24 points; nil when it has none.
    private var buttonRect: CGRect? {
        guard let control = face.controlRect(style) else { return nil }
        let rect = viewRect(control)
        return rect.insetBy(dx: min(0, (rect.width - 44) / 2), dy: min(0, (rect.height - 24) / 2))
    }

    // MARK: Layers

    override func layout() { super.layout(); builtKey = ""; updateLayers() }
    override func viewDidChangeBackingProperties() { super.viewDidChangeBackingProperties(); builtKey = ""; updateLayers() }
    override func viewDidChangeEffectiveAppearance() { super.viewDidChangeEffectiveAppearance(); builtKey = ""; updateLayers() }

    /// Rebuild images when the style, size, appearance or day changes; otherwise just turn the hands.
    private func updateLayers() {
        guard content.width > 0 else { return }
        let scale = window?.backingScaleFactor ?? 2
        let key = "\(style.cacheKey(dark: dark))-\(content)-\(scale)-\(ClockReading.day(date, model.zone))"
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if key != builtKey { build(scale: scale); builtKey = key }
        turnHands()
        CATransaction.commit()
    }

    private func build(scale: CGFloat) {
        let style = style, face = face, dark = dark, unit = unit
        let density = CGFloat(ClockRaster.bucket(content.width * scale)) / face.crop(style).width
        let dial = face.dial(style)
        shownDay = ClockReading.day(date, model.zone)
        func image(_ layer: ClockRaster.Layer, _ region: CGRect?) -> CGImage? {
            ClockRaster.image(layer, style: style, dark: dark, region: region, pixelsPerUnit: density)
        }
        func place(_ layer: CALayer, _ region: CGRect, _ contents: CGImage?) {
            layer.frame = viewRect(region); layer.contents = contents; layer.contentsScale = scale
            layer.contentsGravity = .resize
        }
        root.sublayers = nil
        // The cube's cap sits in a slot behind the case's top edge.
        if face.controlBehindBody { root.addSublayer(controlLayer) }
        place(bodyLayer, face.crop(style), image(.body(control: nil), nil))
        root.addSublayer(bodyLayer)
        if !face.controlBehindBody, face.controlRect(style) != nil { root.addSublayer(controlLayer) }
        updateControl()
        if style.dateWindow {
            let region = DialKit.dateRect(dial).insetBy(dx: -4, dy: -4)
            place(dateLayer, region, image(.date(shownDay), region))
            root.addSublayer(dateLayer)
        }
        let lifts: [ClockDesign.HandKind: CGFloat] = [.alarm: 2, .hour: 4, .minute: 5, .second: 7]
        let handScale = dial.face / ClockDesign.dialRadius
        for kind in [ClockDesign.HandKind.alarm, .hour, .minute, .second] {
            guard let pair = hands[kind] else { continue }
            let region = DialKit.region(kind, dial)
            pair.holder.frame = bounds
            shadow(pair.holder, lift: lifts[kind]! * handScale * unit)
            // Rotate about the dial centre: anchor at the pivot inside the hand's region.
            pair.hand.contents = image(.hand(kind), region); pair.hand.contentsScale = scale
            pair.hand.contentsGravity = .resize
            let frame = viewRect(region), pivot = viewPoint(dial.center)
            pair.hand.bounds = CGRect(origin: .zero, size: frame.size)
            pair.hand.anchorPoint = CGPoint(x: (pivot.x - frame.minX) / frame.width, y: (pivot.y - frame.minY) / frame.height)
            pair.hand.position = pivot
            root.addSublayer(pair.holder)
        }
        hubHolder.frame = bounds
        shadow(hubHolder, lift: 7 * handScale * unit)
        let hubRegion = dial.circle(dial.hubRadius + 4)
        place(hubLayer, hubRegion, image(.hub, hubRegion))
        root.addSublayer(hubHolder)
        if style.glass {
            let region = dial.circle(dial.glassRadius + 2)
            place(glassLayer, region, image(.glass, region))
            root.addSublayer(glassLayer)
        }
        hands[.second]?.hand.removeAllAnimations()
    }

    /// Matches ClockDesign.setShadow: light from above, higher parts cast longer shadows.
    private func shadow(_ layer: CALayer, lift: CGFloat) {
        layer.shadowColor = .black
        layer.shadowOpacity = 0.5
        layer.shadowOffset = CGSize(width: lift * 0.25, height: -lift)
        layer.shadowRadius = (4 * unit + lift) * 0.5
    }

    private func updateControl() {
        guard let region = face.controlRect(style) else { return }
        let density = CGFloat(ClockRaster.bucket(content.width * (window?.backingScaleFactor ?? 2))) / face.crop(style).width
        controlLayer.frame = viewRect(region)
        controlLayer.contents = ClockRaster.image(.control(buttonProgress), style: style, dark: dark, region: region, pixelsPerUnit: density)
        controlLayer.contentsScale = window?.backingScaleFactor ?? 2
        controlLayer.contentsGravity = .resize
    }

    private func turnHands() {
        let showSeconds = style.seconds != .hidden
        let angles = HandAngles.at(date, zone: model.zone, showSeconds: showSeconds, smooth: sweeping)
        func turn(_ kind: ClockDesign.HandKind, _ degrees: Double) {
            hands[kind]?.hand.transform = CATransform3DMakeRotation(-CGFloat(degrees) * .pi / 180, 0, 0, 1)
        }
        turn(.hour, angles.hour)
        turn(.minute, angles.minute)
        hands[.second]?.holder.isHidden = !showSeconds
        if let alarm = hands[.alarm] {
            alarm.holder.isHidden = !model.armed
            turn(.alarm, 30 * (Double(model.alarmHour % 12) + Double(model.alarmMinute) / 60))
        }
        guard showSeconds, let second = hands[.second]?.hand else { return }
        if sweeping {
            // One continuous turn a minute, run by macOS. Re-aimed at each new minute to stay exact.
            let calendar = Calendar.current
            let fresh = second.animation(forKey: "sweep") == nil || calendar.component(.second, from: date) == 0
            guard fresh else { return }
            second.removeAnimation(forKey: "sweep")
            let start = -CGFloat(angles.second) * .pi / 180
            second.transform = CATransform3DMakeRotation(start, 0, 0, 1)
            let sweep = CABasicAnimation(keyPath: "transform.rotation.z")
            sweep.fromValue = start
            sweep.byValue = -2 * CGFloat.pi
            sweep.duration = 60
            sweep.repeatCount = .infinity
            sweep.isRemovedOnCompletion = false
            second.add(sweep, forKey: "sweep")
        } else {
            second.removeAnimation(forKey: "sweep")
            turn(.second, angles.second)
        }
    }

    // MARK: Model and input

    private func modelChanged() {
        if model.armed != armedPreviously {
            armedPreviously = model.armed; buttonAnimation?.stop()
            let target = model.armed ? 1.0 : 0.0
            if reduceMotion { moveButton(target) }
            else {
                let travel = ButtonTravel(clock: self, from: buttonProgress, to: target)
                buttonAnimation = travel; travel.start()
            }
        }
        if model.style != styleShown {
            let familyChanged = model.style.family != styleShown.family
            styleShown = model.style; builtKey = ""
            if familyChanged { NSAccessibility.post(element: self, notification: .layoutChanged) }
        }
        updateLayers()
    }
    fileprivate func moveButton(_ value: Double) {
        buttonProgress = value
        CATransaction.begin(); CATransaction.setDisableActions(true)
        updateControl()
        CATransaction.commit()
    }
    fileprivate func activateAlarm() { if model.armed { model.disarm() } else { model.openSettings?(.alarm) } }
    override func mouseDown(with event: NSEvent) {
        if let buttonRect, buttonRect.contains(convert(event.locationInWindow, from: nil)) { activateAlarm() }
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
    override func accessibilityChildren() -> [Any]? { buttonRect == nil ? [] : [alarmAccessibility] }
    fileprivate var alarmFrame: CGRect {
        guard let buttonRect else { return .zero }
        return window?.convertToScreen(convert(buttonRect, to: nil)) ?? .zero
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
