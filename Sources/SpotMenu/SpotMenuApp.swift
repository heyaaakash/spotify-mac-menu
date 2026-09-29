import AppKit
import Combine
import SwiftUI

private enum PopoverLayout {
    static let width: CGFloat = 432
    static let expandedHeight: CGFloat = 690
    static let compactHeight: CGFloat = 156
}

@main struct SpotMenuApp: App {
    @NSApplicationDelegateAdaptor(SpotMenuDelegate.self) private var appDelegate
    var body: some Scene {
        Settings { EmptyView() }
    }
}

@MainActor final class SpotMenuDelegate: NSObject, NSApplicationDelegate {
    private let spotify = SpotifyService()
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let compactPopover = NSPopover()
    private let expandedPopover = NSPopover()
    private var subscriptions = Set<AnyCancellable>()
    private var activePopover: NSPopover { spotify.compact && spotify.connected ? compactPopover : expandedPopover }

    func applicationDidFinishLaunching(_ notification: Notification) {
        configure(expandedPopover, compact: false)
        configure(compactPopover, compact: true)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "music.note", accessibilityDescription: "SpotMenu")
            button.target = self
            button.action = #selector(togglePopover)
        }

        spotify.$compact.combineLatest(spotify.$connected)
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _, _ in
                self?.switchPopoverIfNeeded()
            }
            .store(in: &subscriptions)
        spotify.$playback
            .sink { [weak self] playback in
                self?.statusItem.button?.image = NSImage(
                    systemSymbolName: playback?.is_playing == true ? "waveform" : "music.note",
                    accessibilityDescription: "SpotMenu"
                )
            }
            .store(in: &subscriptions)
    }

    @objc private func togglePopover() {
        if compactPopover.isShown { compactPopover.performClose(nil) }
        else if expandedPopover.isShown { expandedPopover.performClose(nil) }
        else { showPopover(activePopover) }
    }

    private func configure(_ popover: NSPopover, compact: Bool) {
        popover.behavior = .transient
        popover.animates = false
        popover.contentSize = NSSize(width: PopoverLayout.width, height: compact ? PopoverLayout.compactHeight : PopoverLayout.expandedHeight)
        popover.contentViewController = NSHostingController(rootView: ContentView(compactPresentation: compact).environmentObject(spotify))
    }

    private func showPopover(_ popover: NSPopover) {
        guard let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    private func switchPopoverIfNeeded() {
        let target = activePopover
        let old = target === compactPopover ? expandedPopover : compactPopover
        guard old.isShown else { return }
        old.close()
        // Each popover has a fixed hosting view and size. Show only the latest mode
        // after AppKit has finished closing the old window.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.activePopover === target, !target.isShown else { return }
            self.showPopover(target)
        }
    }
}

private enum Palette {
    static let ink = Color(red: 0.055, green: 0.071, blue: 0.065)
    static let surface = Color(red: 0.10, green: 0.125, blue: 0.113)
    static let raised = Color(red: 0.145, green: 0.17, blue: 0.15)
    static let green = Color(red: 0.42, green: 0.94, blue: 0.49)
    static let muted = Color(red: 0.64, green: 0.70, blue: 0.66)
}

private enum Tab: String, CaseIterable {
    case home = "Home", search = "Search", library = "Library", queue = "Queue"
    var icon: String {
        switch self {
        case .home: "house.fill"
        case .search: "magnifyingglass"
        case .library: "square.stack.fill"
        case .queue: "text.line.first.and.arrowtriangle.forward"
        }
    }
}

