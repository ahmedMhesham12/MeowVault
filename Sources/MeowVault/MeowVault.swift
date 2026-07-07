import AppKit
import Carbon
import CryptoKit
import MeowVaultCore
import Observation
import ServiceManagement
import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var appearance: NSAppearance? {
        switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let model = AppModel()
    private let popover = NSPopover()
    private var window: NSWindow?
    private var statusItem: NSStatusItem?
    private var statusMenu: NSMenu?
    private var hotKeyRef: EventHotKeyRef?
    private var outsideClickMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        model.themeDidChange = { [weak self] _ in
            self?.applyTheme()
        }
        configurePopover()
        configureWindow()
        configureMenuBar()
        configureHotKey()
        configureOutsideClickMonitor()
        model.startClipboardMonitor()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.showWindow()
        }
    }

    func applicationDidResignActive(_ notification: Notification) {
        window?.orderOut(nil)
    }

    private func configurePopover() {
        popover.contentSize = NSSize(width: 760, height: 520)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: VaultView(model: model))
    }

    private func configureWindow() {
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "MeowVault"
        window.center()
        window.level = .floating
        window.hidesOnDeactivate = true
        window.isFloatingPanel = true
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(rootView: VaultView(model: model))
        self.window = window
        applyTheme()
    }

    private func configureMenuBar() {
        let item = NSStatusBar.system.statusItem(withLength: 38)
        item.button?.title = ""
        item.button?.imagePosition = .imageOnly
        item.button?.imageScaling = .scaleProportionallyUpOrDown
        item.button?.toolTip = "Left-click: show clipboard history. Right-click: options and quit."
        item.button?.target = self
        item.button?.action = #selector(statusItemClicked)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem = item
        applyTheme()
    }

    private func configureHotKey() {
        let signature = OSType(UInt32(truncatingIfNeeded: FourCharCode("MEOW")))
        let hotKeyID = EventHotKeyID(signature: signature, id: 1)
        RegisterEventHotKey(
            UInt32(kVK_ANSI_V),
            UInt32(cmdKey | shiftKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let userData else { return noErr }
            let delegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
            Task { @MainActor in
                delegate.toggleWindowFromHotKey()
            }
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), nil)
    }

    private func configureOutsideClickMonitor() {
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in
                self?.window?.orderOut(nil)
            }
        }
    }

    private func applyTheme() {
        let appearance = model.theme.appearance
        NSApp.appearance = appearance
        window?.appearance = appearance
        popover.appearance = appearance
        statusItem?.button?.image = AppIcon.statusImage(for: model.theme)
    }

    @objc private func statusItemClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showStatusMenu()
        } else {
            toggleWindow()
        }
    }

    private func showStatusMenu() {
        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(menuItem(
            title: window?.isVisible == true ? "Hide MeowVault" : "Show MeowVault",
            action: #selector(toggleWindow),
            help: "Open or hide the clipboard history window."
        ))
        menu.addItem(menuItem(
            title: "Search Clipboard",
            action: #selector(openSearch),
            help: "Open the history window and use the search box."
        ))
        menu.addItem(menuItem(
            title: "Open Settings",
            action: #selector(openSettings),
            keyEquivalent: ",",
            help: "Change startup, theme, and app password options."
        ))
        menu.addItem(.separator())
        let launchItem = menuItem(
            title: "Open at Login",
            action: #selector(toggleLaunchAtLogin),
            help: "Start MeowVault automatically when macOS logs in."
        )
        launchItem.state = model.launchAtLogin ? .on : .off
        menu.addItem(launchItem)

        let styleItem = NSMenuItem(title: "Style", action: nil, keyEquivalent: "")
        styleItem.toolTip = "Choose System, Light, or Dark appearance."
        let styleMenu = NSMenu(title: "Style")
        styleMenu.addItem(themeMenuItem(title: "System", theme: .system, action: #selector(setThemeSystem), help: "Follow the current macOS appearance."))
        styleMenu.addItem(themeMenuItem(title: "Light", theme: .light, action: #selector(setThemeLight), help: "Use the light MeowVault appearance."))
        styleMenu.addItem(themeMenuItem(title: "Dark", theme: .dark, action: #selector(setThemeDark), help: "Use the dark MeowVault appearance."))
        menu.addItem(styleItem)
        menu.setSubmenu(styleMenu, for: styleItem)
        menu.addItem(.separator())
        menu.addItem(menuItem(
            title: model.hasPassword ? "Lock MeowVault" : "Set Password",
            action: model.hasPassword ? #selector(lockApp) : #selector(openSettings),
            keyEquivalent: "l",
            help: model.hasPassword
                ? "Hide clipboard history until you enter the app password."
                : "Create an app password first; then Lock can hide clipboard history."
        ))
        menu.addItem(.separator())
        menu.addItem(menuItem(
            title: "Quit MeowVault",
            action: #selector(quit),
            keyEquivalent: "q",
            help: "Stop MeowVault completely."
        ))
        statusMenu = menu
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
    }

    nonisolated func menuDidClose(_ menu: NSMenu) {
        Task { @MainActor in
            self.statusItem?.menu = nil
            self.statusMenu = nil
        }
    }

    private func menuItem(title: String, action: Selector, keyEquivalent: String = "", help: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        item.toolTip = help
        return item
    }

    private func themeMenuItem(title: String, theme: AppTheme, action: Selector, help: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.state = model.theme == theme ? .on : .off
        item.toolTip = help
        return item
    }

    @objc private func toggleWindow() {
        if window?.isVisible == true {
            window?.orderOut(nil)
        } else {
            showWindow()
        }
    }

    private func toggleWindowFromHotKey() {
        if window?.isVisible == true {
            window?.orderOut(nil)
        } else {
            showWindow()
        }
    }

    @objc private func openSettings() {
        model.showSettings = true
        showWindow()
    }

    @objc private func openSearch() {
        model.showSettings = false
        showWindow()
    }

    @objc private func toggleLaunchAtLogin() {
        model.toggleLaunchAtLogin()
    }

    @objc private func setThemeSystem() {
        model.theme = .system
    }

    @objc private func setThemeLight() {
        model.theme = .light
    }

    @objc private func setThemeDark() {
        model.theme = .dark
    }

    @objc private func lockApp() {
        model.lock()
        showWindow()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem?.button else { return }
        NSApp.activate()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    private func showWindow() {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
    }
}

@main
@MainActor
enum MeowVaultMain {
    private static let delegate = AppDelegate()

    static func main() {
        let app = NSApplication.shared
        app.delegate = delegate
        app.run()
    }
}

private func FourCharCode(_ value: String) -> FourCharCode {
    value.utf8.reduce(0) { ($0 << 8) + FourCharCode($1) }
}

@MainActor
@Observable
final class AppModel {
    var searchText = ""
    var selectedGroup: ClipGroup = .all
    var selectedItemID: ClipItem.ID?
    var items: [ClipItem] = []
    var launchAtLogin = SMAppService.mainApp.status == .enabled
    var showSettings = false
    var isLocked: Bool
    var unlockPassword = ""
    var settingsPassword = ""
    var settingsPasswordConfirm = ""
    var settingsMessage = ""
    var actionMessage = ""
    var copiedItemID: ClipItem.ID?
    var theme: AppTheme {
        didSet {
            UserDefaults.standard.set(theme.rawValue, forKey: "appTheme")
            themeDidChange?(theme)
        }
    }
    @ObservationIgnored var themeDidChange: ((AppTheme) -> Void)?

    private let store: ClipStore
    private let persistence: ClipPersistence
    private let passwordManager = PasswordManager()
    private let monitor = ClipboardMonitor()

    init() {
        let keyData = Self.loadStorageKey()
        persistence = ClipPersistence(keyData: keyData)
        let savedTheme = UserDefaults.standard.string(forKey: "appTheme").flatMap(AppTheme.init(rawValue:)) ?? .system
        theme = savedTheme
        isLocked = passwordManager.hasPassword
        store = ClipStore(items: persistence.load())
        items = store.visibleItems
        selectedItemID = Self.latestItemID(in: items)
        ensureLaunchAtLogin()
    }

    private static func loadStorageKey() -> Data {
        do {
            return try LocalKeyFileStore.key(at: AppPaths.storageKeyURL)
        } catch {
            fatalError("Unable to create or read encrypted storage key: \(error)")
        }
    }

    var filteredItems: [ClipItem] {
        let grouped = selectedGroup == .all ? items : items.filter { $0.group == selectedGroup }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return grouped }
        return grouped.filter {
            $0.preview.lowercased().contains(query)
                || $0.group.rawValue.lowercased().contains(query)
        }
    }

    var selectedItem: ClipItem? {
        filteredItems.first { $0.id == selectedItemID } ?? filteredItems.first
    }

    func startClipboardMonitor() {
        monitor.start { [weak self] payload in
            guard let self else { return }
            let captured = self.store.capture(payload)
            self.syncAndSave(selecting: captured.id)
        }
    }

    func select(_ item: ClipItem) {
        selectedItemID = item.id
    }

    func togglePin(_ item: ClipItem) {
        store.togglePin(item.id)
        syncAndSave()
    }

    func remove(_ item: ClipItem) {
        store.remove(item.id)
        syncAndSave()
    }

    func copy(_ item: ClipItem, plainText: Bool = false) {
        ClipboardWriter.write(item.payload, plainText: plainText)
        selectedItemID = item.id
        copiedItemID = item.id
        actionMessage = plainText ? "Copied as plain text" : "Copied"
    }

    func paste(_ item: ClipItem, plainText: Bool = false) {
        ClipboardWriter.write(item.payload, plainText: plainText)
        selectedItemID = item.id
        copiedItemID = item.id
        actionMessage = PasteboardPaster.paste()
            ? "Pasted"
            : "Allow Accessibility permission to paste"
    }

    func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
                launchAtLogin = false
            } else {
                try SMAppService.mainApp.register()
                launchAtLogin = true
            }
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    func ensureLaunchAtLogin() {
        guard SMAppService.mainApp.status != .enabled else {
            launchAtLogin = true
            return
        }
        try? SMAppService.mainApp.register()
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func unlock() {
        guard passwordManager.verify(unlockPassword) else {
            settingsMessage = "Wrong password"
            return
        }
        unlockPassword = ""
        settingsMessage = ""
        isLocked = false
    }

    func lock() {
        guard passwordManager.hasPassword else {
            showSettings = true
            settingsMessage = "Set a password first to enable Lock"
            return
        }
        isLocked = true
        unlockPassword = ""
        settingsMessage = ""
    }

    func setPassword() {
        let password = settingsPassword
        guard password.count >= 8 else {
            settingsMessage = "Password must be at least 8 characters"
            return
        }
        guard password == settingsPasswordConfirm else {
            settingsMessage = "Passwords do not match"
            return
        }
        passwordManager.setPassword(password)
        settingsPassword = ""
        settingsPasswordConfirm = ""
        settingsMessage = "Password saved"
        isLocked = false
    }

    func clearPassword() {
        passwordManager.clear()
        settingsMessage = "Password removed"
        isLocked = false
    }

    var hasPassword: Bool {
        passwordManager.hasPassword
    }

    private func syncAndSave(selecting id: ClipItem.ID? = nil) {
        items = store.visibleItems
        if let id {
            selectedItemID = id
        } else if selectedItemID == nil || !items.contains(where: { $0.id == selectedItemID }) {
            selectedItemID = Self.latestItemID(in: items)
        }
        persistence.save(items)
    }

    private static func latestItemID(in items: [ClipItem]) -> ClipItem.ID? {
        items.max { $0.createdAt < $1.createdAt }?.id
    }
}

@MainActor
final class ClipboardMonitor {
    private var timer: Timer?
    private var lastChangeCount = NSPasteboard.general.changeCount

    @MainActor
    func start(onChange: @escaping @MainActor (ClipPayload) -> Void) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let pasteboard = NSPasteboard.general
                guard pasteboard.changeCount != self.lastChangeCount else { return }
                self.lastChangeCount = pasteboard.changeCount
                guard let payload = Self.payload(from: pasteboard) else { return }
                onChange(payload)
            }
        }
    }

    @MainActor
    private static func payload(from pasteboard: NSPasteboard) -> ClipPayload? {
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], !urls.isEmpty {
            return nil
        }

        if let image = NSImage(pasteboard: pasteboard), let data = image.tiffRepresentation {
            return .image(data: data)
        }

        if let value = pasteboard.string(forType: .string), !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .text(value)
        }

        return nil
    }
}

