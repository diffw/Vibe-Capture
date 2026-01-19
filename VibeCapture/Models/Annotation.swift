import AppKit

// MARK: - Annotation Color

enum AnnotationColor: Int, CaseIterable {
    case red = 0
    case orange
    case yellow
    case green
    case blue
    case purple
    
    var nsColor: NSColor {
        switch self {
        case .red:    return NSColor(red: 1.0, green: 0.231, blue: 0.188, alpha: 1.0)    // #FF3B30
        case .orange: return NSColor(red: 1.0, green: 0.584, blue: 0.0, alpha: 1.0)      // #FF9500
        case .yellow: return NSColor(red: 1.0, green: 0.8, blue: 0.0, alpha: 1.0)        // #FFCC00
        case .green:  return NSColor(red: 0.204, green: 0.78, blue: 0.349, alpha: 1.0)   // #34C759
        case .blue:   return NSColor(red: 0.0, green: 0.478, blue: 1.0, alpha: 1.0)      // #007AFF
        case .purple: return NSColor(red: 0.686, green: 0.322, blue: 0.871, alpha: 1.0)  // #AF52DE
        }
    }
    
    var displayName: String {
        switch self {
        case .red:    return "Red"
        case .orange: return "Orange"
        case .yellow: return "Yellow"
        case .green:  return "Green"
        case .blue:   return "Blue"
        case .purple: return "Purple"
        }
    }
}

// MARK: - Annotation State

enum AnnotationState {
    case idle
    case hover
    case selected
    case creating
    case dragging
}

// MARK: - Annotation Tool

enum AnnotationTool: Equatable {
    case none
    case arrow
    case circle
    case rectangle
    case number
}

// MARK: - Annotation Protocol

protocol Annotation: AnyObject {
    var id: UUID { get }
    var color: AnnotationColor { get }
    
    /// Check if a point (in image coordinates) hits this annotation
    /// - Parameters:
    ///   - point: Point in original image coordinate space
    ///   - tolerance: Hit area expansion in image coordinates
    func contains(point: CGPoint, tolerance: CGFloat) -> Bool
    
    /// Create a copy translated by the given delta
    func translated(by delta: CGPoint) -> Self
    
    /// Draw the annotation in the given context
    /// - Parameters:
    ///   - context: Graphics context to draw in
    ///   - scale: Scale factor from image to display coordinates
    ///   - state: Current visual state of the annotation
    ///   - imageSize: Original image size (for calculating adaptive stroke width)
    func draw(in context: CGContext, scale: CGFloat, state: AnnotationState, imageSize: CGSize)
    
    /// Calculate adaptive stroke width based on image size
    static func adaptiveStrokeWidth(for imageSize: CGSize) -> CGFloat
}

// MARK: - Arrow Annotation

final class ArrowAnnotation: Annotation {
    let id: UUID
    let startPoint: CGPoint  // Tail (in original image coordinates)
    let endPoint: CGPoint    // Head (in original image coordinates)
    let color: AnnotationColor
    
    // Fixed stroke width (4px)
    private static let strokeWidth: CGFloat = 4.0
    private static let arrowHeadLength: CGFloat = 14.0  // 4 * 3.5
    private static let arrowHeadAngle: CGFloat = .pi / 6  // 30 degrees
    
    /// Fixed stroke width for all images
    static func adaptiveStrokeWidth(for imageSize: CGSize) -> CGFloat {
        return strokeWidth
    }
    
    init(id: UUID = UUID(), startPoint: CGPoint, endPoint: CGPoint, color: AnnotationColor) {
        self.id = id
        self.startPoint = startPoint
        self.endPoint = endPoint
        self.color = color
    }
    
    var length: CGFloat {
        hypot(endPoint.x - startPoint.x, endPoint.y - startPoint.y)
    }
    
