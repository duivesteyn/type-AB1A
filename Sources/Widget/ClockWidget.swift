import SwiftUI
import WidgetKit
import AppIntents

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
struct ClockEntry: TimelineEntry {
    let date: Date
    let city: ClockCity
}
struct ClockProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> ClockEntry { ClockEntry(date: Date(), city: .system) }
    func snapshot(for configuration: CityConfiguration, in context: Context) async -> ClockEntry { ClockEntry(date: Date(), city: configuration.city) }
    func timeline(for configuration: CityConfiguration, in context: Context) async -> Timeline<ClockEntry> {
        // Precompute an hour of minute positions; no timer runs in the extension.
        let dates = ClockTime.minuteDates(from: Date())
        return Timeline(entries: dates.map { ClockEntry(date: $0, city: configuration.city) },
                        policy: .after(dates.last!.addingTimeInterval(60)))
    }
}
struct ClockWidgetView: View {
    let entry: ClockEntry
    @Environment(\.widgetFamily) private var family
    var body: some View {
        ClockWidgetContent(entry: entry, family: family)
            .containerBackground(for: .widget) { Color.clear }
            .widgetURL(URL(string: "braunclock://show"))
    }
}
struct ClockWidgetContent: View {
    let entry: ClockEntry
    let family: WidgetFamily
    var body: some View {
        FittedClockArtwork(date: entry.date, zone: TimeZone(identifier: entry.city.zoneID)!, showSeconds: false)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}
struct SystemClockProvider: TimelineProvider {
    func placeholder(in context: Context) -> ClockEntry { ClockEntry(date: Date(), city: .system) }
    func getSnapshot(in context: Context, completion: @escaping (ClockEntry) -> Void) {
        completion(ClockEntry(date: Date(), city: .system))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<ClockEntry>) -> Void) {
        let dates = ClockTime.minuteDates(from: Date())
        completion(Timeline(entries: dates.map { ClockEntry(date: $0, city: .system) },
                            policy: .after(dates.last!.addingTimeInterval(60))))
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
            .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
            .contentMarginsDisabled()
        #else
        // A fully native system-clock widget without an App Intents metadata dependency.
        StaticConfiguration(kind: kind, provider: SystemClockProvider()) { entry in ClockWidgetView(entry: entry) }
            .configurationDisplayName("Type AB1")
            .description("Your Mac’s system time, purely analog. Updates when macOS allows.")
            .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
            .contentMarginsDisabled()
        #endif
    }
}
