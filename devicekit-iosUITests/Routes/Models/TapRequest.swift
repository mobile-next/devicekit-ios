import Foundation

struct TapRequest : Codable {
    let x: Float
    let y: Float
    let duration: TimeInterval?
}
