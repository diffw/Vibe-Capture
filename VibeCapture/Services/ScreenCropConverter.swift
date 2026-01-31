import CoreGraphics

enum ScreenCropConverter {
    /// Converts a selection rect expressed in **global screen points** (Cocoa, origin bottom-left)
    /// into a crop rect expressed in **image pixels** suitable for `CGImage.cropping(to:)`
    /// (raster space, origin top-left, y increasing downward).
    ///
    /// - Parameters:
    ///   - selectionRectInScreenPoints: The selection rect in global screen coordinates (points).
    ///   - screenFrameInScreenPoints: The frame of the selected screen in global screen coordinates (points).
    ///   - imagePixelSize: The pixel size of the full-screen snapshot image for that screen.
    ///   - backingScaleFactor: The scale factor of the selected screen.
    ///
    /// - Returns: A clamped, pixel-aligned crop rect in image pixel coordinates, or nil if invalid.
    static func cropRectInImagePixels(
        selectionRectInScreenPoints: CGRect,
        screenFrameInScreenPoints: CGRect,
        imagePixelSize: CGSize,
        backingScaleFactor: CGFloat
    ) -> CGRect? {
        guard backingScaleFactor.isFinite, backingScaleFactor > 0 else { return nil }
        guard imagePixelSize.width.isFinite, imagePixelSize.height.isFinite,
              imagePixelSize.width > 0, imagePixelSize.height > 0 else { return nil }
        guard selectionRectInScreenPoints.width > 0, selectionRectInScreenPoints.height > 0 else { return nil }

        // Convert from global screen points to screen-local points (origin bottom-left of the screen).
        let localPt = selectionRectInScreenPoints.offsetBy(
            dx: -screenFrameInScreenPoints.origin.x,
            dy: -screenFrameInScreenPoints.origin.y
        )

        // Convert points -> pixels.
        let px = CGRect(
            x: localPt.origin.x * backingScaleFactor,
            y: localPt.origin.y * backingScaleFactor,
            width: localPt.size.width * backingScaleFactor,
            height: localPt.size.height * backingScaleFactor
        )

        // Flip Y: Cocoa (bottom-left) -> raster/top-left (for CGImage.cropping on macOS).
        let flippedY = imagePixelSize.height - (px.origin.y + px.size.height)
        var crop = CGRect(x: px.origin.x, y: flippedY, width: px.size.width, height: px.size.height)

        // Pixel-align to avoid half-pixel edges.
        crop = CGRect(
            x: floor(crop.origin.x),
            y: floor(crop.origin.y),
            width: ceil(crop.size.width),
            height: ceil(crop.size.height)
        )

        // Clamp to image bounds.
        let bounds = CGRect(origin: .zero, size: imagePixelSize)
        crop = crop.intersection(bounds)

        guard crop.width >= 1, crop.height >= 1 else { return nil }
        return crop
    }
}

