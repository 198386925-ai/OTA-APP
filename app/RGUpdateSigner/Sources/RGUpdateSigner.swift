// MARK: LUIYo — self-contained signing for in-app updates.
//
// Implements the six operations RGAppUpdater calls, following the
// approach the main app already runs on device: PKCS12 / profile
// validation with the Security framework, provisioning-profile
// parsing, and IPA signing through the bundled zsign engine
// (CBridge/, MIT — see CBridge/zsign-LICENSE.txt) via the
// `luiyo_zsign_sign` C bridge. The freshly signed package is only
// handed back after its CodeDirectory hashes verify.
//
// All failures are NSError in the "RGUpdateSigner" domain with the
// codes RGAppUpdater.mapSigningError understands (see
// RGProvisioningProfile.swift).
import Foundation
import Security

public enum RGUpdateSigner {

    // MARK: - Certificate and profiles

    /// Opens the PKCS12 with `password` and confirms its certificate
    /// is one of the developer certificates of a profile embedded in
    /// the installed app — i.e. updates signed with it keep the same
    /// signing identity. Returns the certificate's display name.
    /// Throws 1 (unreadable / wrong password / no identity) or
    /// 2 (valid certificate that does not match the installed app).
    public static func validateCertificate(_ data: Data, password: String, installedApp: String) throws -> String {
        let identity = try loadIdentity(p12: data, password: password)
        let embedded = RGIPAPackage.embeddedProfileData(appPath: installedApp)
            .compactMap(RGProvisioningProfile.parse)
        guard embedded.contains(where: { $0.containsCertificate(der: identity.certificateDER) }) else {
            throw RGSignerError.certificateMismatch
        }
        return identity.summary.isEmpty ? "Imported Certificate" : identity.summary
    }

    /// Every payload must parse as a provisioning profile.
    /// Throws 3 (unreadable, or expired with the profile's name).
    public static func validateProfiles(_ profiles: [Data]) throws {
        for raw in profiles {
            guard let profile = RGProvisioningProfile.parse(raw) else {
                throw RGSignerError.make(3)
            }
            if profile.isExpired {
                throw RGSignerError.make(3, reason: "expired", bundleName: profile.name)
            }
        }
    }

    /// Profiles embedded in the installed app (main bundle and
    /// extensions) that authorize the given certificate — the caller
    /// stores them so a later signing run can reuse the very profile
    /// the installed build is running with.
    /// Throws 1 when the certificate itself cannot be opened.
    public static func installedProfiles(_ installedApp: String, certificate: Data, password: String) throws -> [Data] {
        let identity = try loadIdentity(p12: certificate, password: password)
        var result: [Data] = []
        for raw in RGIPAPackage.embeddedProfileData(appPath: installedApp) {
            guard let profile = RGProvisioningProfile.parse(raw),
                  profile.containsCertificate(der: identity.certificateDER),
                  !result.contains(raw) else { continue }
            result.append(raw)
        }
        return result
    }

    /// Confirms at least one of `profiles` can sign updates for the
    /// installed app with the given certificate: unexpired, holds
    /// the certificate, authorizes the installed bundle id, and
    /// covers every entitlement the installed app was signed with.
    /// Throws 1 (certificate), 3 with a specific profileReason
    /// (missing / unreadable / expired / certificate /
    /// applicationIdentifier / entitlement / installedEntitlements),
    /// or 5 when the installed app's identity cannot be read.
    public static func validateInstalledApp(_ installedApp: String, certificate: Data, password: String, profiles: [Data]) throws {
        let identity = try loadIdentity(p12: certificate, password: password)
        _ = try selectProfile(installedApp: installedApp, identityDER: identity.certificateDER, profiles: profiles)
    }

    // MARK: - Signing

