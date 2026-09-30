import AppKit
import Carbon
import Combine
import SwiftUI

#if !SPOTMENU_CHECKS
@main enum SpotMenuApp {
    @MainActor static func main() {
        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)
        let delegate = SpotMenuDelegate()
        application.delegate = delegate
        // Menu bar only: no window scene for macOS to open or restore at launch.
        withExtendedLifetime(delegate) { application.run() }
    }
}
#endif

enum PopoverLayout {
    static let width: CGFloat = 432
    static let expandedHeight: CGFloat = 690
    static let compactHeight: CGFloat = 140
    static func size(_ mode: PopoverMode) -> NSSize { .init(width: width, height: mode == .compact ? compactHeight : expandedHeight) }
}

@MainActor final class SpotMenuDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private let preferences: AppPreferences
    private let spotify: SpotifyService
    private lazy var statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let compactPopover = NSPopover()
    private let expandedPopover = NSPopover()
    private var subscriptions = Set<AnyCancellable>()
    private var presentation = PresentationState()
    private var pendingTransition: (Int, PopoverMode)?
    private var pollingTask: Task<Void, Never>?
    private var keyMonitor: Any?
    private var hotKey: EventHotKeyRef?
    private var hotKeyHandler: EventHandlerRef?
    private var systemAppearance: SystemAppearance?
    private var desiredMode: PopoverMode { preferences.compact && spotify.connected ? .compact : .expanded }
    init(preferences: AppPreferences? = nil, spotify: SpotifyService? = nil) {
        let preferences = preferences ?? AppPreferences()
        self.preferences = preferences
        self.spotify = spotify ?? SpotifyService(preferences: preferences)
        super.init()
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { false }
    private func popover(for mode: PopoverMode) -> NSPopover { mode == .compact ? compactPopover : expandedPopover }
    private var visiblePopover: NSPopover? { compactPopover.isShown ? compactPopover : expandedPopover.isShown ? expandedPopover : nil }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configure(expandedPopover, mode: .expanded)
        configure(compactPopover, mode: .compact)
        systemAppearance = SystemAppearance(popovers: [compactPopover, expandedPopover], preferences: preferences)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "music.note", accessibilityDescription: "Open SpotMenu")
            button.target = self; button.action = #selector(togglePopover)
            button.toolTip = "SpotMenu · ⌘⇧Space"
        }
        preferences.$compact.combineLatest(spotify.$connected)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _, _ in self?.switchMode() }
            .store(in: &subscriptions)
        spotify.player.$playback.map { $0?.is_playing == true }.removeDuplicates().combineLatest(preferences.$playingIcon)
            .sink { [weak self] playing, enabled in self?.statusItem.button?.image = NSImage(systemSymbolName: playing && enabled ? "waveform" : "music.note", accessibilityDescription: "Open SpotMenu") }
            .store(in: &subscriptions)
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let consumed = MainActor.assumeIsolated { self?.handleKey(event) == nil }
            return consumed ? nil : event
        }
        spotify.visualizer.bind(player: spotify.player, preferences: preferences)
        registerShortcut()
    }
    func applicationWillTerminate(_ notification: Notification) {
        spotify.visualizer.shutdown()
        pollingTask?.cancel()
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let hotKeyHandler { RemoveEventHandler(hotKeyHandler) }
    }
    private func configure(_ popover: NSPopover, mode: PopoverMode) {
        popover.behavior = .transient; popover.animates = false; popover.delegate = self
        let controller = NSHostingController(rootView: ContentView(mode: mode)
            .environmentObject(spotify).environmentObject(spotify.player).environmentObject(preferences))
        controller.sizingOptions = []
        let size = PopoverLayout.size(mode)
        controller.view.frame = NSRect(origin: .zero, size: size)
        popover.contentViewController = controller
        popover.contentSize = size
    }
    @objc private func togglePopover() {
        presentation.dismiss(); pendingTransition = nil
        if let shown = visiblePopover { shown.close() }
        else { show(desiredMode) }
    }
    private func show(_ mode: PopoverMode) {
        guard let button = statusItem.button else { return }
        let start = ContinuousClock.now
        popover(for: mode).show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover(for: mode).contentViewController?.view.window?.makeKey()
        Performance.record("Popover presentation", since: start)
    }
    private func switchMode() {
        let mode = desiredMode, token = presentation.request(mode)
        if let shown = visiblePopover, shown !== popover(for: mode) {
            pendingTransition = (token, mode)
            shown.close()
        } else if pendingTransition != nil {
            pendingTransition = (token, mode)
            scheduleTransition(token, mode)
        }
    }
    private func scheduleTransition(_ token: Int, _ mode: PopoverMode) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.presentation.accepts(token, mode: mode), self.visiblePopover == nil else { return }
            self.pendingTransition = nil
            self.show(mode)
        }
    }
    func popoverDidClose(_ notification: Notification) {
        preferences.isPresented = false
        pollingTask?.cancel(); pollingTask = nil
        if let (token, mode) = pendingTransition { scheduleTransition(token, mode) }
        else { presentation.dismiss() }
    }
    func popoverDidShow(_ notification: Notification) {
        preferences.isPresented = true
        pollingTask?.cancel()
        pollingTask = Task {
            while !Task.isCancelled {
                await spotify.refreshPlayback()
                try? await Task.sleep(for: .seconds(spotify.player.playback?.is_playing == true ? 6 : 12))
            }
        }
    }
    private func handleKey(_ event: NSEvent) -> NSEvent? {
        guard visiblePopover != nil else { return event }
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if modifiers.contains(.command), event.charactersIgnoringModifiers == "," {
            preferences.showingDevices = false
            preferences.showingSettings = true
            preferences.compact = false
            return nil
        }
        if modifiers.contains(.command), event.charactersIgnoringModifiers?.lowercased() == "k" {
            spotify.closeDetail()
            preferences.focusSearch(); return nil
        }
        if event.keyCode == 53 {
            if preferences.showingDevices { preferences.showingDevices = false }
            else if preferences.showingSettings { preferences.showingSettings = false }
            else if spotify.detailTitle != nil { spotify.closeDetail() }
            else { presentation.dismiss(); pendingTransition = nil; visiblePopover?.close() }
            return nil
        }
        guard !modifiers.contains(.command), !modifiers.contains(.control), !modifiers.contains(.option) else { return event }
        guard !preferences.showingSettings, !preferences.showingDevices else { return event }
        guard !preferences.adjustingSlider else { return event }
        if desiredMode == .expanded, preferences.tab == .search, spotify.detailTitle == nil, !preferences.showingSettings, !preferences.showingDevices {
            let entries = preferences.entries(from: spotify.search)
            if !entries.isEmpty {
                if event.keyCode == 125 { preferences.selection = min(entries.count - 1, preferences.selection + 1); return nil }
                if event.keyCode == 126 { preferences.selection = max(0, preferences.selection - 1); return nil }
                if event.keyCode == 36 {
                    preferences.rememberSearch(preferences.query)
                    let entry = entries[min(preferences.selection, entries.count - 1)]
                    Task { await spotify.activate(entry) }; return nil
                }
            }
        }
        if event.keyCode == 49, !(NSApp.keyWindow?.firstResponder is NSTextView) {
            Task { await spotify.togglePlayback() }; return nil
        }
        return event
    }
    private func registerShortcut() {
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, _, data in
            guard let data else { return OSStatus(eventNotHandledErr) }
            let owner = Unmanaged<SpotMenuDelegate>.fromOpaque(data).takeUnretainedValue()
            Task { @MainActor in owner.togglePopover() }
            return noErr
        }, 1, &type, pointer, &hotKeyHandler)
        let result = RegisterEventHotKey(49, UInt32(cmdKey | shiftKey), EventHotKeyID(signature: 0x53504D4E, id: 1), GetApplicationEventTarget(), 0, &hotKey)
        if result != noErr { spotify.showNotice("⌘⇧Space is already used by another app", icon: "keyboard") }
    }
}
