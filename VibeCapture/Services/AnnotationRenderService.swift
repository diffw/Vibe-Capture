import AppKit

/// Service for compositing annotations onto images
/// Used when saving or sending screenshots
final class AnnotationRenderService {
    
    /// Render annotations onto an image at original resolution
    /// - Parameters:
    ///   - image: The original screenshot image
    ///   - annotations: Annotations to render (coordinates in image space)
    /// - Returns: New image with annotations composited, or original if no annotations
    static func render(image: NSImage, annotations: [any Annotation]) -> NSImage {
        // If no annotations, return original image
        guard !annotations.isEmpty else { return image }
        
        // Get the actual pixel size of the image
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return image
        }
        
        let pixelWidth = CGFloat(cgImage.width)
        let pixelHeight = CGFloat(cgImage.height)
        
        // Create a new bitmap context at full resolution
        guard let context = CGContext(
            data: nil,
            width: Int(pixelWidth),
            height: Int(pixelHeight),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return image
        }
        
        // Draw the original image
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))
        
        // Calculate scale factor from image's logical size to pixel size
        // Annotations are stored in logical (point) coordinates
        let logicalSize = image.size
        let scaleX = pixelWidth / logicalSize.width
        let scaleY = pixelHeight / logicalSize.height
        let scale = min(scaleX, scaleY)  // Should be equal for non-distorted images
        
        // Draw each annotation at scale 1.0 (annotations handle their own scaling)
        // But we need to account for the pixel scale
        for annotation in annotations {
            annotation.draw(in: context, scale: scale, state: .idle, imageSize: logicalSize)
        }
        
        // Create the final image
        guard let outputCGImage = context.makeImage() else {
            return image
        }
        
        let outputImage = NSImage(cgImage: outputCGImage, size: logicalSize)
        return outputImage
    }
    
    /// Check if rendering is needed (has annotations)
    static func needsRender(annotations: [any Annotation]) -> Bool {
        !annotations.isEmpty
    }
}
