// MARK: LUIYo — post-signing self-check, ported from the main app.
//
// Re-opens a signed IPA, finds the main executable's embedded code
// signature and verifies that the CodeDirectory's per-page hashes
// actually match the file bytes — the same check the loader
// effectively performs. A signer bug that corrupts the binary or
// writes stale hashes fails here instead of handing the user a
// broken IPA.
import CryptoKit
import Foundation

enum RGCodeSignatureCheck {
    static func verify(ipaAt url: URL) -> Bool {
        guard let archive = try? Data(contentsOf: url, options: .mappedIfSafe),
              let entries = RGZipReader.entries(in: archive) else { return false }

        guard let plistEntry = entries.first(where: {
                  $0.name.hasPrefix("Payload/") && $0.name.hasSuffix(".app/Info.plist")
              }),
              let plistData = RGZipReader.entryData(plistEntry, in: archive),
              let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any],
              let executable = plist["CFBundleExecutable"] as? String
        else { return false }

        let appPrefix = plistEntry.name.dropLast("Info.plist".count)
        guard let exeEntry = entries.first(where: { $0.name == appPrefix + executable }),
              let exeData = RGZipReader.entryData(exeEntry, in: archive)
        else { return false }
        return verifyCodeDirectory(inExecutable: exeData)
    }

    private static func verifyCodeDirectory(inExecutable data: Data) -> Bool {
        let bytes = [UInt8](data)
        guard let slice = RGMachO.sliceRange(in: bytes) else { return false }
        let sliceStart = slice.lowerBound
        let sliceLength = slice.count
        func be32(_ offset: Int) -> UInt32 {
            UInt32(bytes[offset]) << 24 | UInt32(bytes[offset + 1]) << 16
                | UInt32(bytes[offset + 2]) << 8 | UInt32(bytes[offset + 3])
        }
        guard let cs = RGMachO.codeSignatureRange(in: bytes, slice: slice) else { return false }
        let csStart = cs.lowerBound
        let signatureSize = cs.count

        // SuperBlob → the primary CodeDirectory (slot type 0).
        guard be32(csStart) == 0xfade0cc0 else { return false }
        let blobCount = Int(be32(csStart + 8))
        var cdStart = 0
        for i in 0..<blobCount {
            let entry = csStart + 12 + i * 8
            guard entry + 8 <= csStart + signatureSize else { return false }
            if be32(entry) == 0 {
                cdStart = csStart + Int(be32(entry + 4))
                break
            }
        }
        guard cdStart > 0, cdStart + 52 <= csStart + signatureSize,
              be32(cdStart) == 0xfade0c02 else { return false }

        let hashOffset = Int(be32(cdStart + 16))
        let nCodeSlots = Int(be32(cdStart + 28))
        let codeLimit = Int(be32(cdStart + 32))
        let hashSize = Int(bytes[cdStart + 36])
        let hashType = UInt32(bytes[cdStart + 37])
        let pageSize = Int(bytes[cdStart + 39])  // log2
        guard nCodeSlots > 0, codeLimit > 0, hashSize > 0,
              codeLimit <= sliceLength else { return false }

        // Hash every page of the executable slice and compare
        // against the hashes recorded in the CodeDirectory.
        let pageLength = 1 << pageSize
        for slot in 0..<nCodeSlots {
            let start = slot * pageLength
            let end = min(start + pageLength, codeLimit)
            guard end > start else { return false }
            let page = Data(bytes[(sliceStart + start)..<(sliceStart + end)])
            let digest: [UInt8]
            switch hashType {
            case 2:
                digest = [UInt8](SHA256.hash(data: page))
            case 1:
                digest = [UInt8](Insecure.SHA1.hash(data: page))
            default:
                return false  // unknown hash type — cannot verify
            }
            let storedStart = cdStart + hashOffset + slot * hashSize
            guard storedStart + hashSize <= csStart + signatureSize,
                  digest.count == hashSize else { return false }
            for i in 0..<hashSize where bytes[storedStart + i] != digest[i] {
                return false
            }
        }
        return true
    }
}
