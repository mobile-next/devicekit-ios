//
//  File.swift
//  
//
//  Created by Victor Kachalov on 04.12.23.
//

import CoreImage

extension CIImage {
    func flip(orientation: CGImagePropertyOrientation) -> CIImage {
        switch orientation {
        case .up, .upMirrored, .down, .downMirrored:
            return oriented(.up)
        case .left, .leftMirrored:
            return oriented(.right)
        case .right, .rightMirrored:
            return oriented(.left)
        }
    }
}
