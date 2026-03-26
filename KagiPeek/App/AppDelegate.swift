import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    let settings = AppSettings()
    lazy var engine = KeyPrefixEngine(settings: settings)

    func applicationDidFinishLaunching(_ notification: Notification) {
        engine.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        engine.stop()
    }
}
