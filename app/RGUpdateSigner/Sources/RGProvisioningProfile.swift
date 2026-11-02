// MARK: LUIYo — provisioning profile parsing for the update signer.
//
// A .mobileprovision is a CMS envelope around an XML plist. Like the
// main app's certificate store, this reads the embedded plist by
// locating the XML span; signature verification of the envelope is
// left to the system installer, which rejects a tampered profile
// when the signed update is installed.
import Foundation

struct RGProvisioningProfile {
    let data: Data
    let name: String
    let uuid: String?
    let teamIdentifiers: [String]
    let expirationDate: Date?
    let creationDate: Date?
    let entitlements: [String: Any]
    /// DER-encoded developer certificates embedded in the profile.
    let developerCertificates: [Data]

    var applicationIdentifier: String? {
        entitlements["application-identifier"] as? String
    }

    var isExpired: Bool {
        guard let expirationDate else { return false }
        return expirationDate.timeIntervalSinceNow < 0
    }

    func containsCertificate(der: Data) -> Bool {
        developerCertificates.contains(der)
    }

    /// Whether this profile's application-identifier authorizes the
    /// given bundle id. Handles the `<TEAMID>.` prefix, exact ids and
    /// the `*` / `prefix.*` wildcard forms.
    func authorizes(bundleId: String) -> Bool {
        guard let raw = applicationIdentifier, !raw.isEmpty else { return false }
        var pattern = raw
        // Strip the team prefix (everything up to the first dot) when
        // it matches one of the profile's own team identifiers.
        if let dot = raw.firstIndex(of: ".") {
            let prefix = String(raw[..<dot])
            if teamIdentifiers.contains(prefix) {
                pattern = String(raw[raw.index(after: dot)...])
            }
        }
        if pattern == "*" { return true }
        if pattern.hasSuffix(".*") {
            return bundleId.hasPrefix(String(pattern.dropLast(1)))
        }
        return pattern == bundleId
    }

    static func parse(_ data: Data) -> RGProvisioningProfile? {
        guard let plist = plistDictionary(fromProvision: data),
              let name = plist["Name"] as? String, !name.isEmpty,
              let entitlements = plist["Entitlements"] as? [String: Any]
        else { return nil }
        return RGProvisioningProfile(
            data: data,
            name: name,
            uuid: plist["UUID"] as? String,
            teamIdentifiers: plist["TeamIdentifier"] as? [String] ?? [],
            expirationDate: plist["ExpirationDate"] as? Date,
            creationDate: plist["CreationDate"] as? Date,
            entitlements: entitlements,
            developerCertificates: plist["DeveloperCertificates"] as? [Data] ?? []
        )
    }

    /// Extracts the plist dictionary from a .mobileprovision blob
    /// (same XML-span approach as the main app's profile parser).
    static func plistDictionary(fromProvision data: Data) -> [String: Any]? {
        guard let start = data.range(of: Data("<?xml".utf8)) else { return nil }
        let tail = data.subdata(in: start.lowerBound..<data.count)
        guard let end = tail.range(of: Data("</plist>".utf8)) else { return nil }
        let xml = tail.subdata(in: 0..<end.upperBound)
        return try? PropertyListSerialization.propertyList(from: xml, options: [], format: nil) as? [String: Any]
    }
}

/// Errors thrown by RGUpdateSigner use the "RGUpdateSigner" NSError
/// domain and the code vocabulary RGAppUpdater.mapSigningError maps:
/// 1 invalid certificate, 2 certificate mismatch, 3 profile problem
/// (userInfo "profileReason" / "bundleName" / "entitlement"),
/// 4 invalid archive, 5 identity mismatch, anything else = signing.
enum RGSignerError {
    static func make(_ code: Int, reason: String? = nil, bundleName: String? = nil, entitlement: String? = nil, description: String? = nil) -> NSError {
        var info: [String: Any] = [:]
        if let reason { info["profileReason"] = reason }
        if let bundleName { info["bundleName"] = bundleName }
        if let entitlement { info["entitlement"] = entitlement }
        if let description { info[NSLocalizedDescriptionKey] = description }
        return NSError(domain: "RGUpdateSigner", code: code, userInfo: info)
    }

    static var invalidCertificate: NSError { make(1) }
    static var certificateMismatch: NSError { make(2) }
    static var invalidArchive: NSError { make(4) }
    static var identityMismatch: NSError { make(5) }
}
