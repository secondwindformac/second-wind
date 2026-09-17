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

        // --- 2. read-back of the ISO copy — MUST run before the GPT patch.
        // The patch below legitimately rewrites the head (protective MBR at
        // byte 0, GPT header at 512, entries at 1024), so comparing the head
        // against the pristine ISO after patching fails on EVERY stick — the
        // exact bug that had two healthy sticks and two Macs condemned as
        // faulty hardware (16-Sep). Windows across the image also catch
        // media that acknowledges writes it never stored (worn-out sticks).
        iso.seek(toFileOffset: 0)
        let isoHead = iso.readData(ofLength: chunkSize)
        let diskHead = try device.read(at: 0, count: isoHead.count)
        guard diskHead == isoHead else { throw WriteError.verifyFailed("start of the system image") }
        for fraction in [0.25, 0.5, 0.75] where isoSize > UInt64(chunkSize) {
            let sampleOffset = UInt64(Double(isoSize) * fraction) / 512 * 512
            let sampleLen = Int(min(UInt64(chunkSize), isoSize - sampleOffset))
            iso.seek(toFileOffset: sampleOffset)
            let fileSample = iso.readData(ofLength: sampleLen)
            let diskSample = try device.read(at: sampleOffset, count: fileSample.count)
            guard diskSample == fileSample else {
                throw WriteError.verifyFailed("system image at \(Int(fraction * 100))% — the stick may be worn out; try another one")
            }
        }

        // --- 3. GPT: move the backup to the end, add the CIDATA partition ---
        progress(.addingSeed)
        let partition = try GPT.addCIDATAPartition(on: device)

        // --- 4. the seed volume inside the new partition ---
        let extents = try SeedBuilder.buildVolumeExtents(payloadTarGz: payloadTarGz)
        for extent in extents {
            try device.write(extent.data, at: partition.partitionByteOffset + extent.offset)
        }
        device.fullSync()

        // --- 5. read-back checks that are valid AFTER the patch ---
        // (raw-device reads must be sector multiples: read 512, compare 8)
        progress(.verifying)
        let gptSector = try device.read(at: 512, count: 512)
        guard [UInt8](gptSector.prefix(8)) == Array("EFI PART".utf8) else {
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
