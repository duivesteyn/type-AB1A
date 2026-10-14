import SwiftUI
import AppKit
import Darwin

struct ClockAppIcon: View {
    private let reference = ISO8601DateFormatter().date(from: "2026-01-01T10:10:30Z")!
    var body: some View {
        GeometryReader { geometry in
            let side = geometry.size.width
            FittedClockArtwork(date: reference, zone: TimeZone(identifier: "UTC")!)
                .shadow(color: .black.opacity(0.35), radius: side * 0.035, y: side * 0.025)
        }.aspectRatio(1, contentMode: .fit)
    }
}

@MainActor final class IdleMeasurement: ObservableObject {
    @Published var summary = "One tick a second. No network. No busy loop."
    @Published var measuring = false
    private func footprintMiB() -> Double? {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? Double(info.phys_footprint) / 1_048_576 : nil
    }
    private func cpuSeconds(_ value: rusage) -> Double {
        Double(value.ru_utime.tv_sec + value.ru_stime.tv_sec) + Double(value.ru_utime.tv_usec + value.ru_stime.tv_usec) / 1_000_000
    }
    func measure() {
        guard !measuring else { return }
        measuring = true; summary = "Measuring this process for 10 seconds…"
        var start = rusage(); getrusage(RUSAGE_SELF, &start)
        let began = ProcessInfo.processInfo.systemUptime
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(10))
            var end = rusage(); getrusage(RUSAGE_SELF, &end)
            let elapsed = ProcessInfo.processInfo.systemUptime - began
            let percent = 100 * (cpuSeconds(end) - cpuSeconds(start)) / elapsed
            if let memory = footprintMiB() {
                summary = String(format: "Last 10 s: %.2f%% of one CPU core · %.1f MB current footprint", percent, memory)
            } else { summary = String(format: "Last 10 s: %.2f%% of one CPU core · memory unavailable", percent) }
            measuring = false
        }
    }
}

struct ClockAbout: View {
    @StateObject private var performance = IdleMeasurement()
    var body: some View {
        VStack(spacing: 16) {
            ClockAppIcon().frame(width: 116, height: 116)
            VStack(spacing: 4) {
                Text("Type AB1").font(.system(size: 34, weight: .medium, design: .rounded))
                Text("A little square. A yellow second. A quieter desktop.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Text("An ode to the Braun AB 1")
                .font(.headline)
            Text("O little square of sensible things,\nwith yellow feet and minute wings,\nno feed to scroll, no world to save —\njust time, behaving. Mostly. Brave.")
                .font(.system(size: 15, design: .serif)).italic().multilineTextAlignment(.center).lineSpacing(4)
            Text("Inspired by Dietrich Lubs’s Braun AB 1 (1987), and the clarity of Braun’s design tradition under Dieter Rams. A small digital thank-you to an object that knew when to stop designing.")
                .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            HStack {
                Link("Meet the original ↗", destination: URL(string: "https://www.broehan-museum.de/wp-content/uploads/Bildliste_Braun100.pdf")!)
                Text("·")
                Text("Made by Benjamin Duivesteyn")
            }.font(.caption)
            Text("Independent tribute · SwiftUI + AppKit + WidgetKit · MIT source")
                .font(.caption2).foregroundStyle(.secondary)
            Divider()
            Text(performance.summary).font(.caption).multilineTextAlignment(.center)
            Button(performance.measuring ? "Measuring…" : "Measure idle use") { performance.measure() }
                .disabled(performance.measuring).controlSize(.small)
            Text("Alarms use macOS notifications. No accounts, analytics or network requests.")
                .font(.caption2).foregroundStyle(.secondary)
        }.padding(30).frame(width: 480, height: 610)
    }
}
