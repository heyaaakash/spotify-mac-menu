import AppKit
import CryptoKit
import Foundation
import Network
import Security

@MainActor final class SpotifyService: ObservableObject {
    @Published var clientID = UserDefaults.standard.string(forKey: "spotifyClientID") ?? ""
    @Published var connected = false
    @Published var busy = false
    @Published var error: String?
    @Published var profile: Profile?
    @Published var playback: Playback?
    @Published var playlists: [Playlist] = []
    @Published var saved: [Track] = []
    @Published var recent: [Track] = []
    @Published var topTracks: [Track] = []
    @Published var search: SearchResults?
    @Published var searching = false
    @Published var queue: [Track] = []
    @Published var devices: [Device] = []
    @Published var detailTitle: String?
    @Published var detailTracks: [Track] = []
    @Published var compact = false
    @Published var showingSettings = false

    private let redirect = "http://127.0.0.1:8888/callback"
    private let scopes = "user-read-playback-state user-modify-playback-state user-read-currently-playing user-library-read user-library-modify playlist-read-private playlist-read-collaborative user-read-recently-played user-top-read"
    private var accessToken: String?
    private var refreshToken: String?
    private var expiresAt = Date.distantPast
    private var verifier: String?
    private var expectedState: String?
    private var listener: NWListener?
    private var searchTask: Task<Void, Never>?
    private var refreshTask: Task<TokenResponse, Error>?
    private var playbackRequestID = 0
    private var detailRequestID = 0

    init() {
        refreshToken = Keychain.read("refreshToken")
        connected = refreshToken != nil
        if connected { Task { await refreshAll() } }
    }