    func contains(point: CGPoint, tolerance: CGFloat) -> Bool {
        // Calculate distance from point to line segment
        let lineLength = length
        guard lineLength > 0 else { return false }
        
        let dx = endPoint.x - startPoint.x
        let dy = endPoint.y - startPoint.y
        
        // Parameter t represents position along line (0 = start, 1 = end)
        let t = max(0, min(1, ((point.x - startPoint.x) * dx + (point.y - startPoint.y) * dy) / (lineLength * lineLength)))
        
        // Closest point on line segment
        let closestX = startPoint.x + t * dx
        let closestY = startPoint.y + t * dy
        
        let distance = hypot(point.x - closestX, point.y - closestY)
        // Use a reasonable stroke width for hit testing
        return distance <= (Self.strokeWidth / 2 + tolerance)
    }
    
    func translated(by delta: CGPoint) -> ArrowAnnotation {
        ArrowAnnotation(
            id: id,
            startPoint: CGPoint(x: startPoint.x + delta.x, y: startPoint.y + delta.y),
            endPoint: CGPoint(x: endPoint.x + delta.x, y: endPoint.y + delta.y),
            color: color
        )
    }
    
    func draw(in context: CGContext, scale: CGFloat, state: AnnotationState, imageSize: CGSize) {
        let scaledStart = CGPoint(x: startPoint.x * scale, y: startPoint.y * scale)
        let scaledEnd = CGPoint(x: endPoint.x * scale, y: endPoint.y * scale)
        
        // Fixed stroke width in screen pixels (not scaled with image)
        let scaledStrokeWidth = Self.strokeWidth
        let scaledHeadLength = Self.arrowHeadLength
        
        context.saveGState()
        
        // Apply state-based styling
        var strokeWidth = scaledStrokeWidth
        let baseColor = color.nsColor
        
        switch state {
        case .hover:
            strokeWidth += 2  // Fixed increase in screen pixels
        case .selected, .dragging, .idle, .creating:
            break
        }
        
        context.setStrokeColor(baseColor.cgColor)
        context.setFillColor(baseColor.cgColor)
        context.setLineWidth(strokeWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        
        // Calculate arrow head first (we need this to know where to stop the line)
        let angle = atan2(scaledEnd.y - scaledStart.y, scaledEnd.x - scaledStart.x)
        
        // Arrow head points
        let arrowPoint1 = CGPoint(
            x: scaledEnd.x - scaledHeadLength * cos(angle - Self.arrowHeadAngle),
            y: scaledEnd.y - scaledHeadLength * sin(angle - Self.arrowHeadAngle)
        )
        let arrowPoint2 = CGPoint(
            x: scaledEnd.x - scaledHeadLength * cos(angle + Self.arrowHeadAngle),
            y: scaledEnd.y - scaledHeadLength * sin(angle + Self.arrowHeadAngle)
        )
        
        // Calculate where the line should stop (at the base of the arrow head)
        let lineEndPoint = CGPoint(
            x: (arrowPoint1.x + arrowPoint2.x) / 2,
            y: (arrowPoint1.y + arrowPoint2.y) / 2
        )
        
        // Draw line (stop at arrow head base, not at the tip)
        context.move(to: scaledStart)
        context.addLine(to: lineEndPoint)
        context.strokePath()
        
        // Draw arrow head as filled triangle
        context.move(to: scaledEnd)
        context.addLine(to: arrowPoint1)
        context.addLine(to: arrowPoint2)
        context.closePath()
        context.fillPath()
        
        context.restoreGState()
        
        // Draw selection handles for selected/dragging state
        if state == .selected || state == .dragging {
            drawSelectionHandles(context: context, scale: scale, start: scaledStart, end: scaledEnd)
        }
    }
    
    private func drawSelectionHandles(context: CGContext, scale: CGFloat, start: CGPoint, end: CGPoint) {
        let handleRadius: CGFloat = 5  // Fixed size in screen pixels
        let handleColor = NSColor.systemBlue
        let handleBorderColor = NSColor.white
        
        context.saveGState()
        
        let handles = [start, end]
        
        for handle in handles {
            // White border
            context.setFillColor(handleBorderColor.cgColor)
            context.fillEllipse(in: CGRect(
                x: handle.x - handleRadius - 1,
                y: handle.y - handleRadius - 1,
                width: (handleRadius + 1) * 2,
                height: (handleRadius + 1) * 2
            ))
            
            // Blue fill
            context.setFillColor(handleColor.cgColor)
            context.fillEllipse(in: CGRect(
                x: handle.x - handleRadius,
                y: handle.y - handleRadius,
                width: handleRadius * 2,
                height: handleRadius * 2
            ))
        }
        
        context.restoreGState()
    }
}

// MARK: - Circle (Ellipse) Annotation

final class CircleAnnotation: Annotation {
    let id: UUID
    let rect: CGRect  // Bounding rect in original image coordinates
    let color: AnnotationColor
    
