import Foundation

@main struct ClockTimeTests {
    static func main() {
        let iso = ISO8601DateFormatter()
        func date(_ value: String) -> Date { iso.date(from: value)! }
        func close(_ a: Double, _ b: Double) { precondition(abs(a-b) < 0.00001, "\(a) != \(b)") }
        let utc = TimeZone(identifier: "UTC")!
        let london = TimeZone(identifier: "Europe/London")!
        let adelaide = TimeZone(identifier: "Australia/Adelaide")!
        let rollover = HandAngles.at(date("2026-10-12T23:59:59Z"), zone: utc)
        close(rollover.second, 354)
        close(HandAngles.at(date("2026-10-13T00:00:00Z"), zone: utc).hour, 0)
        let half = HandAngles.at(date("2026-06-01T00:00:00Z"), zone: adelaide)
        close(half.hour, 285); close(half.minute, 180)
        let summer = HandAngles.at(date("2026-10-13T00:00:00Z"), zone: adelaide)
        close(summer.hour, 315)
        close(HandAngles.at(date("2026-03-29T00:59:00Z"), zone: london).hour, 29.5)
        close(HandAngles.at(date("2026-03-29T01:00:00Z"), zone: london).hour, 60)
        close(HandAngles.at(date("2026-10-25T00:59:00Z"), zone: london).hour, 59.5)
        close(HandAngles.at(date("2026-10-25T01:00:00Z"), zone: london).hour, 30)
        precondition(ClockTime.nextAlarm(after: date("2026-10-13T07:01:00Z"), hour: 7, minute: 0, zone: utc) == date("2026-10-14T07:00:00Z"))
        precondition(ClockTime.nextAlarm(after: date("2026-03-29T00:59:00Z"), hour: 1, minute: 30, zone: london) == date("2026-03-29T01:00:00Z"))
        let entries = ClockTime.minuteDates(from: date("2026-10-13T09:31:45Z"))
        precondition(entries.count == 60 && entries.first == date("2026-10-13T09:31:00Z"))
        precondition(entries.last == date("2026-10-13T10:30:00Z"))
        close(HandAngles.at(date("2026-10-13T09:31:45Z"), zone: utc, showSeconds: false).minute, 186)
        print("Passed clock rollover, half-hour zone, DST, alarm and widget timeline checks.")
    }
}
