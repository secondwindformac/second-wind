// seedtool — the Creator's disk engine, runnable against plain files.
//
// This is how CI (and anyone on Linux) proves the exact code that writes
// real USB sticks on macOS produces structures that sgdisk, fsck.vfat and
// mtools accept. No Mac needed to validate the dangerous 20%.
//
//   seedtool fake-iso  <out>            small GPT image standing in for the Ubuntu ISO
//   seedtool fat-image <out> <payload>  just the 512 MiB CIDATA volume
//   seedtool build-image <out> <iso> <payload> [deviceSizeMB]
//                                       full "stick": iso + patched GPT + seed
import Foundation
import CreatorCore

func die(_ message: String) -> Never {
    FileHandle.standardError.write(Data("seedtool: \(message)\n".utf8))
    exit(1)
}

func createSparseFile(_ path: String, size: UInt64) throws {
    FileManager.default.createFile(atPath: path, contents: nil)
    let handle = try FileHandle(forWritingTo: URL(fileURLWithPath: path))
    handle.truncateFile(atOffset: size)
    handle.closeFile()
}

let args = CommandLine.arguments
guard args.count >= 2 else {
    die("usage: seedtool fake-iso|fat-image|build-image …")
}

do {
    switch args[1] {
    case "fake-iso":
        guard args.count == 3 else { die("usage: seedtool fake-iso <out>") }
        try createSparseFile(args[2], size: FakeISO.sizeMB * 1024 * 1024)
        let dev = try FileBlockDevice(url: URL(fileURLWithPath: args[2]))
        defer { dev.close() }
        try FakeISO.write(to: dev)
        print("fake ISO written: \(args[2]) (\(FakeISO.sizeMB) MB)")

    case "fat-image":
        guard args.count == 4 else { die("usage: seedtool fat-image <out> <payload.tar.gz>") }
        let payload = try Data(contentsOf: URL(fileURLWithPath: args[3]))
        try createSparseFile(args[2], size: GPT.cidataSizeBytes)
        let dev = try FileBlockDevice(url: URL(fileURLWithPath: args[2]))
        defer { dev.close() }
        for extent in try SeedBuilder.buildVolumeExtents(payloadTarGz: payload) {
            try dev.write(extent.data, at: extent.offset)
        }
        print("FAT image written: \(args[2])")

    case "build-image":
        guard args.count >= 5 else {
            die("usage: seedtool build-image <out> <iso> <payload.tar.gz> [deviceSizeMB]")
        }
        let iso = try Data(contentsOf: URL(fileURLWithPath: args[3]))
        let payload = try Data(contentsOf: URL(fileURLWithPath: args[4]))
        let sizeMB = args.count >= 6 ? UInt64(args[5]) ?? 8000 : 8000
        try createSparseFile(args[2], size: sizeMB * 1024 * 1024)
        let dev = try FileBlockDevice(url: URL(fileURLWithPath: args[2]))
        defer { dev.close() }
        try dev.write(iso, at: 0)
        let partition = try GPT.addCIDATAPartition(on: dev)
        for extent in try SeedBuilder.buildVolumeExtents(payloadTarGz: payload) {
            try dev.write(extent.data, at: partition.partitionByteOffset + extent.offset)
        }
        print("stick image written: \(args[2]) — CIDATA at LBA \(partition.partitionFirstLBA)")

    default:
        die("unknown command \(args[1])")
    }
} catch {
    die("\(error)")
}
