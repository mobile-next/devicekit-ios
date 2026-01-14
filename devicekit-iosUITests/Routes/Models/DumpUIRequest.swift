import Foundation

struct DumpUIRequest: Codable {
    let appIds: [String]
    let excludeKeyboardElements: Bool
}