enum ClipboardWriter {
    @MainActor
    static func write(_ payload: ClipPayload, plainText: Bool) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch payload {
        case .text(let value):
            pasteboard.setString(plainText ? PlainText.normalized(value) : value, forType: .string)
        case .image(let data):
            if let image = NSImage(data: data) {
                pasteboard.writeObjects([image])
            }
        }
    }
}

enum PasteboardPaster {
    @MainActor
    static func paste() -> Bool {
        guard AXIsProcessTrusted() else {
            let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
            return false
        }

        let source = CGEventSource(stateID: .combinedSessionState)
        let down = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
        return true
    }
}

struct ClipPersistence {
    let keyData: Data

    private var encryptedURL: URL {
        AppPaths.supportDirectory.appendingPathComponent("clips.enc")
    }

    private var legacyURL: URL {
        encryptedURL.deletingLastPathComponent().appendingPathComponent("clips.json")
    }

    func load() -> [ClipItem] {
        if
            let encrypted = try? Data(contentsOf: encryptedURL),
            let data = try? SecureEnvelope.decrypt(encrypted, keyData: keyData),
            let items = try? JSONDecoder().decode([ClipItem].self, from: data)
        {
            return items
        }

        guard let data = try? Data(contentsOf: legacyURL) else { return [] }
        let items = (try? JSONDecoder().decode([ClipItem].self, from: data)) ?? []
        save(items)
        try? FileManager.default.removeItem(at: legacyURL)
        return items
    }

