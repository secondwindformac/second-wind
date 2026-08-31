// Privileged disk access without a single terminal window.
//
// /usr/libexec/authopen is Apple's own helper: it shows the standard system
// password dialog and hands back an open file descriptor for the device over
// a socket (SCM_RIGHTS). Same mechanism Raspberry Pi Imager uses. No custom
// privileged helpers, nothing to install.
#if os(macOS)
import Foundation
import Darwin
import CreatorCore

enum AuthOpenError: Error, CustomStringConvertible {
    case spawnFailed(Int32)
    case notAuthorized
    case protocolFailure

    var description: String {
        switch self {
        case .spawnFailed(let e): return "could not start the system authorization helper (\(e))"
        case .notAuthorized: return "permission was not granted"
        case .protocolFailure: return "the system authorization helper answered unexpectedly"
        }
    }
}

enum AuthOpen {
    /// Open `path` read-write as root, via the system password dialog.
    static func open(path: String) throws -> Int32 {
        var sv: [Int32] = [0, 0]
        guard socketpair(AF_UNIX, SOCK_STREAM, 0, &sv) == 0 else {
            throw AuthOpenError.spawnFailed(errno)
        }
        defer { Darwin.close(sv[0]) }

        var actions: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&actions)
        defer { posix_spawn_file_actions_destroy(&actions) }
        posix_spawn_file_actions_adddup2(&actions, sv[1], STDOUT_FILENO)
        posix_spawn_file_actions_addclose(&actions, sv[0])
        posix_spawn_file_actions_addclose(&actions, sv[1])

        let argv = ["/usr/libexec/authopen", "-stdoutpipe", "-o", String(O_RDWR), path]
        var pid: pid_t = 0
        let cArgs = argv.map { strdup($0) } + [nil]
        defer { cArgs.forEach { free($0) } }
        let rc = posix_spawn(&pid, argv[0], &actions, nil, cArgs, environ)
        Darwin.close(sv[1])
        guard rc == 0 else { throw AuthOpenError.spawnFailed(rc) }

        let fd = receiveFileDescriptor(on: sv[0])

        var status: Int32 = 0
        waitpid(pid, &status, 0)

        guard let fd = fd else {
            // No descriptor arrived: the person cancelled the password dialog
            // (authopen exits non-zero) or something stranger happened.
            let exited = (status & 0x7F) == 0
            let code = (status >> 8) & 0xFF
            if exited && code != 0 { throw AuthOpenError.notAuthorized }
            throw AuthOpenError.protocolFailure
        }
        return fd
    }

    private static func receiveFileDescriptor(on socket: Int32) -> Int32? {
        var dataByte: UInt8 = 0
        var iov = iovec(iov_base: &dataByte, iov_len: 1)
        let controlSize = 64
        let control = UnsafeMutableRawPointer.allocate(byteCount: controlSize, alignment: 8)
        defer { control.deallocate() }
        control.initializeMemory(as: UInt8.self, repeating: 0, count: controlSize)

        var msg = msghdr()
        withUnsafeMutablePointer(to: &iov) { msg.msg_iov = $0 }
        msg.msg_iovlen = 1
        msg.msg_control = control
        msg.msg_controllen = socklen_t(controlSize)

        // authopen may write a status byte stream; loop until a control
        // message with the descriptor shows up or the pipe closes.
        for _ in 0..<32 {
            let n = recvmsg(socket, &msg, 0)
            if n < 0 { return nil }
            if msg.msg_controllen >= 16 {
                // struct cmsghdr { socklen_t len; int32 level; int32 type; }
                let len = control.load(fromByteOffset: 0, as: UInt32.self)
                let level = control.load(fromByteOffset: 4, as: Int32.self)
                let type = control.load(fromByteOffset: 8, as: Int32.self)
                if level == SOL_SOCKET && type == SCM_RIGHTS && len >= 16 {
                    return control.load(fromByteOffset: 12, as: Int32.self)
                }
            }
            if n == 0 { return nil } // EOF, no descriptor
            msg.msg_controllen = socklen_t(controlSize)
        }
        return nil
    }
}

/// BlockDevice over the raw disk descriptor authopen handed us.
final class RawDiskDevice: BlockDevice {
    let fd: Int32
    let size: UInt64
    private var closed = false

    init(fd: Int32) throws {
        self.fd = fd
        var blockSize: UInt32 = 0
        var blockCount: UInt64 = 0
        // DKIOCGETBLOCKSIZE / DKIOCGETBLOCKCOUNT
        guard ioctl(fd, 0x40046418, &blockSize) == 0,
              ioctl(fd, 0x40086419, &blockCount) == 0,
              blockSize > 0 else {
            throw GPTError.ioTooShort
        }
        guard blockSize == 512 else { throw GPTError.unsupportedSectorSize(Int(blockSize)) }
        size = UInt64(blockSize) * blockCount
    }

    func read(at offset: UInt64, count: Int) throws -> Data {
        var data = Data(count: count)
        let n = data.withUnsafeMutableBytes { buf in
            pread(fd, buf.baseAddress, count, off_t(offset))
        }
        guard n == count else { throw GPTError.ioTooShort }
        return data
    }

    /// Raw disk I/O must be sector-aligned in offset AND length; pad
    /// unaligned tails by read-modify-write of the final sector.
    func write(_ data: Data, at offset: UInt64) throws {
        precondition(offset % 512 == 0, "unaligned disk write offset")
        let aligned = data.count / 512 * 512
        if aligned > 0 {
            try writeFully(data.prefix(aligned), at: offset)
        }
        let tail = data.count - aligned
        if tail > 0 {
            var sector = try read(at: offset + UInt64(aligned), count: 512)
            sector.replaceSubrange(0..<tail, with: data.suffix(tail))
            try writeFully(sector, at: offset + UInt64(aligned))
        }
    }

    private func writeFully(_ data: Data, at offset: UInt64) throws {
        let fd = self.fd
        var written = 0
        try data.withUnsafeBytes { (buf: UnsafeRawBufferPointer) in
            while written < buf.count {
                let n = pwrite(fd, buf.baseAddress!.advanced(by: written),
                               buf.count - written, off_t(offset) + off_t(written))
                guard n > 0 else { throw DownloadError.transport("disk write failed (\(errno))") }
                written += n
            }
        }
    }

    func fullSync() {
        _ = fcntl(fd, F_FULLFSYNC)
    }

    func close() {
        if !closed {
            closed = true
            Darwin.close(fd)
        }
    }
}
#endif
