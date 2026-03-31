import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    let settings = AppSettings()
    lazy var engine = KeyPrefixEngine(settings: settings)

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard ensureSingleInstance() else {
            return
        }
        engine.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        engine.stop()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        engine.retryStartIfNeeded()
    }

    private func ensureSingleInstance() -> Bool {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            return true
        }

        let currentProcessIdentifier = ProcessInfo.processInfo.processIdentifier
        let otherInstances = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
            .filter { $0.processIdentifier != currentProcessIdentifier }

        guard let existingInstance = otherInstances.first else {
            return true
        }

        existingInstance.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        DispatchQueue.main.async {
            NSApp.terminate(nil)
        }
        return false
    }
}
