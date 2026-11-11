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

    init(date: Date, city: ClockCity, zoneID: String? = nil) {
        self.date = date
        self.city = city
        self.zoneID = zoneID ?? city.zoneID
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
    static func entries(for city: ClockCity, now: Date = Date()) -> [ClockEntry] {
        let zoneID = city.zoneID
        return ClockTime.minuteDates(from: now, count: Int(span / 60))
            .map { ClockEntry(date: $0, city: city, zoneID: zoneID) }
    }

    static func timeline(for city: ClockCity, now: Date = Date()) -> Timeline<ClockEntry> {
        let entries = entries(for: city, now: now)
        let refresh = entries[0].date.addingTimeInterval(refreshAfter)
        return Timeline(entries: entries, policy: .after(refresh))
    }
}

struct ClockProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> ClockEntry {
        ClockEntry(date: Date(), city: .system)
    }
    func snapshot(for configuration: CityConfiguration, in context: Context) async -> ClockEntry {
        ClockEntry(date: Date(), city: configuration.city)
    }
    func timeline(for configuration: CityConfiguration, in context: Context) async -> Timeline<ClockEntry> {
        // No timer runs in the extension: precompute three hours of minute positions.
        ClockTimeline.timeline(for: configuration.city)
    }
}

struct SystemClockProvider: TimelineProvider {
    func placeholder(in context: Context) -> ClockEntry {
        ClockEntry(date: Date(), city: .system)
    }
    func getSnapshot(in context: Context, completion: @escaping (ClockEntry) -> Void) {
        completion(ClockEntry(date: Date(), city: .system))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<ClockEntry>) -> Void) {
        completion(ClockTimeline.timeline(for: .system))
    }
}

// MARK: - View

struct ClockWidgetView: View {
    let entry: ClockEntry
    var body: some View {
        ClockWidgetContent(entry: entry)
            .containerBackground(for: .widget) { Color.clear }
            .widgetURL(URL(string: "braunclock://show"))
    }
}

struct ClockWidgetContent: View {
    let entry: ClockEntry
    var body: some View {
        ClockFaceView(date: entry.date, zone: entry.zone, showSeconds: false)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

@main
struct BraunClockWidget: Widget {
    let kind = "BraunClockWidget"
    var body: some WidgetConfiguration {
        #if CLOCK_APP_INTENTS
        AppIntentConfiguration(kind: kind, intent: CityConfiguration.self, provider: ClockProvider()) { entry in ClockWidgetView(entry: entry) }
            .configurationDisplayName("Type AB1")
            .description("Your system clock, in a little analog square. Updates when macOS allows.")
            .supportedFamilies([.systemSmall, .systemLarge])
            .contentMarginsDisabled()
        #else
        // A fully native system-clock widget without an App Intents metadata dependency.
        StaticConfiguration(kind: kind, provider: SystemClockProvider()) { entry in ClockWidgetView(entry: entry) }
            .configurationDisplayName("Type AB1")
            .description("Your Mac’s system time, purely analog. Updates when macOS allows.")
            .supportedFamilies([.systemSmall, .systemLarge])
            .contentMarginsDisabled()
        #endif
    }
}
