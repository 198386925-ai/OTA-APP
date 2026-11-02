// MARK: LUIYo — IPA / installed-app inspection for the update signer.
//
// The ZIP reader is the self-contained central-directory reader the
// main app uses for its certificate imports and post-signing checks
// (store + raw DEFLATE via the Compression framework).
import Compression
import Foundation

enum RGZipReader {
    struct Entry {
        let name: String
        let method: UInt16
        let compressedSize: Int
        let uncompressedSize: Int
        let localHeaderOffset: Int
    }

    static func entries(in data: Data) -> [Entry]? {
        let bytes = [UInt8](data)
        guard bytes.count >= 22 else { return nil }
        func le16(_ offset: Int) -> Int {
            Int(bytes[offset]) | Int(bytes[offset + 1]) << 8
        }
        func le32(_ offset: Int) -> Int {
            Int(bytes[offset]) | Int(bytes[offset + 1]) << 8
                | Int(bytes[offset + 2]) << 16 | Int(bytes[offset + 3]) << 24
        }
        var eocd = -1
        let scanStart = max(0, bytes.count - 22 - 0xFFFF)
        var i = bytes.count - 22
        while i >= scanStart {
            if le32(i) == 0x06054b50 { eocd = i; break }
            i -= 1
        }
        guard eocd >= 0 else { return nil }
        let total = le16(eocd + 10)
        var offset = le32(eocd + 16)
        var entries: [Entry] = []
        for _ in 0..<total {
            guard offset + 46 <= bytes.count, le32(offset) == 0x02014b50 else { return nil }
            let method = UInt16(le16(offset + 10))
            let compressedSize = le32(offset + 20)
            let uncompressedSize = le32(offset + 24)
            let nameLength = le16(offset + 28)
            let extraLength = le16(offset + 30)
            let commentLength = le16(offset + 32)
            let localHeaderOffset = le32(offset + 42)
            let nameStart = offset + 46
            guard nameStart + nameLength <= bytes.count else { return nil }
            let name = String(decoding: bytes[nameStart..<(nameStart + nameLength)], as: UTF8.self)
            entries.append(Entry(name: name, method: method,
                                 compressedSize: compressedSize,
                                 uncompressedSize: uncompressedSize,
                                 localHeaderOffset: localHeaderOffset))
            offset = nameStart + nameLength + extraLength + commentLength
        }
        return entries
    }

    static func entryData(_ entry: Entry, in archive: Data) -> Data? {
        let bytes = [UInt8](archive)
        let offset = entry.localHeaderOffset
        guard offset + 30 <= bytes.count else { return nil }
        func le16(_ o: Int) -> Int { Int(bytes[o]) | Int(bytes[o + 1]) << 8 }
        func le32(_ o: Int) -> Int {
            Int(bytes[o]) | Int(bytes[o + 1]) << 8 | Int(bytes[o + 2]) << 16 | Int(bytes[o + 3]) << 24
        }
        guard le32(offset) == 0x04034b50 else { return nil }
        let dataStart = offset + 30 + le16(offset + 26) + le16(offset + 28)
        let dataEnd = dataStart + entry.compressedSize
        guard dataEnd <= bytes.count else { return nil }
        let raw = Data(bytes[dataStart..<dataEnd])
        switch entry.method {
        case 0:
            return raw
        case 8:
            return inflate(raw, uncompressedSize: entry.uncompressedSize)
        default:
            return nil
        }
    }

    /// Raw DEFLATE (ZIP method 8) via the Compression framework —
    /// its COMPRESSION_ZLIB format is exactly the raw stream ZIP
    /// stores. The central directory's uncompressed size sizes the
    /// buffer, so large entries decode fully.
    private static func inflate(_ data: Data, uncompressedSize: Int) -> Data? {
        let capacity = max(uncompressedSize, max(data.count * 4, 1 << 16))
        let destination = UnsafeMutablePointer<UInt8>.allocate(capacity: capacity)
        defer { destination.deallocate() }
        return data.withUnsafeBytes { source -> Data? in
            guard let base = source.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return nil }
            let streamPointer = UnsafeMutablePointer<compression_stream>.allocate(capacity: 1)
            defer { streamPointer.deallocate() }
            var status = compression_stream_init(streamPointer, COMPRESSION_STREAM_DECODE, COMPRESSION_ZLIB)
            guard status == COMPRESSION_STATUS_OK else { return nil }
            defer { compression_stream_destroy(streamPointer) }
            streamPointer.pointee.src_ptr = base
            streamPointer.pointee.src_size = data.count
            streamPointer.pointee.dst_ptr = destination
            streamPointer.pointee.dst_size = capacity
            status = compression_stream_process(streamPointer, Int32(COMPRESSION_STREAM_FINALIZE.rawValue))
            guard status == COMPRESSION_STATUS_END else { return nil }
            return Data(bytes: destination, count: capacity - streamPointer.pointee.dst_size)
        }
    }
}

