// Minimal FAT32 volume builder for the CIDATA seed partition.
//
// Produces the same result as `mkfs.vfat -n CIDATA` + copying the seed files,
// but with no external tools: a list of (offset, bytes) extents to write into
// the partition. Free clusters are never touched (whatever bytes the stick
// had there stay — FAT marks them free, so nothing reads them).
//
// Deliberately small: 512-byte sectors, 4 KiB clusters, one cluster per
// directory (128 entries — plenty for the seed's handful of files).
// Validated in CI against fsck.vfat and mtools.
import Foundation

public enum FATError: Error, CustomStringConvertible {
    case directoryTooLarge(String)
    case volumeTooSmall

    public var description: String {
        switch self {
        case .directoryTooLarge(let d): return "too many entries in folder \(d)"
        case .volumeTooSmall: return "seed volume too small"
        }
    }
}

public struct FATFile {
    public let name: String
    public let data: Data
    public init(name: String, data: Data) { self.name = name; self.data = data }
}

public struct FATDirectory {
    public let name: String
    public var files: [FATFile]
    public init(name: String, files: [FATFile]) { self.name = name; self.files = files }
}

/// One contiguous run of bytes to write at an offset inside the partition.
public struct FATExtent {
    public let offset: UInt64
    public let data: Data
}

public enum FAT32Builder {
    static let bytesPerSector = 512
    static let sectorsPerCluster = 8
    static let clusterBytes = bytesPerSector * sectorsPerCluster
    static let reservedSectors = 32
    static let numFATs = 2
    // Fixed timestamp for reproducible images: 2026-08-31 12:00:00.
    static let dosDate: UInt16 = UInt16(((2026 - 1980) << 9) | (8 << 5) | 31)
    static let dosTime: UInt16 = UInt16((12 << 11) | (0 << 5) | 0)