    /// Validates the downloaded IPA against the expected release
    /// and the installed app, signs it with the certificate and the
    /// best matching profile, and verifies the result before
    /// returning. The signed package lands at `output`.
    /// Throws 1/3/5 from validation, 4 for a broken archive, and a
    /// plain signing error (engine failure, failed self-check).
    public static func prepareIPA(_ ipa: String, output: String, installedApp: String, certificate: Data, password: String, profiles: [Data], expectedVersion: String, expectedBuild: String) throws {
        let identity = try loadIdentity(p12: certificate, password: password)
        let profile = try selectProfile(installedApp: installedApp, identityDER: identity.certificateDER, profiles: profiles)
        guard let installedInfo = RGIPAPackage.installedAppInfo(appPath: installedApp) else {
            throw RGSignerError.identityMismatch
        }
        let packageInfo = try RGIPAPackage.appInfo(ipaPath: ipa)
        guard packageInfo.bundleId == installedInfo.bundleId,
              packageInfo.version == expectedVersion,
              packageInfo.build == expectedBuild else {
            throw RGSignerError.identityMismatch
        }

        let fm = FileManager.default
        let work = fm.temporaryDirectory.appendingPathComponent("RGUpdateSigner-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: work) }
        try fm.createDirectory(at: work, withIntermediateDirectories: true)
        let p12URL = work.appendingPathComponent("identity.p12")
        let profileURL = work.appendingPathComponent("profile.mobileprovision")
        try certificate.write(to: p12URL, options: .atomic)
        try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: p12URL.path)
        try profile.data.write(to: profileURL, options: .atomic)
        try? fm.removeItem(atPath: output)

        var errorBuffer = [CChar](repeating: 0, count: 4096)
        let rc = luiyo_zsign_sign(
            ipa, p12URL.path, password, profileURL.path,
            output, work.path,
            &errorBuffer, Int32(errorBuffer.count))
        guard rc == 0 else {
            let engineText = String(cString: errorBuffer).trimmingCharacters(in: .whitespacesAndNewlines)
            throw RGSignerError.make(6, description: engineText.isEmpty ? "zsign failed (rc \(rc))" : engineText)
        }
        let outputURL = URL(fileURLWithPath: output)
        guard RGCodeSignatureCheck.verify(ipaAt: outputURL) else {
            try? fm.removeItem(at: outputURL)
            throw RGSignerError.make(6, description: "post-sign CodeDirectory verification failed")
        }
        let signedInfo = try RGIPAPackage.appInfo(ipaPath: output)
        guard signedInfo.bundleId == installedInfo.bundleId,
              signedInfo.version == expectedVersion,
              signedInfo.build == expectedBuild else {
            try? fm.removeItem(at: outputURL)
            throw RGSignerError.identityMismatch
        }
    }

    /// TrollStore installs the original package, so no signing
    /// happens here — only the same identity checks: readable
    /// archive, same bundle id as the installed app, and the
    /// expected version / build. Throws 4 or 5.
    public static func validateTrollStoreIPA(_ ipa: String, installedApp: String, expectedVersion: String, expectedBuild: String) throws {
        let packageInfo = try RGIPAPackage.appInfo(ipaPath: ipa)
        guard let installedInfo = RGIPAPackage.installedAppInfo(appPath: installedApp) else {
            throw RGSignerError.identityMismatch
        }
        guard packageInfo.bundleId == installedInfo.bundleId,
              packageInfo.version == expectedVersion,
              packageInfo.build == expectedBuild else {
            throw RGSignerError.identityMismatch
        }
    }

    // MARK: - Internals

    struct SigningIdentity {
        let certificateDER: Data
        let summary: String
    }

    static func loadIdentity(p12: Data, password: String) throws -> SigningIdentity {
        if let identity = try? openIdentity(p12: p12, password: password) { return identity }
        // Some services deliver the PKCS12 as base64 text (optionally
        // PEM-armored). Unwrap and retry once, like the main app.
        if let unwrapped = unwrappedP12(p12), let identity = try? openIdentity(p12: unwrapped, password: password) {
            return identity
        }
        throw RGSignerError.invalidCertificate
    }

    private static func openIdentity(p12: Data, password: String) throws -> SigningIdentity {
        let options: [String: Any] = [kSecImportExportPassphrase as String: password]
        var items: CFArray?
        let status = SecPKCS12Import(p12 as CFData, options as CFDictionary, &items)
        guard status == errSecSuccess,
              let array = items as? [NSDictionary],
              let first = array.first,
              let rawIdentity = first[kSecImportItemIdentity as String]
        else { throw RGSignerError.invalidCertificate }
        let identity = rawIdentity as! SecIdentity
        var certificate: SecCertificate?
        guard SecIdentityCopyCertificate(identity, &certificate) == errSecSuccess, let certificate else {
            throw RGSignerError.invalidCertificate
        }
        return SigningIdentity(
            certificateDER: SecCertificateCopyData(certificate) as Data,
            summary: (SecCertificateCopySubjectSummary(certificate) as String?) ?? ""
        )
    }