private struct ContentView: View {
    @EnvironmentObject private var spotify: SpotifyService
    let compactPresentation: Bool
    @State private var tab: Tab = .home
    @State private var devices = false
    @State private var query = ""
    @State private var volumeValue = 50.0
    @State private var isVisible = false
    @State private var expandedContentID = UUID()
    private let playbackPoll = Timer.publish(every: 8, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Palette.ink.ignoresSafeArea()
            RadialGradient(colors: [Palette.green.opacity(0.17), .clear], center: .topLeading, startRadius: 15, endRadius: 340)
                .ignoresSafeArea()
            if spotify.connected { connectedView } else { onboarding }
        }
        .frame(width: PopoverLayout.width, height: compactPresentation ? PopoverLayout.compactHeight : PopoverLayout.expandedHeight, alignment: .top)
        .preferredColorScheme(.dark)
        .foregroundStyle(.white)
        .onAppear {
            isVisible = true
            Task { await spotify.refreshPlayback() }
        }
        .onDisappear { isVisible = false }
        .onReceive(playbackPoll) { _ in
            if isVisible { Task { await spotify.refreshPlayback() } }
        }
        .onChange(of: spotify.playback?.device?.volume_percent) { _, value in volumeValue = Double(value ?? 50) }
        .onChange(of: spotify.compact) { _, _ in expandedContentID = UUID() }
        .onChange(of: tab) { _, newValue in
            withAnimation(.snappy(duration: 0.35)) { spotify.closeDetail() }
            expandedContentID = UUID()
            if newValue == .queue { Task { await spotify.loadQueue() } }
        }
    }

    private var connectedView: some View {
        VStack(spacing: 0) {
            header
            if compactPresentation {
                compactPlayer
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 22) {
                        player
                        if let error = spotify.error { errorBanner(error) }
                        if let title = spotify.detailTitle { detailView(title) }
                        else {
                            switch tab {
                            case .home: homeView
                            case .search: searchView
                            case .library: libraryView
                            case .queue: queueView
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 22)
                    .frame(maxWidth: .infinity)
                }
                .id(expandedContentID)
                tabBar
            }
        }
        .overlay(alignment: .top) {
            if !compactPresentation && spotify.showingSettings { settingsSheet.transition(.move(edge: .top).combined(with: .opacity)).zIndex(2) }
            if devices { deviceSheet.transition(.move(edge: .top).combined(with: .opacity)).zIndex(2) }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(Palette.green).frame(width: 29, height: 29)
                Image(systemName: "waveform").font(.system(size: 14, weight: .black)).foregroundStyle(Palette.ink)
            }
            Text("spotmenu").font(.system(size: 18, weight: .heavy, design: .rounded)).tracking(-0.8)
            Spacer()
            if spotify.playback?.is_playing == true { Equalizer().frame(width: 18, height: 16).padding(.trailing, 4) }
            if spotify.busy {
                ProgressView().controlSize(.small).tint(Palette.green).frame(width: 28, height: 28)
            } else {
                headerButton("arrow.clockwise") { Task { await spotify.refreshAll() } }
            }
            headerButton(compactPresentation ? "arrow.up.left.and.arrow.down.right" : "arrow.down.right.and.arrow.up.left") { spotify.compact.toggle() }
            headerButton("gearshape") {
                spotify.showingSettings = true
                spotify.compact = false
            }
        }
        .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 15)
    }

    private func headerButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: icon).font(.system(size: 14, weight: .semibold)).frame(width: 28, height: 28).contentShape(Rectangle()) }
            .buttonStyle(HoverIconStyle())
    }

    private var player: some View {
        VStack(spacing: 17) {
            ZStack {
                RoundedRectangle(cornerRadius: 24).fill(LinearGradient(colors: [Color(red: 0.25, green: 0.39, blue: 0.29), Color(red: 0.10, green: 0.18, blue: 0.16), Palette.surface], startPoint: .topLeading, endPoint: .bottomTrailing))
                Circle().fill(Palette.green.opacity(0.23)).frame(width: 240).blur(radius: 58).offset(x: -90, y: -80)
                if let track = spotify.playback?.item {
                    HStack(spacing: 17) {
                        CoverArt(url: track.imageURL, size: 114, radius: 15)
                            .shadow(color: .black.opacity(0.35), radius: 18, y: 10)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("NOW PLAYING").font(.system(size: 10, weight: .bold)).tracking(2.2).foregroundStyle(Palette.green)
                            Text(track.name).font(.system(size: 22, weight: .bold, design: .rounded)).lineLimit(2)
                            Text(track.artistLine).font(.system(size: 13)).lineLimit(1).foregroundStyle(.white.opacity(0.69))
                            HStack(spacing: 8) {
                                Button { Task { await spotify.save(track, saved: spotify.saved.contains(where: { $0.id == track.id })) } } label: {
                                    Image(systemName: spotify.saved.contains(where: { $0.id == track.id }) ? "heart.fill" : "heart")
                                        .foregroundStyle(spotify.saved.contains(where: { $0.id == track.id }) ? Palette.green : .white)
                                }.buttonStyle(.plain).help("Save or remove from Liked Songs")
                                Button { if let url = URL(string: "https://open.spotify.com/track/\(track.id ?? "")") { NSWorkspace.shared.open(url) } } label: {
                                    Image(systemName: "arrow.up.right.square").foregroundStyle(.white.opacity(0.75))
                                }.buttonStyle(.plain).help("Open in Spotify")
                            }.font(.system(size: 15)).padding(.top, 7)
                        }
                        Spacer(minLength: 0)
                    }.padding(17)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "music.note.list").font(.system(size: 30, weight: .light)).foregroundStyle(Palette.green)
                        Text("Ready when you are").font(.system(size: 18, weight: .bold, design: .rounded))
                        Text("Start playing on a Spotify device").font(.caption).foregroundStyle(Palette.muted)
                    }.frame(maxWidth: .infinity)
                }
            }
            .frame(height: 148).clipShape(RoundedRectangle(cornerRadius: 24))

            HStack(spacing: 28) {
                control("shuffle", active: spotify.playback?.shuffle_state == true, size: 17) { Task { await spotify.shuffle() } }
                control("backward.end.fill", size: 20) { Task { await spotify.previous() } }
                Button { Task { await spotify.togglePlayback() } } label: {
                    Image(systemName: spotify.playback?.is_playing == true ? "pause.fill" : "play.fill")
                        .font(.system(size: 21, weight: .bold)).foregroundStyle(Palette.ink)
                        .frame(width: 48, height: 48).background(Palette.green, in: Circle())
                        .shadow(color: Palette.green.opacity(0.3), radius: 13, y: 4)
                }.buttonStyle(BounceStyle()).help(spotify.playback?.is_playing == true ? "Pause" : "Play")
                control("forward.end.fill", size: 20) { Task { await spotify.next() } }
                control(spotify.playback?.repeat_state == "track" ? "repeat.1" : "repeat", active: spotify.playback?.repeat_state != "off" && spotify.playback?.repeat_state != nil, size: 17) { Task { await spotify.repeatMode() } }
            }.frame(maxWidth: .infinity)

            SeekBar(playback: spotify.playback)
            HStack(spacing: 12) {
                Button { Task { await spotify.loadDevices() }; withAnimation(.spring()) { devices = true } } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "hifispeaker.and.homepod")
                        Text(spotify.playback?.device?.name ?? "Choose a device").lineLimit(1)
                    }.font(.system(size: 11, weight: .semibold)).foregroundStyle(Palette.muted)
                }.buttonStyle(.plain).frame(maxWidth: 170, alignment: .leading)
                Spacer()
                Image(systemName: "speaker.wave.2").font(.system(size: 12)).foregroundStyle(Palette.muted)
                Slider(value: $volumeValue, in: 0...100, onEditingChanged: { editing in
                    if !editing { Task { await spotify.volume(Int(volumeValue)) } }
                }).tint(Palette.green).frame(width: 100)
            }
        }
        .padding(14)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 28))
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(.white.opacity(0.055)))
    }

    private var compactPlayer: some View {
        HStack(spacing: 13) {
            CoverArt(url: spotify.playback?.item?.imageURL, size: 55, radius: 10)
            VStack(alignment: .leading, spacing: 3) {
                Text(spotify.playback?.item?.name ?? "Nothing playing").font(.system(size: 14, weight: .bold)).lineLimit(1)
                Text(spotify.playback?.item?.artistLine ?? "Open Spotify to play").font(.caption).foregroundStyle(Palette.muted).lineLimit(1)
            }
            Spacer()
            control("backward.end.fill", size: 14) { Task { await spotify.previous() } }
            Button { Task { await spotify.togglePlayback() } } label: {
                Image(systemName: spotify.playback?.is_playing == true ? "pause.fill" : "play.fill")
                    .foregroundStyle(Palette.ink).frame(width: 34, height: 34).background(Palette.green, in: Circle())
            }.buttonStyle(BounceStyle())
            control("forward.end.fill", size: 14) { Task { await spotify.next() } }
        }.padding(13).background(Palette.surface, in: RoundedRectangle(cornerRadius: 18)).padding(.horizontal, 17)
    }

    private func control(_ icon: String, active: Bool = false, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: size, weight: .semibold))
                .foregroundStyle(active ? Palette.green : .white.opacity(0.82))
                .frame(width: 24, height: 30).contentShape(Rectangle())
        }.buttonStyle(HoverIconStyle())
    }

    private var homeView: some View {
        LazyVStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("YOUR SPACE").font(.system(size: 10, weight: .heavy)).tracking(2).foregroundStyle(Palette.green)
                    Text("Good to see you\(spotify.profile?.display_name.map { ", \($0.components(separatedBy: " ").first ?? $0)" } ?? "")")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                }
                Spacer()
            }
            if !spotify.playlists.isEmpty {
                sectionHeading("Your playlists", icon: "square.stack")
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 11) {
                        ForEach(spotify.playlists.prefix(10), id: \.stableID) { playlist in
                            Button { Task { await spotify.openPlaylist(playlist) } } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    CoverArt(url: playlist.imageURL, size: 114, radius: 12)
                                    Text(playlist.name).font(.system(size: 11, weight: .semibold)).lineLimit(1).frame(width: 114, alignment: .leading)
                                }
                            }.buttonStyle(LiftStyle())
                        }
                    }
                }
            }
            if !spotify.recent.isEmpty {
                sectionHeading("Recently played", icon: "clock.arrow.circlepath")
                ForEach(spotify.recent.prefix(5), id: \.stableID) { track in trackRow(track) }
            }
            if !spotify.topTracks.isEmpty {
                sectionHeading("On repeat", icon: "sparkles")
                ForEach(spotify.topTracks.prefix(5), id: \.stableID) { track in trackRow(track) }
            }
            if spotify.playlists.isEmpty && spotify.recent.isEmpty { emptyState("Your music will show up here", "Play something in Spotify, then tap refresh.", "music.note.house") }
        }
    }

    private var searchView: some View {
        LazyVStack(alignment: .leading, spacing: 17) {
            Text("Find your next favorite").font(.system(size: 22, weight: .bold, design: .rounded))
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(Palette.green)
                TextField("Songs, artists, albums, playlists", text: $query)
                    .textFieldStyle(.plain)
                    .onChange(of: query) { _, value in spotify.searchFor(value) }
                if !query.isEmpty { Button { query = ""; spotify.searchFor("") } label: { Image(systemName: "xmark.circle.fill") }.buttonStyle(.plain).foregroundStyle(Palette.muted) }
            }.padding(13).background(Palette.raised, in: RoundedRectangle(cornerRadius: 13))
            if query.isEmpty { emptyState("Search all of Spotify", "Every track, album, artist and playlist is a few keystrokes away.", "sparkle.magnifyingglass") }
            if spotify.searching {
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small).tint(Palette.green)
                    Text("Searching Spotify…").font(.system(size: 11)).foregroundStyle(Palette.muted)
                }.padding(.vertical, 8)
            }
            if let results = spotify.search {
                if let tracks = results.tracks?.items, !tracks.isEmpty {
                    sectionHeading("Tracks", icon: "music.note")
                    ForEach(tracks, id: \.stableID) { track in trackRow(track) }
                }
                if let albums = results.albums?.items, !albums.isEmpty {
                    sectionHeading("Albums", icon: "square.stack")
                    ForEach(albums, id: \.stableID) { album in
                        Button { Task { await spotify.openAlbum(album) } } label: { mediaRow(title: album.name, subtitle: album.artists?.map(\.name).joined(separator: ", ") ?? "Album", url: album.imageURL) }
                            .buttonStyle(.plain)
                    }
                }
                if let playlists = results.playlists?.items.compactMap({ $0 }), !playlists.isEmpty {
                    sectionHeading("Playlists", icon: "music.note.list")
                    ForEach(playlists, id: \.stableID) { playlist in
                        Button { Task { await spotify.openPlaylist(playlist) } } label: { mediaRow(title: playlist.name, subtitle: "Playlist", url: playlist.imageURL) }.buttonStyle(.plain)
                    }
                }
                if let artists = results.artists?.items, !artists.isEmpty {
                    sectionHeading("Artists", icon: "person.crop.circle")
                    ForEach(artists, id: \.stableID) { artist in
                        Button { if let id = artist.id, let url = URL(string: "https://open.spotify.com/artist/\(id)") { NSWorkspace.shared.open(url) } } label: {
                            HStack { Image(systemName: "person.crop.circle.fill").font(.title2).foregroundStyle(Palette.green).frame(width: 43); Text(artist.name); Spacer(); Image(systemName: "arrow.up.right").foregroundStyle(Palette.muted) }.padding(8)
                        }.buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var libraryView: some View {
        LazyVStack(alignment: .leading, spacing: 17) {
            Text("Your library").font(.system(size: 22, weight: .bold, design: .rounded))
            if !spotify.playlists.isEmpty {
                sectionHeading("Playlists", icon: "square.stack")
                ForEach(spotify.playlists, id: \.stableID) { playlist in
                    Button { Task { await spotify.openPlaylist(playlist) } } label: { mediaRow(title: playlist.name, subtitle: "Playlist", url: playlist.imageURL) }.buttonStyle(.plain)
                }
            }
            sectionHeading("Liked songs", icon: "heart.fill")
            if spotify.saved.isEmpty { emptyState("No liked songs yet", "Tap the heart on a track to keep it here.", "heart") }
            ForEach(spotify.saved, id: \.stableID) { track in trackRow(track) }
        }
    }

    private var queueView: some View {
        LazyVStack(alignment: .leading, spacing: 17) {
            HStack {
                Text("Up next").font(.system(size: 22, weight: .bold, design: .rounded))
                Spacer()
                Button { Task { await spotify.loadQueue() } } label: { Image(systemName: "arrow.clockwise").foregroundStyle(Palette.green) }.buttonStyle(.plain)
            }
            if spotify.queue.isEmpty { emptyState("The queue is clear", "Add tracks using the ••• menu beside a song.", "text.line.first.and.arrowtriangle.forward") }
            ForEach(spotify.queue.prefix(40), id: \.stableID) { track in trackRow(track) }
        }
    }

    private func detailView(_ title: String) -> some View {
        LazyVStack(alignment: .leading, spacing: 16) {
            Button { withAnimation(.snappy) { spotify.closeDetail() } } label: { Label("Back", systemImage: "chevron.left").foregroundStyle(Palette.green) }.buttonStyle(.plain)
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("COLLECTION").font(.system(size: 10, weight: .bold)).tracking(2).foregroundStyle(Palette.green)
                    Text(title).font(.system(size: 23, weight: .bold, design: .rounded)).lineLimit(2)
                    Text("\(spotify.detailTracks.count) tracks").font(.caption).foregroundStyle(Palette.muted)
                }
                Spacer()
                if let first = spotify.detailTracks.first {
                    Button { Task { await spotify.play(first) } } label: { Image(systemName: "play.fill").foregroundStyle(Palette.ink).frame(width: 42, height: 42).background(Palette.green, in: Circle()) }.buttonStyle(BounceStyle())
                }
            }
            ForEach(spotify.detailTracks, id: \.stableID) { track in trackRow(track) }
        }
    }

    private func trackRow(_ track: Track) -> some View {
        HStack(spacing: 4) {
            Button { Task { await spotify.play(track) } } label: {
                HStack(spacing: 11) {
                    CoverArt(url: track.imageURL, size: 43, radius: 7)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(track.name).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                        Text(track.artistLine).font(.system(size: 11)).foregroundStyle(Palette.muted).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            Menu {
                Button("Play now", systemImage: "play.fill") { Task { await spotify.play(track) } }
                Button("Add to queue", systemImage: "text.badge.plus") { Task { await spotify.addToQueue(track) } }
                let isSaved = spotify.saved.contains(where: { $0.id == track.id })
                Button(isSaved ? "Remove from Liked Songs" : "Save to Liked Songs", systemImage: isSaved ? "heart.slash" : "heart") { Task { await spotify.save(track, saved: isSaved) } }
                if let id = track.id, let url = URL(string: "https://open.spotify.com/track/\(id)") {
                    Button("Open in Spotify", systemImage: "arrow.up.right.square") { NSWorkspace.shared.open(url) }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Palette.muted)
                    .frame(width: 30, height: 40)
                    .contentShape(Rectangle())
            }
            .menuIndicator(.hidden)
            .fixedSize(horizontal: true, vertical: false)
            .frame(width: 30)
        }
        .padding(7)
        .frame(maxWidth: .infinity)
        .background(Palette.raised.opacity(0.76), in: RoundedRectangle(cornerRadius: 13))
    }

    private func mediaRow(title: String, subtitle: String, url: URL?) -> some View {
        HStack(spacing: 11) {
            CoverArt(url: url, size: 43, radius: 7)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                Text(subtitle).font(.system(size: 11)).foregroundStyle(Palette.muted).lineLimit(1)
            }
            Spacer(minLength: 0)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(6).background(Palette.raised.opacity(0.64), in: RoundedRectangle(cornerRadius: 11))
    }

    private func sectionHeading(_ title: String, icon: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon).foregroundStyle(Palette.green)
            Text(title).foregroundStyle(.white)
        }.font(.system(size: 13, weight: .bold))
    }

    private func emptyState(_ title: String, _ subtitle: String, _ icon: String) -> some View {
        VStack(spacing: 9) {
            Image(systemName: icon).font(.system(size: 32, weight: .light)).foregroundStyle(Palette.green)
            Text(title).font(.system(size: 15, weight: .bold, design: .rounded))
            Text(subtitle).font(.system(size: 11)).foregroundStyle(Palette.muted).multilineTextAlignment(.center).frame(maxWidth: 245)
        }.frame(maxWidth: .infinity).padding(.vertical, 30).background(Palette.surface, in: RoundedRectangle(cornerRadius: 18))
    }

    private var tabBar: some View {
        HStack(spacing: 2) {
            ForEach(Tab.allCases, id: \.self) { item in
                Button {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.75)) { tab = item }
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: item.icon).font(.system(size: 16, weight: .semibold))
                            .symbolEffect(.bounce, value: tab == item)
                        Text(item.rawValue).font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(tab == item ? Palette.green : Palette.muted)
                    .frame(maxWidth: .infinity).frame(height: 49)
                    .background(tab == item ? Palette.green.opacity(0.09) : .clear, in: RoundedRectangle(cornerRadius: 12))
                }.buttonStyle(.plain)
            }
        }.padding(.horizontal, 14).padding(.vertical, 8)
            .background(Palette.surface)
            .overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.06)).frame(height: 1) }
    }

    private var onboarding: some View {
        VStack(spacing: 0) {
            Spacer()
            ZStack {
                Circle().fill(Palette.green.opacity(0.2)).frame(width: 195).blur(radius: 38)
                Circle().fill(Palette.green).frame(width: 104)
                Image(systemName: "waveform").font(.system(size: 48, weight: .black)).foregroundStyle(Palette.ink)
            }.frame(height: 175)
            Text("Your music.\nOne click away.")
                .font(.system(size: 35, weight: .heavy, design: .rounded)).tracking(-1.5).multilineTextAlignment(.center)
            Text("A beautiful little home for Spotify in your menu bar.")
                .font(.system(size: 13)).foregroundStyle(Palette.muted).multilineTextAlignment(.center).padding(.top, 12)
            VStack(alignment: .leading, spacing: 9) {
                Text("SPOTIFY CLIENT ID").font(.system(size: 10, weight: .bold)).tracking(1.6).foregroundStyle(Palette.green)
                TextField("Paste your Spotify app Client ID", text: $spotify.clientID)
                    .textFieldStyle(.plain).padding(13).background(Palette.raised, in: RoundedRectangle(cornerRadius: 12))
                Text("Register http://127.0.0.1:8888/callback as a redirect URI in your Spotify developer app.")
                    .font(.system(size: 11)).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true)
            }.padding(.top, 36)
            Button { spotify.connect() } label: {
                HStack { Text("Connect Spotify"); Image(systemName: "arrow.right") }
                    .font(.system(size: 14, weight: .bold)).foregroundStyle(Palette.ink)
                    .frame(maxWidth: .infinity).frame(height: 46).background(Palette.green, in: Capsule())
            }.buttonStyle(BounceStyle()).padding(.top, 22)
            if let error = spotify.error { Text(error).font(.caption).foregroundStyle(.red).padding(.top, 13) }
            Button("Open Spotify Developer Dashboard") { NSWorkspace.shared.open(URL(string: "https://developer.spotify.com/dashboard")!) }
                .buttonStyle(.plain).font(.caption).foregroundStyle(Palette.muted).padding(.top, 18)
            Spacer()
            Text("Music plays on your Spotify devices")
                .font(.system(size: 10, weight: .medium)).foregroundStyle(Palette.muted).padding(.bottom, 30)
        }.padding(.horizontal, 36)
    }

    private var settingsSheet: some View {
        sheetFrame("Settings", close: { withAnimation(.spring()) { spotify.showingSettings = false } }) {
            VStack(alignment: .leading, spacing: 18) {
                HStack { Image(systemName: "person.crop.circle.fill").font(.system(size: 34)).foregroundStyle(Palette.green); VStack(alignment: .leading) { Text(spotify.profile?.display_name ?? "Spotify account").font(.headline); Text(spotify.profile?.product?.capitalized ?? "Connected").font(.caption).foregroundStyle(Palette.muted) }; Spacer() }
                VStack(alignment: .leading, spacing: 6) { Text("CLIENT ID").font(.system(size: 10, weight: .bold)).tracking(1.5).foregroundStyle(Palette.green); Text(spotify.clientID).font(.system(size: 11, design: .monospaced)).foregroundStyle(Palette.muted).textSelection(.enabled) }
                Button("Disconnect Spotify") { spotify.disconnect(); withAnimation { spotify.showingSettings = false } }.buttonStyle(.plain).foregroundStyle(.red.opacity(0.9))
                Spacer()
                Button("Quit SpotMenu") { NSApplication.shared.terminate(nil) }.buttonStyle(.plain).foregroundStyle(Palette.muted)
            }
        }
    }

    private var deviceSheet: some View {
        sheetFrame("Connect to a device", close: { withAnimation(.spring()) { devices = false } }) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Play your music anywhere").font(.caption).foregroundStyle(Palette.muted)
                ForEach(spotify.devices, id: \.stableID) { device in
                    Button { Task { await spotify.transfer(to: device) }; withAnimation { devices = false } } label: {
                        HStack(spacing: 13) {
                            Image(systemName: device.type == "Computer" ? "laptopcomputer" : device.type == "Smartphone" ? "iphone" : "hifispeaker").font(.title3).frame(width: 28)
                            VStack(alignment: .leading, spacing: 3) { Text(device.name).font(.system(size: 13, weight: .semibold)); Text(device.type).font(.caption).foregroundStyle(Palette.muted) }
                            Spacer()
                            if device.is_active { Image(systemName: "waveform").foregroundStyle(Palette.green) }
                        }.padding(13).background(Palette.raised, in: RoundedRectangle(cornerRadius: 12))
                    }.buttonStyle(.plain)
                }
                if spotify.devices.isEmpty { Text("Open Spotify on your Mac, phone, or speaker to see it here.").font(.caption).foregroundStyle(Palette.muted).padding(.top, 18) }
            }
        }
    }

    private func sheetFrame<Content: View>(_ title: String, close: @escaping () -> Void, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack { Text(title).font(.system(size: 23, weight: .bold, design: .rounded)); Spacer(); Button(action: close) { Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).frame(width: 29, height: 29).background(Palette.raised, in: Circle()) }.buttonStyle(.plain) }
            content()
            Spacer(minLength: 0)
        }.padding(24).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Palette.ink).overlay(alignment: .bottom) { Rectangle().fill(Palette.green.opacity(0.55)).frame(height: 2) }
    }

    private func errorBanner(_ error: String) -> some View {
        HStack(alignment: .top, spacing: 8) { Image(systemName: "exclamationmark.circle.fill"); Text(error).font(.system(size: 11)).fixedSize(horizontal: false, vertical: true); Spacer(); Button { spotify.error = nil } label: { Image(systemName: "xmark") }.buttonStyle(.plain) }
            .foregroundStyle(Color(red: 1, green: 0.72, blue: 0.67)).padding(11).background(Color.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 11))
    }

}

