// Assembles the CIDATA seed volume contents from the Second Wind payload
// tarball — the same file set scripts/make-usb.sh stages on Linux:
//
//   user-data                  (autoinstall answers, password placeholder filled)
//   meta-data
//   autoinstall/user-data      (copy — the Desktop installer's folder scan)
//   firstboot/second-wind-firstboot.sh
//   firstboot/second-wind-firstboot.desktop
//   second-wind.tar.gz         (the payload itself)
import Foundation

public enum SeedBuilder {
    // SHA-512 crypt of the placeholder password "secondwind" — replaced by the
    // interactive identity screen during install, exactly like the Linux
    // creator (which generates it with `openssl passwd -6 secondwind`).
    static let placeholderHash =
        "$6$zC.F0yEOSLU.5I7C$fxLumvRNf4JyY09sLHixBNtxzBmY19pXJAQvkan0yddu//eGBbzZjkictcWzUURgV/j1P0465Dzmjr7MgqAr./"

    static let seedPaths: Set<String> = [
        "second-wind/usb/seed/user-data",
        "second-wind/usb/seed/meta-data",
        "second-wind/usb/firstboot/second-wind-firstboot.sh",
        "second-wind/usb/firstboot/second-wind-firstboot.desktop",
    ]

    /// Build the extents of the complete CIDATA volume from the payload
    /// tarball bytes (already checksum-verified by the caller).
    public static func buildVolumeExtents(payloadTarGz: Data) throws -> [FATExtent] {
        let tar = try Gzip.decompress(payloadTarGz)
        let files = try Tar.extract(tar, paths: seedPaths)

        let userDataTemplate = String(decoding: files["second-wind/usb/seed/user-data"]!, as: UTF8.self)
        let userData = Data(userDataTemplate
            .replacingOccurrences(of: "@PASSWORD_HASH@", with: placeholderHash).utf8)

        return try FAT32Builder.buildExtents(
            volumeBytes: GPT.cidataSizeBytes,
            label: "CIDATA",
            rootFiles: [
                FATFile(name: "user-data", data: userData),
                FATFile(name: "meta-data", data: files["second-wind/usb/seed/meta-data"]!),
                FATFile(name: "second-wind.tar.gz", data: payloadTarGz),
            ],
            directories: [
                FATDirectory(name: "autoinstall", files: [
                    FATFile(name: "user-data", data: userData),
                ]),
                FATDirectory(name: "firstboot", files: [
                    FATFile(name: "second-wind-firstboot.sh",
                            data: files["second-wind/usb/firstboot/second-wind-firstboot.sh"]!),
                    FATFile(name: "second-wind-firstboot.desktop",
                            data: files["second-wind/usb/firstboot/second-wind-firstboot.desktop"]!),
                ]),
            ]
        )
    }
}
