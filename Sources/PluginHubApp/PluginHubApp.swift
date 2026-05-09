import SwiftUI
import PluginHubCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate, NSWindowDelegate {
    static var shared: AppDelegate!
    let store = PluginHubStore()
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var popoverHostingController: NSViewController?
    private var globalClickMonitor: Any?
    private var localClickMonitor: Any?
    private var settingsWindowController: NSWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.shared = self
        NSApp.setActivationPolicy(.accessory)
        applyTheme(store.configuration.theme)
        setupStatusItem()
        if isInAppBundle {
            NotificationManager().requestPermission()
        }
    }

    private var isInAppBundle: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }

    func applyTheme(_ theme: Theme) {
        switch theme {
        case .system:
            NSApp.appearance = nil
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "puzzlepiece.fill", accessibilityDescription: "PluginHub")
            button.action = #selector(togglePopover)
            button.target = self
        }
        statusItem = item
    }

    @objc func showPopover() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { self.showPopover() }
            return
        }
        guard let button = statusItem?.button else { return }
        if let popover, popover.isShown {
            popover.performClose(nil)
            return
        }
        // 复用缓存的 hosting controller
        let hostingController: NSViewController
        if let cached = popoverHostingController {
            hostingController = cached
        } else {
            let vc = NSHostingController(
                rootView: DashboardView(store: store)
                    .frame(width: 400)
            )
            popoverHostingController = vc
            hostingController = vc
        }
        hostingController.view.appearance = NSApp.effectiveAppearance

        let popover = NSPopover()
        popover.contentSize = NSSize(width: 400, height: 500)
        popover.behavior = .applicationDefined
        popover.animates = false
        popover.delegate = self
        popover.appearance = NSApp.effectiveAppearance
        popover.contentViewController = hostingController
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        self.popover = popover
        startGlobalClickMonitor()
    }

    private func startGlobalClickMonitor() {
        stopGlobalClickMonitor()

        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            DispatchQueue.main.async {
                self?.closePopoverIfNeeded(event: event)
            }
        }

        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.closePopoverIfNeeded(event: event)
            return event
        }
    }

    private func closePopoverIfNeeded(event: NSEvent) {
        guard let popover, popover.isShown else { return }
        if let button = statusItem?.button,
           let window = event.window,
           window === button.window {
            return
        }
        if let popoverWindow = popover.contentViewController?.view.window,
           let window = event.window,
           window === popoverWindow {
            return
        }
        popover.performClose(nil)
    }

    private func stopGlobalClickMonitor() {
        if let monitor = globalClickMonitor {
            NSEvent.removeMonitor(monitor)
            globalClickMonitor = nil
        }
        if let monitor = localClickMonitor {
            NSEvent.removeMonitor(monitor)
            localClickMonitor = nil
        }
    }

    @objc private func togglePopover() {
        showPopover()
    }

    func openSettings() {
        if let popover, popover.isShown {
            popover.performClose(nil)
        }
        if let controller = settingsWindowController, let window = controller.window, !window.isReleasedWhenClosed {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let settingsView = SettingsView(store: store)
            .frame(minWidth: 700, minHeight: 480)
        let hostingController = NSHostingController(rootView: settingsView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "PluginHub 设置"
        window.setContentSize(NSSize(width: 780, height: 560))
        window.minSize = NSSize(width: 700, height: 480)
        window.styleMask = [.titled, .closable, .resizable, .miniaturizable]
        window.delegate = self
        window.center()
        let controller = NSWindowController(window: window)
        controller.showWindow(nil)
        settingsWindowController = controller
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - NSPopoverDelegate

    func popoverDidClose(_ notification: Notification) {
        stopGlobalClickMonitor()
        popover = nil
        // 保持 hostingController 缓存，下次打开更快
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        settingsWindowController = nil
    }
}

@main
struct PluginHubApplication: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