    func save(_ items: [ClipItem]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        guard let encrypted = try? SecureEnvelope.encrypt(data, keyData: keyData) else { return }
        try? encrypted.write(to: encryptedURL, options: .atomic)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: encryptedURL.path)
    }
}

enum AppPaths {
    static var supportDirectory: URL {
        let directory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/MeowVault", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static var storageKeyURL: URL {
        supportDirectory.appendingPathComponent("storage.key")
    }

    static var passwordURL: URL {
        supportDirectory.appendingPathComponent("password.json")
    }
}

struct PasswordRecord: Codable {
    let salt: Data
    let hash: Data
}

final class PasswordManager {
    var hasPassword: Bool {
        FileManager.default.fileExists(atPath: AppPaths.passwordURL.path)
    }

    func setPassword(_ password: String) {
        var generator = SystemRandomNumberGenerator()
        let salt = Data((0..<16).map { _ in UInt8.random(in: UInt8.min...UInt8.max, using: &generator) })
        let record = PasswordRecord(salt: salt, hash: Self.hash(password: password, salt: salt))
        if let data = try? JSONEncoder().encode(record) {
            try? data.write(to: AppPaths.passwordURL, options: .atomic)
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: AppPaths.passwordURL.path)
        }
    }

    func verify(_ password: String) -> Bool {
        guard
            let data = try? Data(contentsOf: AppPaths.passwordURL),
            let record = try? JSONDecoder().decode(PasswordRecord.self, from: data)
        else {
            return true
        }
        return Self.hash(password: password, salt: record.salt) == record.hash
    }

    func clear() {
        try? FileManager.default.removeItem(at: AppPaths.passwordURL)
    }

    private static func hash(password: String, salt: Data) -> Data {
        var data = salt
        data.append(Data(password.utf8))
        return Data(SHA256.hash(data: data))
    }
}

