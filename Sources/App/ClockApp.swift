import SwiftUI
import AppKit
import UserNotifications

@main
struct BraunClockApp {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = ClockDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { app.run() }
    }
}

@MainActor
final class ClockModel: ObservableObject {
    @Published var zoneID: String { didSet { defaults.set(zoneID, forKey: "zone"); if armed { disarm(); message = "Time zone changed. Set the alarm again for this city." } } }
    @Published var sizingStandard: ClockSizingStandard { didSet { defaults.set(sizingStandard.rawValue, forKey: "sizingStandard"); updateWindow?() } }
    @Published var footprint: ClockFootprint { didSet { defaults.set(footprint.rawValue, forKey: "footprint"); updateWindow?() } }
    @Published var allSpaces: Bool { didSet { defaults.set(allSpaces, forKey: "allSpaces"); updateWindow?() } }
    @Published var onTop: Bool { didSet { defaults.set(onTop, forKey: "onTop"); updateWindow?() } }
    @Published var armed = false
    @Published var nextAlarm: Date?
    @Published var alarmHour: Int { didSet { defaults.set(alarmHour, forKey: "alarmHour") } }
    @Published var alarmMinute: Int { didSet { defaults.set(alarmMinute, forKey: "alarmMinute") } }
    @Published var message = ""
    @Published var scheduling = false
    var updateWindow: (() -> Void)?
    var openSettings: (() -> Void)?
    var openAbout: (() -> Void)?
    private let defaults = UserDefaults.standard
    private var requestGeneration = 0
    var zone: TimeZone { zoneID == "system" ? .autoupdatingCurrent : TimeZone(identifier: zoneID) ?? .autoupdatingCurrent }
    var zoneLabel: String { zoneID == "system" ? "System · \(zone.identifier)" : zoneID }
    init() {
        // Preserve local preferences when upgrading from the original app identity.
        if !defaults.bool(forKey: "typeAB1IdentityMigration") {
            let old = defaults.persistentDomain(forName: "com.duivesteyn.clock")
                ?? defaults.persistentDomain(forName: "co.deautomation.braunclock") ?? [:]
            for key in ["zone", "footprint", "size", "onTop", "allSpaces", "alarmHour", "alarmMinute", "widgetFootprintMigration", "sizingStandard", "NSWindow Frame ClockPlacement"] {
                if defaults.object(forKey: key) == nil, let value = old[key] { defaults.set(value, forKey: key) }
            }
            // Pending notifications belong to the old bundle; do not claim they are armed.
            defaults.set(true, forKey: "typeAB1IdentityMigration")
        }
        if !defaults.bool(forKey: "widgetFootprintMigration") {
            defaults.set("small", forKey: "footprint")
            defaults.set("system", forKey: "zone")
            defaults.set(false, forKey: "onTop")
            defaults.set(false, forKey: "allSpaces")
            defaults.set(true, forKey: "widgetFootprintMigration")
        }
        zoneID = defaults.string(forKey: "zone") ?? "system"
        sizingStandard = ClockSizingStandard(rawValue: defaults.string(forKey: "sizingStandard") ?? "calendar") ?? .calendar
        footprint = ClockFootprint(rawValue: defaults.string(forKey: "footprint") ?? "small") ?? .small
        allSpaces = defaults.bool(forKey: "allSpaces")
        onTop = defaults.bool(forKey: "onTop")
        alarmHour = defaults.object(forKey: "alarmHour") as? Int ?? 7
        alarmMinute = defaults.integer(forKey: "alarmMinute")
        // Reconcile the saved date with the actual notification request before raising the button.
        if let date = defaults.object(forKey: "nextAlarm") as? Date, date > Date() {
            UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                Task { @MainActor in
                    if requests.contains(where: { $0.identifier == "clock.alarm" }) {
                        self.nextAlarm = date; self.armed = true
                    } else { self.defaults.removeObject(forKey: "nextAlarm") }
                }
            }
        } else { defaults.removeObject(forKey: "nextAlarm") }
    }
    func disarm() {
        requestGeneration += 1
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["clock.alarm"])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ["clock.alarm"])
        armed = false; nextAlarm = nil; defaults.removeObject(forKey: "nextAlarm")
    }
    func arm() {
        guard !scheduling else { return }
        scheduling = true
        requestGeneration += 1
        let generation = requestGeneration
        Task { @MainActor in
            defer { scheduling = false }
            do {
                let center = UNUserNotificationCenter.current()
                let granted = try await center.requestAuthorization(options: [.alert, .sound])
                guard generation == requestGeneration else { return }
                guard granted else { message = "Enable Type AB1 notifications in System Settings before arming an alarm."; return }
                guard let date = ClockTime.nextAlarm(after: Date(), hour: alarmHour, minute: alarmMinute, zone: zone) else { return }
                var calendar = Calendar(identifier: .gregorian); calendar.timeZone = zone
                var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
                components.timeZone = zone
                let content = UNMutableNotificationContent()
                content.title = "Type AB1 alarm"
                content.body = "It’s \(String(format: "%02d:%02d", alarmHour, alarmMinute)) in \(zone.identifier)."
                content.sound = .default
                try await center.add(UNNotificationRequest(identifier: "clock.alarm", content: content,
                                                          trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)))
                guard generation == requestGeneration else {
                    center.removePendingNotificationRequests(withIdentifiers: ["clock.alarm"]); return
                }
                nextAlarm = date; defaults.set(date, forKey: "nextAlarm"); armed = true; message = ""
            } catch { message = "Could not schedule alarm: \(error.localizedDescription)" }
        }
    }
    func checkExpiration() {
        if let nextAlarm, nextAlarm <= Date() {
            // Preserve the delivered notification for missed alarms, including after sleep.
            armed = false; self.nextAlarm = nil; defaults.removeObject(forKey: "nextAlarm")
        }
    }
}

