// "Which Mac will you install on?" — the compatibility catalog behind the
// Creator's first real question. Platform-agnostic (tested on Linux in CI).
//
// Two ways in, both in plain words for a non-technical person:
//   • the app runs ON the target Mac → its model identifier (hw.model) names it;
//   • it runs on another Mac → the person types the model number printed on the
//     bottom case (e.g. "A1466"). That number repeats across years (A1466 = the
//     13" MacBook Air from 2012 to 2017, with different WiFi chips), so the
//     person then picks the year from a short list.
import Foundation

public struct MacModel: Codable, Equatable, Identifiable {
    public let name: String
    public let year: Int
    public let identifiers: [String]
    public let aNumbers: [String]
    public let support: Support
    public let noteES: String
    public let noteEN: String
    public var id: String { name + "|" + (identifiers.first ?? "") }

    public enum Support: String, Codable {
        case verified, expected, partial, beta, unsupported
        /// May the person go on and write the stick?
        public var allowsInstall: Bool { self != .unsupported }
        /// Must they explicitly accept known limits first?
        public var needsAcknowledgement: Bool { self == .beta }
    }

    enum CodingKeys: String, CodingKey {
        case name = "n", year = "y", identifiers = "i", aNumbers = "a", support = "s", noteES = "es", noteEN = "en"
    }
}

public enum MacCatalog {
    public static let all: [MacModel] = {
        (try? JSONDecoder().decode([MacModel].self, from: Data(MacCatalogData.json.utf8))) ?? []
    }()

    /// Rows for a model identifier such as "MacBookAir6,2" (several marketing
    /// years can share one identifier).
    public static func models(identifier: String) -> [MacModel] {
        all.filter { $0.identifiers.contains(identifier) }
    }

    /// Normalizes what a person may type: "a1466", "1466", "Model A1466".
    public static func normalizeANumber(_ raw: String) -> String? {
        let digits = raw.uppercased().filter { $0.isNumber }
        guard digits.count == 4 else { return nil }
        return "A" + digits
    }

    /// Every Intel Mac sold under that model number, newest first.
    public static func models(aNumber raw: String) -> [MacModel] {
        guard let a = normalizeANumber(raw) else { return [] }
        return all.filter { $0.aNumbers.contains(a) }.sorted { $0.year > $1.year }
    }
}
