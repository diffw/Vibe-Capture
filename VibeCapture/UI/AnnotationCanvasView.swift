import AppKit

/// Delegate protocol for annotation canvas events
protocol AnnotationCanvasViewDelegate: AnyObject {
    func annotationCanvasDidChangeAnnotations(_ canvas: AnnotationCanvasView)
}

/// View that handles annotation drawing and interaction
/// Overlays the screenshot image and manages all annotation state
final class AnnotationCanvasView: NSView {
    
    weak var delegate: AnnotationCanvasViewDelegate?
    
    // MARK: - Properties
    
    /// Original image size (for coordinate conversion)
    var imageSize: CGSize = .zero {
        didSet { needsDisplay = true }
    }
    
    /// Current tool selected in toolbar
    var currentTool: AnnotationTool = .none {
        didSet {
            updateCursor()
            // Deselect when switching to a drawing tool
            if currentTool != .none {
                selectedAnnotationId = nil
                needsDisplay = true
            }
        }
    }
    
    /// Current color for new annotations
    var currentColor: AnnotationColor = .red
    
    /// All annotations
    private(set) var annotations: [any Annotation] = []
    
    /// Currently selected annotation ID
    private(set) var selectedAnnotationId: UUID?
    
    /// Currently hovered annotation ID
    private var hoveredAnnotationId: UUID?
    
    // MARK: - Interaction State
    
    private enum InteractionState {
        case idle
        case creating(startPoint: CGPoint, currentPoint: CGPoint)
        case dragging(annotation: any Annotation, startMousePoint: CGPoint, originalPosition: CGPoint)
        case resizingArrow(arrow: ArrowAnnotation, handle: ArrowHandle, otherEnd: CGPoint)
        case resizingCircle(circle: CircleAnnotation, handle: CircleHandle, originalRect: CGRect)
        case resizingRectangle(rectangle: RectangleAnnotation, handle: RectHandle, originalRect: CGRect)
        case resizingNumberedArrow(numberedArrow: NumberedArrowAnnotation, handle: NumberedArrowHandle, otherEnd: CGPoint)
        // For number tool: pending click vs drag detection
        case pendingNumberCreation(startPoint: CGPoint, startViewPoint: CGPoint)
        case creatingNumberedArrow(startPoint: CGPoint, currentPoint: CGPoint)
    }
    
    /// Which end of an arrow is being dragged
    enum ArrowHandle {
        case start
        case end
    }
    
    /// Which handle of a circle is being dragged
    enum CircleHandle {
        // Corner handles (proportional scaling)
        case topLeft, topRight, bottomLeft, bottomRight
        // Edge handles (single axis)
        case top, bottom, left, right
        
        var isCorner: Bool {
            switch self {
            case .topLeft, .topRight, .bottomLeft, .bottomRight:
                return true
            default:
                return false
            }
        }
    }
    
    /// Which handle of a rectangle is being dragged (same as circle)
    enum RectHandle {
        case topLeft, topRight, bottomLeft, bottomRight
        case top, bottom, left, right
    }
    
    /// Which end of a numbered arrow is being dragged
    enum NumberedArrowHandle {
        case start  // Number end
        case end    // Arrow head end
    }
    
    private var interactionState: InteractionState = .idle
    
    /// Threshold for distinguishing click from drag (in view pixels)
    private let dragThreshold: CGFloat = 5.0
    
    /// Hit area tolerance in display coordinates
    private let hitTolerance: CGFloat = 8.0
    
    /// Handle hit area radius in display coordinates
    private let handleHitRadius: CGFloat = 10.0
    
    // MARK: - Computed Properties
    
    /// Prevent window drag when tool is selected or annotation is selected
    override var mouseDownCanMoveWindow: Bool {
        return false  // Never allow window drag from canvas
    }
    
    /// Scale factor from image coordinates to view coordinates
    private var scale: CGFloat {
        guard imageSize.width > 0 && imageSize.height > 0 else { return 1 }
        let scaleX = bounds.width / imageSize.width
        let scaleY = bounds.height / imageSize.height
        return min(scaleX, scaleY)
    }
    
    /// Offset to center the image in the view
    private var imageOffset: CGPoint {
        let scaledWidth = imageSize.width * scale
        let scaledHeight = imageSize.height * scale
        return CGPoint(
            x: (bounds.width - scaledWidth) / 2,
            y: (bounds.height - scaledHeight) / 2
        )
    }
    