final class ClockWindow: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class ClockDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, UNUserNotificationCenterDelegate {
    let model = ClockModel()
    var window: ClockWindow!
    var settingsWindow: NSWindow?
    var statusItem: NSStatusItem!
    var aboutWindow: NSWindow?
    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
        window = ClockWindow(contentRect: NSRect(x: 0, y: 0, width: model.footprint.width(for: model.sizingStandard), height: model.footprint.height(for: model.sizingStandard)), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        window.isOpaque = false; window.backgroundColor = .clear; window.hasShadow = false
        window.isMovableByWindowBackground = true; window.hidesOnDeactivate = false
        window.contentView = NativeClockView(model: model)
        window.setFrameAutosaveName("ClockPlacement")
        if !window.setFrameUsingName("ClockPlacement") { window.center() }
        model.updateWindow = { [weak self] in self?.configureWindow() }
        model.openSettings = { [weak self] in self?.showSettings() }
        model.openAbout = { [weak self] in self?.showAbout() }
        configureWindow(); window.orderFrontRegardless()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "clock", accessibilityDescription: "Type AB1")
        let menu = NSMenu()
        for (title, action, key) in [("Show Type AB1", #selector(showClock), ""), ("Type AB1 Settings…", #selector(showSettings), ","), ("About Type AB1…", #selector(showAbout), ""), ("Quit Type AB1", #selector(quitClock), "q")] {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: key); item.target = self; menu.addItem(item)
        }
        statusItem.menu = menu
        let mainMenu = NSMenu()
        let applicationMenu = NSMenuItem(title: "Type AB1", action: nil, keyEquivalent: "")
        let appMenu = NSMenu(title: "Type AB1")
        for item in menu.items where item.action != #selector(showClock) { appMenu.addItem(item.copy() as! NSMenuItem) }
        applicationMenu.submenu = appMenu; mainMenu.addItem(applicationMenu); NSApp.mainMenu = mainMenu
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(woke), name: NSWorkspace.didWakeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(systemZoneChanged), name: .NSSystemTimeZoneDidChange, object: nil)
    }
    func configureWindow() {
        window.level = model.onTop ? .floating : .normal
        window.setContentSize(NSSize(width: model.footprint.width(for: model.sizingStandard), height: model.footprint.height(for: model.sizingStandard)))
    }
    @objc func systemZoneChanged() {
        if model.zoneID == "system", model.armed {
            model.disarm(); model.message = "Your Mac’s time zone changed. Set the alarm again for the new zone."
        }
        window.contentView?.needsDisplay = true
    }
    @objc func woke() { model.checkExpiration(); window.contentView?.needsDisplay = true }
    @objc func showClock() { window.orderFrontRegardless() }
    @objc func showSettings() {
        if settingsWindow == nil {
            let settings = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 620), styleMask: [.titled, .closable], backing: .buffered, defer: false)
            settings.title = "Type AB1 Settings"; settings.isReleasedWhenClosed = false; settings.delegate = self
            settings.contentView = NSHostingView(rootView: ClockSettings(model: model)); settings.center()
            settingsWindow = settings
        }
        NSApp.activate(ignoringOtherApps: true); settingsWindow?.makeKeyAndOrderFront(nil)
    }
    func application(_ application: NSApplication, open urls: [URL]) { showClock() }
    @objc func showAbout() {
        if aboutWindow == nil {
            let about = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 610), styleMask: [.titled, .closable], backing: .buffered, defer: false)
            about.title = "About Type AB1"; about.isReleasedWhenClosed = false; about.delegate = self
            about.contentView = NSHostingView(rootView: ClockAbout()); about.center(); aboutWindow = about
        }
        NSApp.activate(ignoringOtherApps: true); aboutWindow?.makeKeyAndOrderFront(nil)
    }
    func windowWillClose(_ notification: Notification) {
        guard let closing = notification.object as? NSWindow else { return }
        if closing === settingsWindow { closing.contentView = nil; settingsWindow = nil }
        if closing === aboutWindow { closing.contentView = nil; aboutWindow = nil }
    }
    @objc func quitClock() { NSApp.terminate(nil) }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions { [.banner, .sound, .list] }
}