    /// Build a FAT32 volume of `volumeBytes` holding `rootFiles` and
    /// `directories` (one level deep — all the seed needs).
    public static func buildExtents(
        volumeBytes: UInt64,
        label: String,
        rootFiles: [FATFile],
        directories: [FATDirectory],
        volumeID: UInt32 = 0x53_57_4E_44 // "SWND"
    ) throws -> [FATExtent] {
        let totalSectors = Int(volumeBytes) / bytesPerSector
        guard totalSectors > 4096 else { throw FATError.volumeTooSmall }

        // FAT size: iterate to a fixed point.
        var fatSectors = 1
        for _ in 0..<8 {
            let dataSectors = totalSectors - reservedSectors - numFATs * fatSectors
            let clusters = dataSectors / sectorsPerCluster
            let needed = (Int(clusters + 2) * 4 + bytesPerSector - 1) / bytesPerSector
            if needed == fatSectors { break }
            fatSectors = needed
        }
        let dataStartSector = reservedSectors + numFATs * fatSectors
        let totalClusters = (totalSectors - dataStartSector) / sectorsPerCluster

        // --- allocation (root dir is cluster 2; then one cluster per
        // subdirectory; then file data, contiguous) ---
        var nextCluster: UInt32 = 2
        func allocate(clusters n: UInt32) -> UInt32 {
            let first = nextCluster
            nextCluster += n
            return first
        }
        func clustersFor(_ byteCount: Int) -> UInt32 {
            byteCount == 0 ? 0 : UInt32((byteCount + clusterBytes - 1) / clusterBytes)
        }

        let rootCluster = allocate(clusters: 1)
        var dirClusters: [String: UInt32] = [:]
        for d in directories { dirClusters[d.name] = allocate(clusters: 1) }
        struct Placed { let file: FATFile; let firstCluster: UInt32 }
        func place(_ files: [FATFile]) -> [Placed] {
            files.map { f in
                let n = clustersFor(f.data.count)
                return Placed(file: f, firstCluster: n == 0 ? 0 : allocate(clusters: n))
            }
        }
        let placedRoot = place(rootFiles)
        let placedDirs = directories.map { ($0, place($0.files)) }
        guard Int(nextCluster) - 2 <= totalClusters else { throw FATError.volumeTooSmall }

        // --- FAT tables ---
        var fat = [UInt32](repeating: 0, count: fatSectors * bytesPerSector / 4)
        fat[0] = 0x0FFF_FFF8
        fat[1] = 0x0FFF_FFFF
        func chain(first: UInt32, count: UInt32) {
            guard count > 0 else { return }
            for i in 0..<count {
                let c = Int(first + i)
                fat[c] = (i == count - 1) ? 0x0FFF_FFFF : first + i + 1
            }
        }
        chain(first: rootCluster, count: 1)
        for (_, c) in dirClusters { chain(first: c, count: 1) }
        for p in placedRoot { chain(first: p.firstCluster, count: clustersFor(p.file.data.count)) }
        for (_, placed) in placedDirs {
            for p in placed { chain(first: p.firstCluster, count: clustersFor(p.file.data.count)) }
        }

        // --- directory clusters ---
        func renderDirectory(
            name: String, selfCluster: UInt32, parentCluster: UInt32?,
            volumeLabel: String?, placed: [Placed], childDirs: [(String, UInt32)]
        ) throws -> Data {
            var entries = [Data]()
            if let label = volumeLabel {
                entries.append(shortEntry(name11: pad11(label), attr: 0x08, cluster: 0, size: 0))
            }
            if let parent = parentCluster {
                entries.append(shortEntry(name11: pad11(".", isDot: true), attr: 0x10, cluster: selfCluster, size: 0))
                entries.append(shortEntry(name11: pad11("..", isDot: true), attr: 0x10,
                                          cluster: parent == 2 ? 0 : parent, size: 0))
            }
            var used = Set<String>()
            for (dirName, cluster) in childDirs {
                entries.append(contentsOf: namedEntry(dirName, attr: 0x10, cluster: cluster,
                                                      size: 0, used: &used))
            }
            for p in placed {
                entries.append(contentsOf: namedEntry(p.file.name, attr: 0x20, cluster: p.firstCluster,
                                                      size: UInt32(p.file.data.count), used: &used))
            }
            guard entries.count <= clusterBytes / 32 else { throw FATError.directoryTooLarge(name) }
            var blob = Data(capacity: clusterBytes)
            for e in entries { blob.append(e) }
            blob.append(Data(repeating: 0, count: clusterBytes - blob.count))
            return blob
        }

        // --- assemble extents ---
        var extents = [FATExtent]()
        extents.append(FATExtent(offset: 0, data: bootSector(
            totalSectors: totalSectors, fatSectors: fatSectors,
            rootCluster: rootCluster, label: label, volumeID: volumeID)))
        let freeClusters = UInt32(totalClusters) - (nextCluster - 2)
        extents.append(FATExtent(offset: UInt64(1 * bytesPerSector),
                                 data: fsInfo(freeCount: freeClusters, nextFree: nextCluster)))
        // Backup boot sector + backup FSInfo (sectors 6 and 7).
        extents.append(FATExtent(offset: UInt64(6 * bytesPerSector), data: extents[0].data))
        extents.append(FATExtent(offset: UInt64(7 * bytesPerSector), data: extents[1].data))

        var fatData = Data(capacity: fatSectors * bytesPerSector)
        for v in fat {
            var le = v.littleEndian
            withUnsafeBytes(of: &le) { fatData.append(contentsOf: $0) }
        }
        extents.append(FATExtent(offset: UInt64(reservedSectors * bytesPerSector), data: fatData))
        extents.append(FATExtent(offset: UInt64((reservedSectors + fatSectors) * bytesPerSector), data: fatData))

        func clusterOffset(_ c: UInt32) -> UInt64 {
            UInt64(dataStartSector * bytesPerSector) + UInt64(c - 2) * UInt64(clusterBytes)
        }
        let childDirList = directories.map { ($0.name, dirClusters[$0.name]!) }
        extents.append(FATExtent(offset: clusterOffset(rootCluster), data: try renderDirectory(
            name: "/", selfCluster: rootCluster, parentCluster: nil,
            volumeLabel: label, placed: placedRoot, childDirs: childDirList)))
        for (dir, placed) in placedDirs {
            let c = dirClusters[dir.name]!
            extents.append(FATExtent(offset: clusterOffset(c), data: try renderDirectory(
                name: dir.name, selfCluster: c, parentCluster: rootCluster,
                volumeLabel: nil, placed: placed, childDirs: [])))
        }
        for p in placedRoot where !p.file.data.isEmpty {
            extents.append(FATExtent(offset: clusterOffset(p.firstCluster), data: p.file.data))
        }
        for (_, placed) in placedDirs {
            for p in placed where !p.file.data.isEmpty {
                extents.append(FATExtent(offset: clusterOffset(p.firstCluster), data: p.file.data))
            }
        }
        return extents
    }