    var hasAnnotations: Bool {
        !annotations.isEmpty
    }
    
    // MARK: - Initialization
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        
        // Enable mouse tracking for hover effects
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }
    
    // MARK: - Debug Logging
    
    private func log(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        print("[AnnotationCanvas \(timestamp)] \(message)")
    }
    
    // MARK: - Keyboard Events
    
    override var acceptsFirstResponder: Bool {
        log("acceptsFirstResponder called, returning: true")
        return true
    }
    
    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        log("becomeFirstResponder called, result: \(result)")
        return result
    }
    
    override func resignFirstResponder() -> Bool {
        let result = super.resignFirstResponder()
        log("resignFirstResponder called, result: \(result)")
        return result
    }
    
    override func keyDown(with event: NSEvent) {
        // Delete or Backspace to delete selected annotation
        if event.keyCode == 51 || event.keyCode == 117 {  // Backspace or Forward Delete
            if selectedAnnotationId != nil {
                deleteSelected()
                return
            }
        }
        // ESC to cancel creation or deselect
        if event.keyCode == 53 {  // ESC
            if case .creating = interactionState {
                cancelCreation()
                return
            }
            if selectedAnnotationId != nil {
                selectedAnnotationId = nil
                needsDisplay = true
                return
            }
        }
        super.keyDown(with: event)
    }
    
    // MARK: - Public Methods
    
    /// Clear all annotations
    func clearAll() {
        annotations.removeAll()
        selectedAnnotationId = nil
        hoveredAnnotationId = nil
        interactionState = .idle
        needsDisplay = true
        delegate?.annotationCanvasDidChangeAnnotations(self)
    }
    
    /// Delete the currently selected annotation
    func deleteSelected() {
        guard let selectedId = selectedAnnotationId else { return }
        annotations.removeAll { $0.id == selectedId }
        selectedAnnotationId = nil
        renumberAnnotations()  // Renumber after deletion
        needsDisplay = true
        delegate?.annotationCanvasDidChangeAnnotations(self)
    }
    
    /// Renumber all number-based annotations sequentially (1, 2, 3...)
    private func renumberAnnotations() {
        var nextNumber = 1
        for annotation in annotations {
            if let numberAnnotation = annotation as? NumberAnnotation {
                numberAnnotation.number = nextNumber
                nextNumber += 1
            } else if let numberedArrow = annotation as? NumberedArrowAnnotation {
                numberedArrow.number = nextNumber
                nextNumber += 1
            }
        }
    }
    
    /// Get the next number value for a new number-based annotation
    private var nextNumberValue: Int {
        let count = annotations.filter { $0 is NumberAnnotation || $0 is NumberedArrowAnnotation }.count
        return count + 1
    }
    
    /// Cancel current creation in progress
    func cancelCreation() {
        if case .creating = interactionState {
            interactionState = .idle
            needsDisplay = true
        }
    }
    
    /// Get annotations for rendering/saving
    func getAnnotations() -> [any Annotation] {
        annotations
    }
    
    // MARK: - Coordinate Conversion
    
    /// Convert view coordinates to image coordinates
    private func viewToImage(_ viewPoint: CGPoint) -> CGPoint {
        let offset = imageOffset
        return CGPoint(
            x: (viewPoint.x - offset.x) / scale,
            y: (viewPoint.y - offset.y) / scale
        )
    }
    
    /// Convert image coordinates to view coordinates
    private func imageToView(_ imagePoint: CGPoint) -> CGPoint {
        let offset = imageOffset
        return CGPoint(
            x: imagePoint.x * scale + offset.x,
            y: imagePoint.y * scale + offset.y
        )
    }
    
    // MARK: - Hit Testing
    
    /// Find annotation at the given view point
    private func annotationAt(viewPoint: CGPoint) -> (any Annotation)? {
        let imagePoint = viewToImage(viewPoint)
        let toleranceInImage = hitTolerance / scale
        
        // Search from top (last added) to bottom
        for annotation in annotations.reversed() {
            if annotation.contains(point: imagePoint, tolerance: toleranceInImage) {
                return annotation
            }
        }
        return nil
    }
    
    /// Check if view point hits a handle of the selected arrow annotation
    /// Returns (arrow, handle) if hit, nil otherwise
    private func arrowHandleAt(viewPoint: CGPoint) -> (ArrowAnnotation, ArrowHandle)? {
        guard let selectedId = selectedAnnotationId,
              let arrow = annotations.first(where: { $0.id == selectedId }) as? ArrowAnnotation else {
            return nil
        }
        
        let startInView = imageToView(arrow.startPoint)
        let endInView = imageToView(arrow.endPoint)
        
        // Check if clicking on start handle
        if hypot(viewPoint.x - startInView.x, viewPoint.y - startInView.y) <= handleHitRadius {
            return (arrow, .start)
        }
        
        // Check if clicking on end handle
        if hypot(viewPoint.x - endInView.x, viewPoint.y - endInView.y) <= handleHitRadius {
            return (arrow, .end)
        }
        
        return nil
    }
    
    /// Check if view point hits a handle of the selected circle annotation
    /// Returns (circle, handle) if hit, nil otherwise
    private func circleHandleAt(viewPoint: CGPoint) -> (CircleAnnotation, CircleHandle)? {
        guard let selectedId = selectedAnnotationId,
              let circle = annotations.first(where: { $0.id == selectedId }) as? CircleAnnotation else {
            return nil
        }
        
        let rect = circle.rect
        
        // Define handles in image coordinates
        let handles: [(CGPoint, CircleHandle)] = [
            // Corners
            (CGPoint(x: rect.minX, y: rect.minY), .bottomLeft),
            (CGPoint(x: rect.maxX, y: rect.minY), .bottomRight),
            (CGPoint(x: rect.minX, y: rect.maxY), .topLeft),
            (CGPoint(x: rect.maxX, y: rect.maxY), .topRight),
            // Edge midpoints
            (CGPoint(x: rect.midX, y: rect.minY), .bottom),
            (CGPoint(x: rect.midX, y: rect.maxY), .top),
            (CGPoint(x: rect.minX, y: rect.midY), .left),
            (CGPoint(x: rect.maxX, y: rect.midY), .right),
        ]
        
        for (point, handle) in handles {
            let pointInView = imageToView(point)
            if hypot(viewPoint.x - pointInView.x, viewPoint.y - pointInView.y) <= handleHitRadius {
                return (circle, handle)
            }
        }
        
        return nil
    }
    
    /// Check if view point hits a handle of the selected rectangle annotation
    private func rectangleHandleAt(viewPoint: CGPoint) -> (RectangleAnnotation, RectHandle)? {
        guard let selectedId = selectedAnnotationId,
              let rectangle = annotations.first(where: { $0.id == selectedId }) as? RectangleAnnotation else {
            return nil
        }
        
        let rect = rectangle.rect
        
        // Define handles in image coordinates
        let handles: [(CGPoint, RectHandle)] = [
            // Corners
            (CGPoint(x: rect.minX, y: rect.minY), .bottomLeft),
            (CGPoint(x: rect.maxX, y: rect.minY), .bottomRight),
            (CGPoint(x: rect.minX, y: rect.maxY), .topLeft),
            (CGPoint(x: rect.maxX, y: rect.maxY), .topRight),
            // Edge midpoints
            (CGPoint(x: rect.midX, y: rect.minY), .bottom),
            (CGPoint(x: rect.midX, y: rect.maxY), .top),
            (CGPoint(x: rect.minX, y: rect.midY), .left),
            (CGPoint(x: rect.maxX, y: rect.midY), .right),
        ]
        
        for (point, handle) in handles {
            let pointInView = imageToView(point)
            if hypot(viewPoint.x - pointInView.x, viewPoint.y - pointInView.y) <= handleHitRadius {
                return (rectangle, handle)
            }
        }
        
        return nil
    }
    
    /// Check if view point hits a handle of the selected numbered arrow annotation
    private func numberedArrowHandleAt(viewPoint: CGPoint) -> (NumberedArrowAnnotation, NumberedArrowHandle)? {
        guard let selectedId = selectedAnnotationId,
              let numberedArrow = annotations.first(where: { $0.id == selectedId }) as? NumberedArrowAnnotation else {
            return nil
        }
        
        let startInView = imageToView(numberedArrow.startPoint)
        let endInView = imageToView(numberedArrow.endPoint)
        
        // Check if clicking on start handle (number)
        if hypot(viewPoint.x - startInView.x, viewPoint.y - startInView.y) <= handleHitRadius + NumberedArrowAnnotation.numberDiameter / 2 {
            return (numberedArrow, .start)
        }
        
        // Check if clicking on end handle (arrow head)
        if hypot(viewPoint.x - endInView.x, viewPoint.y - endInView.y) <= handleHitRadius {
            return (numberedArrow, .end)
        }
        
        return nil
    }
    
    // MARK: - Mouse Events
    
    override func mouseDown(with event: NSEvent) {
        log("mouseDown - before makeFirstResponder, window.firstResponder: \(String(describing: window?.firstResponder))")
        
        // Become first responder to receive keyboard events
        window?.makeFirstResponder(self)
        
        log("mouseDown - after makeFirstResponder, window.firstResponder: \(String(describing: window?.firstResponder))")
        
        let viewPoint = convert(event.locationInWindow, from: nil)
        let imagePoint = viewToImage(viewPoint)
        
        // First, check if clicking on a handle of a selected arrow (for resizing)
        if let (arrow, handle) = arrowHandleAt(viewPoint: viewPoint) {
            let otherEnd = (handle == .start) ? arrow.endPoint : arrow.startPoint
            interactionState = .resizingArrow(arrow: arrow, handle: handle, otherEnd: otherEnd)
            needsDisplay = true
            return
        }
        
        // Check if clicking on a handle of a selected circle (for resizing)
        if let (circle, handle) = circleHandleAt(viewPoint: viewPoint) {
            interactionState = .resizingCircle(circle: circle, handle: handle, originalRect: circle.rect)
            needsDisplay = true
            return
        }
        
        // Check if clicking on a handle of a selected rectangle (for resizing)
        if let (rectangle, handle) = rectangleHandleAt(viewPoint: viewPoint) {
            interactionState = .resizingRectangle(rectangle: rectangle, handle: handle, originalRect: rectangle.rect)
            needsDisplay = true
            return
        }
        
        // Check if clicking on a handle of a selected numbered arrow (for resizing)
        if let (numberedArrow, handle) = numberedArrowHandleAt(viewPoint: viewPoint) {
            let otherEnd = (handle == .start) ? numberedArrow.endPoint : numberedArrow.startPoint
            interactionState = .resizingNumberedArrow(numberedArrow: numberedArrow, handle: handle, otherEnd: otherEnd)
            needsDisplay = true
            return
        }
        
        // Next, check if clicking on an existing annotation (prioritize selection/drag over creation)
        if let hitAnnotation = annotationAt(viewPoint: viewPoint) {
            if hitAnnotation.id == selectedAnnotationId {
                // Start dragging the already-selected annotation
                interactionState = .dragging(annotation: hitAnnotation, startMousePoint: imagePoint, originalPosition: .zero)
            } else {
                // Select this annotation (and prepare for potential drag)
                selectedAnnotationId = hitAnnotation.id
                bringToFront(id: hitAnnotation.id)
                // Start dragging immediately
                interactionState = .dragging(annotation: hitAnnotation, startMousePoint: imagePoint, originalPosition: .zero)
            }
            needsDisplay = true
            return
        }
        
        // Clicked on empty area
        // If we have a tool selected, start creating
        if currentTool != .none {
            // Number tool: double-click creates number, drag creates numbered arrow
            if currentTool == .number {
                if event.clickCount == 2 {
                    // Double-click: create number annotation immediately
                    let numberAnnotation = NumberAnnotation(
                        center: imagePoint,
                        number: nextNumberValue,
                        color: currentColor
                    )
                    annotations.append(numberAnnotation)
                    selectedAnnotationId = numberAnnotation.id
                    interactionState = .idle
                    delegate?.annotationCanvasDidChangeAnnotations(self)
                    needsDisplay = true
                    return
                }
                // Single click: start pending state for potential drag
                interactionState = .pendingNumberCreation(startPoint: imagePoint, startViewPoint: viewPoint)
                selectedAnnotationId = nil
                needsDisplay = true
                return
            }
            
            // Other tools use drag to create
            interactionState = .creating(startPoint: imagePoint, currentPoint: imagePoint)
            selectedAnnotationId = nil
            needsDisplay = true
            return
        }
        
        // No tool and clicked empty area - just deselect
        selectedAnnotationId = nil
        needsDisplay = true
    }
    
    override func mouseDragged(with event: NSEvent) {
        let viewPoint = convert(event.locationInWindow, from: nil)
        let imagePoint = viewToImage(viewPoint)
        
        switch interactionState {
        case .creating(let startPoint, _):
            interactionState = .creating(startPoint: startPoint, currentPoint: imagePoint)
            needsDisplay = true
            
        case .dragging(let annotation, let startMousePoint, _):
            let delta = CGPoint(
                x: imagePoint.x - startMousePoint.x,
                y: imagePoint.y - startMousePoint.y
            )
            
            // Update annotation position
            if let index = annotations.firstIndex(where: { $0.id == annotation.id }) {
                if let arrow = annotation as? ArrowAnnotation {
                    annotations[index] = arrow.translated(by: delta)
                } else if let circle = annotation as? CircleAnnotation {
                    annotations[index] = circle.translated(by: delta)
                } else if let rectangle = annotation as? RectangleAnnotation {
                    annotations[index] = rectangle.translated(by: delta)
                } else if let number = annotation as? NumberAnnotation {
                    annotations[index] = number.translated(by: delta)
                } else if let numberedArrow = annotation as? NumberedArrowAnnotation {
                    annotations[index] = numberedArrow.translated(by: delta)
                }
                // Update drag state with new start point
                interactionState = .dragging(
                    annotation: annotations[index],
                    startMousePoint: imagePoint,
                    originalPosition: .zero
                )
            }
            needsDisplay = true
            
        case .resizingArrow(let arrow, let handle, let otherEnd):
            // Update the arrow by moving the dragged handle
            if let index = annotations.firstIndex(where: { $0.id == arrow.id }) {
                let newArrow: ArrowAnnotation
                switch handle {
                case .start:
                    newArrow = ArrowAnnotation(id: arrow.id, startPoint: imagePoint, endPoint: otherEnd, color: arrow.color)
                case .end:
                    newArrow = ArrowAnnotation(id: arrow.id, startPoint: otherEnd, endPoint: imagePoint, color: arrow.color)
                }
                annotations[index] = newArrow
                interactionState = .resizingArrow(arrow: newArrow, handle: handle, otherEnd: otherEnd)
            }
            needsDisplay = true
            
        case .resizingCircle(let circle, let handle, let originalRect):
            // Update the circle based on which handle is being dragged
            if let index = annotations.firstIndex(where: { $0.id == circle.id }) {
                let newRect = calculateResizedRect(original: originalRect, handle: handle, currentPoint: imagePoint)
                let newCircle = CircleAnnotation(id: circle.id, rect: newRect, color: circle.color)
                annotations[index] = newCircle
                // Keep original rect for reference during drag
                interactionState = .resizingCircle(circle: newCircle, handle: handle, originalRect: originalRect)
            }
            needsDisplay = true
            
        case .resizingRectangle(let rectangle, let handle, let originalRect):
            // Update the rectangle based on which handle is being dragged
            if let index = annotations.firstIndex(where: { $0.id == rectangle.id }) {
                let newRect = calculateResizedRectForRectangle(original: originalRect, handle: handle, currentPoint: imagePoint)
                let newRectangle = RectangleAnnotation(id: rectangle.id, rect: newRect, color: rectangle.color)
                annotations[index] = newRectangle
                interactionState = .resizingRectangle(rectangle: newRectangle, handle: handle, originalRect: originalRect)
            }
            needsDisplay = true
            
        case .resizingNumberedArrow(let numberedArrow, let handle, let otherEnd):
            // Update the numbered arrow by moving the dragged handle
            if let index = annotations.firstIndex(where: { $0.id == numberedArrow.id }) {
                let newNumberedArrow: NumberedArrowAnnotation
                switch handle {
                case .start:
                    newNumberedArrow = NumberedArrowAnnotation(id: numberedArrow.id, startPoint: imagePoint, endPoint: otherEnd, number: numberedArrow.number, color: numberedArrow.color)
                case .end:
                    newNumberedArrow = NumberedArrowAnnotation(id: numberedArrow.id, startPoint: otherEnd, endPoint: imagePoint, number: numberedArrow.number, color: numberedArrow.color)
                }
                annotations[index] = newNumberedArrow
                interactionState = .resizingNumberedArrow(numberedArrow: newNumberedArrow, handle: handle, otherEnd: otherEnd)
            }
            needsDisplay = true
            
        case .pendingNumberCreation(let startPoint, let startViewPoint):
            // Check if dragged past threshold
            let distance = hypot(viewPoint.x - startViewPoint.x, viewPoint.y - startViewPoint.y)
            if distance >= dragThreshold {
                // Switch to creating numbered arrow
                interactionState = .creatingNumberedArrow(startPoint: startPoint, currentPoint: imagePoint)
            }
            needsDisplay = true
            
        case .creatingNumberedArrow(let startPoint, _):
            // Update current point for preview
            interactionState = .creatingNumberedArrow(startPoint: startPoint, currentPoint: imagePoint)
            needsDisplay = true
            
        case .idle:
            break
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        switch interactionState {
        case .creating(let startPoint, let currentPoint):
            // Try to finalize the annotation
            if let newAnnotation = createAnnotation(from: startPoint, to: currentPoint) {
                annotations.append(newAnnotation)
                selectedAnnotationId = newAnnotation.id
                delegate?.annotationCanvasDidChangeAnnotations(self)
            }
            interactionState = .idle
            needsDisplay = true
            
        case .dragging:
            interactionState = .idle
            delegate?.annotationCanvasDidChangeAnnotations(self)
            needsDisplay = true
            
        case .resizingArrow:
            interactionState = .idle
            delegate?.annotationCanvasDidChangeAnnotations(self)
            needsDisplay = true
            
        case .resizingCircle:
            interactionState = .idle
            delegate?.annotationCanvasDidChangeAnnotations(self)
            needsDisplay = true
            
        case .resizingRectangle:
            interactionState = .idle
            delegate?.annotationCanvasDidChangeAnnotations(self)
            needsDisplay = true
            
        case .resizingNumberedArrow:
            interactionState = .idle
            delegate?.annotationCanvasDidChangeAnnotations(self)
            needsDisplay = true
            
        case .pendingNumberCreation:
            // Single click without drag - do nothing (double-click creates number)
            interactionState = .idle
            needsDisplay = true
            
        case .creatingNumberedArrow(let startPoint, let currentPoint):
            // Finalize numbered arrow if long enough
            let length = hypot(currentPoint.x - startPoint.x, currentPoint.y - startPoint.y)
            if length >= 20 {  // Minimum length for arrow
                let numberedArrow = NumberedArrowAnnotation(
                    startPoint: startPoint,
                    endPoint: currentPoint,
                    number: nextNumberValue,
                    color: currentColor
                )
                annotations.append(numberedArrow)
                selectedAnnotationId = numberedArrow.id
                delegate?.annotationCanvasDidChangeAnnotations(self)
            }
            interactionState = .idle
            needsDisplay = true
            
        case .idle:
            break
        }
    }
    
    override func mouseMoved(with event: NSEvent) {
        let viewPoint = convert(event.locationInWindow, from: nil)
        
        // Check if hovering over any handle (for cursor change)
        let isOverHandle = arrowHandleAt(viewPoint: viewPoint) != nil || circleHandleAt(viewPoint: viewPoint) != nil || rectangleHandleAt(viewPoint: viewPoint) != nil || numberedArrowHandleAt(viewPoint: viewPoint) != nil
        
        // Update hover state
        let hitAnnotation = annotationAt(viewPoint: viewPoint)
        let newHoveredId = hitAnnotation?.id
        
        if newHoveredId != hoveredAnnotationId || isOverHandle {
            hoveredAnnotationId = newHoveredId
            needsDisplay = true
            updateCursor()
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        if hoveredAnnotationId != nil {
            hoveredAnnotationId = nil
            needsDisplay = true
            updateCursor()
        }
    }
    
    // MARK: - Cursor Management
    
    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: cursorForCurrentState())
    }
    
    private func updateCursor() {
        window?.invalidateCursorRects(for: self)
    }
    
    private func cursorForCurrentState() -> NSCursor {
        // If dragging, show closed hand
        if case .dragging = interactionState {
            return .closedHand
        }
        
        // If hovering over any annotation, show open hand (can be moved)
        if hoveredAnnotationId != nil {
            return .openHand
        }
        
        // If a tool is selected, show crosshair for drawing
        switch currentTool {
        case .arrow, .circle, .rectangle, .number:
            return .crosshair
        case .none:
            return .arrow
        }
    }
    
    // MARK: - Circle Resize Calculation
    
    private func calculateResizedRect(original: CGRect, handle: CircleHandle, currentPoint: CGPoint) -> CGRect {
        var newRect = original
        
        if handle.isCorner {
            // Corner handles: proportional scaling from opposite corner
            let (anchorX, anchorY): (CGFloat, CGFloat)
            
            switch handle {
            case .topLeft:
                anchorX = original.maxX
                anchorY = original.minY
            case .topRight:
                anchorX = original.minX
                anchorY = original.minY
            case .bottomLeft:
                anchorX = original.maxX
                anchorY = original.maxY
            case .bottomRight:
                anchorX = original.minX
                anchorY = original.maxY
            default:
                return original
            }
            
            // Calculate new size maintaining aspect ratio
            let dx = currentPoint.x - anchorX
            let dy = currentPoint.y - anchorY
            
            // Use the larger dimension to determine scale, maintain aspect ratio
            let originalAspect = original.width / original.height
            var newWidth = abs(dx)
            var newHeight = abs(dy)
            
            // Determine which dimension to use as reference
            if newWidth / originalAspect > newHeight {
                newHeight = newWidth / originalAspect
            } else {
                newWidth = newHeight * originalAspect
            }
            
            // Apply minimum size
            newWidth = max(newWidth, 16)
            newHeight = max(newHeight, 16)
            
            // Determine new origin based on handle position
            let newX = (currentPoint.x < anchorX) ? anchorX - newWidth : anchorX
            let newY = (currentPoint.y < anchorY) ? anchorY - newHeight : anchorY
            
            newRect = CGRect(x: newX, y: newY, width: newWidth, height: newHeight)
        } else {
            // Edge handles: single axis resize
            switch handle {
            case .top:
                let newMaxY = currentPoint.y
                newRect = CGRect(x: original.minX, y: original.minY,
                               width: original.width, height: max(16, newMaxY - original.minY))
            case .bottom:
                let newMinY = currentPoint.y
                let newHeight = max(16, original.maxY - newMinY)
                newRect = CGRect(x: original.minX, y: original.maxY - newHeight,
                               width: original.width, height: newHeight)
            case .right:
                let newMaxX = currentPoint.x
                newRect = CGRect(x: original.minX, y: original.minY,
                               width: max(16, newMaxX - original.minX), height: original.height)
            case .left:
                let newMinX = currentPoint.x
                let newWidth = max(16, original.maxX - newMinX)
                newRect = CGRect(x: original.maxX - newWidth, y: original.minY,
                               width: newWidth, height: original.height)
            default:
                break
            }
        }
        
        return newRect
    }
    
    // MARK: - Rectangle Resize Calculation (no aspect ratio constraint)
    
    private func calculateResizedRectForRectangle(original: CGRect, handle: RectHandle, currentPoint: CGPoint) -> CGRect {
        var newRect = original
        
        switch handle {
        case .topLeft:
            let newMinX = currentPoint.x
            let newMaxY = currentPoint.y
            newRect = CGRect(x: newMinX, y: original.minY,
                           width: max(16, original.maxX - newMinX),
                           height: max(16, newMaxY - original.minY))
        case .topRight:
            let newMaxX = currentPoint.x
            let newMaxY = currentPoint.y
            newRect = CGRect(x: original.minX, y: original.minY,
                           width: max(16, newMaxX - original.minX),
                           height: max(16, newMaxY - original.minY))
        case .bottomLeft:
            let newMinX = currentPoint.x
            let newMinY = currentPoint.y
            let newWidth = max(16, original.maxX - newMinX)
            let newHeight = max(16, original.maxY - newMinY)
            newRect = CGRect(x: original.maxX - newWidth, y: original.maxY - newHeight,
                           width: newWidth, height: newHeight)
        case .bottomRight:
            let newMaxX = currentPoint.x
            let newMinY = currentPoint.y
            let newHeight = max(16, original.maxY - newMinY)
            newRect = CGRect(x: original.minX, y: original.maxY - newHeight,
                           width: max(16, newMaxX - original.minX), height: newHeight)
        case .top:
            let newMaxY = currentPoint.y
            newRect = CGRect(x: original.minX, y: original.minY,
                           width: original.width, height: max(16, newMaxY - original.minY))
        case .bottom:
            let newMinY = currentPoint.y
            let newHeight = max(16, original.maxY - newMinY)
            newRect = CGRect(x: original.minX, y: original.maxY - newHeight,
                           width: original.width, height: newHeight)
        case .right:
            let newMaxX = currentPoint.x
            newRect = CGRect(x: original.minX, y: original.minY,
                           width: max(16, newMaxX - original.minX), height: original.height)
        case .left:
            let newMinX = currentPoint.x
            let newWidth = max(16, original.maxX - newMinX)
            newRect = CGRect(x: original.maxX - newWidth, y: original.minY,
                           width: newWidth, height: original.height)
        }
        
        return newRect
    }
    
    // MARK: - Annotation Creation
    
    private func createAnnotation(from startPoint: CGPoint, to endPoint: CGPoint) -> (any Annotation)? {
        switch currentTool {
        case .arrow:
            let length = hypot(endPoint.x - startPoint.x, endPoint.y - startPoint.y)
            guard length >= 10 else { return nil }  // Minimum 10px
            return ArrowAnnotation(startPoint: startPoint, endPoint: endPoint, color: currentColor)
            
        case .circle:
            let width = abs(endPoint.x - startPoint.x)
            let height = abs(endPoint.y - startPoint.y)
            guard width >= 8 || height >= 8 else { return nil }  // Minimum 8px
            return CircleAnnotation(from: startPoint, to: endPoint, color: currentColor)
            
        case .rectangle:
            let width = abs(endPoint.x - startPoint.x)
            let height = abs(endPoint.y - startPoint.y)
            guard width >= 8 || height >= 8 else { return nil }  // Minimum 8px
            return RectangleAnnotation(from: startPoint, to: endPoint, color: currentColor)
            
        case .number:
            // Numbers are created on single click, not drag
            return nil
            
        case .none:
            return nil
        }
    }
    
    // MARK: - Annotation Management
    
    private func bringToFront(id: UUID) {
        guard let index = annotations.firstIndex(where: { $0.id == id }) else { return }
        let annotation = annotations.remove(at: index)
        annotations.append(annotation)
    }
    
    // MARK: - Drawing
    
    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        // Clear background (transparent)
        context.clear(bounds)
        
        // Draw all annotations
        for annotation in annotations {
            let state = stateFor(annotation: annotation)
            annotation.draw(in: context, scale: scale, state: state, imageSize: imageSize)
        }
        
        // Draw in-progress annotation
        if case .creating(let startPoint, let currentPoint) = interactionState {
            drawCreatingAnnotation(context: context, from: startPoint, to: currentPoint)
        }
        
        // Draw in-progress numbered arrow
        if case .creatingNumberedArrow(let startPoint, let currentPoint) = interactionState {
            let temp = NumberedArrowAnnotation(startPoint: startPoint, endPoint: currentPoint, number: nextNumberValue, color: currentColor)
            temp.draw(in: context, scale: scale, state: .creating, imageSize: imageSize)
        }
    }
    
    private func stateFor(annotation: any Annotation) -> AnnotationState {
        if case .dragging(let draggedAnnotation, _, _) = interactionState,
           draggedAnnotation.id == annotation.id {
            return .dragging
        }
        if case .resizingArrow(let resizingArrow, _, _) = interactionState,
           resizingArrow.id == annotation.id {
            return .selected  // Keep showing selected state while resizing
        }
        if case .resizingCircle(let resizingCircle, _, _) = interactionState,
           resizingCircle.id == annotation.id {
            return .selected  // Keep showing selected state while resizing
        }
        if case .resizingRectangle(let resizingRectangle, _, _) = interactionState,
           resizingRectangle.id == annotation.id {
            return .selected  // Keep showing selected state while resizing
        }
        if case .resizingNumberedArrow(let resizingNumberedArrow, _, _) = interactionState,
           resizingNumberedArrow.id == annotation.id {
            return .selected  // Keep showing selected state while resizing
        }
        if annotation.id == selectedAnnotationId {
            return .selected
        }
        if annotation.id == hoveredAnnotationId {
            return .hover
        }
        return .idle
    }
    
    private func drawCreatingAnnotation(context: CGContext, from startPoint: CGPoint, to currentPoint: CGPoint) {
        // Create temporary annotation for preview
        switch currentTool {
        case .arrow:
            let temp = ArrowAnnotation(startPoint: startPoint, endPoint: currentPoint, color: currentColor)
            temp.draw(in: context, scale: scale, state: .creating, imageSize: imageSize)
            
        case .circle:
            let temp = CircleAnnotation(from: startPoint, to: currentPoint, color: currentColor)
            temp.draw(in: context, scale: scale, state: .creating, imageSize: imageSize)
            
        case .rectangle:
            let temp = RectangleAnnotation(from: startPoint, to: currentPoint, color: currentColor)
            temp.draw(in: context, scale: scale, state: .creating, imageSize: imageSize)
            
        case .number:
            // Numbers are created on single click, no drag preview needed
            break
            
        case .none:
            break
        }
    }
}