enum AppIcon {
    @MainActor
    static func statusImage(for theme: AppTheme = .system) -> NSImage? {
        let size = NSSize(width: 32, height: 24)
        let image = NSImage(size: size, flipped: false) { rect in
            let useLightInk = Self.useLightInk(for: theme)
            let ink = useLightInk ? NSColor.white : NSColor.black.withAlphaComponent(0.88)
            let offsetX = (rect.width - size.width) / 2

            NSGraphicsContext.current?.imageInterpolation = .high
            ink.setFill()

            func oval(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat, originX: CGFloat, originY: CGFloat, scale: CGFloat) {
                NSBezierPath(ovalIn: NSRect(
                    x: offsetX + originX + x * scale,
                    y: originY + y * scale,
                    width: width * scale,
                    height: height * scale
                )).fill()
            }

            func point(_ x: CGFloat, _ y: CGFloat, originX: CGFloat, originY: CGFloat, scale: CGFloat) -> NSPoint {
                NSPoint(x: offsetX + originX + x * scale, y: originY + y * scale)
            }

            func drawPaw(originX: CGFloat, originY: CGFloat, scale: CGFloat) {
                oval(0.0, 8.8, 4.8, 6.2, originX: originX, originY: originY, scale: scale)
                oval(4.8, 12.0, 5.2, 6.4, originX: originX, originY: originY, scale: scale)
                oval(10.6, 12.0, 5.2, 6.4, originX: originX, originY: originY, scale: scale)
                oval(15.4, 8.8, 4.8, 6.2, originX: originX, originY: originY, scale: scale)

                let pad = NSBezierPath()
                pad.move(to: point(1.8, 2.4, originX: originX, originY: originY, scale: scale))
                pad.curve(
                    to: point(5.2, 7.7, originX: originX, originY: originY, scale: scale),
                    controlPoint1: point(1.7, 5.1, originX: originX, originY: originY, scale: scale),
                    controlPoint2: point(2.8, 6.6, originX: originX, originY: originY, scale: scale)
                )
                pad.curve(
                    to: point(8.0, 9.4, originX: originX, originY: originY, scale: scale),
                    controlPoint1: point(6.4, 8.3, originX: originX, originY: originY, scale: scale),
                    controlPoint2: point(6.8, 9.4, originX: originX, originY: originY, scale: scale)
                )
                pad.curve(
                    to: point(10.8, 9.4, originX: originX, originY: originY, scale: scale),
                    controlPoint1: point(9.1, 9.4, originX: originX, originY: originY, scale: scale),
                    controlPoint2: point(9.6, 9.4, originX: originX, originY: originY, scale: scale)
                )
                pad.curve(
                    to: point(13.6, 7.7, originX: originX, originY: originY, scale: scale),
                    controlPoint1: point(12.0, 9.4, originX: originX, originY: originY, scale: scale),
                    controlPoint2: point(12.4, 8.3, originX: originX, originY: originY, scale: scale)
                )
                pad.curve(
                    to: point(17.0, 2.4, originX: originX, originY: originY, scale: scale),
                    controlPoint1: point(16.0, 6.6, originX: originX, originY: originY, scale: scale),
                    controlPoint2: point(17.1, 5.1, originX: originX, originY: originY, scale: scale)
                )
                pad.curve(
                    to: point(9.4, 0.0, originX: originX, originY: originY, scale: scale),
                    controlPoint1: point(16.9, -0.5, originX: originX, originY: originY, scale: scale),
                    controlPoint2: point(12.5, 0.0, originX: originX, originY: originY, scale: scale)
                )
                pad.curve(
                    to: point(1.8, 2.4, originX: originX, originY: originY, scale: scale),
                    controlPoint1: point(6.3, 0.0, originX: originX, originY: originY, scale: scale),
                    controlPoint2: point(1.9, -0.5, originX: originX, originY: originY, scale: scale)
                )
                pad.close()
                pad.fill()
            }

            drawPaw(originX: 2.8, originY: 3.0, scale: 0.58)
            drawPaw(originX: 15.6, originY: 8.8, scale: 0.58)

            return true
        }
        image.isTemplate = false
        return image
    }