    /// Base64 / PEM text wrapped PKCS12 → raw bytes (nil when the
    /// data is not such text).
    private static func unwrappedP12(_ data: Data) -> Data? {
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("-----") }
        guard !lines.isEmpty else { return nil }
        let joined = lines.joined()
        let base64Set = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=")
        guard joined.count % 4 == 0,
              joined.unicodeScalars.allSatisfy({ base64Set.contains($0) }),
              let decoded = Data(base64Encoded: joined), !decoded.isEmpty
        else { return nil }
        return decoded
    }

    /// Picks the profile that can sign updates for the installed
    /// app with this identity, or throws the failure of the profile
    /// that progressed furthest through the checks.
    static func selectProfile(installedApp: String, identityDER: Data, profiles: [Data]) throws -> RGProvisioningProfile {
        guard let info = RGIPAPackage.installedAppInfo(appPath: installedApp) else {
            throw RGSignerError.identityMismatch
        }
        guard let installedEntitlements = RGIPAPackage.installedEntitlements(appPath: installedApp) else {
            throw RGSignerError.make(3, reason: "installedEntitlements", bundleName: info.displayName)
        }
        guard !profiles.isEmpty else {
            throw RGSignerError.make(3, reason: "missing", bundleName: info.bundleId)
        }
        var best: (stage: Int, error: NSError)?
        func consider(stage: Int, error: NSError) {
            if best == nil || stage > best!.stage { best = (stage, error) }
        }
        for raw in profiles {
            guard let profile = RGProvisioningProfile.parse(raw) else {
                consider(stage: 0, error: RGSignerError.make(3, reason: "unreadable", bundleName: info.displayName))
                continue
            }
            if profile.isExpired {
                consider(stage: 1, error: RGSignerError.make(3, reason: "expired", bundleName: profile.name))
                continue
            }
            guard profile.containsCertificate(der: identityDER) else {
                consider(stage: 2, error: RGSignerError.make(3, reason: "certificate", bundleName: profile.name))
                continue
            }
            guard profile.authorizes(bundleId: info.bundleId) else {
                consider(stage: 3, error: RGSignerError.make(3, reason: "applicationIdentifier", bundleName: profile.name))
                continue
            }
            if let gap = entitlementGap(installed: installedEntitlements, profile: profile) {
                consider(stage: 4, error: RGSignerError.make(3, reason: "entitlement", bundleName: profile.name, entitlement: gap))
                continue
            }
            return profile
        }
        throw best?.error ?? RGSignerError.make(3, reason: "missing", bundleName: info.bundleId)
    }

    /// The first installed-app entitlement the profile does not
    /// cover, if any. application-identifier and the team id are
    /// checked separately; exotic value types never fail the check.
    static func entitlementGap(installed: [String: Any], profile: RGProvisioningProfile) -> String? {
        for key in installed.keys.sorted() {
            if key == "application-identifier" || key == "com.apple.developer.team-identifier" { continue }
            let installedValue = installed[key]!
            if key == "keychain-access-groups" {
                let wanted = stringArray(installedValue).map(stripTeamPrefix)
                let offered = stringArray(profile.entitlements[key]).map(stripTeamPrefix)
                if offered.contains("*") || wanted.allSatisfy(offered.contains) { continue }
                return key
            }
            guard let profileValue = profile.entitlements[key] else { return key }
            switch installedValue {
            case let bool as Bool:
                if bool && (profileValue as? Bool) != true { return key }
            case let string as String:
                let offered = profileValue as? String
                if offered != string && offered != "*" { return key }
            case let array as [String]:
                let offered = stringArray(profileValue)
                if !array.allSatisfy(offered.contains) { return key }
            default:
                continue
            }
        }
        return nil
    }

    private static func stringArray(_ value: Any?) -> [String] {
        (value as? [String]) ?? []
    }

    private static func stripTeamPrefix(_ group: String) -> String {
        guard let dot = group.firstIndex(of: ".") else { return group }
        return String(group[group.index(after: dot)...])
    }
}
