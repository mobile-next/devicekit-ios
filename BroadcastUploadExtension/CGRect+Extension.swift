import UIKit

extension CGRect {
    static var logicalResolutionScreen: CGRect {
        makeScreen(bounds: UIScreen.main.bounds)
    }

    static var actualResolutionScreen: CGRect {
        makeScreen(bounds: UIScreen.main.nativeBounds)
    }

    private static func makeScreen(bounds: CGRect) -> CGRect {
        let size = CGSize(width: bounds.width, height: bounds.height)
        return CGRect(origin: .zero, size: size)
    }

    func scaledDimensions(_ factor: Float) -> (width: Int32, height: Int32) {
        let scaledWidth = Int32(Float(width) * factor)
        let scaledHeight = Int32(Float(height) * factor)
        return (width: scaledWidth, height: scaledHeight)
    }

    private var nativeSide: Float {
        Float(max(height, width))
    }
}