    // Fixed stroke width (4px)
    private static let strokeWidth: CGFloat = 4.0
    
    /// Fixed stroke width for all images
    static func adaptiveStrokeWidth(for imageSize: CGSize) -> CGFloat {
        return strokeWidth
    }
    
    init(id: UUID = UUID(), rect: CGRect, color: AnnotationColor) {
        self.id = id
        self.rect = rect
        self.color = color
    }
    
    /// Create from two corner points (handles any drag direction)
    convenience init(id: UUID = UUID(), from point1: CGPoint, to point2: CGPoint, color: AnnotationColor) {
        let rect = CGRect(
            x: min(point1.x, point2.x),
            y: min(point1.y, point2.y),
            width: abs(point2.x - point1.x),
            height: abs(point2.y - point1.y)
        )
        self.init(id: id, rect: rect, color: color)
    }
    
    func contains(point: CGPoint, tolerance: CGFloat) -> Bool {
        // Check if point is near the ellipse stroke
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let a = rect.width / 2  // Semi-major axis
        let b = rect.height / 2  // Semi-minor axis
        
        guard a > 0 && b > 0 else { return false }
        
        // Normalized distance from center (1.0 = on ellipse)
        let dx = point.x - center.x
        let dy = point.y - center.y
        let normalizedDist = sqrt((dx * dx) / (a * a) + (dy * dy) / (b * b))
        
        // Check if within stroke width + tolerance
        let strokeRadius = Self.strokeWidth / 2
        let innerThreshold = max(0, 1 - (strokeRadius + tolerance) / min(a, b))
        let outerThreshold = 1 + (strokeRadius + tolerance) / min(a, b)
        
        return normalizedDist >= innerThreshold && normalizedDist <= outerThreshold
    }
    
    func translated(by delta: CGPoint) -> CircleAnnotation {
        CircleAnnotation(
            id: id,
            rect: rect.offsetBy(dx: delta.x, dy: delta.y),
            color: color
        )
    }
    
    func draw(in context: CGContext, scale: CGFloat, state: AnnotationState, imageSize: CGSize) {
        let scaledRect = CGRect(
            x: rect.origin.x * scale,
            y: rect.origin.y * scale,
            width: rect.width * scale,
            height: rect.height * scale
        )
        
        // Fixed stroke width in screen pixels (not scaled with image)
        let scaledStrokeWidth = Self.strokeWidth
        
        context.saveGState()
        
        // Apply state-based styling
        var strokeWidth = scaledStrokeWidth
        let baseColor = color.nsColor
        
        switch state {
        case .hover:
            strokeWidth += 2  // Fixed increase in screen pixels
        case .selected, .dragging, .idle, .creating:
            break
        }
        
        context.setStrokeColor(baseColor.cgColor)
        context.setLineWidth(strokeWidth)
        
        // Draw ellipse
        context.strokeEllipse(in: scaledRect)
        
        context.restoreGState()
        
        // Draw selection handles for selected/dragging state
        if state == .selected || state == .dragging {
            drawSelectionHandles(context: context, scale: scale, rect: scaledRect)
        }
    }
    