    // --- on-disk structures ---

    static func bootSector(totalSectors: Int, fatSectors: Int, rootCluster: UInt32,
                           label: String, volumeID: UInt32) -> Data {
        var b = [UInt8](repeating: 0, count: bytesPerSector)
        b[0] = 0xEB; b[1] = 0x58; b[2] = 0x90
        replace(&b, 3, Array("SECWIND ".utf8))                 // OEM name
        put16(&b, 11, UInt16(bytesPerSector))
        b[13] = UInt8(sectorsPerCluster)
        put16(&b, 14, UInt16(reservedSectors))
        b[16] = UInt8(numFATs)
        put16(&b, 17, 0)                                        // root entries (FAT32: 0)
        put16(&b, 19, 0)                                        // total16
        b[21] = 0xF8                                            // media
        put16(&b, 22, 0)                                        // fatSz16
        put16(&b, 24, 63)                                       // sectors/track (legacy)
        put16(&b, 26, 255)                                      // heads (legacy)
        put32(&b, 28, 0)                                        // hidden
        put32(&b, 32, UInt32(totalSectors))
        put32(&b, 36, UInt32(fatSectors))                       // fatSz32
        put16(&b, 40, 0)                                        // extFlags: mirrored
        put16(&b, 42, 0)                                        // fsVer
        put32(&b, 44, rootCluster)
        put16(&b, 48, 1)                                        // FSInfo sector
        put16(&b, 50, 6)                                        // backup boot sector
        b[64] = 0x80                                            // drive number
        b[66] = 0x29                                            // extended boot signature
        put32(&b, 67, volumeID)
        replace(&b, 71, Array(pad11(label).utf8))
        replace(&b, 82, Array("FAT32   ".utf8))
        b[510] = 0x55; b[511] = 0xAA
        return Data(b)
    }

    static func fsInfo(freeCount: UInt32, nextFree: UInt32) -> Data {
        var b = [UInt8](repeating: 0, count: bytesPerSector)
        put32(&b, 0, 0x4161_5252)
        put32(&b, 484, 0x6141_7272)
        put32(&b, 488, freeCount)
        put32(&b, 492, nextFree)
        b[510] = 0x55; b[511] = 0xAA
        return Data(b)
    }

    /// LFN entries (when needed) + the 8.3 short entry.
    static func namedEntry(_ name: String, attr: UInt8, cluster: UInt32,
                           size: UInt32, used: inout Set<String>) -> [Data] {
        let short = shortName(for: name, used: &used)
        let fits83 = shortNameMatches(name, short)
        var out = [Data]()
        if !fits83 {
            let units = Array(name.utf16)
            let pieces = stride(from: 0, to: units.count, by: 13).map {
                Array(units[$0..<min($0 + 13, units.count)])
            }
            let checksum = lfnChecksum(short)
            for (i, piece) in pieces.enumerated().reversed() {
                var padded = piece
                if padded.count < 13 {
                    padded.append(0x0000)
                    while padded.count < 13 { padded.append(0xFFFF) }
                }
                var e = [UInt8](repeating: 0, count: 32)
                e[0] = UInt8(i + 1) | (i == pieces.count - 1 ? 0x40 : 0)
                e[11] = 0x0F
                e[13] = checksum
                let slots = [(1, 5), (14, 6), (28, 2)]
                var u = 0
                for (off, count) in slots {
                    for j in 0..<count {
                        e[off + j * 2] = UInt8(padded[u] & 0xFF)
                        e[off + j * 2 + 1] = UInt8(padded[u] >> 8)
                        u += 1
                    }
                }
                out.append(Data(e))
            }
        }
        out.append(shortEntry(name11: short, attr: attr, cluster: cluster, size: size))
        return out
    }

