import SwiftUI
import AppKit

enum SettingsTab: Int, CaseIterable {
    case clock, style, alarm
    var title: String {
        switch self { case .clock: "Clock"; case .style: "Style"; case .alarm: "Alarm" }
    }
    var symbol: String {
        switch self { case .clock: "clock"; case .style: "paintpalette"; case .alarm: "alarm" }
    }
}

/// A standard Mac settings window: toolbar tabs, each a grouped SwiftUI form.
/// Created on demand and released on close, so the idle clock carries no SwiftUI.
@MainActor final class SettingsWindowController: NSWindowController {
    private let tabs = SettingsTabs()

    init(model: ClockModel) {
        tabs.tabStyle = .toolbar
        for tab in SettingsTab.allCases {
            let pane: AnyView = switch tab {
            case .clock: AnyView(ClockPane(model: model))
            case .style: AnyView(StylePane(model: model))
            case .alarm: AnyView(AlarmPane(model: model))
            }
            let host = NSHostingController(rootView: pane)
            host.sizingOptions = [.preferredContentSize]
            host.title = tab.title
            let item = NSTabViewItem(viewController: host)
            item.label = tab.title
            item.image = NSImage(systemSymbolName: tab.symbol, accessibilityDescription: tab.title)
            tabs.addTabViewItem(item)
        }
        let window = NSWindow(contentViewController: tabs)
        window.styleMask = [.titled, .closable]
        window.toolbarStyle = .preference
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.center()
    }
    required init?(coder: NSCoder) { fatalError("Use init(model:)") }

    /// Bring the window forward, switching tab only when asked.
    func show(_ tab: SettingsTab?) {
        if let tab { tabs.selectedTabViewItemIndex = tab.rawValue }
        window?.title = tabs.tabViewItems[tabs.selectedTabViewItemIndex].label
        NSApp.activate()
        showWindow(nil)
    }
}

/// Titles the window after the selected tab, like System Settings panes.
private final class SettingsTabs: NSTabViewController {
    override func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        super.tabView(tabView, didSelect: tabViewItem)
        view.window?.title = tabViewItem?.label ?? "Settings"
    }
    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.title = tabViewItems[selectedTabViewItemIndex].label
    }
}

// MARK: - Clock

private struct ClockPane: View {
    @ObservedObject var model: ClockModel

