import XCTest
@testable import CreatorCore

/// In-memory BlockDevice for fast structural tests.
final class MemoryDevice: BlockDevice {
    var bytes: [UInt8]
    var size: UInt64 { UInt64(bytes.count) }

    init(sizeMB: Int) { bytes = [UInt8](repeating: 0, count: sizeMB * 1024 * 1024) }

    func read(at offset: UInt64, count: Int) throws -> Data {
        let start = Int(offset)
        guard start + count <= bytes.count else { throw GPTError.ioTooShort }
        return Data(bytes[start..<start + count])
    }

    func write(_ data: Data, at offset: UInt64) throws {
        let start = Int(offset)
        bytes.replaceSubrange(start..<start + data.count, with: data)
    }
}

/// Minimal ustar builder so tests can fabricate a payload tarball.
enum TarBuilder {
    static func build(_ files: [(String, Data)]) -> Data {
        var out = Data()
        for (name, data) in files {
            var h = [UInt8](repeating: 0, count: 512)
            let nameBytes = Array(name.utf8)
            h.replaceSubrange(0..<nameBytes.count, with: nameBytes)
            h.replaceSubrange(100..<107, with: Array("0000644".utf8))
            h.replaceSubrange(108..<115, with: Array("0000000".utf8))
            h.replaceSubrange(116..<123, with: Array("0000000".utf8))
            let sizeOctal = String(data.count, radix: 8)
            let sizeField = String(repeating: "0", count: 11 - sizeOctal.count) + sizeOctal
            h.replaceSubrange(124..<135, with: Array(sizeField.utf8))
            h.replaceSubrange(136..<147, with: Array("00000000000".utf8))
            h[156] = 0x30 // regular file
            h.replaceSubrange(257..<262, with: Array("ustar".utf8))
            h[263] = 0x30; h[264] = 0x30
            // checksum: field treated as spaces
            h.replaceSubrange(148..<156, with: Array("        ".utf8))
            let sum = h.reduce(0) { $0 + Int($1) }
            let sumOctal = String(sum, radix: 8)
            let sumField = String(repeating: "0", count: 6 - sumOctal.count) + sumOctal + "\0 "
            h.replaceSubrange(148..<156, with: Array(sumField.utf8))
            out.append(Data(h))
            out.append(data)
            let pad = (512 - data.count % 512) % 512
            out.append(Data(repeating: 0, count: pad))
        }
        out.append(Data(repeating: 0, count: 1024))
        return out
    }
}

func makeTestPayload() throws -> Data {
    let userData = "#cloud-config\nautoinstall:\n  identity:\n    password: \"@PASSWORD_HASH@\"\n"
    let tar = TarBuilder.build([
        ("second-wind/usb/seed/user-data", Data(userData.utf8)),
        ("second-wind/usb/seed/meta-data", Data("instance-id: second-wind-usb\n".utf8)),
        ("second-wind/usb/firstboot/second-wind-firstboot.sh", Data("#!/bin/bash\necho hi\n".utf8)),
        ("second-wind/usb/firstboot/second-wind-firstboot.desktop", Data("[Desktop Entry]\n".utf8)),
    ])
    return try Gzip.compress(tar)
}