/// Mach-O helpers shared by the entitlements reader and the
/// post-signing CodeDirectory check.
enum RGMachO {
    /// Byte range of the arm64 slice (a thin 64-bit Mach-O is its
    /// own slice).
    static func sliceRange(in bytes: [UInt8]) -> Range<Int>? {
        guard bytes.count >= 4 else { return nil }
        func be32(_ offset: Int) -> UInt32 {
            UInt32(bytes[offset]) << 24 | UInt32(bytes[offset + 1]) << 16
                | UInt32(bytes[offset + 2]) << 8 | UInt32(bytes[offset + 3])
        }
        func le32(_ offset: Int) -> UInt32 {
            UInt32(bytes[offset]) | UInt32(bytes[offset + 1]) << 8
                | UInt32(bytes[offset + 2]) << 16 | UInt32(bytes[offset + 3])
        }
        if be32(0) == 0xcafebabe {
            guard bytes.count >= 8 else { return nil }
            let count = Int(be32(4))
            for i in 0..<count {
                let entry = 8 + i * 20
                guard entry + 20 <= bytes.count else { return nil }
                if be32(entry) == 0x0100_000C {  // CPU_TYPE_ARM64
                    let start = Int(be32(entry + 8))
                    let length = Int(be32(entry + 12))
                    guard start + length <= bytes.count else { return nil }
                    return start..<(start + length)
                }
            }
            return nil
        }
        guard le32(0) == 0xfeedfacf else { return nil }
        return 0..<bytes.count
    }

    /// Byte range of the embedded code signature (superblob) of the
    /// executable slice, from its LC_CODE_SIGNATURE load command.
    static func codeSignatureRange(in bytes: [UInt8], slice: Range<Int>) -> Range<Int>? {
        func le32(_ offset: Int) -> UInt32 {
            UInt32(bytes[offset]) | UInt32(bytes[offset + 1]) << 8
                | UInt32(bytes[offset + 2]) << 16 | UInt32(bytes[offset + 3])
        }
        guard slice.count >= 32 else { return nil }
        let ncmds = Int(le32(slice.lowerBound + 16))
        var offset = slice.lowerBound + 32
        var signatureOffset = 0
        var signatureSize = 0
        for _ in 0..<ncmds {
            guard offset + 8 <= slice.upperBound else { return nil }
            let cmd = le32(offset)
            let cmdSize = Int(le32(offset + 4))
            if cmd == 0x1d {  // LC_CODE_SIGNATURE
                guard offset + 16 <= slice.upperBound else { return nil }
                signatureOffset = Int(le32(offset + 8))
                signatureSize = Int(le32(offset + 12))
            }
            guard cmdSize >= 8 else { return nil }
            offset += cmdSize
        }
        guard signatureSize >= 16, signatureOffset > 0 else { return nil }
        let start = slice.lowerBound + signatureOffset
        guard start + signatureSize <= slice.upperBound else { return nil }
        return start..<(start + signatureSize)
    }

