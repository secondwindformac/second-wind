// Resumable, checksum-verified downloads.
//
// Written for a macOS 11 floor: no URLSession.bytes / data(for:) async APIs,
// just a delegate bridged to Swift concurrency. Also compiles on Linux
// (FoundationNetworking) so CI can exercise it.
import Foundation
import Crypto
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum DownloadError: Error, CustomStringConvertible {
    case badStatus(Int)
    case checksumMismatch(expected: String, got: String)
    case cancelled
    case transport(String)

    public var description: String {
        switch self {
        case .badStatus(let s): return "server answered \(s)"
        case .checksumMismatch(let e, let g): return "verification failed (expected \(e.prefix(12))…, got \(g.prefix(12))…)"
        case .cancelled: return "cancelled"
        case .transport(let m): return m
        }
    }
}

public final class Downloader: NSObject, URLSessionDataDelegate {
    public struct Progress {
        public let bytesReceived: Int64
        public let totalBytes: Int64?
    }

    private var handle: FileHandle!
    private var hasher = SHA256()
    private var received: Int64 = 0
    private var total: Int64?
    private var resumedFrom: Int64 = 0
    private var progressCallback: ((Progress) -> Void)?
    private var continuation: CheckedContinuation<Void, Error>?
    private var restartedFromScratch = false
    private var destination: URL!

    /// Download `url` to `file`, resuming a partial file if present, and
    /// verify the final SHA-256 (lowercase hex) when given.
    public func download(
        _ url: URL,
        to file: URL,
        expectedSHA256: String?,
        progress: @escaping (Progress) -> Void
    ) async throws {
        destination = file
        progressCallback = progress
        try FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(), withIntermediateDirectories: true)

        // Hash any bytes we already have, so resume keeps verification honest.
        if let existing = try? FileHandle(forReadingFrom: file) {
            while true {
                let chunk = existing.readData(ofLength: 1 << 20)
                if chunk.isEmpty { break }
                hasher.update(data: chunk)
                resumedFrom += Int64(chunk.count)
            }
            existing.closeFile()
        }
        if !FileManager.default.fileExists(atPath: file.path) {
            FileManager.default.createFile(atPath: file.path, contents: nil)
        }
        handle = try FileHandle(forWritingTo: file)
        if resumedFrom > 0 { handle.seekToEndOfFile() }
        received = resumedFrom

        var request = URLRequest(url: url)
        request.timeoutInterval = 60
        if resumedFrom > 0 {
            request.setValue("bytes=\(resumedFrom)-", forHTTPHeaderField: "Range")
        }

        let config = URLSessionConfiguration.ephemeral
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            continuation = cont
            session.dataTask(with: request).resume()
        }
        handle.closeFile()

        if let expected = expectedSHA256 {
            let digest = hasher.finalize().map { String(format: "%02x", $0) }.joined()
            guard digest == expected.lowercased() else {
                try? FileManager.default.removeItem(at: file) // poisoned — start clean next time
                throw DownloadError.checksumMismatch(expected: expected, got: digest)
            }
        }
    }

    // --- URLSessionDataDelegate ---

    public func urlSession(
        _ session: URLSession, dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        guard let http = response as? HTTPURLResponse else {
            completionHandler(.allow); return
        }
        switch http.statusCode {
        case 206:
            total = resumedFrom + http.expectedContentLength
        case 200:
            // Server ignored our Range: start over from byte zero.
            if resumedFrom > 0 {
                restartedFromScratch = true
                hasher = SHA256()
                handle.truncateFile(atOffset: 0)
                received = 0
            }
            total = http.expectedContentLength > 0 ? http.expectedContentLength : nil
        case 416:
            // Range not satisfiable — we probably already have the full file.
            completionHandler(.cancel)
            continuation?.resume()
            continuation = nil
            return
        default:
            completionHandler(.cancel)
            continuation?.resume(throwing: DownloadError.badStatus(http.statusCode))
            continuation = nil
            return
        }
        completionHandler(.allow)
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        handle.write(data)
        hasher.update(data: data)
        received += Int64(data.count)
        progressCallback?(Progress(bytesReceived: received, totalBytes: total))
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            continuation?.resume(throwing: DownloadError.transport(error.localizedDescription))
        } else {
            continuation?.resume()
        }
        continuation = nil
    }
}

/// Small async GET helper (JSON APIs, checksum files) with a macOS 11 floor.
public enum HTTP {
    public static func get(_ url: URL, accept: String? = nil) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        if let accept = accept { request.setValue(accept, forHTTPHeaderField: "Accept") }
        return try await withCheckedThrowingContinuation { cont in
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    cont.resume(throwing: DownloadError.transport(error.localizedDescription))
                    return
                }
                if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                    cont.resume(throwing: DownloadError.badStatus(http.statusCode))
                    return
                }
                cont.resume(returning: data ?? Data())
            }.resume()
        }
    }
}
