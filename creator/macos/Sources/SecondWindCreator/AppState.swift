// The wizard's state machine and orchestration. Views render it; the engine
// does the work on background tasks.
#if os(macOS)
import Foundation
import SwiftUI
import CreatorCore

enum Stage {
    case welcome
    case locks
    case download
    case pickDisk
    case confirm
    case writing
    case done
}

@MainActor
final class AppState: ObservableObject {
    @Published var stage: Stage = .welcome

    // Locks
    @Published var lockBackup = false
    @Published var lockErase = false

    // Download
    @Published var isoProgress: Double = 0
    @Published var isoDone = false
    @Published var payloadDone = false
    @Published var downloadError: String?

    // Disks
    @Published var disks: [USBDisk] = []
    @Published var selected: USBDisk?

    // Confirm + write
    @Published var confirmText = ""
    @Published var phaseLabel = ""
    @Published var writeProgress: Double = 0
    @Published var writeError: String?

    private var manifest: CreatorManifest?
    private var payloadData: Data?
    private var downloading = false

    var supportDir: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SecondWindCreator")
    }
    var isoFile: URL? {
        guard let manifest = manifest,
              let name = URL(string: manifest.isoURL)?.lastPathComponent else { return nil }
        return supportDir.appendingPathComponent(name)
    }

    // --- Download step ---

    func startDownloads() {
        guard !downloading else { return }
        downloading = true
        downloadError = nil
        Task {
            do {
                let manifest = await ManifestSource.resolve()
                self.manifest = manifest

                // Second Wind payload first (small, fails fast if offline).
                if payloadData == nil {
                    guard let payloadURL = manifest.payloadURL.flatMap(URL.init(string:)) else {
                        throw DownloadError.transport("no payload published yet")
                    }
                    let file = supportDir.appendingPathComponent(manifest.payloadName)
                    let downloader = Downloader()
                    try await downloader.download(
                        payloadURL, to: file,
                        expectedSHA256: manifest.payloadSHA256.isEmpty ? nil : manifest.payloadSHA256
                    ) { _ in }
                    payloadData = try Data(contentsOf: file)
                }
                payloadDone = true

                // The big one: the official Ubuntu system.
                if !isoDone, let isoURL = URL(string: manifest.isoURL), let isoFile = isoFile {
                    let downloader = Downloader()
                    try await downloader.download(
                        isoURL, to: isoFile, expectedSHA256: manifest.isoSHA256
                    ) { [weak self] p in
                        guard let total = p.totalBytes, total > 0 else { return }
                        let fraction = Double(p.bytesReceived) / Double(total)
                        Task { @MainActor in self?.isoProgress = fraction }
                    }
                }
                isoDone = true
                isoProgress = 1
                downloading = false
                refreshDisks()
                stage = .pickDisk
            } catch {
                downloading = false
                downloadError = "\(L10n.downloadFailed)\n(\(error))"
            }
        }
    }

    // --- Disk step ---

    func refreshDisks() {
        Task.detached {
            let found = DiskEnumerator.externalSticks()
            await MainActor.run {
                self.disks = found
                if let selected = self.selected, !found.contains(selected) {
                    self.selected = nil
                }
            }
        }
    }

    // --- Write step ---

    func startWrite() {
        guard let disk = selected, let isoFile = isoFile, let payload = payloadData else { return }
        stage = .writing
        writeError = nil
        writeProgress = 0
        phaseLabel = L10n.phaseUnmount

        Task.detached {
            do {
                try ImageWriter.writeStick(isoPath: isoFile, payloadTarGz: payload, disk: disk) { phase in
                    Task { @MainActor in
                        switch phase {
                        case .unmounting:
                            self.phaseLabel = L10n.phaseUnmount
                        case .writingISO(let written, let total):
                            self.phaseLabel = L10n.phaseISO
                            if total > 0 { self.writeProgress = 0.9 * Double(written) / Double(total) }
                        case .addingSeed:
                            self.phaseLabel = L10n.phaseSeed
                            self.writeProgress = 0.92
                        case .verifying:
                            self.phaseLabel = L10n.phaseVerify
                            self.writeProgress = 0.96
                        case .ejecting:
                            self.phaseLabel = L10n.phaseEject
                            self.writeProgress = 0.99
                        case .done:
                            self.writeProgress = 1
                        }
                    }
                }
                await MainActor.run { self.stage = .done }
            } catch let error as AuthOpenError {
                await MainActor.run {
                    self.writeError = error == .notAuthorized ? L10n.authDeclined : "\(L10n.writeFailed)\n(\(error))"
                    self.stage = .confirm
                }
            } catch {
                await MainActor.run {
                    self.writeError = "\(L10n.writeFailed)\n(\(error))"
                    self.stage = .confirm
                }
            }
        }
    }

    func resetForAnother() {
        selected = nil
        confirmText = ""
        writeError = nil
        writeProgress = 0
        refreshDisks()
        stage = .pickDisk
    }
}

extension AuthOpenError: Equatable {
    static func == (lhs: AuthOpenError, rhs: AuthOpenError) -> Bool {
        String(describing: lhs) == String(describing: rhs)
    }
}
#endif
