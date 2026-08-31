// The write pipeline: ISO → stick, patch GPT, drop the CIDATA seed, verify.
// One system password dialog (authopen), then everything happens over that
// descriptor. Mirrors scripts/make-usb.sh write_core() step by step.
#if os(macOS)
import Foundation
import CreatorCore

enum WritePhase {
    case unmounting
    case writingISO(bytesWritten: UInt64, totalBytes: UInt64)
    case addingSeed
    case verifying
    case ejecting
    case done
}

enum WriteError: Error, CustomStringConvertible {
    case unmountFailed
    case verifyFailed(String)

    var description: String {
        switch self {
        case .unmountFailed: return "the stick could not be released by the system"
        case .verifyFailed(let what): return "verification failed after writing (\(what))"
        }
    }
}

enum ImageWriter {
    static let chunkSize = 4 * 1024 * 1024

    /// Everything, in order. Throws on the first problem; the stick may then
    /// be in any state, but the Mac it runs on is untouched — that is the
    /// promise that matters.
    static func writeStick(
        isoPath: URL,
        payloadTarGz: Data,
        disk: USBDisk,
        progress: @escaping (WritePhase) -> Void
    ) throws {
        progress(.unmounting)
        guard DiskEnumerator.unmount(disk) else { throw WriteError.unmountFailed }

        let fd = try AuthOpen.open(path: disk.rawPath)
        let device = try RawDiskDevice(fd: fd)
        defer { device.close() }

        // --- 1. the official ISO, byte for byte ---
        let isoSize = (try FileManager.default.attributesOfItem(atPath: isoPath.path)[.size]
            as? NSNumber)?.uint64Value ?? 0
        let iso = try FileHandle(forReadingFrom: isoPath)
        defer { iso.closeFile() }
        var offset: UInt64 = 0
        while true {
            let chunk = iso.readData(ofLength: chunkSize)
            if chunk.isEmpty { break }
            try device.write(chunk, at: offset)
            offset += UInt64(chunk.count)
            progress(.writingISO(bytesWritten: offset, totalBytes: isoSize))
        }
        device.fullSync()

        // --- 2. GPT: move the backup to the end, add the CIDATA partition ---
        progress(.addingSeed)
        let partition = try GPT.addCIDATAPartition(on: device)

        // --- 3. the seed volume inside the new partition ---
        let extents = try SeedBuilder.buildVolumeExtents(payloadTarGz: payloadTarGz)
        for extent in extents {
            try device.write(extent.data, at: partition.partitionByteOffset + extent.offset)
        }
        device.fullSync()

        // --- 4. read-back checks: ISO start, GPT, FAT boot sector ---
        progress(.verifying)
        iso.seek(toFileOffset: 0)
        let isoHead = iso.readData(ofLength: chunkSize)
        let diskHead = try device.read(at: 0, count: isoHead.count)
        guard diskHead == isoHead else { throw WriteError.verifyFailed("start of the system image") }

        let gptHeader = try device.read(at: 512, count: 8)
        guard [UInt8](gptHeader) == Array("EFI PART".utf8) else {
            throw WriteError.verifyFailed("partition table")
        }
        let bootSector = try device.read(at: partition.partitionByteOffset, count: 512)
        guard bootSector[510] == 0x55, bootSector[511] == 0xAA else {
            throw WriteError.verifyFailed("seed volume")
        }
        device.fullSync()

        progress(.ejecting)
        device.close()
        DiskEnumerator.eject(disk)
        progress(.done)
    }
}
#endif