    /// The XML entitlements embedded in the executable's code
    /// signature (superblob slot 5), parsed as a plist dictionary.
    static func entitlements(inExecutable data: Data) -> [String: Any]? {
        let bytes = [UInt8](data)
        guard let slice = sliceRange(in: bytes),
              let cs = codeSignatureRange(in: bytes, slice: slice) else { return nil }
        func be32(_ offset: Int) -> UInt32 {
            UInt32(bytes[offset]) << 24 | UInt32(bytes[offset + 1]) << 16
                | UInt32(bytes[offset + 2]) << 8 | UInt32(bytes[offset + 3])
        }
        guard be32(cs.lowerBound) == 0xfade0cc0 else { return nil }  // CSMAGIC_EMBEDDED_SIGNATURE
        let count = Int(be32(cs.lowerBound + 8))
        for i in 0..<count {
            let entry = cs.lowerBound + 12 + i * 8
            guard entry + 8 <= cs.upperBound else { return nil }
            guard be32(entry) == 5 else { continue }  // CSSLOT_ENTITLEMENTS
            let blob = cs.lowerBound + Int(be32(entry + 4))
            guard blob + 8 <= cs.upperBound, be32(blob) == 0xfade7171 else { return nil }  // CSMAGIC_EMBEDDED_ENTITLEMENTS
            let length = Int(be32(blob + 4))
            guard length >= 8, blob + length <= cs.upperBound else { return nil }
            let xml = Data(bytes[(blob + 8)..<(blob + length)])
            return try? PropertyListSerialization.propertyList(from: xml, options: [], format: nil) as? [String: Any]
        }
        return nil
    }
}

struct RGAppBundleInfo {
    let bundleId: String
    let version: String
    let build: String
    let displayName: String
    let executableName: String?

    init?(plist: [String: Any]) {
        guard let bundleId = plist["CFBundleIdentifier"] as? String, !bundleId.isEmpty else { return nil }
        self.bundleId = bundleId
        self.version = plist["CFBundleShortVersionString"] as? String ?? ""
        self.build = plist["CFBundleVersion"] as? String ?? ""
        self.displayName = (plist["CFBundleDisplayName"] as? String) ?? (plist["CFBundleName"] as? String) ?? bundleId
        self.executableName = plist["CFBundleExecutable"] as? String
    }
}

enum RGIPAPackage {
    /// Info of the .app inside an IPA. Throws signer error 4 when
    /// the archive cannot be read or holds no app.
    static func appInfo(ipaPath: String) throws -> RGAppBundleInfo {
        guard let archive = try? Data(contentsOf: URL(fileURLWithPath: ipaPath), options: .mappedIfSafe),
              let entries = RGZipReader.entries(in: archive),
              let plistEntry = entries.first(where: { $0.name.hasPrefix("Payload/") && $0.name.hasSuffix(".app/Info.plist") }),
              let plistData = RGZipReader.entryData(plistEntry, in: archive),
              let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any],
              let info = RGAppBundleInfo(plist: plist)
        else { throw RGSignerError.invalidArchive }
        return info
    }

    /// Info of an installed .app bundle on disk.
    static func installedAppInfo(appPath: String) -> RGAppBundleInfo? {
        let url = URL(fileURLWithPath: appPath).appendingPathComponent("Info.plist")
        guard let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return nil }
        return RGAppBundleInfo(plist: plist)
    }

    /// Entitlements the installed app was actually signed with,
    /// read from its main executable's embedded code signature.
    static func installedEntitlements(appPath: String) -> [String: Any]? {
        guard let info = installedAppInfo(appPath: appPath), let executable = info.executableName else { return nil }
        let url = URL(fileURLWithPath: appPath).appendingPathComponent(executable)
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { return nil }
        return RGMachO.entitlements(inExecutable: data)
    }

    /// embedded.mobileprovision payloads found in an installed app:
    /// the main bundle plus every PlugIns/*.appex.
    static func embeddedProfileData(appPath: String) -> [Data] {
        var result: [Data] = []
        let fm = FileManager.default
        let root = URL(fileURLWithPath: appPath).appendingPathComponent("embedded.mobileprovision")
        if let data = try? Data(contentsOf: root) { result.append(data) }
        let plugins = URL(fileURLWithPath: appPath).appendingPathComponent("PlugIns")
        if let children = try? fm.contentsOfDirectory(at: plugins, includingPropertiesForKeys: nil) {
            for child in children where child.pathExtension == "appex" {
                let profile = child.appendingPathComponent("embedded.mobileprovision")
                if let data = try? Data(contentsOf: profile), !result.contains(data) { result.append(data) }
            }
        }
        return result
    }
}