    private func drawSelectionHandles(context: CGContext, scale: CGFloat, rect: CGRect) {
        let handleRadius: CGFloat = 5  // Fixed size in screen pixels
        let handleColor = NSColor.systemBlue
        let handleBorderColor = NSColor.white
        
        context.saveGState()
        
        // 8 handles: 4 corners + 4 edge midpoints
        let handles: [CGPoint] = [
            // Corners
            CGPoint(x: rect.minX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.minX, y: rect.maxY),
            CGPoint(x: rect.maxX, y: rect.maxY),
            // Edge midpoints
            CGPoint(x: rect.midX, y: rect.minY),
            CGPoint(x: rect.midX, y: rect.maxY),
            CGPoint(x: rect.minX, y: rect.midY),
            CGPoint(x: rect.maxX, y: rect.midY),
        ]
        
        for handle in handles {
            // White border
            context.setFillColor(handleBorderColor.cgColor)
            context.fillEllipse(in: CGRect(
                x: handle.x - handleRadius - 1,
                y: handle.y - handleRadius - 1,
                width: (handleRadius + 1) * 2,
                height: (handleRadius + 1) * 2
            ))
            
            // Blue fill
            context.setFillColor(handleColor.cgColor)
            context.fillEllipse(in: CGRect(
                x: handle.x - handleRadius,
                y: handle.y - handleRadius,
                width: handleRadius * 2,
                height: handleRadius * 2
            ))
        }
        
        context.restoreGState()
    }
}

// MARK: - Rectangle Annotation

final class RectangleAnnotation: Annotation {
    let id: UUID
    let rect: CGRect  // Bounding rect in original image coordinates
    let color: AnnotationColor
    
    // Fixed stroke width (4px)
    private static let strokeWidth: CGFloat = 4.0
    
    /// Fixed stroke width for all images
    static func adaptiveStrokeWidth(for imageSize: CGSize) -> CGFloat {
        return strokeWidth
    }
    
    init(id: UUID = UUID(), rect: CGRect, color: AnnotationColor) {
        self.id = id
        self.rect = rect
        self.color = color
    }
    
    /// Create from two corner points (handles any drag direction)
    convenience init(id: UUID = UUID(), from point1: CGPoint, to point2: CGPoint, color: AnnotationColor) {
        let rect = CGRect(
            x: min(point1.x, point2.x),
            y: min(point1.y, point2.y),
            width: abs(point2.x - point1.x),
            height: abs(point2.y - point1.y)
        )
        self.init(id: id, rect: rect, color: color)
    }
    
    func contains(point: CGPoint, tolerance: CGFloat) -> Bool {
        // Check if point is near any edge of the rectangle
        let strokeRadius = Self.strokeWidth / 2
        let innerRect = rect.insetBy(dx: strokeRadius + tolerance, dy: strokeRadius + tolerance)
        let outerRect = rect.insetBy(dx: -(strokeRadius + tolerance), dy: -(strokeRadius + tolerance))
        
        // Point must be inside outer rect but outside inner rect (on the stroke)
        return outerRect.contains(point) && !innerRect.contains(point)
    }
    
    func translated(by delta: CGPoint) -> RectangleAnnotation {
        RectangleAnnotation(
            id: id,
            rect: rect.offsetBy(dx: delta.x, dy: delta.y),
            color: color
        )
    }
    
    func draw(in context: CGContext, scale: CGFloat, state: AnnotationState, imageSize: CGSize) {
        let scaledRect = CGRect(
            x: rect.origin.x * scale,
            y: rect.origin.y * scale,
            width: rect.width * scale,
            height: rect.height * scale
        )
        
        // Fixed stroke width in screen pixels (not scaled with image)
        let scaledStrokeWidth = Self.strokeWidth
        
        context.saveGState()
        
        // Apply state-based styling
        var strokeWidth = scaledStrokeWidth
        let baseColor = color.nsColor
        
        switch state {
        case .hover:
            strokeWidth += 2  // Fixed increase in screen pixels
        case .selected, .dragging, .idle, .creating:
            break
        }
        
        context.setStrokeColor(baseColor.cgColor)
        context.setLineWidth(strokeWidth)
        
        // Draw rectangle
        context.stroke(scaledRect)
        
        context.restoreGState()
        
        // Draw selection handles for selected/dragging state
        if state == .selected || state == .dragging {
            drawSelectionHandles(context: context, scale: scale, rect: scaledRect)
        }
    }
    
