// GPT (GUID Partition Table) reading and patching.
//
// After the official Ubuntu ISO is raw-written to a stick, its GPT still
// describes a "disk" the size of the ISO. This module does exactly what the
// Linux creator does with `sgdisk -e` + `sgdisk -n 0:0:+512MiB -t 0:0700
// -c 0:CIDATA`:
//   1. relocate the backup GPT to the true end of the device,
//   2. extend the usable range,
//   3. append one 512 MiB "Microsoft basic data" partition named CIDATA.
// Everything else (protective MBR, ISO partitions) is left byte-identical.
import Foundation

public enum GPTError: Error, CustomStringConvertible {
    case badSignature
    case badCRC(String)
    case unsupportedSectorSize(Int)
    case noRoom(String)
    case ioTooShort

    public var description: String {
        switch self {
        case .badSignature: return "no GPT signature at LBA 1 (was the image written?)"
        case .badCRC(let what): return "GPT \(what) checksum mismatch"
        case .unsupportedSectorSize(let n): return "unsupported sector size \(n) (only 512 supported)"
        case .noRoom(let what): return "no room on the device: \(what)"
        case .ioTooShort: return "short read from device"
        }
    }
}

/// Random-access byte device (a real disk on macOS, a plain file in tests).
public protocol BlockDevice {
    /// Total size in bytes.
    var size: UInt64 { get }
    func read(at offset: UInt64, count: Int) throws -> Data
    func write(_ data: Data, at offset: UInt64) throws
}

public struct GPTPatchResult {
    /// First byte of the new CIDATA partition on the device.
    public let partitionByteOffset: UInt64
    /// Size of the new partition in bytes.
    public let partitionByteCount: UInt64
    public let partitionFirstLBA: UInt64
    public let partitionLastLBA: UInt64
}

public enum GPT {
    public static let sectorSize = 512
    static let signature: [UInt8] = Array("EFI PART".utf8)
    /// Microsoft basic data — sgdisk code 0700, what the Linux creator uses.
    static let basicDataGUID = mixedEndianGUID("EBD0A0A2-B9E5-4433-87C0-68B6B72699C7")
    public static let cidataSizeBytes: UInt64 = 512 * 1024 * 1024
    static let alignLBA: UInt64 = 2048

    /// Relocate the backup GPT to the device end and append the CIDATA
    /// partition. Mirrors `sgdisk -e` + `-n 0:0:+512MiB -t 0:0700 -c 0:CIDATA`.
    /// `partitionGUID` is injectable so tests are reproducible.
    @discardableResult
    public static func addCIDATAPartition(
        on dev: BlockDevice,
        partitionGUID: UUID = UUID()
    ) throws -> GPTPatchResult {
        let ss = UInt64(sectorSize)
        let deviceLBAs = dev.size / ss

        // --- read + verify the primary header (LBA 1) ---
        var header = [UInt8](try dev.read(at: 1 * ss, count: sectorSize))
        guard Array(header[0..<8]) == signature else { throw GPTError.badSignature }
        let headerSize = Int(le32(header, 12))
        let storedHeaderCRC = le32(header, 16)
        var zeroed = header
        zeroed.replaceSubrange(16..<20, with: [0, 0, 0, 0])
        guard crc32(Array(zeroed[0..<headerSize])) == storedHeaderCRC else {
            throw GPTError.badCRC("header")
        }

        let entriesLBA = le64(header, 72)
        let numEntries = Int(le32(header, 80))
        let entrySize = Int(le32(header, 84))
        let storedEntriesCRC = le32(header, 88)
        let entriesBytes = numEntries * entrySize
        var entries = [UInt8](try dev.read(at: entriesLBA * ss, count: entriesBytes))
        guard crc32(entries) == storedEntriesCRC else { throw GPTError.badCRC("entries") }

        // --- find the end of existing partitions and a free slot ---
        var maxLast: UInt64 = 0
        var freeSlot = -1
        for i in 0..<numEntries {
            let off = i * entrySize
            let type = Array(entries[off..<off + 16])
            if type.allSatisfy({ $0 == 0 }) {
                if freeSlot < 0 { freeSlot = i }
                continue
            }
            let last = le64(entries, off + 40)
            if last > maxLast { maxLast = last }
        }
        guard freeSlot >= 0 else { throw GPTError.noRoom("partition table is full") }

        // --- new geometry: backup GPT at the true device end ---
        let entriesSectors = UInt64((entriesBytes + sectorSize - 1) / sectorSize)
        let backupHeaderLBA = deviceLBAs - 1
        let backupEntriesLBA = deviceLBAs - 1 - entriesSectors
        let lastUsable = backupEntriesLBA - 1

        // --- the CIDATA partition: first aligned free LBA after everything ---
        let sizeLBAs = cidataSizeBytes / ss
        var first = maxLast + 1
        first = (first + alignLBA - 1) / alignLBA * alignLBA
        let last = first + sizeLBAs - 1
        guard last <= lastUsable else {
            throw GPTError.noRoom("stick too small for the 512 MiB seed volume")
        }

        // --- write the new partition entry ---
        var e = [UInt8](repeating: 0, count: entrySize)
        e.replaceSubrange(0..<16, with: basicDataGUID)
        e.replaceSubrange(16..<32, with: mixedEndianGUID(partitionGUID.uuidString))
        put64(&e, 32, first)
        put64(&e, 40, last)
        put64(&e, 48, 0) // attributes
        let name = Array("CIDATA".utf16) // UTF-16LE, zero-padded to 36 chars
        for (i, unit) in name.enumerated() where i < 36 {
            e[56 + i * 2] = UInt8(unit & 0xFF)
            e[56 + i * 2 + 1] = UInt8(unit >> 8)
        }
        entries.replaceSubrange(freeSlot * entrySize..<(freeSlot + 1) * entrySize, with: e)
        let entriesCRC = crc32(entries)

        // --- primary header: point at the relocated backup, extend usable ---
        // (header layout: 24 current LBA, 32 backup LBA, 40 first usable,
        //  48 last usable, 56 disk GUID, 72 entries LBA)
        put64(&header, 24, 1)               // current LBA
        put64(&header, 32, backupHeaderLBA) // backup LBA
        put64(&header, 48, lastUsable)      // last usable
        put32(&header, 88, entriesCRC)
        sealHeaderCRC(&header, headerSize: headerSize)

        // --- backup header: mirrored fields ---
        var backup = header
        put64(&backup, 24, backupHeaderLBA)
        put64(&backup, 32, 1)
        put64(&backup, 72, backupEntriesLBA)
        sealHeaderCRC(&backup, headerSize: headerSize)

        // Write order: entries first, headers last (a torn write leaves the
        // old, still-valid structures in place as long as possible).
        try dev.write(Data(entries), at: entriesLBA * ss)
        try dev.write(Data(entries), at: backupEntriesLBA * ss)
        try dev.write(Data(backup), at: backupHeaderLBA * ss)
        try dev.write(Data(header), at: 1 * ss)

        // Protective MBR: stretch the 0xEE entry to the whole device, the
        // same fix sgdisk -e applies (some firmware dislikes an undersized
        // protective partition).
        var mbr = [UInt8](try dev.read(at: 0, count: sectorSize))
        for slot in 0..<4 {
            let off = 446 + slot * 16
            if mbr[off + 4] == 0xEE {
                let span = UInt32(min(deviceLBAs - 1, 0xFFFF_FFFF))
                put32(&mbr, off + 12, span)
                try dev.write(Data(mbr), at: 0)
                break
            }
        }

        return GPTPatchResult(
            partitionByteOffset: first * ss,
            partitionByteCount: cidataSizeBytes,
            partitionFirstLBA: first,
            partitionLastLBA: last
        )
    }

