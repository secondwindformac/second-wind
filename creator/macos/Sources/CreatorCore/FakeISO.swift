// A tiny but structurally valid GPT disk image imitating the Ubuntu ISO
// layout (protective MBR + two partitions + backup GPT at image end).
// Test/CI fixture only — lets the pipeline be validated without downloading
// a 6 GB ISO.
import Foundation

public enum FakeISO {
    public static let sizeMB: UInt64 = 64

    public static func write(to dev: BlockDevice) throws {
        let size = sizeMB * 1024 * 1024
        let lbas = size / 512

        // Protective MBR
        var mbr = [UInt8](repeating: 0, count: 512)
        mbr[446 + 1] = 0x00; mbr[446 + 2] = 0x02
        mbr[446 + 4] = 0xEE
        GPT.put32(&mbr, 446 + 8, 1)
        GPT.put32(&mbr, 446 + 12, UInt32(min(lbas - 1, 0xFFFF_FFFF)))
        mbr[510] = 0x55; mbr[511] = 0xAA
        try dev.write(Data(mbr), at: 0)

        // Two partitions, like the real ISO (data area + EFI system partition)
        let entrySize = 128, numEntries = 128
        var entries = [UInt8](repeating: 0, count: entrySize * numEntries)
        func entry(_ slot: Int, type: String, first: UInt64, last: UInt64, name: String) {
            var e = [UInt8](repeating: 0, count: entrySize)
            e.replaceSubrange(0..<16, with: GPT.mixedEndianGUID(type))
            e.replaceSubrange(16..<32, with: GPT.mixedEndianGUID(UUID().uuidString))
            GPT.put64(&e, 32, first)
            GPT.put64(&e, 40, last)
            for (i, unit) in Array(name.utf16).enumerated() where i < 36 {
                e[56 + i * 2] = UInt8(unit & 0xFF)
                e[56 + i * 2 + 1] = UInt8(unit >> 8)
            }
            entries.replaceSubrange(slot * entrySize..<(slot + 1) * entrySize, with: e)
        }
        let entriesSectors = UInt64(entrySize * numEntries / 512) // 32
        let lastUsable = lbas - 2 - entriesSectors
        entry(0, type: "0FC63DAF-8483-4772-8E79-3D69D8477DE4",
              first: 64, last: lbas / 2, name: "ISO9660")
        entry(1, type: "C12A7328-F81F-11D2-BA4B-00A0C93EC93B",
              first: lbas / 2 + 1, last: lbas / 2 + 2048, name: "EFI System Partition")
        let entriesCRC = GPT.crc32(entries)

        // Header layout: 24 current LBA, 32 backup LBA, 40 first usable,
        // 48 last usable, 56 disk GUID, 72 entries LBA, 80/84 count/size,
        // 88 entries CRC.
        var h = [UInt8](repeating: 0, count: 512)
        h.replaceSubrange(0..<8, with: Array("EFI PART".utf8))
        h[10] = 1
        GPT.put32(&h, 12, 92)
        GPT.put64(&h, 24, 1)
        GPT.put64(&h, 32, lbas - 1)
        GPT.put64(&h, 40, 64)
        GPT.put64(&h, 48, lastUsable)
        h.replaceSubrange(56..<72, with: GPT.mixedEndianGUID(UUID().uuidString))
        GPT.put64(&h, 72, 2)
        GPT.put32(&h, 80, UInt32(numEntries))
        GPT.put32(&h, 84, UInt32(entrySize))
        GPT.put32(&h, 88, entriesCRC)
        GPT.sealHeaderCRC(&h, headerSize: 92)

        var backup = h
        GPT.put64(&backup, 24, lbas - 1)
        GPT.put64(&backup, 32, 1)
        GPT.put64(&backup, 72, lbas - 1 - entriesSectors)
        GPT.sealHeaderCRC(&backup, headerSize: 92)

        try dev.write(Data(entries), at: 2 * 512)
        try dev.write(Data(h), at: 1 * 512)
        try dev.write(Data(entries), at: (lbas - 1 - entriesSectors) * 512)
        try dev.write(Data(backup), at: (lbas - 1) * 512)
    }
}