    private func drawSelectionHandles(context: CGContext, scale: CGFloat, rect: CGRect) {
        let handleRadius: CGFloat = 5  // Fixed size in screen pixels
        let handleColor = NSColor.systemBlue
        let handleBorderColor = NSColor.white
        
        context.saveGState()
        
        // 8 handles: 4 corners + 4 edge midpoints
        let handles: [CGPoint] = [
            // Corners
            CGPoint(x: rect.minX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.minX, y: rect.maxY),
            CGPoint(x: rect.maxX, y: rect.maxY),
            // Edge midpoints
            CGPoint(x: rect.midX, y: rect.minY),
            CGPoint(x: rect.midX, y: rect.maxY),
            CGPoint(x: rect.minX, y: rect.midY),
            CGPoint(x: rect.maxX, y: rect.midY),
        ]
        
        for handle in handles {
            // White border
            context.setFillColor(handleBorderColor.cgColor)
            context.fillEllipse(in: CGRect(
                x: handle.x - handleRadius - 1,
                y: handle.y - handleRadius - 1,
                width: (handleRadius + 1) * 2,
                height: (handleRadius + 1) * 2
            ))
            
            // Blue fill
            context.setFillColor(handleColor.cgColor)
            context.fillEllipse(in: CGRect(
                x: handle.x - handleRadius,
                y: handle.y - handleRadius,
                width: handleRadius * 2,
                height: handleRadius * 2
            ))
        }
        
        context.restoreGState()
    }
}

// MARK: - Number Annotation

final class NumberAnnotation: Annotation {
    let id: UUID
    let center: CGPoint  // Center point in original image coordinates
    var number: Int      // Mutable for renumbering
    let color: AnnotationColor
    
    // Fixed diameter (24px in screen pixels)
    static let diameter: CGFloat = 24.0
    
    /// Fixed stroke width (not used, but required by protocol)
    static func adaptiveStrokeWidth(for imageSize: CGSize) -> CGFloat {
        return 0
    }
    
    init(id: UUID = UUID(), center: CGPoint, number: Int, color: AnnotationColor) {
        self.id = id
        self.center = center
        self.number = number
        self.color = color
    }
    
    func contains(point: CGPoint, tolerance: CGFloat) -> Bool {
        // Simple circle hit test
        let distance = hypot(point.x - center.x, point.y - center.y)
        // Use half diameter + tolerance for hit area
        return distance <= (Self.diameter / 2 + tolerance)
    }
    
    func translated(by delta: CGPoint) -> NumberAnnotation {
        NumberAnnotation(
            id: id,
            center: CGPoint(x: center.x + delta.x, y: center.y + delta.y),
            number: number,
            color: color
        )
    }
    
    func draw(in context: CGContext, scale: CGFloat, state: AnnotationState, imageSize: CGSize) {
        let scaledCenter = CGPoint(x: center.x * scale, y: center.y * scale)
        
        // Fixed diameter in screen pixels
        var currentDiameter = Self.diameter
        
        // Slightly larger on hover
        if state == .hover {
            currentDiameter += 4
        }
        
        let currentRadius = currentDiameter / 2
        
        context.saveGState()
        
        let baseColor = color.nsColor
        
        // Draw filled circle background
        context.setFillColor(baseColor.cgColor)
        context.fillEllipse(in: CGRect(
            x: scaledCenter.x - currentRadius,
            y: scaledCenter.y - currentRadius,
            width: currentDiameter,
            height: currentDiameter
        ))
        
        // Draw white number text
        let text = "\(number)" as NSString
        let fontSize: CGFloat = currentDiameter * 0.6  // 60% of diameter
        let font = NSFont.systemFont(ofSize: fontSize, weight: .bold)
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white
        ]
        
        let textSize = text.size(withAttributes: attributes)
        let textRect = CGRect(
            x: scaledCenter.x - textSize.width / 2,
            y: scaledCenter.y - textSize.height / 2,
            width: textSize.width,
            height: textSize.height
        )
        