    @MainActor
    private static func useLightInk(for theme: AppTheme) -> Bool {
        switch theme {
        case .dark:
            return true
        case .light:
            return false
        case .system:
            return NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        }
    }
}

struct VaultView: View {
    @Bindable var model: AppModel

    var body: some View {
        Group {
            if model.isLocked {
                LockView(model: model)
            } else {
                VStack(spacing: 0) {
                    HeaderView(model: model)
                    Divider()
                    HStack(spacing: 0) {
                        ClipListView(model: model)
                            .frame(width: 360)
                        Divider()
                        PreviewView(model: model)
                    }
                }
            }
        }
        .frame(width: 760, height: 520)
        .preferredColorScheme(model.theme.colorScheme)
        .sheet(isPresented: $model.showSettings) {
            SettingsView(model: model)
                .preferredColorScheme(model.theme.colorScheme)
        }
    }
}

struct HeaderView: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("MeowVault")
                    .font(.headline)
                Spacer()
                Text("⌘⇧V")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button {
                    NSApp.windows.first { $0.title == "MeowVault" }?.makeKeyAndOrderFront(nil)
                } label: {
                    Image(systemName: "macwindow")
                }
                .buttonStyle(.borderless)
                .help("Open the clipboard history window.")
                Button {
                    model.showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.borderless)
                .help("Change startup, theme, and app password options.")
                Button {
                    model.lock()
                } label: {
                    Image(systemName: "lock")
                }
                .buttonStyle(.borderless)
                .help(model.hasPassword
                    ? "Hide clipboard history until you enter the app password."
                    : "Set an app password first; then Lock can hide clipboard history."
                )
                Button {
                    NSApp.terminate(nil)
                } label: {
                    Image(systemName: "power")
                }
                .buttonStyle(.borderless)
                .help("Stop MeowVault completely.")
            }

            TextField("Search clipboard history", text: $model.searchText)
                .textFieldStyle(.roundedBorder)
                .help("Search saved clipboard items by text or group.")

            Picker("", selection: $model.selectedGroup) {
                ForEach(ClipGroup.allCases) { group in
                    Text(group.rawValue).tag(group)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .help("Filter clipboard history by links, code, images, emails, or text.")
        }
        .padding(12)
    }
}