    func connect() {
        let trimmed = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { error = "Enter the Client ID from your Spotify developer app."; return }
        UserDefaults.standard.set(trimmed, forKey: "spotifyClientID")
        clientID = trimmed
        do {
            listener = try NWListener(using: .tcp, on: 8888)
        } catch {
            self.error = "Could not open callback port 8888. Close any app using it and try again."
            return
        }
        let verifier = randomURLSafe(64)
        let state = randomURLSafe(24)
        self.verifier = verifier
        expectedState = state
        let digest = SHA256.hash(data: Data(verifier.utf8))
        let challenge = Data(digest).base64URLEncodedString()
        listener?.newConnectionHandler = { [weak self] connection in
            connection.start(queue: .main)
            connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { data, _, _, _ in
                guard let data, let request = String(data: data, encoding: .utf8),
                      let path = request.components(separatedBy: " ").dropFirst().first,
                      let url = URL(string: "http://127.0.0.1:8888" + path) else { connection.cancel(); return }
                let html = "<html><body style='background:#101410;color:#fff;font:18px system-ui;text-align:center;padding:80px'><h1>Connected to SpotMenu</h1><p>You can close this tab and return to the menu bar.</p></body></html>"
                let response = "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: \(html.utf8.count)\r\nConnection: close\r\n\r\n" + html
                connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in connection.cancel() })
                Task { @MainActor in self?.handleCallback(url) }
            }
        }
        listener?.stateUpdateHandler = { [weak self] state in
            if case .failed = state { Task { @MainActor in self?.error = "Callback listener failed. Check that port 8888 is free." } }
        }
        listener?.start(queue: .main)
        var components = URLComponents(string: "https://accounts.spotify.com/authorize")!
        components.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: trimmed),
            URLQueryItem(name: "scope", value: scopes),
            URLQueryItem(name: "redirect_uri", value: redirect),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: challenge)
        ]
        if let url = components.url { NSWorkspace.shared.open(url) }
    }

    private func handleCallback(_ url: URL) {
        listener?.cancel(); listener = nil
        let values = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ key: String) -> String? { values.first(where: { $0.name == key })?.value }
        guard value("state") == expectedState else { error = "Spotify sign-in state did not match. Please try again."; return }
        guard let code = value("code"), let verifier else { error = value("error") ?? "Spotify sign-in did not finish."; return }
        Task {
            do {
                let token = try await tokenRequest(["grant_type": "authorization_code", "code": code, "redirect_uri": redirect, "client_id": clientID, "code_verifier": verifier])
                store(token)
                connected = true
                error = nil
                await refreshAll()
            } catch { self.error = error.localizedDescription }
        }
    }

    func disconnect() {
        listener?.cancel(); listener = nil
        Keychain.delete("refreshToken")
        accessToken = nil; refreshToken = nil; connected = false
        playback = nil; playlists = []; saved = []; recent = []; topTracks = []; queue = []
    }

    private func tokenRequest(_ form: [String: String]) async throws -> TokenResponse {
        var request = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var components = URLComponents()
        components.queryItems = form.map { URLQueryItem(name: $0.key, value: $0.value) }
        request.httpBody = components.percentEncodedQuery?.data(using: .utf8)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw APIError.message("Spotify authorization failed. Check your Client ID and redirect URI.") }
        return try JSONDecoder().decode(TokenResponse.self, from: data)
    }

    private func store(_ token: TokenResponse) {
        accessToken = token.access_token
        expiresAt = Date().addingTimeInterval(TimeInterval(token.expires_in - 60))
        if let newRefresh = token.refresh_token { refreshToken = newRefresh; Keychain.write(newRefresh, "refreshToken") }
    }

    private func validToken() async throws -> String {
        if let accessToken, Date() < expiresAt { return accessToken }
        guard let refreshToken else { throw APIError.message("Connect Spotify to continue.") }
        if let refreshTask { return try await refreshTask.value.access_token }
        let task = Task { try await tokenRequest(["grant_type": "refresh_token", "refresh_token": refreshToken, "client_id": clientID]) }
        refreshTask = task
        defer { refreshTask = nil }
        let token = try await task.value
        store(token)
        return token.access_token
    }

    private func request<T: Decodable & Sendable>(_ path: String, method: String = "GET", query: [URLQueryItem] = [], body: Data? = nil) async throws -> T? {
        var components = URLComponents(string: "https://api.spotify.com/v1" + path)!
        if !query.isEmpty { components.queryItems = query }
        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        request.setValue("Bearer \(try await validToken())", forHTTPHeaderField: "Authorization")
        if let body { request.httpBody = body; request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 204 { return nil }
        guard (200..<300).contains(status) else {
            if status == 401 { accessToken = nil }
            let message: String
            switch status {
            case 401: message = "Spotify session expired. Reconnect from Settings."
            case 403: message = "Spotify denied this action. Playback controls require an eligible Premium account and an active device."
            case 404: message = "No active Spotify device. Open Spotify on your Mac or choose a device."
            case 429: message = "Spotify is rate limiting requests. Please try again shortly."
            default: message = "Spotify request failed (\(status))."
            }
            throw APIError.message(message)
        }
        if T.self == Empty.self { return Empty() as? T }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private struct Empty: Decodable, Sendable {}
    private func send(_ path: String, method: String, query: [URLQueryItem] = [], body: Data? = nil, localFallback: String? = nil, refreshAfter: Bool = true) async {
        do {
            let _: Empty? = try await request(path, method: method, query: query, body: body)
            error = nil
            if refreshAfter { await refreshPlayback() }
        }
        catch {
            if let localFallback, runLocal(localFallback) {
                self.error = nil
                if refreshAfter { await refreshPlayback() }
            }
            else { self.error = error.localizedDescription }
        }
    }

    private func runLocal(_ command: String) -> Bool {
        guard let script = NSAppleScript(source: "tell application id \"com.spotify.client\" to \(command)") else { return false }
        var details: NSDictionary?
        _ = script.executeAndReturnError(&details)
        return details == nil
    }

    func refreshAll() async {
        guard connected && !busy else { return }
        busy = true
        async let profileResult: Profile? = request("/me")
        async let playlistResult: Page<Playlist>? = request("/me/playlists", query: [.init(name: "limit", value: "30")])
        async let savedResult: Page<SavedTrack>? = request("/me/tracks", query: [.init(name: "limit", value: "30")])
        async let recentResult: Page<RecentTrack>? = request("/me/player/recently-played", query: [.init(name: "limit", value: "20")])
        async let topResult: Page<Track>? = request("/me/top/tracks", query: [.init(name: "limit", value: "20")])
        async let playbackResult: Playback? = request("/me/player")
        do { profile = try await profileResult } catch { self.error = error.localizedDescription }
        do { playlists = try await playlistResult?.items ?? [] } catch { self.error = error.localizedDescription }
        do { saved = try await savedResult?.items.map(\.track) ?? [] } catch { self.error = error.localizedDescription }
        do { recent = try await recentResult?.items.map(\.track) ?? [] } catch { self.error = error.localizedDescription }
        do { topTracks = try await topResult?.items ?? [] } catch { self.error = error.localizedDescription }
        do { playback = try await playbackResult } catch { self.error = error.localizedDescription }
        busy = false
    }

    func refreshPlayback() async {
        guard connected else { return }
        playbackRequestID += 1
        let requestID = playbackRequestID
        do {
            let latest: Playback? = try await request("/me/player")
            if requestID == playbackRequestID { playback = latest }
        }
        catch { self.error = error.localizedDescription }
    }

    func loadQueue() async {
        do { queue = try await (request("/me/player/queue") as QueueResult?)?.queue ?? [] }
        catch { self.error = error.localizedDescription }
    }
    func loadDevices() async {
        do { devices = try await (request("/me/player/devices") as DeviceList?)?.devices ?? [] }
        catch { self.error = error.localizedDescription }
    }
    func searchFor(_ text: String) {
        searchTask?.cancel()
        search = nil
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { searching = false; return }
        searching = true
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(260))
            guard !Task.isCancelled else { return }
            do {
                let result: SearchResults? = try await request("/search", query: [.init(name: "q", value: query), .init(name: "type", value: "track,album,artist,playlist"), .init(name: "limit", value: "8")])
                if !Task.isCancelled { search = result; searching = false }
            } catch { if !Task.isCancelled { self.error = error.localizedDescription; searching = false } }
        }
    }
    func closeDetail() { detailRequestID += 1; detailTitle = nil; detailTracks = [] }
    func openPlaylist(_ playlist: Playlist) async {
        guard let id = playlist.id else { return }
        detailRequestID += 1
        let requestID = detailRequestID
        detailTitle = playlist.name; detailTracks = []
        do {
            let tracks = try await (request("/playlists/\(id)/items", query: [.init(name: "limit", value: "50")]) as Page<PlaylistItem>?)?.items.compactMap(\.resolved) ?? []
            if requestID == detailRequestID { detailTracks = tracks }
        }
        catch { self.error = error.localizedDescription }
    }
    func openAlbum(_ album: Album) async {
        guard let id = album.id else { return }
        detailRequestID += 1
        let requestID = detailRequestID
        detailTitle = album.name; detailTracks = []
        do {
            let page: Page<Track>? = try await request("/albums/\(id)/tracks", query: [.init(name: "limit", value: "50")])
            if requestID == detailRequestID {
                detailTracks = page?.items.map { Track(id: $0.id, name: $0.name, uri: $0.uri, duration_ms: $0.duration_ms, artists: $0.artists, album: album) } ?? []
            }
        } catch { self.error = error.localizedDescription }
    }
    func play(_ track: Track) async {
        guard let uri = track.uri else { return }
        let body = try? JSONSerialization.data(withJSONObject: ["uris": [uri]])
        await send("/me/player/play", method: "PUT", body: body, localFallback: "play track \"\(uri)\"")
    }
    func playContext(_ uri: String?) async {
        guard let uri else { return }
        let body = try? JSONSerialization.data(withJSONObject: ["context_uri": uri])
        await send("/me/player/play", method: "PUT", body: body)
    }
    func togglePlayback() async { await send(playback?.is_playing == true ? "/me/player/pause" : "/me/player/play", method: "PUT", localFallback: "playpause") }
    func next() async { await send("/me/player/next", method: "POST", localFallback: "next track") }
    func previous() async { await send("/me/player/previous", method: "POST", localFallback: "previous track") }
    func seek(_ milliseconds: Int) async { await send("/me/player/seek", method: "PUT", query: [.init(name: "position_ms", value: String(milliseconds))], localFallback: "set player position to \(max(0, milliseconds / 1000))") }
    func volume(_ percent: Int) async { await send("/me/player/volume", method: "PUT", query: [.init(name: "volume_percent", value: String(percent))], localFallback: "set sound volume to \(min(100, max(0, percent)))") }
    func shuffle() async { await send("/me/player/shuffle", method: "PUT", query: [.init(name: "state", value: playback?.shuffle_state == true ? "false" : "true")]) }
    func repeatMode() async {
        let next = playback?.repeat_state == "off" ? "context" : playback?.repeat_state == "context" ? "track" : "off"
        await send("/me/player/repeat", method: "PUT", query: [.init(name: "state", value: next)])
    }
    func addToQueue(_ track: Track) async {
        guard let uri = track.uri else { return }
        await send("/me/player/queue", method: "POST", query: [.init(name: "uri", value: uri)], refreshAfter: false)
        await loadQueue()
    }
    func transfer(to device: Device) async {
        guard let id = device.id else { return }
        let body = try? JSONSerialization.data(withJSONObject: ["device_ids": [id], "play": true] as [String: Any])
        await send("/me/player", method: "PUT", body: body)
        await loadDevices()
    }
    func save(_ track: Track, saved isSaved: Bool) async {
        guard let id = track.id else { return }
        await send("/me/tracks", method: isSaved ? "DELETE" : "PUT", query: [.init(name: "ids", value: id)], refreshAfter: false)
        do { saved = try await (request("/me/tracks", query: [.init(name: "limit", value: "30")]) as Page<SavedTrack>?)?.items.map(\.track) ?? [] }
        catch { self.error = error.localizedDescription }
    }
}

private func randomURLSafe(_ count: Int) -> String {
    let chars = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
    return String((0..<count).compactMap { _ in chars.randomElement() })
}
private extension Data {
    func base64URLEncodedString() -> String { base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "") }
}
private enum Keychain {
    static let service = "com.spotmenu.auth"
    static func read(_ key: String) -> String? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: key, kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    static func write(_ value: String, _ key: String) {
        delete(key)
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: key, kSecValueData as String: Data(value.utf8)]
        SecItemAdd(query as CFDictionary, nil)
    }
    static func delete(_ key: String) {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: key]
        SecItemDelete(query as CFDictionary)
    }
}