        // Draw text using NSString (need to flip context for text)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        text.draw(in: textRect, withAttributes: attributes)
        NSGraphicsContext.restoreGraphicsState()
        
        context.restoreGState()
        
        // Draw selection ring for selected state
        if state == .selected || state == .dragging {
            drawSelectionRing(context: context, center: scaledCenter, radius: currentRadius)
        }
    }
    
    private func drawSelectionRing(context: CGContext, center: CGPoint, radius: CGFloat) {
        let ringRadius = radius + 4
        let handleColor = NSColor.systemBlue
        
        context.saveGState()
        
        context.setStrokeColor(handleColor.cgColor)
        context.setLineWidth(2)
        context.strokeEllipse(in: CGRect(
            x: center.x - ringRadius,
            y: center.y - ringRadius,
            width: ringRadius * 2,
            height: ringRadius * 2
        ))
        
        context.restoreGState()
    }
}

// MARK: - Numbered Arrow Annotation

final class NumberedArrowAnnotation: Annotation {
    let id: UUID
    let startPoint: CGPoint  // Where the number is (tail of arrow)
    let endPoint: CGPoint    // Where the arrow points to (head)
    var number: Int          // Mutable for renumbering
    let color: AnnotationColor
    
    // Fixed dimensions
    static let numberDiameter: CGFloat = 24.0
    private static let strokeWidth: CGFloat = 4.0
    private static let arrowHeadLength: CGFloat = 14.0
    private static let arrowHeadAngle: CGFloat = .pi / 6
    
    static func adaptiveStrokeWidth(for imageSize: CGSize) -> CGFloat {
        return strokeWidth
    }
    
    init(id: UUID = UUID(), startPoint: CGPoint, endPoint: CGPoint, number: Int, color: AnnotationColor) {
        self.id = id
        self.startPoint = startPoint
        self.endPoint = endPoint
        self.number = number
        self.color = color
    }
    
    var length: CGFloat {
        hypot(endPoint.x - startPoint.x, endPoint.y - startPoint.y)
    }
    
    func contains(point: CGPoint, tolerance: CGFloat) -> Bool {
        // Check if point hits the number circle
        let distanceToNumber = hypot(point.x - startPoint.x, point.y - startPoint.y)
        if distanceToNumber <= (Self.numberDiameter / 2 + tolerance) {
            return true
        }
        
        // Check if point hits the arrow line
        let lineLength = length
        guard lineLength > 0 else { return false }
        
        let dx = endPoint.x - startPoint.x
        let dy = endPoint.y - startPoint.y
        
        let t = max(0, min(1, ((point.x - startPoint.x) * dx + (point.y - startPoint.y) * dy) / (lineLength * lineLength)))
        
        let closestX = startPoint.x + t * dx
        let closestY = startPoint.y + t * dy
        
        let distance = hypot(point.x - closestX, point.y - closestY)
        return distance <= (Self.strokeWidth / 2 + tolerance)
    }
    
    func translated(by delta: CGPoint) -> NumberedArrowAnnotation {
        NumberedArrowAnnotation(
            id: id,
            startPoint: CGPoint(x: startPoint.x + delta.x, y: startPoint.y + delta.y),
            endPoint: CGPoint(x: endPoint.x + delta.x, y: endPoint.y + delta.y),
            number: number,
            color: color
        )
    }
    