    // --- helpers ---

    public static func sealHeaderCRC(_ header: inout [UInt8], headerSize: Int) {
        put32(&header, 16, 0)
        let crc = crc32(Array(header[0..<headerSize]))
        put32(&header, 16, crc)
    }

    /// On-disk GUID: first three groups little-endian, last two big-endian.
    public static func mixedEndianGUID(_ s: String) -> [UInt8] {
        let hex = s.replacingOccurrences(of: "-", with: "")
        var raw = [UInt8]()
        var idx = hex.startIndex
        while idx < hex.endIndex {
            let next = hex.index(idx, offsetBy: 2)
            raw.append(UInt8(hex[idx..<next], radix: 16)!)
            idx = next
        }
        return [raw[3], raw[2], raw[1], raw[0],
                raw[5], raw[4],
                raw[7], raw[6]] + raw[8...15]
    }

    public static func le32(_ b: [UInt8], _ o: Int) -> UInt32 {
        UInt32(b[o]) | UInt32(b[o + 1]) << 8 | UInt32(b[o + 2]) << 16 | UInt32(b[o + 3]) << 24
    }
    public static func le64(_ b: [UInt8], _ o: Int) -> UInt64 {
        var v: UInt64 = 0
        for i in (0..<8).reversed() { v = v << 8 | UInt64(b[o + i]) }
        return v
    }
    public static func put32(_ b: inout [UInt8], _ o: Int, _ v: UInt32) {
        for i in 0..<4 { b[o + i] = UInt8((v >> (8 * UInt32(i))) & 0xFF) }
    }
    public static func put64(_ b: inout [UInt8], _ o: Int, _ v: UInt64) {
        for i in 0..<8 { b[o + i] = UInt8((v >> (8 * UInt64(i))) & 0xFF) }
    }

    /// CRC-32 (IEEE 802.3), the flavor GPT uses.
    public static func crc32(_ bytes: [UInt8]) -> UInt32 {
        var table = [UInt32](repeating: 0, count: 256)
        for i in 0..<256 {
            var c = UInt32(i)
            for _ in 0..<8 { c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1 }
            table[i] = c
        }
        var crc: UInt32 = 0xFFFFFFFF
        for b in bytes { crc = table[Int((crc ^ UInt32(b)) & 0xFF)] ^ (crc >> 8) }
        return crc ^ 0xFFFFFFFF
    }
}