    var body: some View {
        Form {
            Section {
                Picker("Time zone", selection: $model.zoneID) {
                    Text("System (\(ClockTime.cityName(TimeZone.autoupdatingCurrent.identifier)))").tag("system")
                    Divider()
                    ForEach(ClockTime.zones, id: \.self) { Text(ClockTime.cityName($0)).tag($0) }
                }
            } header: {
                Text("Time")
            } footer: {
                footnote("Always reads your Mac’s clock. A city changes only what this clock shows, daylight saving included.")
            }

            Section {
                Picker("Clock", selection: $model.footprint) {
                    ForEach(ClockFootprint.allCases) { Text($0.rawValue.capitalized).tag($0) }
                }
                .pickerStyle(.segmented)
                Picker("Sized like", selection: $model.sizingStandard) {
                    Text("Calendar widgets").tag(ClockSizingStandard.calendar)
                    Text("Native Mac widgets").tag(ClockSizingStandard.nativeMac)
                }
            } header: {
                Text("Size")
            } footer: {
                footnote("\(Int(model.footprint.width(for: model.sizingStandard))) × \(Int(model.footprint.height(for: model.sizingStandard))) points. The whole clock fits inside, alarm control included.")
            }

            Section {
                Toggle("Show on all Spaces", isOn: $model.allSpaces)
                Toggle("Always on top", isOn: $model.onTop)
            } header: {
                Text("Placement")
            } footer: {
                footnote("Drag the clock to move it. For the desktop widget, right-click the desktop and choose Edit Widgets.")
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .frame(width: 520, height: 470)
    }
}

// MARK: - Style

private struct StylePane: View {
    @ObservedObject var model: ClockModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Form {
            Section {
                TimelineView(.periodic(from: .now, by: model.style.seconds == .sweep ? 1.0 / 20 : 1)) { context in
                    ClockFaceView(date: context.date, zone: model.zone, style: model.style)
                        .frame(height: 170)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 12) {
                    ForEach(ClockPreset.all) { preset in
                        PresetTile(preset: preset, dark: colorScheme == .dark,
                                   selected: ClockPreset.matching(model.style)?.id == preset.id) {
                            model.apply(preset)
                        }
                    }
                }
                .padding(.vertical, 4)
            } footer: {
                footnote("Pick a starting point, then make it yours below. Your clock changes as you go.")
            }

            Section("Clock") {
                Picker("Family", selection: Binding(get: { model.style.family }, set: { model.setFamily($0) })) {
                    ForEach(ClockFamily.allCases) { Text($0.name).tag($0) }
                }
                .pickerStyle(.segmented)
                Picker("Finish", selection: binding(\.finish)) {
                    ForEach(model.style.family.finishes) { Text($0.name).tag($0) }
                }
            }

            Section {
                Picker("Numerals", selection: binding(\.numerals)) {
                    ForEach(ClockNumerals.allCases) { Text($0.name).tag($0) }
                }
                Picker("Hands", selection: binding(\.hands)) {
                    ForEach(ClockHands.allCases) { Text($0.name).tag($0) }
                }
                Picker("Seconds", selection: binding(\.seconds)) {
                    ForEach(SecondsMotion.allCases) { Text($0.name).tag($0) }
                }
                .pickerStyle(.segmented)
                Toggle("Date window", isOn: binding(\.dateWindow))
                Toggle("“quartz” on the dial", isOn: binding(\.dialText))
                Toggle("Crystal reflection", isOn: binding(\.glass))
            } header: {
                Text("Dial")
            } footer: {
                footnote("Each clock remembers its own seconds, so the \(model.style.family.name.lowercased()) can sweep while the others tick. The date window replaces the 3.")
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 700)
    }

    private func binding<T>(_ path: WritableKeyPath<ClockStyle, T>) -> Binding<T> {
        Binding(get: { model.style[keyPath: path] },
                set: { var style = model.style; style[keyPath: path] = $0; model.style = style.normalised() })
    }
}

/// A preset thumbnail: the clock at 10:10, its name, and a ring when it matches.
private struct PresetTile: View {
    let preset: ClockPreset
    let dark: Bool
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                if let image = PresetThumbnails.image(preset, dark: dark) {
                    Image(decorative: image, scale: 2)
                        .resizable().interpolation(.high).aspectRatio(contentMode: .fit)
                        .frame(height: 64)
                }
                Text(preset.name).font(.caption).lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 10).fill(selected ? Color.accentColor.opacity(0.15) : Color.clear))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(selected ? Color.accentColor : Color.clear, lineWidth: 2))
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(preset.name)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Rendered once per appearance and kept while Settings is open.
@MainActor private enum PresetThumbnails {
    private static var cache: [String: CGImage] = [:]
    private static let moment = ISO8601DateFormatter().date(from: "2026-01-01T10:10:30Z")!
    static func image(_ preset: ClockPreset, dark: Bool) -> CGImage? {
        let key = preset.id + (dark ? "-d" : "-l")
        if let image = cache[key] { return image }
        let crop = ClockRender.face(preset.style).crop(preset.style)
        let width = Int(max(128, 128 * crop.width / crop.height))
        let image = ClockRaster.composite(pixels: width, date: moment, zone: TimeZone(identifier: "UTC")!, style: preset.style, dark: dark)
        cache[key] = image
        return image
    }
    static func clear() { cache.removeAll() }
}

// MARK: - Alarm

private struct AlarmPane: View {
    @ObservedObject var model: ClockModel

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    Image(systemName: model.armed ? "alarm.fill" : "alarm")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(model.armed ? Color.green : Color.secondary)
                        .frame(width: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.armed ? "Armed" : model.scheduling ? "Arming…" : "Off").font(.headline)
                        Text(status).font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(model.armed ? "Disarm" : "Arm") { model.armed ? model.disarm() : model.arm() }
                        .buttonStyle(.borderedProminent)
                        .tint(model.armed ? .gray : .accentColor)
                        .controlSize(.large)
                        .disabled(model.scheduling)
                        .keyboardShortcut(.defaultAction)
                }
                .padding(.vertical, 4)
            }

            Section {
                DatePicker("Time", selection: time, displayedComponents: .hourAndMinute)
                    .disabled(model.armed || model.scheduling)
                LabeledContent("City", value: ClockTime.cityName(model.zone.identifier))
            } footer: {
                footnote("Rings once, as a macOS notification with its default sound. Focus, sleep and notification settings can delay or silence it. Changing city disarms it.")
            }

            if !model.message.isEmpty {
                Section {
                    Label(model.message, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .frame(width: 520, height: model.message.isEmpty ? 236 : 296)
    }

    private var status: String {
        if let alarm = model.nextAlarm {
            return "Rings " + alarm.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened, timeZone: model.zone))
        }
        return "Set a time and arm it. The clock shows it is armed, as the real one does."
    }

    /// The alarm's hour and minute, shown and edited as a time of day.
    private var time: Binding<Date> {
        Binding {
            Calendar.current.date(bySettingHour: model.alarmHour, minute: model.alarmMinute, second: 0, of: Date()) ?? Date()
        } set: { date in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            model.alarmHour = parts.hour ?? model.alarmHour
            model.alarmMinute = parts.minute ?? model.alarmMinute
        }
    }
}

private func footnote(_ text: String) -> some View {
    Text(text).font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
}
