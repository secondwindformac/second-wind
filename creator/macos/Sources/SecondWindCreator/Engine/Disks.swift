// USB stick discovery with the safety guards the council demanded:
// external + physical + removable only, never the boot disk, 8 GB minimum.
// Uses diskutil's stable plist output — Apple's own tool, no parsing of
// human-readable text.
#if os(macOS)
import Foundation

struct USBDisk: Identifiable, Equatable {
    let id: String          // "disk4"
    let devicePath: String  // "/dev/disk4"
    let rawPath: String     // "/dev/rdisk4"
    let name: String        // "SanDisk Ultra"
    let sizeBytes: UInt64

    var sizeLabel: String {
        let gb = Double(sizeBytes) / 1_000_000_000
        return String(format: "%.0f GB", gb)
    }
}

enum DiskEnumerator {
    static let minimumBytes: UInt64 = 8_000_000_000

    static func externalSticks() -> [USBDisk] {
        guard let listPlist = runDiskutil(["list", "-plist", "external", "physical"]),
              let wholeDisks = listPlist["WholeDisks"] as? [String] else { return [] }

        var found = [USBDisk]()
        for disk in wholeDisks {
            guard let info = runDiskutil(["info", "-plist", disk]) else { continue }
            let internalDisk = (info["Internal"] as? Bool) ?? true
            let removableOrExternal =
                (info["RemovableMediaOrExternalDevice"] as? Bool)
                ?? ((info["Removable"] as? Bool) ?? false || (info["Ejectable"] as? Bool) ?? false)
            let virtualOrPhysical = (info["VirtualOrPhysical"] as? String) ?? "Physical"
            let size = (info["TotalSize"] as? NSNumber)?.uint64Value
                ?? (info["Size"] as? NSNumber)?.uint64Value ?? 0
            let mediaName = (info["MediaName"] as? String) ?? "USB"

            guard !internalDisk,
                  removableOrExternal,
                  virtualOrPhysical == "Physical",
                  size >= minimumBytes,
                  disk != bootWholeDisk()
            else { continue }

            found.append(USBDisk(
                id: disk,
                devicePath: "/dev/\(disk)",
                rawPath: "/dev/r\(disk)",
                name: mediaName.trimmingCharacters(in: .whitespaces),
                sizeBytes: size))
        }
        return found
    }

    /// The whole disk the running system booted from — never offered, ever.
    static func bootWholeDisk() -> String? {
        guard let info = runDiskutil(["info", "-plist", "/"]) else { return nil }
        if let parent = info["ParentWholeDisk"] as? String { return parent }
        return info["DeviceIdentifier"] as? String
    }

    static func unmount(_ disk: USBDisk) -> Bool {
        run("/usr/sbin/diskutil", ["unmountDisk", disk.devicePath]) == 0
    }

    static func eject(_ disk: USBDisk) {
        _ = run("/usr/sbin/diskutil", ["eject", disk.devicePath])
    }

    // --- helpers ---

    private static func runDiskutil(_ args: [String]) -> [String: Any]? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do { try process.run() } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        return (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any]
    }

    private static func run(_ tool: String, _ args: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = args
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do { try process.run() } catch { return -1 }
        process.waitUntilExit()
        return process.terminationStatus
    }
}
#endif
