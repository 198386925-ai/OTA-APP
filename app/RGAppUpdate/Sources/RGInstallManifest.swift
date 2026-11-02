// MARK: LUIYo — Apple OTA installation manifest, built and checked locally.
//
// The manifest is the standard plist the system installer fetches
// for itms-services downloads: one software item whose metadata
// names the bundle id / version and whose single software-package
// asset points at the package URL. It is generated on device and
// served by RGLocalUpdateServer together with the package, so no
// third-party manifest service is involved.
import Foundation

public enum RGInstallManifest {
    public static func make(bundleId: String, build: String, title: String, packageURL: URL) throws -> Data {
        guard packageURL.scheme == "http" || packageURL.scheme == "https",
              packageURL.host != nil, packageURL.user == nil, packageURL.password == nil else {
            throw RGUpdateError.invalidManifest
        }
        let plist: [String: Any] = [
            "items": [[
                "assets": [["kind": "software-package", "url": packageURL.absoluteString]],
                "metadata": [
                    "bundle-identifier": bundleId,
                    "bundle-version": build,
                    "kind": "software",
                    "title": title
                ]
            ]]
        ]
        return try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
    }

    /// Re-reads a manifest and confirms it describes exactly this
    /// package for this app build before it is handed to the system.
    public static func validate(_ data: Data, bundleId: String, build: String, packageURL: URL) throws {
        guard let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let items = plist["items"] as? [[String: Any]], items.count == 1,
              let metadata = items[0]["metadata"] as? [String: Any],
              metadata["bundle-identifier"] as? String == bundleId,
              metadata["bundle-version"] as? String == build,
              metadata["kind"] as? String == "software",
              let assets = items[0]["assets"] as? [[String: Any]], assets.count == 1,
              assets[0]["kind"] as? String == "software-package",
              assets[0]["url"] as? String == packageURL.absoluteString
        else { throw RGUpdateError.invalidManifest }
    }

    /// itms-services download URL for a manifest URL. The empty
    /// authority is required to produce itms-services://? rather
    /// than the opaque itms-services:? form.
    public static func installationURL(manifestURL: URL) throws -> URL {
        guard manifestURL.scheme == "http" || manifestURL.scheme == "https",
              manifestURL.host != nil, manifestURL.query == nil else {
            throw RGUpdateError.invalidManifest
        }
        var components = URLComponents()
        components.scheme = "itms-services"
        components.host = ""
        components.queryItems = [
            URLQueryItem(name: "action", value: "download-manifest"),
            URLQueryItem(name: "url", value: manifestURL.absoluteString)
        ]
        guard let url = components.url else { throw RGUpdateError.invalidManifest }
        return url
    }
}
