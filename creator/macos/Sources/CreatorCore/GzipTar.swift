// Gzip decompression (zlib) + minimal ustar reading — enough to pull the
// seed files out of the Second Wind payload tarball (a `git archive` output).
import Foundation
import CZLib

public enum ArchiveError: Error, CustomStringConvertible {
    case gzip(String)
    case tarTruncated
    case memberMissing(String)

    public var description: String {
        switch self {
        case .gzip(let m): return "could not decompress: \(m)"
        case .tarTruncated: return "archive is cut short"
        case .memberMissing(let m): return "file missing inside the archive: \(m)"
        }
    }
}

public enum Gzip {
    /// Inflate gzip (or raw zlib) data in one call.
    public static func decompress(_ input: Data) throws -> Data {
        var stream = z_stream()
        // 15 window bits + 32 = auto-detect gzip/zlib header.
        var status = inflateInit2_(&stream, 15 + 32, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))
        guard status == Z_OK else { throw ArchiveError.gzip("init failed (\(status))") }
        defer { inflateEnd(&stream) }

        var output = Data()
        var chunk = [UInt8](repeating: 0, count: 1 << 18)
        var inputBytes = [UInt8](input)
        return try inputBytes.withUnsafeMutableBufferPointer { inPtr -> Data in
            stream.next_in = inPtr.baseAddress
            stream.avail_in = uInt(inPtr.count)
            repeat {
                status = chunk.withUnsafeMutableBufferPointer { outPtr -> Int32 in
                    stream.next_out = outPtr.baseAddress
                    stream.avail_out = uInt(outPtr.count)
                    return inflate(&stream, Z_NO_FLUSH)
                }
                guard status == Z_OK || status == Z_STREAM_END || status == Z_BUF_ERROR else {
                    throw ArchiveError.gzip("inflate failed (\(status))")
                }
                let produced = chunk.count - Int(stream.avail_out)
                if produced > 0 { output.append(contentsOf: chunk[0..<produced]) }
                if status == Z_BUF_ERROR && produced == 0 { throw ArchiveError.gzip("truncated stream") }
            } while status != Z_STREAM_END
            return output
        }
    }
}

extension Gzip {
    /// Gzip-compress data (used by tests and tooling).
    public static func compress(_ input: Data) throws -> Data {
        var stream = z_stream()
        var status = deflateInit2_(&stream, Z_BEST_SPEED, Z_DEFLATED, 15 + 16, 8,
                                   Z_DEFAULT_STRATEGY, ZLIB_VERSION,
                                   Int32(MemoryLayout<z_stream>.size))
        guard status == Z_OK else { throw ArchiveError.gzip("deflate init failed (\(status))") }
        defer { deflateEnd(&stream) }

        var output = Data()
        var chunk = [UInt8](repeating: 0, count: 1 << 18)
        var inputBytes = [UInt8](input)
        return inputBytes.withUnsafeMutableBufferPointer { inPtr -> Data in
            stream.next_in = inPtr.baseAddress
            stream.avail_in = uInt(inPtr.count)
            repeat {
                status = chunk.withUnsafeMutableBufferPointer { outPtr -> Int32 in
                    stream.next_out = outPtr.baseAddress
                    stream.avail_out = uInt(outPtr.count)
                    return deflate(&stream, Z_FINISH)
                }
                let produced = chunk.count - Int(stream.avail_out)
                if produced > 0 { output.append(contentsOf: chunk[0..<produced]) }
            } while status != Z_STREAM_END
            return output
        }
    }
}

public enum Tar {
    /// Extract the named regular files from an (uncompressed) tar stream.
    /// Returns [path: contents]. Paths must match exactly.
    public static func extract(_ tar: Data, paths: Set<String>) throws -> [String: Data] {
        var result = [String: Data]()
        var offset = 0
        let bytes = [UInt8](tar)
        while offset + 512 <= bytes.count {
            let block = Array(bytes[offset..<offset + 512])
            if block.allSatisfy({ $0 == 0 }) { break } // end-of-archive
            func field(_ start: Int, _ len: Int) -> String {
                let raw = block[start..<start + len].prefix { $0 != 0 }
                return String(decoding: raw, as: UTF8.self)
            }
            let name = field(0, 100)
            let prefix = field(345, 155)
            let fullName = prefix.isEmpty ? name : prefix + "/" + name
            let size = Int(field(124, 12).trimmingCharacters(in: .whitespaces), radix: 8) ?? 0
            let typeFlag = block[156]
            offset += 512
            let dataEnd = offset + size
            guard dataEnd <= bytes.count else { throw ArchiveError.tarTruncated }
            if (typeFlag == 0x30 || typeFlag == 0) && paths.contains(fullName) {
                result[fullName] = Data(bytes[offset..<dataEnd])
            }
            offset = dataEnd + (512 - size % 512) % 512
        }
        for p in paths where result[p] == nil { throw ArchiveError.memberMissing(p) }
        return result
    }
}
