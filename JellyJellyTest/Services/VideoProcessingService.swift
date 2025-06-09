import AVFoundation
import CoreImage

protocol VideoProcessingServiceProtocol {
    func convertTo32BGRA(pixelBuffer: CVPixelBuffer) -> CVPixelBuffer?
    func createCombinedPixelBuffer(topBuffer: CVPixelBuffer, bottomBuffer: CVPixelBuffer) -> CVPixelBuffer?
}

class VideoProcessingService: VideoProcessingServiceProtocol {
    private let ciContext = CIContext()

    func convertTo32BGRA(pixelBuffer: CVPixelBuffer) -> CVPixelBuffer? {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let pixelFormat = kCVPixelFormatType_32BGRA
        
        var outputBuffer: CVPixelBuffer?
        let attrs = [
            kCVPixelBufferPixelFormatTypeKey as String: pixelFormat,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ] as CFDictionary
        
        let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, pixelFormat, attrs, &outputBuffer)
        guard status == kCVReturnSuccess, let outBuffer = outputBuffer else {
            print("Failed to create output pixel buffer for BGRA conversion")
            return nil
        }
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        ciContext.render(ciImage, to: outBuffer)
        return outBuffer
    }

    func createCombinedPixelBuffer(topBuffer: CVPixelBuffer, bottomBuffer: CVPixelBuffer) -> CVPixelBuffer? {
        guard let rotatedTopBuffer = rotate(pixelBuffer: topBuffer, by: .leftMirrored),
              let rotatedBottomBuffer = rotate(pixelBuffer: bottomBuffer, by: .leftMirrored) else {
            print("Rotation failed for one or both buffers")
            return nil
        }
        
        let topWidth = CVPixelBufferGetWidth(rotatedTopBuffer)
        let topHeight = CVPixelBufferGetHeight(rotatedTopBuffer)
        let bottomWidth = CVPixelBufferGetWidth(rotatedBottomBuffer)
        let bottomHeight = CVPixelBufferGetHeight(rotatedBottomBuffer)
        
        guard topWidth == bottomWidth else {
            print("Error: Top and bottom buffers have different widths after rotation")
            return nil
        }
        
        let combinedWidth = topWidth
        let combinedHeight = topHeight + bottomHeight
        let pixelFormat = kCVPixelFormatType_32BGRA // Assuming rotated buffers are BGRA
        
        var combinedBuffer: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: pixelFormat,
            kCVPixelBufferWidthKey as String: combinedWidth,
            kCVPixelBufferHeightKey as String: combinedHeight,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ]
        
        let status = CVPixelBufferCreate(kCFAllocatorDefault, combinedWidth, combinedHeight, pixelFormat, attrs as CFDictionary, &combinedBuffer)
        guard status == kCVReturnSuccess, let destBuffer = combinedBuffer else {
            print("Failed to create combined pixel buffer, status: \(status)")
            return nil
        }
        
        CVPixelBufferLockBaseAddress(destBuffer, [])
        CVPixelBufferLockBaseAddress(rotatedTopBuffer, .readOnly)
        CVPixelBufferLockBaseAddress(rotatedBottomBuffer, .readOnly)
        
        guard let destBase = CVPixelBufferGetBaseAddress(destBuffer),
              let topBase = CVPixelBufferGetBaseAddress(rotatedTopBuffer),
              let bottomBase = CVPixelBufferGetBaseAddress(rotatedBottomBuffer) else {
            print("Failed to get base addresses for combined buffer")
            CVPixelBufferUnlockBaseAddress(destBuffer, [])
            CVPixelBufferUnlockBaseAddress(rotatedTopBuffer, .readOnly)
            CVPixelBufferUnlockBaseAddress(rotatedBottomBuffer, .readOnly)
            return nil
        }
        
        let destBytesPerRow = CVPixelBufferGetBytesPerRow(destBuffer)
        let topBytesPerRow = CVPixelBufferGetBytesPerRow(rotatedTopBuffer)
        let bottomBytesPerRow = CVPixelBufferGetBytesPerRow(rotatedBottomBuffer)
        
        // Copy top buffer
        for row in 0..<topHeight {
            let destPtr = destBase.advanced(by: row * destBytesPerRow)
            let srcPtr = topBase.advanced(by: row * topBytesPerRow)
            memcpy(destPtr, srcPtr, topBytesPerRow)
        }
        
        // Copy bottom buffer
        for row in 0..<bottomHeight {
            let destPtr = destBase.advanced(by: (topHeight + row) * destBytesPerRow)
            let srcPtr = bottomBase.advanced(by: row * bottomBytesPerRow)
            memcpy(destPtr, srcPtr, bottomBytesPerRow)
        }
        
        CVPixelBufferUnlockBaseAddress(destBuffer, [])
        CVPixelBufferUnlockBaseAddress(rotatedTopBuffer, .readOnly)
        CVPixelBufferUnlockBaseAddress(rotatedBottomBuffer, .readOnly)
        
        return destBuffer
    }

    // Helper for rotation, similar to your CVPixelBuffer extension
    private func rotate(pixelBuffer: CVPixelBuffer, by orientation: CGImagePropertyOrientation) -> CVPixelBuffer? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer).oriented(orientation)
        // Ensure the output buffer is also BGRA if the input was, or if combining requires it
        let outputPixelFormat = kCVPixelFormatType_32BGRA
        
        var rotatedBuffer: CVPixelBuffer?
        let attrs = [
            kCVPixelBufferPixelFormatTypeKey as String: outputPixelFormat,
            kCVPixelBufferWidthKey as String: Int(ciImage.extent.width),
            kCVPixelBufferHeightKey as String: Int(ciImage.extent.height),
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ] as CFDictionary

        let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                         Int(ciImage.extent.width),
                                         Int(ciImage.extent.height),
                                         outputPixelFormat,
                                         attrs,
                                         &rotatedBuffer)
        
        guard status == kCVReturnSuccess, let buffer = rotatedBuffer else {
            print("Failed to create rotated pixel buffer")
            return nil
        }
        
        ciContext.render(ciImage, to: buffer)
        return buffer
    }
}