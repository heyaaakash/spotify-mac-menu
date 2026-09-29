import Foundation

struct SpotifyImage: Decodable, Hashable, Sendable { let url: String }
struct Artist: Decodable, Identifiable, Hashable, Sendable {
    let id: String?
    let name: String
    let uri: String?
    var stableID: String { id ?? name }
}
struct Album: Decodable, Identifiable, Hashable, Sendable {
    let id: String?
    let name: String
    let uri: String?
    let images: [SpotifyImage]?
    let artists: [Artist]?
    var stableID: String { id ?? name }
    var imageURL: URL? { images?.first.flatMap { URL(string: $0.url) } }
}
struct Track: Decodable, Identifiable, Hashable, Sendable {
    let id: String?
    let name: String
    let uri: String?
    let duration_ms: Int?
    let artists: [Artist]?
    let album: Album?
    var stableID: String { id ?? uri ?? name }
    var artistLine: String { artists?.map(\.name).joined(separator: ", ") ?? "Unknown artist" }
    var imageURL: URL? { album?.imageURL }
}
struct Playlist: Decodable, Identifiable, Hashable, Sendable {
    let id: String?
    let name: String
    let uri: String?
    let description: String?
    let images: [SpotifyImage]?
    var stableID: String { id ?? name }
    var imageURL: URL? { images?.first.flatMap { URL(string: $0.url) } }
}
struct Page<T: Decodable & Sendable>: Decodable, Sendable { let items: [T] }
struct SavedTrack: Decodable, Sendable { let track: Track }
struct RecentTrack: Decodable, Sendable { let track: Track }
struct PlaylistItem: Decodable, Sendable { let item: Track?; let track: Track?; var resolved: Track? { item ?? track } }
struct SearchResults: Decodable, Sendable { let tracks: Page<Track>?; let artists: Page<Artist>?; let albums: Page<Album>?; let playlists: Page<Playlist?>? }
struct Playback: Decodable, Sendable {
    let is_playing: Bool
    let progress_ms: Int?
    let repeat_state: String?
    let shuffle_state: Bool?
    let item: Track?
    let device: Device?
}
struct Device: Decodable, Identifiable, Sendable {
    let id: String?
    let name: String
    let type: String
    let is_active: Bool
    let volume_percent: Int?
    var stableID: String { id ?? name }
}
struct DeviceList: Decodable, Sendable { let devices: [Device] }
struct QueueResult: Decodable, Sendable { let queue: [Track] }
struct Profile: Decodable, Sendable { let display_name: String?; let product: String? }
struct TokenResponse: Decodable, Sendable { let access_token: String; let token_type: String; let expires_in: Int; let refresh_token: String? }

enum APIError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let value) = self { value } else { nil } }
}
