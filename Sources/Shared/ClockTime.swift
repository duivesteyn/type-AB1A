import Foundation

struct HandAngles {
    let hour: Double
    let minute: Double
    let second: Double
    static func at(_ date: Date, zone: TimeZone, showSeconds: Bool = true) -> HandAngles {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let c = calendar.dateComponents([.hour, .minute, .second], from: date)
        let h = Double(c.hour ?? 0), m = Double(c.minute ?? 0)
        let s = showSeconds ? Double(c.second ?? 0) : 0
        return HandAngles(hour: 30 * (h.truncatingRemainder(dividingBy: 12) + m / 60 + s / 3600),
                          minute: 6 * (m + s / 60), second: 6 * s)
    }
}

enum ClockTime {
    static let zones = ["Australia/Adelaide", "Australia/Sydney", "Australia/Perth", "Europe/London", "Pacific/Auckland", "America/New_York", "Asia/Tokyo", "UTC"]
    static func nextAlarm(after date: Date, hour: Int, minute: Int, zone: TimeZone) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        return calendar.nextDate(after: date, matching: DateComponents(hour: hour, minute: minute, second: 0),
                                 matchingPolicy: .nextTime, repeatedTimePolicy: .first, direction: .forward)
    }
    static func minuteDates(from date: Date, count: Int = 60) -> [Date] {
        let first = floor(date.timeIntervalSince1970 / 60) * 60
        return (0..<count).map { Date(timeIntervalSince1970: first + Double($0 * 60)) }
    }
}