private struct SeekBar: View {
    @EnvironmentObject private var spotify: SpotifyService
    let playback: Playback?
    @State private var position = 0.0
    @State private var seeking = false
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 4) {
            Slider(value: $position, in: 0...Double(max(playback?.item?.duration_ms ?? 1, 1)), onEditingChanged: { editing in
                seeking = editing
                if !editing { Task { await spotify.seek(Int(position)) } }
            })
            .tint(Palette.green)
            .disabled(playback?.item == nil)
            HStack {
                Text(timeString(Int(position)))
                Spacer()
                Text(timeString(playback?.item?.duration_ms ?? 0))
            }
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(Palette.muted)
        }
        .onAppear { position = Double(playback?.progress_ms ?? 0) }
        .onChange(of: playback?.item?.stableID) { _, _ in position = Double(playback?.progress_ms ?? 0) }
        .onChange(of: playback?.progress_ms) { _, value in if !seeking { position = Double(value ?? 0) } }
        .onReceive(ticker) { _ in
            if playback?.is_playing == true && !seeking {
                position = min(position + 1000, Double(playback?.item?.duration_ms ?? 0))
            }
        }
    }

    private func timeString(_ milliseconds: Int) -> String {
        let seconds = max(milliseconds / 1000, 0)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

private struct CoverArt: View {
    let url: URL?
    let size: CGFloat
    let radius: CGFloat
    var body: some View {
        AsyncImage(url: url) { phase in
            if case .success(let image) = phase { image.resizable().scaledToFit() }
            else { ZStack { LinearGradient(colors: [Palette.green.opacity(0.55), Palette.surface], startPoint: .topLeading, endPoint: .bottomTrailing); Image(systemName: "music.note").font(.system(size: size * 0.28)).foregroundStyle(.white.opacity(0.8)) } }
        }
        .frame(width: size, height: size).background(Palette.raised).clipShape(RoundedRectangle(cornerRadius: radius))
    }
}

private struct BounceStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { configuration.label.scaleEffect(configuration.isPressed ? 0.92 : 1).animation(.spring(response: 0.25, dampingFraction: 0.55), value: configuration.isPressed) }
}
private struct HoverIconStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { configuration.label.opacity(configuration.isPressed ? 0.55 : 1).scaleEffect(configuration.isPressed ? 0.88 : 1).animation(.spring(response: 0.25), value: configuration.isPressed) }
}
private struct LiftStyle: ButtonStyle {
    @State private var hovering = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed ? 0.95 : hovering ? 1.035 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.7), value: hovering)
            .onHover { hovering = $0 }
    }
}
private struct Equalizer: View {
    @State private var dancing = false
    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(0..<4) { index in
                Capsule().fill(Palette.green).frame(width: 3, height: dancing ? CGFloat([7, 15, 10, 13][index]) : CGFloat([14, 6, 13, 8][index]))
                    .animation(.easeInOut(duration: Double([0.38, 0.52, 0.43, 0.61][index])).repeatForever(autoreverses: true), value: dancing)
            }
        }.onAppear { dancing = true }
    }
}