struct ClipListView: View {
    @Bindable var model: AppModel

    var body: some View {
        List(selection: $model.selectedItemID) {
            ForEach(model.filteredItems) { item in
                ClipRow(item: item, isSelected: model.selectedItemID == item.id)
                    .tag(item.id)
                    .onTapGesture {
                        model.select(item)
                        model.copy(item)
                    }
                    .contextMenu {
                        Button(item.isPinned ? "Unpin" : "Pin") { model.togglePin(item) }
                            .help(item.isPinned ? "Let this clip move normally in history." : "Keep this clip at the top of history.")
                        Button("Copy") { model.copy(item) }
                            .help("Make this item the current clipboard.")
                        Button("Copy Plain Text") { model.copy(item, plainText: true) }
                            .help("Copy text without extra formatting.")
                        Button("Delete", role: .destructive) { model.remove(item) }
                            .help("Remove this item from history.")
                    }
            }
        }
        .listStyle(.sidebar)
    }
}

struct ClipRow: View {
    let item: ClipItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Text(icon)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.preview)
                    .font(.system(size: 13, weight: item.isPinned ? .semibold : .regular))
                    .lineLimit(2)
                Text(item.group.rawValue)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
            if item.isPinned {
                Image(systemName: "pin.fill")
                    .foregroundStyle(.yellow)
            }
        }
        .padding(.vertical, 4)
    }

    private var icon: String {
        switch item.group {
        case .links: "🔗"
        case .code: "⌘"
        case .images: "▧"
        case .emails: "@"
        case .all, .text: "T"
        }
    }
}