struct ClockSettings: View {
    @ObservedObject var model: ClockModel
    var body: some View {
        Form {
            Section("Your Mac keeps the time") {
                Picker("Time zone", selection: $model.zoneID) {
                    Text("System time zone").tag("system")
                    ForEach(ClockTime.zones, id: \.self) { Text($0).tag($0) }
                }
                Text(model.zoneLabel).font(.caption).foregroundStyle(.secondary)
                Text("Always reads your Mac’s system clock. System time zone follows System Settings → Date & Time. A city changes the display, including daylight saving; it does not change your Mac’s time or Apple Clock’s city list.").font(.caption).foregroundStyle(.secondary)
            }
            Picker("Size reference", selection: $model.sizingStandard) {
                ForEach(ClockSizingStandard.allCases) { Text($0.label).tag($0) }
            }
            Picker("Widget size", selection: $model.footprint) {
                ForEach(ClockFootprint.allCases) { Text($0.label(for: model.sizingStandard)).tag($0) }
            }
            Text("The complete clock, including its raised button, fits inside the chosen size. Match Calendar uses a 170-point small clock; Native Mac uses 164.").font(.caption).foregroundStyle(.secondary)
            Toggle("Show on all Spaces", isOn: $model.allSpaces)
            Toggle("Always on top", isOn: $model.onTop)
            Text(model.onTop ? "Floats above other windows." : "On the wallpaper, behind normal windows. One Space by default.").font(.caption).foregroundStyle(.secondary)
            Section("One-time alarm in the selected time zone") {
                HStack {
                    Picker("Hour", selection: $model.alarmHour) { ForEach(0..<24) { Text(String(format: "%02d", $0)).tag($0) } }
                    Picker("Minute", selection: $model.alarmMinute) { ForEach(0..<60) { Text(String(format: "%02d", $0)).tag($0) } }
                }.disabled(model.armed || model.scheduling)
                Button(model.armed ? "Disarm alarm" : model.scheduling ? "Scheduling…" : "Save and arm alarm") {
                    if model.armed { model.disarm() } else { model.arm() }
                }.disabled(model.scheduling)
                if let alarm = model.nextAlarm { Text("Armed for \(alarm.formatted(date: .abbreviated, time: .shortened)) (Mac local time)").font(.caption) }
                Text("Uses a macOS notification and its default sound. Sleep, Focus and notification settings can delay or silence delivery. It is a reminder, not a continuous ringing alarm.").font(.caption).foregroundStyle(.secondary)
                if !model.message.isEmpty { Text(model.message).font(.caption).foregroundStyle(.orange) }
            }
            Text("Drag the housing to move. Right-click for settings. Add the Type AB1 widget using Edit Widgets; choose its city in Edit Widget.").font(.caption).foregroundStyle(.secondary)
            Button("About this little clock…") { model.openAbout?() }
        }.formStyle(.grouped).padding().frame(width: 460, height: 620)
    }
}
