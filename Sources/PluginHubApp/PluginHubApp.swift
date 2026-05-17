import SwiftUI
import PluginHubCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate, NSWindowDelegate {
    static var shared: AppDelegate!
    let store = PluginHubStore()
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var settingsWindowController: NSWindowController?
    private var clickMonitor: Any?
    private var localClickMonitor: Any?
    private var escMonitor: Any?

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
            let icon = NSImage(contentsOf: Bundle.main.url(forResource: "menubar-icon", withExtension: "png")!)
            icon?.size = NSSize(width: 22, height: 22)
            icon?.isTemplate = true
            button.image = icon
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

        let hostingController = NSHostingController(
            rootView: DashboardView(store: store) { [weak self] newSize in
                self?.updateContentSize(newSize)
            }
            .frame(width: 400)
        )
        hostingController.view.appearance = NSApp.effectiveAppearance

        let contentWidth = DashboardView.contentWidth
        let contentSize = computeContentSize(hostingController: hostingController, width: contentWidth)

        let popover = NSPopover()
        popover.contentSize = contentSize
        popover.behavior = .applicationDefined
        popover.animates = false
        popover.delegate = self
        popover.appearance = NSApp.effectiveAppearance
        popover.contentViewController = hostingController
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        self.popover = popover

        NSApp.activate(ignoringOtherApps: true)

        startMonitors()
    }

    // MARK: - Event Monitors

    private func startMonitors() {
        stopMonitors()

        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            DispatchQueue.main.async {
                self?.closePopoverIfNeeded(event: event)
            }
        }

        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.closePopoverIfNeeded(event: event)
            return event
        }

        escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                self?.popover?.performClose(nil)
                return nil
            }
            return event
        }
    }

    private func stopMonitors() {
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
            clickMonitor = nil
        }
        if let monitor = localClickMonitor {
            NSEvent.removeMonitor(monitor)
            localClickMonitor = nil
        }
        if let monitor = escMonitor {
            NSEvent.removeMonitor(monitor)
            escMonitor = nil
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

    // MARK: - Content Size

    private func updateContentSize(_ size: NSSize) {
        let width = DashboardView.contentWidth
        let maxH: CGFloat = (NSScreen.main?.visibleFrame.height ?? 800) * 0.85
        let clamped = NSSize(width: width, height: min(max(size.height, 120), maxH))

        if let popover, popover.isShown {
            popover.contentSize = clamped
        }
    }

    private func computeContentSize(hostingController: NSViewController, width: CGFloat) -> NSSize {
        let maxH: CGFloat = (NSScreen.main?.visibleFrame.height ?? 800) * 0.85
        hostingController.view.frame = NSRect(x: 0, y: 0, width: width, height: maxH)
        hostingController.view.layoutSubtreeIfNeeded()
        let fit = hostingController.view.fittingSize
        let height = min(max(fit.height, 120), maxH)
        return NSSize(width: width, height: height)
    }

    // MARK: - Actions

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
        stopMonitors()
        popover = nil
        NSApp.deactivate()
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