struct PreviewView: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let item = model.selectedItem {
                HStack {
                    Text(item.group.rawValue)
                        .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    model.togglePin(item)
                } label: {
                    Label(item.isPinned ? "Unpin" : "Pin", systemImage: item.isPinned ? "pin.slash" : "pin")
                }
                .help(item.isPinned ? "Let this clip move normally in history." : "Keep this clip at the top of history.")
                Button {
                    model.copy(item)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .help("Make this item the current clipboard.")
                Button {
                    model.copy(item, plainText: true)
                } label: {
                    Label("Plain Text", systemImage: "textformat")
                }
                .help("Copy text without extra formatting.")
                Button {
                    model.paste(item)
                } label: {
                    Label("Paste", systemImage: "arrow.turn.down.left")
                }
                .help("Paste this clip into the focused app. macOS may ask for Accessibility permission.")
                if model.copiedItemID == item.id {
                    Label("Copied", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
                }

                if !model.actionMessage.isEmpty {
                    Text(model.actionMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                preview(for: item)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                HStack {
                    Spacer()
                    Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .help("Date and time this clip was copied.")
                }
            } else {
                ContentUnavailableView("No clips yet", systemImage: "doc.on.clipboard")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(14)
    }

    @ViewBuilder
    private func preview(for item: ClipItem) -> some View {
        switch item.payload {
        case .text(let value):
            ScrollView {
                Text(value)
                    .font(.system(.body, design: item.group == .code ? .monospaced : .default))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .image(let data):
            if let image = NSImage(data: data) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Text(item.preview)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct LockView: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(spacing: 16) {
            if let image = AppIcon.statusImage() {
                Image(nsImage: image)
                    .resizable()
                    .frame(width: 58, height: 58)
            }
            Text("MeowVault Locked")
                .font(.title2.bold())
            SecureField("Password", text: $model.unlockPassword)
                .textFieldStyle(.roundedBorder)
                .frame(width: 280)
                .onSubmit { model.unlock() }
            Button("Unlock") {
                model.unlock()
            }
            .help("Unlock MeowVault with the app password.")
            if !model.settingsMessage.isEmpty {
                Text(model.settingsMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Button("Quit") {
                NSApp.terminate(nil)
            }
            .buttonStyle(.borderless)
            .help("Stop MeowVault completely.")
        }
        .padding(28)
    }
}

struct SettingsView: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Settings")
                    .font(.title2.bold())
                Spacer()
                Button("Done") {
                    model.showSettings = false
                }
                .help("Close Settings and return to clipboard history.")
            }

            Toggle("Open MeowVault when macOS starts", isOn: Binding(
                get: { model.launchAtLogin },
                set: { _ in model.toggleLaunchAtLogin() }
            ))
            .help("Start MeowVault automatically when macOS logs in.")

            Picker("Style", selection: $model.theme) {
                ForEach(AppTheme.allCases) { theme in
                    Text(theme.rawValue).tag(theme)
                }
            }
            .pickerStyle(.segmented)
            .help("Choose whether MeowVault follows macOS or uses Light/Dark mode.")

            Divider()

            Text("App Password")
                .font(.headline)
            SecureField("New password", text: $model.settingsPassword)
                .textFieldStyle(.roundedBorder)
                .help("Set the password used to unlock the MeowVault window.")
            SecureField("Confirm password", text: $model.settingsPasswordConfirm)
                .textFieldStyle(.roundedBorder)
                .help("Repeat the same password to confirm it.")
            HStack {
                Button("Set Password") {
                    model.setPassword()
                }
                .help("Save the app password so Lock can hide clipboard history.")
                Button("Remove Password", role: .destructive) {
                    model.clearPassword()
                }
                .help("Remove the app password and disable Lock.")
            }

            Divider()

            HStack {
                Button("Lock Now") {
                    model.lock()
                }
                .disabled(!model.hasPassword)
                .help(model.hasPassword
                    ? "Hide clipboard history until you enter the app password."
                    : "Set a password first to enable Lock."
                )
                Button("Quit MeowVault", role: .destructive) {
                    NSApp.terminate(nil)
                }
                .help("Stop MeowVault completely.")
            }

            if !model.settingsMessage.isEmpty {
                Text(model.settingsMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(22)
        .frame(width: 430, height: 440)
    }
}
