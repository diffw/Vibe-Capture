import XCTest
@testable import VibeCap

final class ScreenCropConverterTests: XCTestCase {
    func testCropRectInImagePixels_BottomLeftQuarter_mapsToLowerLeftInRasterSpace() {
        let screenFrame = CGRect(x: 0, y: 0, width: 100, height: 100) // points
        let selection = CGRect(x: 0, y: 0, width: 50, height: 50) // bottom-left quarter (points)
        let scale: CGFloat = 2
        let imageSize = CGSize(width: 200, height: 200) // pixels

        let crop = ScreenCropConverter.cropRectInImagePixels(
            selectionRectInScreenPoints: selection,
            screenFrameInScreenPoints: screenFrame,
            imagePixelSize: imageSize,
            backingScaleFactor: scale
        )

        XCTAssertEqual(crop, CGRect(x: 0, y: 100, width: 100, height: 100))
    }

    func testCropRectInImagePixels_TopLeftQuarter_mapsToUpperLeftInRasterSpace() {
        let screenFrame = CGRect(x: 0, y: 0, width: 100, height: 100) // points
        let selection = CGRect(x: 0, y: 50, width: 50, height: 50) // top-left quarter (points)
        let scale: CGFloat = 2
        let imageSize = CGSize(width: 200, height: 200) // pixels

        let crop = ScreenCropConverter.cropRectInImagePixels(
            selectionRectInScreenPoints: selection,
            screenFrameInScreenPoints: screenFrame,
            imagePixelSize: imageSize,
            backingScaleFactor: scale
        )

        XCTAssertEqual(crop, CGRect(x: 0, y: 0, width: 100, height: 100))
    }

    func testCropRectInImagePixels_AppliesScreenOriginOffset() {
        let screenFrame = CGRect(x: 100, y: 200, width: 100, height: 100) // points
        let selection = CGRect(x: 110, y: 210, width: 10, height: 20) // points (global)
        let scale: CGFloat = 2
        let imageSize = CGSize(width: 200, height: 200) // pixels

        let crop = ScreenCropConverter.cropRectInImagePixels(
            selectionRectInScreenPoints: selection,
            screenFrameInScreenPoints: screenFrame,
            imagePixelSize: imageSize,
            backingScaleFactor: scale
        )

        // localPt = (10, 10, 10, 20) -> px = (20, 20, 20, 40) -> yFlip = 200 - (20+40) = 140
        XCTAssertEqual(crop, CGRect(x: 20, y: 140, width: 20, height: 40))
    }

    func testCropRectInImagePixels_ReturnsNilWhenSelectionIsEmptyOrOffscreen() {
        let screenFrame = CGRect(x: 0, y: 0, width: 100, height: 100)
        let scale: CGFloat = 2
        let imageSize = CGSize(width: 200, height: 200)

        XCTAssertNil(ScreenCropConverter.cropRectInImagePixels(
            selectionRectInScreenPoints: CGRect(x: 0, y: 0, width: 0, height: 10),
            screenFrameInScreenPoints: screenFrame,
            imagePixelSize: imageSize,
            backingScaleFactor: scale
        ))

        XCTAssertNil(ScreenCropConverter.cropRectInImagePixels(
            selectionRectInScreenPoints: CGRect(x: -1000, y: -1000, width: 10, height: 10),
            screenFrameInScreenPoints: screenFrame,
            imagePixelSize: imageSize,
            backingScaleFactor: scale
        ))
    }
}

