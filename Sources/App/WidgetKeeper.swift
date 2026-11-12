import AppKit
import Darwin
import WidgetKit

/// Keeps the desktop widgets on time.
///
/// WidgetKit is meant to refresh a widget when its timeline asks, but on this Mac it
/// sometimes stops: after a long sleep, or once the app has been replaced, macOS keeps a
/// broken connection to the old widget process and quietly ignores refresh requests. The
/// widget then freezes on the last minute of its timeline. Restarting our own widget
/// process (macOS starts a fresh one on demand) and asking again always brings it back.
@MainActor final class WidgetKeeper {
    private var timer: Timer?
    private var hours = 0

    /// Refresh now, after waking and every hour; restart the widget process every third hour.
    func start() {
        refresh(restart: true)
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            center.addObserver(self, selector: #selector(woke), name: name, object: nil)
        }
        let timer = Timer(timeInterval: 3600, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.hours += 1
                self.refresh(restart: self.hours % 3 == 0)
            }
        }
        timer.tolerance = 300
        RunLoop.main.add(timer, forMode: .common); self.timer = timer
    }

    /// Ask for fresh timelines without restarting anything: clock or time-zone changes.
    func reload() { WidgetCenter.shared.reloadAllTimelines() }

    @objc private func woke() { refresh(restart: true) }

    private func refresh(restart: Bool) {
        if restart { Self.stopWidgetProcesses() }
        // Give launchd a moment to clear the old process before WidgetKit asks for a new one.
        DispatchQueue.main.asyncAfter(deadline: .now() + (restart ? 1 : 0)) {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    /// End any running copy of this app's widget extension. Only our own executable is touched.
    static func stopWidgetProcesses() {
        guard let plugins = Bundle.main.builtInPlugInsURL else { return }
        let target = plugins.appendingPathComponent("TypeAB1Widget.appex/Contents/MacOS/TypeAB1Widget").resolvingSymlinksInPath().path
        let count = proc_listallpids(nil, 0)
        guard count > 0 else { return }
        var pids = [pid_t](repeating: 0, count: Int(count) * 2)
        let found = proc_listallpids(&pids, Int32(pids.count * MemoryLayout<pid_t>.size))
        var buffer = [CChar](repeating: 0, count: 4096)
        for pid in pids.prefix(Int(max(0, found))) where pid > 0 {
            guard proc_pidpath(pid, &buffer, UInt32(buffer.count)) > 0 else { continue }
            if String(cString: buffer) == target { kill(pid, SIGTERM) }
        }
    }
}
