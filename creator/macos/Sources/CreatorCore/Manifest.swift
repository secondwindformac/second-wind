// What to download and how to verify it.
//
// The source of truth is `creator-manifest.json`, attached to every GitHub
// release by scripts/publish.sh --release. The app fetches the latest
// release's manifest; if the network or API fails, it falls back to the
// values pinned at build time (kept in sync with versions.lock).
import Foundation

public struct CreatorManifest: Codable {
    public let version: String
    public let isoURL: String
    public let isoSHA256: String
    public let payloadName: String
    public let payloadSHA256: String
    /// Filled in after resolving the release assets (not part of the JSON).
    public var payloadURL: String?

    enum CodingKeys: String, CodingKey {
        case version
        case isoURL = "iso_url"
        case isoSHA256 = "iso_sha256"
        case payloadName = "payload_name"
        case payloadSHA256 = "payload_sha256"
    }
}

public enum ManifestSource {
    public static let repo = "arancibiamartin/second-wind"

    /// Pinned fallback — mirrors versions.lock at the time this app was built.
    public static let builtIn = CreatorManifest(
        version: "0.9.0",
        isoURL: "https://releases.ubuntu.com/24.04/ubuntu-24.04.4-desktop-amd64.iso",
        isoSHA256: "3a4c9877b483ab46d7c3fbe165a0db275e1ae3cfe56a5657e5a47c2f99a99d1e",
        payloadName: "second-wind-0.9.0.tar.gz",
        payloadSHA256: "",
        payloadURL: "https://github.com/arancibiamartin/second-wind/releases/download/v0.9.0/second-wind-0.9.0.tar.gz"
    )

    /// Latest manifest from GitHub releases, with the payload URL resolved.
    public static func fetchLatest() async throws -> CreatorManifest {
        let api = URL(string: "https://api.github.com/repos/\(repo)/releases/latest")!
        let releaseData = try await HTTP.get(api, accept: "application/vnd.github+json")
        struct Asset: Codable {
            let name: String
            let browser_download_url: String
        }
        struct Release: Codable { let assets: [Asset] }
        let release = try JSONDecoder().decode(Release.self, from: releaseData)

        guard let manifestAsset = release.assets.first(where: { $0.name == "creator-manifest.json" })
        else { throw DownloadError.transport("release has no creator-manifest.json") }
        let manifestData = try await HTTP.get(URL(string: manifestAsset.browser_download_url)!)
        var manifest = try JSONDecoder().decode(CreatorManifest.self, from: manifestData)

        guard let payload = release.assets.first(where: { $0.name == manifest.payloadName })
        else { throw DownloadError.transport("release has no \(manifest.payloadName)") }
        manifest.payloadURL = payload.browser_download_url
        return manifest
    }

    /// Latest if reachable, built-in pin otherwise.
    public static func resolve() async -> CreatorManifest {
        (try? await fetchLatest()) ?? builtIn
    }
}