    func draw(in context: CGContext, scale: CGFloat, state: AnnotationState, imageSize: CGSize) {
        let scaledStart = CGPoint(x: startPoint.x * scale, y: startPoint.y * scale)
        let scaledEnd = CGPoint(x: endPoint.x * scale, y: endPoint.y * scale)
        
        let baseColor = color.nsColor
        var strokeWidth = Self.strokeWidth
        var numberDiameter = Self.numberDiameter
        
        if state == .hover {
            strokeWidth += 2
            numberDiameter += 4
        }
        
        let numberRadius = numberDiameter / 2
        
        context.saveGState()
        
        // Calculate arrow direction
        let angle = atan2(scaledEnd.y - scaledStart.y, scaledEnd.x - scaledStart.x)
        
        // Arrow line starts from the edge of the number circle
        let lineStart = CGPoint(
            x: scaledStart.x + numberRadius * cos(angle),
            y: scaledStart.y + numberRadius * sin(angle)
        )
        
        // Arrow head points
        let arrowPoint1 = CGPoint(
            x: scaledEnd.x - Self.arrowHeadLength * cos(angle - Self.arrowHeadAngle),
            y: scaledEnd.y - Self.arrowHeadLength * sin(angle - Self.arrowHeadAngle)
        )
        let arrowPoint2 = CGPoint(
            x: scaledEnd.x - Self.arrowHeadLength * cos(angle + Self.arrowHeadAngle),
            y: scaledEnd.y - Self.arrowHeadLength * sin(angle + Self.arrowHeadAngle)
        )
        
        // Line end point (at base of arrow head)
        let lineEnd = CGPoint(
            x: (arrowPoint1.x + arrowPoint2.x) / 2,
            y: (arrowPoint1.y + arrowPoint2.y) / 2
        )
        
        // Draw arrow line
        context.setStrokeColor(baseColor.cgColor)
        context.setLineWidth(strokeWidth)
        context.setLineCap(.round)
        context.move(to: lineStart)
        context.addLine(to: lineEnd)
        context.strokePath()
        
        // Draw arrow head
        context.setFillColor(baseColor.cgColor)
        context.move(to: scaledEnd)
        context.addLine(to: arrowPoint1)
        context.addLine(to: arrowPoint2)
        context.closePath()
        context.fillPath()
        
        // Draw number circle
        context.setFillColor(baseColor.cgColor)
        context.fillEllipse(in: CGRect(
            x: scaledStart.x - numberRadius,
            y: scaledStart.y - numberRadius,
            width: numberDiameter,
            height: numberDiameter
        ))
        
        // Draw white number text
        let text = "\(number)" as NSString
        let fontSize: CGFloat = numberDiameter * 0.6
        let font = NSFont.systemFont(ofSize: fontSize, weight: .bold)
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white
        ]
        
        let textSize = text.size(withAttributes: attributes)
        let textRect = CGRect(
            x: scaledStart.x - textSize.width / 2,
            y: scaledStart.y - textSize.height / 2,
            width: textSize.width,
            height: textSize.height
        )
        
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        text.draw(in: textRect, withAttributes: attributes)
        NSGraphicsContext.restoreGraphicsState()
        
        context.restoreGState()
        
        // Draw selection handles
        if state == .selected || state == .dragging {
            drawSelectionHandles(context: context, start: scaledStart, end: scaledEnd, numberRadius: numberRadius)
        }
    }
    
    private func drawSelectionHandles(context: CGContext, start: CGPoint, end: CGPoint, numberRadius: CGFloat) {
        let handleRadius: CGFloat = 5
        let handleColor = NSColor.systemBlue
        let handleBorderColor = NSColor.white
        
        context.saveGState()
        
        // Handle at arrow end only (start has the number circle as visual indicator)
        let handles = [end]
        
        for handle in handles {
            context.setFillColor(handleBorderColor.cgColor)
            context.fillEllipse(in: CGRect(
                x: handle.x - handleRadius - 1,
                y: handle.y - handleRadius - 1,
                width: (handleRadius + 1) * 2,
                height: (handleRadius + 1) * 2
            ))
            
            context.setFillColor(handleColor.cgColor)
            context.fillEllipse(in: CGRect(
                x: handle.x - handleRadius,
                y: handle.y - handleRadius,
                width: handleRadius * 2,
                height: handleRadius * 2
            ))
        }
        
        // Draw selection ring around number
        let ringRadius = numberRadius + 4
        context.setStrokeColor(handleColor.cgColor)
        context.setLineWidth(2)
        context.strokeEllipse(in: CGRect(
            x: start.x - ringRadius,
            y: start.y - ringRadius,
            width: ringRadius * 2,
            height: ringRadius * 2
        ))
        
        context.restoreGState()
    }
}
