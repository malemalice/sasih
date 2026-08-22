import Foundation
import SasihCore

enum UpdateCheckResult {
    case upToDate(current: String)
    case updateAvailable(current: String, latest: String, url: URL)
    case failed(String)
}

enum UpdateChecker {
    private static let latestReleaseURL = URL(string: "https://api.github.com/repos/malemalice/sasih/releases/latest")!

    static func check() async -> UpdateCheckResult {
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"

        var request = URLRequest(url: latestReleaseURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return .failed("Couldn't reach GitHub to check for updates.")
            }

            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            let latestVersion = release.tagName.hasPrefix("v") ? String(release.tagName.dropFirst()) : release.tagName

            guard let url = URL(string: release.htmlURL) else {
                return .failed("Received an invalid release URL from GitHub.")
            }

            if VersionComparison.isNewer(latestVersion, than: currentVersion) {
                return .updateAvailable(current: currentVersion, latest: latestVersion, url: url)
            } else {
                return .upToDate(current: currentVersion)
            }
        } catch {
            return .failed("Couldn't check for updates: \(error.localizedDescription)")
        }
    }
}

private struct GitHubRelease: Decodable {
    let tagName: String
    let htmlURL: String

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
    }
}