    static func shortEntry(name11: String, attr: UInt8, cluster: UInt32, size: UInt32) -> Data {
        var e = [UInt8](repeating: 0, count: 32)
        replace(&e, 0, Array(name11.utf8))
        e[11] = attr
        put16(&e, 14, dosTime); put16(&e, 16, dosDate)          // created
        put16(&e, 18, dosDate)                                  // accessed
        put16(&e, 20, UInt16(cluster >> 16))
        put16(&e, 22, dosTime); put16(&e, 24, dosDate)          // written
        put16(&e, 26, UInt16(cluster & 0xFFFF))
        put32(&e, 28, size)
        return Data(e)
    }

    /// Generate a unique 8.3 name (e.g. "SECOND~1GZ " style padded 11 chars).
    static func shortName(for name: String, used: inout Set<String>) -> String {
        let upper = name.uppercased()
        let dot = upper.lastIndex(of: ".")
        var base = dot.map { String(upper[..<$0]) } ?? upper
        var ext = dot.map { String(upper[upper.index(after: $0)...]) } ?? ""
        func clean(_ s: String) -> String {
            String(s.unicodeScalars.filter {
                ("A"..."Z").contains(String($0)) || ("0"..."9").contains(String($0))
                    || $0 == "-" || $0 == "_"
            }.map(Character.init))
        }
        base = clean(base); ext = String(clean(ext).prefix(3))
        if base.isEmpty { base = "FILE" }
        var candidateBase = String(base.prefix(8))
        var n = 0
        while true {
            let name11 = candidateBase.padding(toLength: 8, withPad: " ", startingAt: 0)
                + ext.padding(toLength: 3, withPad: " ", startingAt: 0)
            if !used.contains(name11) {
                used.insert(name11)
                return name11
            }
            n += 1
            let tail = "~\(n)"
            candidateBase = String(base.prefix(8 - tail.count)) + tail
        }
    }

    static func shortNameMatches(_ name: String, _ short11: String) -> Bool {
        let base = short11.prefix(8).trimmingCharacters(in: .whitespaces)
        let ext = short11.suffix(3).trimmingCharacters(in: .whitespaces)
        let rebuilt = ext.isEmpty ? base : "\(base).\(ext)"
        return rebuilt == name.uppercased() && name == name.uppercased()
    }

    static func lfnChecksum(_ short11: String) -> UInt8 {
        var sum: UInt8 = 0
        for c in Array(short11.utf8) {
            sum = ((sum & 1) != 0 ? 0x80 : 0) &+ (sum >> 1) &+ c
        }
        return sum
    }

    static func pad11(_ s: String, isDot: Bool = false) -> String {
        if isDot { return s.padding(toLength: 11, withPad: " ", startingAt: 0) }
        return String(s.uppercased().prefix(11)).padding(toLength: 11, withPad: " ", startingAt: 0)
    }

    static func replace(_ b: inout [UInt8], _ off: Int, _ bytes: [UInt8]) {
        b.replaceSubrange(off..<off + bytes.count, with: bytes)
    }
    static func put16(_ b: inout [UInt8], _ o: Int, _ v: UInt16) {
        b[o] = UInt8(v & 0xFF); b[o + 1] = UInt8(v >> 8)
    }
    static func put32(_ b: inout [UInt8], _ o: Int, _ v: UInt32) {
        for i in 0..<4 { b[o + i] = UInt8((v >> (8 * UInt32(i))) & 0xFF) }
    }
}
