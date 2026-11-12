import SwiftUI
import WidgetKit
import AppIntents

// MARK: - Configuration

enum ClockCity: String, AppEnum {
    case system, adelaide, sydney, perth, london, auckland, newYork, tokyo, utc
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "City"
    static var caseDisplayRepresentations: [ClockCity: DisplayRepresentation] = [
        .system: "System time zone", .adelaide: "Adelaide", .sydney: "Sydney", .perth: "Perth", .london: "London",
        .auckland: "Auckland", .newYork: "New York", .tokyo: "Tokyo", .utc: "UTC"
    ]
    var zoneID: String {
        switch self {
        case .system: TimeZone.autoupdatingCurrent.identifier
        case .adelaide: "Australia/Adelaide"
        case .sydney: "Australia/Sydney"
        case .perth: "Australia/Perth"
        case .london: "Europe/London"
        case .auckland: "Pacific/Auckland"
        case .newYork: "America/New_York"
        case .tokyo: "Asia/Tokyo"
        case .utc: "UTC"
        }
    }
    var title: String {
        switch self {
        case .system: "System clock"
        case .adelaide: "Adelaide"
        case .sydney: "Sydney"
        case .perth: "Perth"
        case .london: "London"
        case .auckland: "Auckland"
        case .newYork: "New York"
        case .tokyo: "Tokyo"
        case .utc: "UTC"
        }
    }
}

struct CityConfiguration: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Clock city"
    static var description = IntentDescription("Choose the time zone shown on this clock.")
    @Parameter(title: "City", default: .system) var city: ClockCity
}

// MARK: - Timeline

/// The zone is resolved once when the timeline is built, so every entry in
/// one timeline agrees with itself even if the system zone changes mid-hour.
/// The view re-resolves `.autoupdatingCurrent` only as a fallback.
struct ClockEntry: TimelineEntry {
    let date: Date
    let city: ClockCity
    let zoneID: String
    let style: ClockStyle

    init(date: Date, city: ClockCity, zoneID: String? = nil, style: ClockStyle = WidgetStyle.cube) {
        self.date = date
        self.city = city
        self.zoneID = zoneID ?? city.zoneID
        self.style = style
    }

    var zone: TimeZone {
        // .system must track the Mac live so travel / DST / Settings changes
        // stay correct even before the next hourly timeline rebuild.
        // Fixed cities use the snapshot captured at timeline-build time.
        if city == .system { return TimeZone.autoupdatingCurrent }
        return TimeZone(identifier: zoneID) ?? TimeZone.autoupdatingCurrent
    }
}

enum ClockTimeline {
    /// How far ahead each timeline reaches, and when macOS is asked for the next one.
    /// Asking well before the end leaves two spare hours, so a late or skipped
    /// refresh never freezes the hands on an old time.
    static let span: TimeInterval = 3 * 3600
    static let refreshAfter: TimeInterval = 3600

    /// One entry per minute. The first is the current minute (floored), so there is
    /// always something valid to show right now.
    static func entries(for city: ClockCity, style: ClockStyle = WidgetStyle.cube, now: Date = Date()) -> [ClockEntry] {
        let zoneID = city.zoneID
        return ClockTime.minuteDates(from: now, count: Int(span / 60))
            .map { ClockEntry(date: $0, city: city, zoneID: zoneID, style: style) }
    }

    static func timeline(for city: ClockCity, style: ClockStyle = WidgetStyle.cube, now: Date = Date()) -> Timeline<ClockEntry> {
        let entries = entries(for: city, style: style, now: now)
        let refresh = entries[0].date.addingTimeInterval(refreshAfter)
        return Timeline(entries: entries, policy: .after(refresh))
    }
}

struct ClockProvider: AppIntentTimelineProvider {
    var style: ClockStyle
    func placeholder(in context: Context) -> ClockEntry {
        ClockEntry(date: Date(), city: .system, style: style)
    }
    func snapshot(for configuration: CityConfiguration, in context: Context) async -> ClockEntry {
        ClockEntry(date: Date(), city: configuration.city, style: style)
    }
    func timeline(for configuration: CityConfiguration, in context: Context) async -> Timeline<ClockEntry> {
        // No timer runs in the extension: precompute three hours of minute positions.
        ClockTimeline.timeline(for: configuration.city, style: style)
    }
}

struct SystemClockProvider: TimelineProvider {
    var style: ClockStyle
    func placeholder(in context: Context) -> ClockEntry {
        ClockEntry(date: Date(), city: .system, style: style)
    }
    func getSnapshot(in context: Context, completion: @escaping (ClockEntry) -> Void) {
        completion(ClockEntry(date: Date(), city: .system, style: style))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<ClockEntry>) -> Void) {
        completion(ClockTimeline.timeline(for: .system, style: style))
    }
}

/// The look of each widget. Finishes follow the Mac's appearance: black in Dark Mode, white in Light.
enum WidgetStyle {
    static let cube = ClockStyle(family: .cube, finish: .automatic)
    static let arch = ClockStyle(family: .arch, finish: .automatic, hands: .lume, dialText: true)
    static let wall = ClockStyle(family: .wall, finish: .automatic)
}

// MARK: - View

struct ClockWidgetView: View {
    let entry: ClockEntry
    var body: some View {
        ClockWidgetContent(entry: entry)
            .containerBackground(for: .widget) { Color.clear }
            .widgetURL(URL(string: "typeab1://show"))
    }
}

struct ClockWidgetContent: View {
    let entry: ClockEntry
    var body: some View {
        ClockFaceView(date: entry.date, zone: entry.zone, style: entry.style, showSeconds: false)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

@main
struct TypeAB1Widgets: WidgetBundle {
    var body: some Widget {
        CubeClockWidget()
        ArchClockWidget()
        WallClockWidget()
    }
}

/// One widget per clock family, all built the same way.
private func clockWidget(kind: String, name: String, description: String, style: ClockStyle,
                         families: [WidgetFamily]) -> some WidgetConfiguration {
    #if CLOCK_APP_INTENTS
    AppIntentConfiguration(kind: kind, intent: CityConfiguration.self, provider: ClockProvider(style: style)) { entry in ClockWidgetView(entry: entry) }
        .configurationDisplayName(name)
        .description(description)
        .supportedFamilies(families)
        .contentMarginsDisabled()
    #else
    // A fully native system-clock widget without an App Intents metadata dependency.
    StaticConfiguration(kind: kind, provider: SystemClockProvider(style: style)) { entry in ClockWidgetView(entry: entry) }
        .configurationDisplayName(name)
        .description(description)
        .supportedFamilies(families)
        .contentMarginsDisabled()
    #endif
}

struct CubeClockWidget: Widget {
    /// Kept from the first release: changing it would remove widgets already placed.
    let kind = "BraunClockWidget"
    var body: some WidgetConfiguration {
        clockWidget(kind: kind, name: "Type AB1", description: "The square desk clock, purely analog. Updates when macOS allows.",
                    style: WidgetStyle.cube, families: [.systemSmall, .systemLarge])
    }
}

struct ArchClockWidget: Widget {
    var body: some WidgetConfiguration {
        clockWidget(kind: "TypeAB1ArchWidget", name: "Type AB1 Arch", description: "The arched desk clock, with luminous hands.",
                    style: WidgetStyle.arch, families: [.systemSmall, .systemLarge])
    }
}

struct WallClockWidget: Widget {
    var body: some WidgetConfiguration {
        clockWidget(kind: "TypeAB1WallWidget", name: "Type AB1 Wall", description: "A round wall clock for your desktop.",
                    style: WidgetStyle.wall, families: [.systemSmall, .systemLarge])
    }
}
