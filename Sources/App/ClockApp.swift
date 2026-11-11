import SwiftUI
import AppKit
import UserNotifications
import WidgetKit

@main
struct BraunClockApp {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = ClockDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
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
    @Published var showMenuBarItem: Bool { didSet { defaults.set(showMenuBarItem, forKey: "showMenuBarItem"); updateMenuBar?() } }
    @Published var armed = false
    @Published var nextAlarm: Date?
    @Published var alarmHour: Int { didSet { defaults.set(alarmHour, forKey: "alarmHour") } }
    @Published var alarmMinute: Int { didSet { defaults.set(alarmMinute, forKey: "alarmMinute") } }
    @Published var message = ""
    @Published var scheduling = false
    var updateWindow: (() -> Void)?
    var updateMenuBar: (() -> Void)?
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
        showMenuBarItem = defaults.bool(forKey: "showMenuBarItem")
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
final class ClockDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, UNUserNotificationCenterDelegate, NSMenuDelegate {
    enum MenuContext {
        case dock
        case clockContext
        case menuBar
    }

    let model = ClockModel()
    var window: ClockWindow!
    var settingsWindow: NSWindow?
    var statusItem: NSStatusItem?
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
        model.updateMenuBar = { [weak self] in self?.configureMenuBar() }
        model.openSettings = { [weak self] in self?.showSettings() }
        model.openAbout = { [weak self] in self?.showAbout() }
        configureWindow(); window.orderFrontRegardless()
        configureMenuBar()

        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu(title: "Type AB1")
        let about = NSMenuItem(title: "About Type AB1…", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        appMenu.addItem(about)
        appMenu.addItem(.separator())
        let settings = NSMenuItem(title: "Type AB1 Settings…", action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self
        appMenu.addItem(settings)
        appMenu.addItem(.separator())
        let servicesItem = NSMenuItem(title: "Services", action: nil, keyEquivalent: "")
        let servicesMenu = NSMenu(title: "Services")
        servicesItem.submenu = servicesMenu
        NSApp.servicesMenu = servicesMenu
        appMenu.addItem(servicesItem)
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide Type AB1", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthers = NSMenuItem(title: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthers)
        appMenu.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Type AB1", action: #selector(quitClock), keyEquivalent: "q")
        quit.target = self
        appMenu.addItem(quit)
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        let showClockItem = NSMenuItem(title: "Show Type AB1", action: #selector(showClock), keyEquivalent: "0")
        showClockItem.target = self
        windowMenu.addItem(showClockItem)
        windowMenu.addItem(.separator())
        windowMenu.addItem(withTitle: "Bring All to Front", action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)
        NSApp.windowsMenu = windowMenu

        NSApp.mainMenu = mainMenu

        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(woke), name: NSWorkspace.didWakeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(systemZoneChanged), name: .NSSystemTimeZoneDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(systemClockChanged), name: .NSSystemClockDidChange, object: nil)
        reloadWidgetTimelines()
    }

    func configureWindow() {
        window.level = model.onTop ? .floating : .normal
        if model.allSpaces {
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        } else {
            window.collectionBehavior = [.managed]
        }
        window.setContentSize(NSSize(width: model.footprint.width(for: model.sizingStandard), height: model.footprint.height(for: model.sizingStandard)))
    }

    func configureMenuBar() {
        if model.showMenuBarItem {
            if statusItem == nil {
                let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
                item.button?.image = NSImage(systemSymbolName: "clock", accessibilityDescription: "Type AB1")
                let menu = NSMenu()
                menu.delegate = self
                item.menu = menu
                statusItem = item
            }
        } else {
            if let item = statusItem {
                NSStatusBar.system.removeStatusItem(item)
                statusItem = nil
            }
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.items.removeAll()
        populateMenu(menu, context: .menuBar)
    }

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()
        populateMenu(menu, context: .dock)
        return menu
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showClock()
        return true
    }

    func populateMenu(_ menu: NSMenu, context: MenuContext) {
        if context == .dock || context == .menuBar {
            let showItem = NSMenuItem(title: "Show Type AB1", action: #selector(showClock), keyEquivalent: "")
            showItem.target = self
            menu.addItem(showItem)
        }

        let settingsItem = NSMenuItem(title: "Type AB1 Settings…", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let zoneItem = NSMenuItem(title: "Time Zone", action: nil, keyEquivalent: "")
        let zonesMenu = NSMenu(title: "Time Zone")
        let sysItem = NSMenuItem(title: "System · \(TimeZone.autoupdatingCurrent.identifier)", action: #selector(selectZone(_:)), keyEquivalent: "")
        sysItem.target = self
        sysItem.representedObject = "system"
        sysItem.state = model.zoneID == "system" ? .on : .off
        zonesMenu.addItem(sysItem)
        zonesMenu.addItem(.separator())
        for zone in ClockTime.zones {
            let item = NSMenuItem(title: zone, action: #selector(selectZone(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = zone
            item.state = model.zoneID == zone ? .on : .off
            zonesMenu.addItem(item)
        }
        zoneItem.submenu = zonesMenu
        menu.addItem(zoneItem)

        let sizeItem = NSMenuItem(title: "Clock Size", action: nil, keyEquivalent: "")
        let sizesMenu = NSMenu(title: "Clock Size")
        for standard in ClockSizingStandard.allCases {
            let item = NSMenuItem(title: standard.label, action: #selector(selectStandard(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = standard.rawValue
            item.state = model.sizingStandard == standard ? .on : .off
            sizesMenu.addItem(item)
        }
        sizesMenu.addItem(.separator())
        for size in ClockFootprint.allCases {
            let item = NSMenuItem(title: size.label(for: model.sizingStandard), action: #selector(selectSize(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = size.rawValue
            item.state = model.footprint == size ? .on : .off
            sizesMenu.addItem(item)
        }
        sizeItem.submenu = sizesMenu
        menu.addItem(sizeItem)

        let spacesItem = NSMenuItem(title: "Show on All Spaces", action: #selector(toggleSpaces), keyEquivalent: "")
        spacesItem.target = self
        spacesItem.state = model.allSpaces ? .on : .off
        menu.addItem(spacesItem)

        let topItem = NSMenuItem(title: "Always on Top", action: #selector(toggleTop), keyEquivalent: "")
        topItem.target = self
        topItem.state = model.onTop ? .on : .off
        menu.addItem(topItem)

        let menuBarToggle = NSMenuItem(title: "Show in Menu Bar", action: #selector(toggleMenuBar), keyEquivalent: "")
        menuBarToggle.target = self
        menuBarToggle.state = model.showMenuBarItem ? .on : .off
        menu.addItem(menuBarToggle)

        menu.addItem(.separator())

        let timeStr = String(format: "%02d:%02d", model.alarmHour, model.alarmMinute)
        if model.scheduling {
            let alarmItem = NSMenuItem(title: "Scheduling Alarm…", action: nil, keyEquivalent: "")
            alarmItem.isEnabled = false
            menu.addItem(alarmItem)
        } else if model.armed {
            let disarmItem = NSMenuItem(title: "Disarm Alarm (\(timeStr))", action: #selector(disarmAlarm), keyEquivalent: "")
            disarmItem.target = self
            menu.addItem(disarmItem)
        } else {
            let armItem = NSMenuItem(title: "Arm Alarm (\(timeStr))", action: #selector(armAlarm), keyEquivalent: "")
            armItem.target = self
            menu.addItem(armItem)
        }

        menu.addItem(.separator())

        let aboutItem = NSMenuItem(title: "About Type AB1…", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        if context == .clockContext || context == .menuBar {
            menu.addItem(.separator())
            let quitItem = NSMenuItem(title: "Quit Type AB1", action: #selector(quitClock), keyEquivalent: "q")
            quitItem.target = self
            menu.addItem(quitItem)
        }
    }

    /// Ask macOS to rebuild the widget's timeline after launch, wake, or a clock or
    /// time-zone change, so it never sits on an old one.
    private func reloadWidgetTimelines() {
        WidgetCenter.shared.reloadAllTimelines()
    }
    @objc func systemZoneChanged() {
        if model.zoneID == "system", model.armed {
            model.disarm(); model.message = "Your Mac’s time zone changed. Set the alarm again for the new zone."
        }
        clockView?.tick()
        reloadWidgetTimelines()
    }
    /// The Mac's clock was set or synced: show the new time and rebuild widget timelines.
    @objc func systemClockChanged() { clockView?.tick(); reloadWidgetTimelines() }
    @objc func woke() { clockView?.tick(); reloadWidgetTimelines() }
    private var clockView: NativeClockView? { window.contentView as? NativeClockView }
    @objc func showClock() {
        window.setIsVisible(true)
        window.orderFrontRegardless()
        NSApp.activate()
    }
    @objc func showSettings() {
        if settingsWindow == nil {
            let settings = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 660), styleMask: [.titled, .closable], backing: .buffered, defer: false)
            settings.title = "Type AB1 Settings"; settings.isReleasedWhenClosed = false; settings.delegate = self
            settings.contentView = NSHostingView(rootView: ClockSettings(model: model)); settings.center()
            settingsWindow = settings
        }
        NSApp.activate(); settingsWindow?.makeKeyAndOrderFront(nil)
    }
    func application(_ application: NSApplication, open urls: [URL]) { showClock() }
    @objc func showAbout() {
        if aboutWindow == nil {
            let about = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 610), styleMask: [.titled, .closable], backing: .buffered, defer: false)
            about.title = "About Type AB1"; about.isReleasedWhenClosed = false; about.delegate = self
            about.contentView = NSHostingView(rootView: ClockAbout()); about.center(); aboutWindow = about
        }
        NSApp.activate(); aboutWindow?.makeKeyAndOrderFront(nil)
    }
    func windowWillClose(_ notification: Notification) {
        guard let closing = notification.object as? NSWindow else { return }
        if closing === settingsWindow { closing.contentView = nil; settingsWindow = nil }
        if closing === aboutWindow { closing.contentView = nil; aboutWindow = nil }
    }
    @objc func quitClock() { NSApp.terminate(nil) }
    @objc func selectZone(_ item: NSMenuItem) {
        if let zone = item.representedObject as? String { model.zoneID = zone }
    }
    @objc func selectStandard(_ item: NSMenuItem) {
        if let value = item.representedObject as? String, let standard = ClockSizingStandard(rawValue: value) {
            model.sizingStandard = standard
        }
    }
    @objc func selectSize(_ item: NSMenuItem) {
        if let value = item.representedObject as? String, let size = ClockFootprint(rawValue: value) {
            model.footprint = size
        }
    }
    @objc func toggleSpaces() { model.allSpaces.toggle() }
    @objc func toggleTop() { model.onTop.toggle() }
    @objc func toggleMenuBar() { model.showMenuBarItem.toggle() }
    @objc func armAlarm() { model.arm() }
    @objc func disarmAlarm() { model.disarm() }
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
            Picker("Clock size", selection: $model.footprint) {
                ForEach(ClockFootprint.allCases) { Text($0.label(for: model.sizingStandard)).tag($0) }
            }
            Text("The complete clock, including its raised button, fits inside the chosen size. Match Calendar uses a 170-point small clock; Native Mac uses 164.").font(.caption).foregroundStyle(.secondary)
            Toggle("Show on all Spaces", isOn: $model.allSpaces)
            Toggle("Always on top", isOn: $model.onTop)
            Text(model.onTop ? "Floats above other windows." : "Sits among your windows like any other. Stays on one Space unless Show on all Spaces is on.").font(.caption).foregroundStyle(.secondary)
            Toggle("Show in menu bar", isOn: $model.showMenuBarItem)
            Text(model.showMenuBarItem ? "Displays a Type AB1 icon in the macOS menu bar." : "Off by default. Access Type AB1 via the Dock icon and right-click menu.").font(.caption).foregroundStyle(.secondary)
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
            Text("Drag the housing to move. Right-click or use the Dock for settings and controls. For the desktop widget, choose Edit Widgets and look for Type AB1 (small or large).").font(.caption).foregroundStyle(.secondary)
            Button("About this little clock…") { model.openAbout?() }
        }.formStyle(.grouped).padding().frame(width: 460, height: 660)
    }
}
