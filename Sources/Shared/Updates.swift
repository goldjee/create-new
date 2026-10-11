import Foundation

/// The parts of a GitHub release the updater needs.
struct Release: Decodable {
    struct Asset: Decodable {
        let name: String
        let url: URL

        enum CodingKeys: String, CodingKey { case name, url = "browser_download_url" }
    }

    let tag: String
    let page: URL
    let assets: [Asset]

    enum CodingKeys: String, CodingKey { case tag = "tag_name", page = "html_url", assets }

    var version: String { tag.hasPrefix("v") ? String(tag.dropFirst()) : tag }
}

/// Shared by the app (offers and installs updates) and the Finder extension (daily check).
enum Updates {
    static let latestURL = URL(string: "https://api.github.com/repos/goldjee/create-new/releases/latest")!

    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    /// Compares numerically, so "v1.10" is newer than "1.9" and "1.0" equals "1.0.0".
    static func isNewer(_ version: String, than other: String) -> Bool {
        func parts(_ v: String) -> [Int] {
            (v.hasPrefix("v") ? v.dropFirst() : Substring(v)).split(separator: ".").map { Int($0) ?? 0 }
        }
        let a = parts(version), b = parts(other)
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0, y = i < b.count ? b[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    static func latest() async throws -> Release {
        var request = URLRequest(url: latestURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(Release.self, from: data)
    }
}
