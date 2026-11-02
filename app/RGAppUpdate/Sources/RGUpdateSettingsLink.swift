// MARK: LUIYo — deep link into the app's own update settings,
// built from the URL schemes the host app actually registered.
import Foundation

enum RGUpdateSettingsLink {
    static var current: URL {
        let reserved: Set<String> = ["http", "https", "file"]
        let schemes = (Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] ?? [])
            .flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }
        let scheme = schemes.first { candidate in
            let lower = candidate.lowercased()
            return !reserved.contains(lower)
                && candidate.range(of: "^[A-Za-z][A-Za-z0-9+.-]*$", options: .regularExpression) != nil
        } ?? "luiyo"
        var components = URLComponents()
        components.scheme = scheme; components.host = "rg"; components.path = "/settings"
        components.queryItems = [URLQueryItem(name: "page", value: "updates")]
        return components.url!
    }
}
