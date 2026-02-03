import AppKit
import CoreGraphics
import QuickLook
 
/// AppKit does not reliably render SVGs via `NSImage(contentsOf:)` on all macOS versions.
/// This provides a synchronous fallback using Quick Look thumbnail rendering.
enum SVGImageFallback {
    static func image(contentsOf url: URL, maxPixelSize: CGFloat = 1024) -> NSImage? {
        if let img = NSImage(contentsOf: url) {
            return img
        }
 
        // Fallback for SVG (and other formats Quick Look can rasterize).
        let size = CGSize(width: maxPixelSize, height: maxPixelSize)
        let options: CFDictionary = [
            kQLThumbnailOptionIconModeKey: false,
        ] as CFDictionary
 
        guard let thumb = QLThumbnailImageCreate(kCFAllocatorDefault, url as CFURL, size, options)?.takeRetainedValue() else {
            return nil
        }
        return NSImage(cgImage: thumb, size: .zero)
    }
}

