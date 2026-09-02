import AppKit
import ServiceManagement

// MARK: - Appearance modes

enum Mode: String, CaseIterable {
    /// Raw values are the SF Symbols shown in the status bar and menu.
    case auto = "circle.lefthalf.filled", light = "sun.max", dark = "moon"

    var title: String { "\(self)".capitalized }
    var image: NSImage? { NSImage(systemSymbolName: rawValue, accessibilityDescription: title) }
}

// MARK: - Reading and writing the system appearance
//
// System Settings drives appearance through SkyLight. System Events' AppleScript
// dictionary only knows dark-vs-light, so it can't express Auto — hence the
// dlsym. Symbols are looked up at run time so a future macOS that drops them
// degrades to the AppleScript path instead of failing to launch.

private let skyLight = dlopen(
    "/System/Library/PrivateFrameworks/SkyLight.framework/Versions/A/SkyLight", RTLD_LAZY)

private func skyLightFunction<T>(_ name: String) -> T? {
    guard let skyLight, let symbol = dlsym(skyLight, name) else { return nil }
    return unsafeBitCast(symbol, to: T.self)
}

private typealias BoolGetter = @convention(c) () -> Bool
private typealias BoolSetter = @convention(c) (Bool) -> Void

enum SystemAppearance {

    static var current: Mode {
        let isAuto: BoolGetter? = skyLightFunction("SLSGetAppearanceThemeSwitchesAutomatically")
        let isDark: BoolGetter? = skyLightFunction("SLSGetAppearanceThemeLegacy")
        if isAuto?() == true { return .auto }
        // UserDefaults.standard searches NSGlobalDomain, where this key lives.
        let dark = isDark?() ?? (UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark")
        return dark ? .dark : .light
    }

    static func set(_ mode: Mode) {
        let setAuto: BoolSetter? = skyLightFunction("SLSSetAppearanceThemeSwitchesAutomatically")
        let setDark: BoolSetter? = skyLightFunction("SLSSetAppearanceThemeLegacy")

        guard let setAuto, let setDark else {
            // Only reached if SkyLight stops exporting the symbols above. Auto has
            // no AppleScript equivalent, so it falls back to Light.
            NSAppleScript(source: """
                tell application "System Events" to tell appearance preferences \
                to set dark mode to \(mode == .dark)
                """)?.executeAndReturnError(nil)
            return
        }

        setAuto(mode == .auto)
        if mode != .auto { setDark(mode == .dark) }
    }
}

// MARK: - Menu bar item

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    private lazy var statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()

    func applicationDidFinishLaunching(_ notification: Notification) {
        menu.delegate = self
        // Deliberately not statusItem.menu: that hands positioning to the system,
        // which lines the menu's *content* up with the button and leaves the panel
        // hanging to its left. Handling the click ourselves pins the panel's own
        // left edge to the button's.
        statusItem.button?.target = self
        statusItem.button?.action = #selector(showMenu)
        statusItem.button?.sendAction(on: [.leftMouseDown])
        updateIcon()

        // Keep the icon honest when appearance is changed elsewhere: from System
        // Settings, or by the Auto schedule flipping at sunrise/sunset.
        DistributedNotificationCenter.default.addObserver(
            self, selector: #selector(updateIcon),
            name: Notification.Name("AppleInterfaceThemeChangedNotification"), object: nil)
    }

    @objc private func updateIcon() {
        let mode = SystemAppearance.current
        statusItem.button?.image = mode.image
        statusItem.button?.toolTip = "Appearance: \(mode.title)"
    }

    @objc private func showMenu() {
        guard let button = statusItem.button else { return }

        // The status bar window carries the *menu bar's* appearance, which goes
        // dark over a dark wallpaper even while the system is Light. A menu popped
        // in that window inherits it and renders dark out of step with every other
        // menu on screen, so pin it to the app's appearance, which tracks the real
        // system setting. Re-read on each open so Auto flipping is picked up.
        menu.appearance = NSApp.effectiveAppearance

        button.highlight(true)
        // NSStatusBarButton is flipped, so y grows downward and bounds.height is
        // its bottom edge: the menu's top-left corner lands on the button's
        // bottom-left corner. x is measured so the menu's glyph column sits in the
        // same lane as the status bar glyph; the 6pt drop matches neighbouring
        // menus. popUp blocks until the menu closes, so the un-highlight runs on
        // dismissal.
        menu.popUp(positioning: nil, at: NSPoint(x: -19.75, y: button.bounds.height + 6), in: button)
        button.highlight(false)
    }

    // Rebuilt on every open so the checkmarks reflect the live system state.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let current = SystemAppearance.current
        for mode in Mode.allCases {
            let item = NSMenuItem(title: mode.title, action: #selector(selectMode(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = mode
            // Same image the status bar uses. NSMenuItem normalises item images
            // to its own size -- measured 10.5pt wide against the status bar's
            // 13pt, and unchanged by anything set on the image -- so matching
            // the two is not possible without a custom item view.
            item.image = mode.image
            item.state = mode == current ? .on : .off
            menu.addItem(item)
        }

        menu.addItem(.separator())

        let loginItem = NSMenuItem(
            title: "Open at Login", action: #selector(toggleOpenAtLogin), keyEquivalent: "")
        loginItem.target = self
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(loginItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: "Quit ThemeSwitch", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    @objc private func selectMode(_ sender: NSMenuItem) {
        guard let mode = sender.representedObject as? Mode else { return }
        SystemAppearance.set(mode)
        updateIcon()
    }

    @objc private func toggleOpenAtLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            NSApp.activate(ignoringOtherApps: true)
            NSApp.presentError(error)
        }
    }
}

// LSUIElement in Info.plist already makes this an accessory app: no Dock icon, no app menu.
let delegate = AppDelegate()
NSApplication.shared.delegate = delegate
NSApplication.shared.run()