final class GPTTests: XCTestCase {
    func testPatchAddsCIDATAAndRelocatesBackup() throws {
        let dev = MemoryDevice(sizeMB: 1024)
        try FakeISO.write(to: dev)
        let result = try GPT.addCIDATAPartition(on: dev)

        XCTAssertEqual(result.partitionFirstLBA % 2048, 0, "partition must be 1 MiB aligned")
        XCTAssertEqual(result.partitionByteCount, 512 * 1024 * 1024)

        // Primary header re-reads as valid and points at the device end.
        let header = [UInt8](try dev.read(at: 512, count: 512))
        let headerSize = Int(GPT.le32(header, 12))
        var zeroed = header
        zeroed.replaceSubrange(16..<20, with: [0, 0, 0, 0])
        XCTAssertEqual(GPT.crc32(Array(zeroed[0..<headerSize])), GPT.le32(header, 16))
        let deviceLBAs = dev.size / 512
        XCTAssertEqual(GPT.le64(header, 24), 1)
        XCTAssertEqual(GPT.le64(header, 32), deviceLBAs - 1)
        XCTAssertLessThan(GPT.le64(header, 48), deviceLBAs)
        XCTAssertGreaterThan(GPT.le64(header, 48), result.partitionLastLBA - 1)

        // Backup header lives at the last LBA and is valid too.
        let backup = [UInt8](try dev.read(at: (deviceLBAs - 1) * 512, count: 512))
        XCTAssertEqual(Array(backup[0..<8]), Array("EFI PART".utf8))
        var bz = backup
        bz.replaceSubrange(16..<20, with: [0, 0, 0, 0])
        XCTAssertEqual(GPT.crc32(Array(bz[0..<headerSize])), GPT.le32(backup, 16))
        XCTAssertEqual(GPT.le64(backup, 24), deviceLBAs - 1)
        XCTAssertEqual(GPT.le64(backup, 32), 1)

        // The CIDATA entry exists with the right name and type.
        let entriesLBA = GPT.le64(header, 72)
        let entries = [UInt8](try dev.read(at: entriesLBA * 512, count: 128 * 128))
        var found = false
        for slot in 0..<128 {
            let off = slot * 128
            let name = (0..<6).map { i -> Character in
                Character(UnicodeScalar(UInt16(entries[off + 56 + i * 2])
                    | UInt16(entries[off + 56 + i * 2 + 1]) << 8)!)
            }
            if String(name) == "CIDATA" {
                found = true
                XCTAssertEqual(GPT.le64(entries, off + 32), result.partitionFirstLBA)
                XCTAssertEqual(GPT.le64(entries, off + 40), result.partitionLastLBA)
            }
        }
        XCTAssertTrue(found, "CIDATA partition entry missing")
    }

    func testRefusesTinyStick() throws {
        let dev = MemoryDevice(sizeMB: 96) // fake ISO is 64 MB; no room for 512 MiB seed
        try FakeISO.write(to: dev)
        XCTAssertThrowsError(try GPT.addCIDATAPartition(on: dev))
    }
}

final class ArchiveTests: XCTestCase {
    func testGzipTarRoundtrip() throws {
        let payload = try makeTestPayload()
        let tar = try Gzip.decompress(payload)
        let files = try Tar.extract(tar, paths: ["second-wind/usb/seed/meta-data"])
        XCTAssertEqual(files["second-wind/usb/seed/meta-data"],
                       Data("instance-id: second-wind-usb\n".utf8))
    }

    func testMissingMemberThrows() throws {
        let payload = try makeTestPayload()
        let tar = try Gzip.decompress(payload)
        XCTAssertThrowsError(try Tar.extract(tar, paths: ["nope"]))
    }
}

final class SeedTests: XCTestCase {
    func testSeedVolumeStructure() throws {
        let payload = try makeTestPayload()
        let extents = try SeedBuilder.buildVolumeExtents(payloadTarGz: payload)

        // Extents stay inside the volume and never overlap.
        let sorted = extents.sorted { $0.offset < $1.offset }
        var lastEnd: UInt64 = 0
        for extent in sorted {
            XCTAssertGreaterThanOrEqual(extent.offset, lastEnd, "extents overlap")
            lastEnd = extent.offset + UInt64(extent.data.count)
        }
        XCTAssertLessThanOrEqual(lastEnd, GPT.cidataSizeBytes)

        // Boot sector: magic + FAT32 label.
        let boot = sorted.first { $0.offset == 0 }!.data
        XCTAssertEqual(boot[510], 0x55)
        XCTAssertEqual(boot[511], 0xAA)
        XCTAssertEqual(String(decoding: boot[82..<90], as: UTF8.self), "FAT32   ")
        XCTAssertEqual(String(decoding: boot[71..<77], as: UTF8.self), "CIDATA")

        // The password placeholder was replaced everywhere.
        for extent in extents {
            XCTAssertFalse(String(decoding: extent.data, as: UTF8.self)
                .contains("@PASSWORD_HASH@"))
        }
        // And the substituted hash appears somewhere.
        XCTAssertTrue(extents.contains {
            String(decoding: $0.data, as: UTF8.self).contains("$6$")
        })
    }
}
