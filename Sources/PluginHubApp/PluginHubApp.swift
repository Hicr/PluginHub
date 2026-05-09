import SwiftUI
import PluginHubCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate, NSWindowDelegate {
    static var shared: AppDelegate!
    let store = PluginHubStore()
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var glassWindow: NSWindow?
    private var popoverHostingController: NSViewController?
    private var globalClickMonitor: Any?
    private var localClickMonitor: Any?
    private var settingsWindowController: NSWindowController?

    private var useGlassEffect: Bool {
        if #available(macOS 26, *) {
            return store.configuration.visualEffect.enabled
        }
        return false
    }

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
        if let w = glassWindow, w.isVisible {
            w.orderOut(nil)
            stopGlobalClickMonitor()
            return
        }

        let hostingController: NSViewController
        if let cached = popoverHostingController {
            hostingController = cached
        } else {
            let vc = NSHostingController(
                rootView: DashboardView(store: store) { [weak self] newSize in
                    self?.updateContentSize(newSize)
                }
                .frame(width: 400)
            )
            popoverHostingController = vc
            hostingController = vc
        }
        hostingController.view.appearance = NSApp.effectiveAppearance

        let contentWidth = DashboardView.contentWidth
        let contentSize = computeContentSize(hostingController: hostingController, width: contentWidth)

        if useGlassEffect {
            showGlassWindow(button: button, hostingController: hostingController, size: contentSize)
        } else {
            let popover = NSPopover()
            popover.contentSize = contentSize
            popover.behavior = .applicationDefined
            popover.animates = false
            popover.delegate = self
            popover.appearance = NSApp.effectiveAppearance
            popover.contentViewController = hostingController
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            self.popover = popover
            startGlobalClickMonitor()
        }
    }

    private func updateContentSize(_ size: NSSize) {
        let width = DashboardView.contentWidth
        let maxH: CGFloat = (NSScreen.main?.visibleFrame.height ?? 800) * 0.85
        let clamped = NSSize(width: width, height: min(max(size.height, 120), maxH))

        if let window = glassWindow, window.isVisible {
            window.setContentSize(clamped)
        }
        if let popover, popover.isShown {
            popover.contentSize = clamped
        }
    }

    private func computeContentSize(hostingController: NSViewController, width: CGFloat) -> NSSize {
        let maxH: CGFloat = (NSScreen.main?.visibleFrame.height ?? 800) * 0.85
        // 给一个很大的高度让视图自由收缩到内容实际大小
        hostingController.view.frame = NSRect(x: 0, y: 0, width: width, height: maxH)
        hostingController.view.layoutSubtreeIfNeeded()
        let fit = hostingController.view.fittingSize
        let height = min(max(fit.height, 120), maxH)
        return NSSize(width: width, height: height)
    }

    private func showGlassWindow(button: NSStatusBarButton, hostingController: NSViewController, size: NSSize) {
        let window: NSWindow
        if let existing = glassWindow {
            window = existing
        } else {
            window = NSWindow(
                contentRect: NSRect(origin: .zero, size: size),
                styleMask: [.borderless, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.isOpaque = false
            window.backgroundColor = .clear
            window.level = .floating
            window.hasShadow = true
            window.collectionBehavior = [.transient, .ignoresCycle]
            window.animationBehavior = .none
            window.delegate = self
            window.contentViewController = hostingController
            glassWindow = window
        }

        hostingController.view.frame = NSRect(origin: .zero, size: size)
        window.setContentSize(size)

        let buttonScreenRect = button.window!.convertToScreen(button.frame)
        let winX = buttonScreenRect.midX - size.width / 2
        let winY = buttonScreenRect.minY
        window.setFrameTopLeftPoint(NSPoint(x: winX, y: winY))

        window.makeKeyAndOrderFront(nil)
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
        // 检查菜单栏按钮
        if let button = statusItem?.button,
           let window = event.window,
           window === button.window {
            return
        }
        // 检查液态玻璃窗口
        if let w = glassWindow, w.isVisible,
           let eventWindow = event.window,
           eventWindow === w {
            return
        }
        // 检查传统 popover
        if let popover, popover.isShown,
           let popoverWindow = popover.contentViewController?.view.window,
           let eventWindow = event.window,
           eventWindow === popoverWindow {
            return
        }
        // 关闭
        popover?.performClose(nil)
        glassWindow?.orderOut(nil)
        stopGlobalClickMonitor()
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
        glassWindow?.orderOut(nil)
        stopGlobalClickMonitor()
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
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        if notification.object as? NSWindow === glassWindow {
            stopGlobalClickMonitor()
        } else {
            settingsWindowController = nil
        }
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
