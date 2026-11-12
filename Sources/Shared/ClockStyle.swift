import Foundation

/// The shape of clock on the desk.
enum ClockFamily: String, Codable, CaseIterable, Identifiable {
    /// The square desk alarm clock: the original Type AB1.
    case cube
    /// A desk alarm clock with a round-topped, tower-like case and an alarm slider in its base.
    case arch
    /// A round wall clock with a broad rim and a domed crystal.
    case wall

    var id: String { rawValue }
    var name: String {
        switch self {
        case .cube: "Cube"
        case .arch: "Arch"
        case .wall: "Wall"
        }
    }
    /// Finishes this family is made in, in menu order.
    var finishes: [ClockFinish] {
        switch self {
        case .cube: [.automatic, .black, .white, .lagoon]
        case .arch: [.automatic, .black, .white]
        case .wall: [.automatic, .white, .black]
        }
    }
}

/// Case and dial colour.
enum ClockFinish: String, Codable, CaseIterable, Identifiable {
    /// Black in Dark Mode, white in Light Mode.
    case automatic
    case black
    case white
    /// White case with a glossy teal-blue dial (cube only).
    case lagoon

    var id: String { rawValue }
    var name: String {
        switch self {
        case .automatic: "Match appearance"
        case .black: "Black"
        case .white: "White"
        case .lagoon: "Lagoon"
        }
    }
    func resolved(dark: Bool) -> ClockFinish { self == .automatic ? (dark ? .black : .white) : self }
}

/// What marks the twelve hour positions.
enum ClockNumerals: String, Codable, CaseIterable, Identifiable {
    case hours, minutes, roman, quarters, none
    var id: String { rawValue }
    var name: String {
        switch self {
        case .hours: "1 – 12"
        case .minutes: "5 – 60"
        case .roman: "Roman"
        case .quarters: "12 · 3 · 6 · 9"
        case .none: "None"
        }
    }
    /// The label at an hour position, 1...12 with 12 at the top.
    func label(_ position: Int) -> String? {
        switch self {
        case .hours: return "\(position)"
        case .minutes: return "\(position * 5)"
        case .roman: return ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII"][position - 1]
        case .quarters: return position % 3 == 0 ? "\(position)" : nil
        case .none: return nil
        }
    }
}

/// Hand colours. Ink is white on dark dials and near-black on light ones.
enum ClockHands: String, Codable, CaseIterable, Identifiable {
    /// Ink hour and minute hands, yellow seconds and hub.
    case classic
    /// Classic, with a pale mint luminous strip in the hour and minute hands.
    case lume
    /// A red minute hand: easy to read at a glance.
    case redMinute
    /// Red seconds and hub, like a station clock.
    case redSeconds
    case allRed
    case mono

    var id: String { rawValue }
    var name: String {
        switch self {
        case .classic: "Classic"
        case .lume: "Luminous"
        case .redMinute: "Red minute"
        case .redSeconds: "Red seconds"
        case .allRed: "All red"
        case .mono: "Monochrome"
        }
    }
}

/// How the seconds hand moves.
enum SecondsMotion: String, Codable, CaseIterable, Identifiable {
    case tick, sweep, hidden
    var id: String { rawValue }
    var name: String {
        switch self {
        case .tick: "Tick"
        case .sweep: "Sweep"
        case .hidden: "Off"
        }
    }
}

/// Everything that decides how the clock looks. Stored as JSON in the app's defaults.
struct ClockStyle: Codable, Hashable {
    var family: ClockFamily = .cube
    var finish: ClockFinish = .black
    var numerals: ClockNumerals = .hours
    var hands: ClockHands = .classic
    var seconds: SecondsMotion = .tick
    /// A small date window in place of the 3.
    var dateWindow = false
    /// "quartz", printed small below the centre.
    var dialText = false
    /// Crystal reflection over the dial.
    var glass = true

    static let standard = ClockStyle()

    init(family: ClockFamily = .cube, finish: ClockFinish = .black, numerals: ClockNumerals = .hours,
         hands: ClockHands = .classic, seconds: SecondsMotion = .tick, dateWindow: Bool = false,
         dialText: Bool = false, glass: Bool = true) {
        self.family = family; self.finish = finish; self.numerals = numerals; self.hands = hands
        self.seconds = seconds; self.dateWindow = dateWindow; self.dialText = dialText; self.glass = glass
    }

    /// Tolerates missing or unknown values, so older and newer saved styles both load.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func value<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T { (try? c.decodeIfPresent(T.self, forKey: key)) ?? fallback }
        let d = ClockStyle()
        family = value(.family, d.family); finish = value(.finish, d.finish); numerals = value(.numerals, d.numerals)
        hands = value(.hands, d.hands); seconds = value(.seconds, d.seconds); dateWindow = value(.dateWindow, d.dateWindow)
        dialText = value(.dialText, d.dialText); glass = value(.glass, d.glass)
        self = normalised()
    }

    /// Keep the finish to one this family is made in.
    func normalised() -> ClockStyle {
        var style = self
        if !family.finishes.contains(finish) { style.finish = family.finishes.dropFirst().first ?? .automatic }
        return style
    }

    /// Identifies everything drawn into the cached still layers.
    func cacheKey(dark: Bool) -> String {
        [family.rawValue, finish.resolved(dark: dark).rawValue, numerals.rawValue, hands.rawValue,
         dateWindow ? "d" : "", dialText ? "q" : "", glass ? "g" : ""].joined(separator: "-")
    }
}

/// Named starting points, shown as a gallery in Settings and in the right-click menu.
struct ClockPreset: Identifiable {
    let id: String
    let name: String
    let style: ClockStyle

    static let all: [ClockPreset] = [
        ClockPreset(id: "ab1", name: "Type AB1", style: ClockStyle()),
        ClockPreset(id: "ab1-white", name: "Type AB1 White", style: ClockStyle(finish: .white)),
        ClockPreset(id: "lagoon", name: "Lagoon", style: ClockStyle(finish: .lagoon, hands: .mono, seconds: .sweep, dialText: true)),
        ClockPreset(id: "arch-night", name: "Arch Night", style: ClockStyle(family: .arch, finish: .black, hands: .lume, dialText: true)),
        ClockPreset(id: "arch-day", name: "Arch Day", style: ClockStyle(family: .arch, finish: .white, hands: .lume, dialText: true)),
        ClockPreset(id: "stopwatch", name: "Stopwatch", style: ClockStyle(family: .arch, finish: .white, numerals: .minutes, hands: .lume, seconds: .sweep)),
        ClockPreset(id: "station", name: "Station", style: ClockStyle(family: .wall, finish: .white, numerals: .none, hands: .redSeconds, seconds: .sweep)),
        ClockPreset(id: "studio", name: "Studio", style: ClockStyle(family: .wall, finish: .black, numerals: .minutes, hands: .redMinute, seconds: .sweep)),
        ClockPreset(id: "salon", name: "Salon", style: ClockStyle(family: .wall, finish: .white, numerals: .roman, hands: .mono, dateWindow: true)),
    ]

    /// The preset this style matches, if any. Seconds motion is a per-family setting, not part of a preset.
    static func matching(_ style: ClockStyle) -> ClockPreset? {
        all.first { preset in
            var a = preset.style
            a.seconds = style.seconds
            return a == style
        }
    }
}
