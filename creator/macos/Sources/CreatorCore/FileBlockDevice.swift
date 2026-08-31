// BlockDevice over a plain file — what seedtool and the tests use, so the
// exact GPT/FAT code that touches real sticks is validated against files
// with fsck.vfat, sgdisk and mtools first.
import Foundation

public final class FileBlockDevice: BlockDevice {
    private let handle: FileHandle
    public let size: UInt64

    public init(url: URL) throws {
        handle = try FileHandle(forUpdating: url)
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        size = (attrs[.size] as? NSNumber)?.uint64Value ?? 0
    }

    public func read(at offset: UInt64, count: Int) throws -> Data {
        handle.seek(toFileOffset: offset)
        let data = handle.readData(ofLength: count)
        guard data.count == count else { throw GPTError.ioTooShort }
        return data
    }

    public func write(_ data: Data, at offset: UInt64) throws {
        handle.seek(toFileOffset: offset)
        handle.write(data)
    }

    public func close() {
        handle.closeFile()
    }
}
