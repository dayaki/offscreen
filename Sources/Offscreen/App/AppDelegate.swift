import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var container: AppContainer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let container = AppContainer()
        self.container = container
        container.start()
        Log.app.info("Offscreen launched (timeScale=\(container.clock.timeScale))")
    }
}
