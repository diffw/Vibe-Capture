import AppKit

/// Delegate protocol for toolbar events
protocol AnnotationToolbarViewDelegate: AnyObject {
    func toolbarDidSelectTool(_ tool: AnnotationTool)
    func toolbarDidSelectColor(_ color: AnnotationColor)
    func toolbarDidPressClearAll()
}

/// Toolbar view for annotation tools
/// Layout: [Arrow] [Circle] | [Color ▾] | [Clear All]
final class AnnotationToolbarView: NSView {
    
    weak var delegate: AnnotationToolbarViewDelegate?
    
    // MARK: - UI Components
    
    private let arrowButton = NSButton()
    private let circleButton = NSButton()
    private let rectangleButton = NSButton()
    private let numberButton = NSButton()
    private let colorButton = NSButton()
    private let clearAllButton = NSButton()
    
    // MARK: - State
    
    private(set) var selectedTool: AnnotationTool = .none {
        didSet { updateToolButtonStates() }
    }
    
    private(set) var selectedColor: AnnotationColor = .red {
        didSet { updateColorButton() }
    }
    
    var hasAnnotations: Bool = false {
        didSet { updateClearAllVisibility() }
    }
    
    // MARK: - Constants
    
    private let toolbarHeight: CGFloat = 36
    private let buttonSize: CGFloat = 28
    private let colorDotSize: CGFloat = 16

    private var proStatusObserver: Any?
    
    /// Brand color for selected state
    private let brandColor = NSColor(red: 1.0, green: 0.553, blue: 0.463, alpha: 1.0) // #FF8D76
    /// Default icon color (same as system icons like dropdown chevron)
    private let defaultIconColor = NSColor.labelColor
    private let lockedIconColor = NSColor.secondaryLabelColor
    
    // MARK: - Initialization
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    deinit {
        if let proStatusObserver {
            NotificationCenter.default.removeObserver(proStatusObserver)
            self.proStatusObserver = nil
        }
    }
    
    private func setupView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor  // Transparent background
        
        setupToolButtons()
        setupColorButton()
        setupClearAllButton()
        setupLayout()
        
        updateToolButtonStates()
        updateColorButton()
        updateClearAllVisibility()

        proStatusObserver = NotificationCenter.default.addObserver(
            forName: .proStatusDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleProStatusChanged()
        }
    }
    
    // MARK: - Setup
    
    private func setupToolButtons() {
        // Arrow button
        configureToolButton(arrowButton, symbolName: "arrow.up.right", tooltip: L("annotation.tool.arrow"))
        arrowButton.target = self
        arrowButton.action = #selector(arrowButtonPressed)
        
        // Circle button
        configureToolButton(circleButton, symbolName: "circle", tooltip: L("annotation.tool.circle"))
        circleButton.target = self
        circleButton.action = #selector(circleButtonPressed)
        
        // Rectangle button
        configureToolButton(rectangleButton, symbolName: "rectangle", tooltip: L("annotation.tool.rectangle"))
        rectangleButton.target = self
        rectangleButton.action = #selector(rectangleButtonPressed)
        
        // Number button
        configureToolButton(numberButton, symbolName: "1.circle", tooltip: L("annotation.tool.number"))
        numberButton.target = self
        numberButton.action = #selector(numberButtonPressed)
    }
    
    private func configureToolButton(_ button: NSButton, symbolName: String, tooltip: String) {
        button.bezelStyle = .toolbar
        button.isBordered = false  // Remove border for cleaner look
        button.setButtonType(.momentaryPushIn)  // We'll handle toggle state manually
        button.imagePosition = .imageOnly
        button.toolTip = tooltip
        button.translatesAutoresizingMaskIntoConstraints = false
        
        // Set initial image with default color
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
            .applying(.init(paletteColors: [defaultIconColor]))
        button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: tooltip)?
            .withSymbolConfiguration(config)
    }
    
    private func setupColorButton() {
        colorButton.bezelStyle = .toolbar
        colorButton.isBordered = true
        colorButton.setButtonType(.momentaryPushIn)
        colorButton.imagePosition = .imageOnly
        colorButton.toolTip = L("annotation.color.tooltip")
        colorButton.target = self
        colorButton.action = #selector(colorButtonPressed)
        colorButton.translatesAutoresizingMaskIntoConstraints = false
        
        updateColorButton()
    }
    
    private func setupClearAllButton() {
        clearAllButton.bezelStyle = .toolbar
        clearAllButton.isBordered = true
        clearAllButton.title = L("annotation.clear_all")
        clearAllButton.toolTip = L("annotation.clear_all.tooltip")
        clearAllButton.target = self
        clearAllButton.action = #selector(clearAllButtonPressed)
        clearAllButton.translatesAutoresizingMaskIntoConstraints = false
    }
    
    private func setupLayout() {
        // Tool buttons stack
        let toolStack = NSStackView(views: [arrowButton, circleButton, rectangleButton, numberButton])
        toolStack.orientation = .horizontal
        toolStack.spacing = 4
        toolStack.translatesAutoresizingMaskIntoConstraints = false
        
        // Separator 1
        let separator1 = createSeparator()
        
        // Color picker
        let colorStack = NSStackView(views: [colorButton])
        colorStack.orientation = .horizontal
        colorStack.translatesAutoresizingMaskIntoConstraints = false
        
        // Separator 2
        let separator2 = createSeparator()
        
        // Spacer
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        
        // Main stack
        let mainStack = NSStackView(views: [toolStack, separator1, colorStack, separator2, spacer, clearAllButton])
        mainStack.orientation = .horizontal
        mainStack.spacing = 8
        mainStack.alignment = .centerY
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(mainStack)
        
        NSLayoutConstraint.activate([
            mainStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            mainStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            mainStack.topAnchor.constraint(equalTo: topAnchor),
            mainStack.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            arrowButton.widthAnchor.constraint(equalToConstant: buttonSize),
            arrowButton.heightAnchor.constraint(equalToConstant: buttonSize),
            circleButton.widthAnchor.constraint(equalToConstant: buttonSize),
            circleButton.heightAnchor.constraint(equalToConstant: buttonSize),
            rectangleButton.widthAnchor.constraint(equalToConstant: buttonSize),
            rectangleButton.heightAnchor.constraint(equalToConstant: buttonSize),
            numberButton.widthAnchor.constraint(equalToConstant: buttonSize),
            numberButton.heightAnchor.constraint(equalToConstant: buttonSize),
            
            colorButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 44),
            colorButton.heightAnchor.constraint(equalToConstant: buttonSize),
            
            separator1.widthAnchor.constraint(equalToConstant: 1),
            separator1.heightAnchor.constraint(equalToConstant: 20),
            separator2.widthAnchor.constraint(equalToConstant: 1),
            separator2.heightAnchor.constraint(equalToConstant: 20),
        ])
    }
    
    private func createSeparator() -> NSView {
        let separator = NSView()
        separator.wantsLayer = true
        separator.layer?.backgroundColor = NSColor.separatorColor.cgColor
        separator.translatesAutoresizingMaskIntoConstraints = false
        return separator
    }
    
    // MARK: - Actions
    
    @objc private func arrowButtonPressed() {
        if selectedTool == .arrow {
            selectedTool = .none
        } else {
            selectedTool = .arrow
        }
        delegate?.toolbarDidSelectTool(selectedTool)
    }
    
    @objc private func circleButtonPressed() {
        guard requireProCapability(.annotationsShapes) else { return }
        if selectedTool == .circle {
            selectedTool = .none
        } else {
            selectedTool = .circle
        }
        delegate?.toolbarDidSelectTool(selectedTool)
    }
    
    @objc private func rectangleButtonPressed() {
        guard requireProCapability(.annotationsShapes) else { return }
        if selectedTool == .rectangle {
            selectedTool = .none
        } else {
            selectedTool = .rectangle
        }
        delegate?.toolbarDidSelectTool(selectedTool)
    }
    
    @objc private func numberButtonPressed() {
        guard requireProCapability(.annotationsNumbering) else { return }
        if selectedTool == .number {
            selectedTool = .none
        } else {
            selectedTool = .number
        }
        delegate?.toolbarDidSelectTool(selectedTool)
    }
    
    @objc private func colorButtonPressed() {
        guard requireProCapability(.annotationsColors) else { return }
        showColorMenu()
    }
    
    @objc private func clearAllButtonPressed() {
        delegate?.toolbarDidPressClearAll()
    }
    
    // MARK: - Color Menu
    
    private func showColorMenu() {
        let menu = NSMenu()
        
        for color in AnnotationColor.allCases {
            let item = NSMenuItem()
            item.title = color.displayName
            item.image = createColorDotImage(color: color, size: 14)
            item.representedObject = color
            item.target = self
            item.action = #selector(colorMenuItemSelected(_:))
            
            // Checkmark for current color
            if color == selectedColor {
                item.state = .on
            }
            
            menu.addItem(item)
        }
        
        // Position menu below the color button
        let buttonFrame = colorButton.convert(colorButton.bounds, to: nil)
        if let windowFrame = window?.convertToScreen(buttonFrame) {
            menu.popUp(positioning: nil, at: NSPoint(x: windowFrame.origin.x, y: windowFrame.origin.y), in: nil)
        } else {
            menu.popUp(positioning: nil, at: NSPoint(x: colorButton.frame.minX, y: colorButton.frame.minY), in: self)
        }
    }
    
    @objc private func colorMenuItemSelected(_ sender: NSMenuItem) {
        guard let color = sender.representedObject as? AnnotationColor else { return }
        selectedColor = color
        delegate?.toolbarDidSelectColor(color)
    }

    // MARK: - Gating

    private func requireProCapability(_ capability: CapabilityKey) -> Bool {
        if CapabilityService.shared.canUse(capability) {
            return true
        }
        PaywallWindowController.shared.show()
        return false
    }

    private func handleProStatusChanged() {
        // If user downgraded while a Pro tool is selected, fall back to Arrow.
        if !EntitlementsService.shared.isPro {
            if selectedTool == .circle || selectedTool == .rectangle || selectedTool == .number {
                selectedTool = .arrow
                delegate?.toolbarDidSelectTool(.arrow)
            }

            // Free users can't change color; revert to default red if needed.
            if selectedColor != .red {
                selectedColor = .red
                delegate?.toolbarDidSelectColor(.red)
            }
        }

        updateToolButtonStates()
        updateColorButton()
    }
    
    // MARK: - UI Updates
    
    private func updateToolButtonStates() {
        // Update arrow button
        let arrowSelected = selectedTool == .arrow
        let arrowColor = arrowSelected ? brandColor : defaultIconColor
        let arrowConfig = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
            .applying(.init(paletteColors: [arrowColor]))
        arrowButton.image = NSImage(systemSymbolName: "arrow.up.right", accessibilityDescription: L("annotation.tool.arrow"))?
            .withSymbolConfiguration(arrowConfig)
        arrowButton.contentTintColor = arrowColor
        
        // Update circle button
        let canShapes = CapabilityService.shared.canUse(.annotationsShapes)
        let circleSelected = selectedTool == .circle && canShapes
        let circleColor = circleSelected ? brandColor : defaultIconColor
        circleButton.image = canShapes
            ? makeSymbolImage(symbolName: "circle", color: circleColor, accessibility: L("annotation.tool.circle"))
            : makeLockedSymbolImage(symbolName: "circle", color: circleColor, accessibility: L("annotation.tool.circle"))
        circleButton.contentTintColor = circleColor
        
        // Update rectangle button
        let rectangleSelected = selectedTool == .rectangle && canShapes
        let rectangleColor = rectangleSelected ? brandColor : defaultIconColor
        rectangleButton.image = canShapes
            ? makeSymbolImage(symbolName: "rectangle", color: rectangleColor, accessibility: L("annotation.tool.rectangle"))
            : makeLockedSymbolImage(symbolName: "rectangle", color: rectangleColor, accessibility: L("annotation.tool.rectangle"))
        rectangleButton.contentTintColor = rectangleColor
        
        // Update number button
        let canNumbering = CapabilityService.shared.canUse(.annotationsNumbering)
        let numberSelected = selectedTool == .number && canNumbering
        let numberColor = numberSelected ? brandColor : defaultIconColor
        numberButton.image = canNumbering
            ? makeSymbolImage(symbolName: "1.circle", color: numberColor, accessibility: L("annotation.tool.number"))
            : makeLockedSymbolImage(symbolName: "1.circle", color: numberColor, accessibility: L("annotation.tool.number"))
        numberButton.contentTintColor = numberColor
    }
    
    private func updateColorButton() {
        let canColors = CapabilityService.shared.canUse(.annotationsColors)

        // Free: color is fixed to red.
        let displayedColor: AnnotationColor = canColors ? selectedColor : .red

        // Create composite image: color dot + chevron
        let dotImage = createColorDotImage(color: displayedColor, size: colorDotSize)
        let chevronImage = NSImage(systemSymbolName: "chevron.down", accessibilityDescription: nil)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 10, weight: .medium))
        
        // Combine images
        let totalWidth: CGFloat = colorDotSize + 4 + 10  // dot + spacing + chevron
        let totalHeight: CGFloat = colorDotSize
        
        let combinedImage = NSImage(size: NSSize(width: totalWidth, height: totalHeight))
        combinedImage.lockFocus()
        
        // Draw color dot
        dotImage.draw(in: NSRect(x: 0, y: 0, width: colorDotSize, height: colorDotSize))
        
        // Draw chevron
        if let chevron = chevronImage {
            let chevronSize = chevron.size
            chevron.draw(in: NSRect(
                x: colorDotSize + 4,
                y: (totalHeight - chevronSize.height) / 2,
                width: chevronSize.width,
                height: chevronSize.height
            ))
        }
        
        combinedImage.unlockFocus()
        colorButton.image = canColors ? combinedImage : overlayLock(on: combinedImage)
    }
    
    private func updateClearAllVisibility() {
        clearAllButton.isHidden = !hasAnnotations
    }
    
    private func createColorDotImage(color: AnnotationColor, size: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        
        let rect = NSRect(x: 1, y: 1, width: size - 2, height: size - 2)
        let path = NSBezierPath(ovalIn: rect)
        
        color.nsColor.setFill()
        path.fill()
        
        // Add subtle border
        NSColor.black.withAlphaComponent(0.2).setStroke()
        path.lineWidth = 0.5
        path.stroke()
        
        image.unlockFocus()
        return image
    }
    
    // MARK: - Public Methods
    
    /// Set the selected tool (called externally to sync state)
    func setSelectedTool(_ tool: AnnotationTool) {
        if !EntitlementsService.shared.isPro, (tool == .circle || tool == .rectangle || tool == .number) {
            selectedTool = .arrow
        } else {
            selectedTool = tool
        }
    }
    
    /// Set the selected color (called externally to sync state)
    func setSelectedColor(_ color: AnnotationColor) {
        if !CapabilityService.shared.canUse(.annotationsColors) {
            selectedColor = .red
        } else {
            selectedColor = color
        }
    }

    // MARK: - Locked UI Helpers

    private func makeSymbolImage(symbolName: String, color: NSColor, accessibility: String) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
            .applying(.init(paletteColors: [color]))
        return NSImage(systemSymbolName: symbolName, accessibilityDescription: accessibility)?
            .withSymbolConfiguration(config)
    }

    private func makeLockedSymbolImage(symbolName: String, color: NSColor, accessibility: String) -> NSImage? {
        guard let base = makeSymbolImage(symbolName: symbolName, color: color, accessibility: accessibility) else { return nil }
        return overlayLock(on: base)
    }

    private func overlayLock(on base: NSImage) -> NSImage {
        let output = NSImage(size: base.size)
        output.lockFocus()

        base.draw(in: NSRect(origin: .zero, size: base.size))

        let lockConfig = NSImage.SymbolConfiguration(pointSize: 8, weight: .bold)
            .applying(.init(paletteColors: [lockedIconColor]))
        if let lock = NSImage(systemSymbolName: "lock.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(lockConfig) {
            let padding: CGFloat = 1
            let lockSize = lock.size
            let rect = NSRect(
                x: base.size.width - lockSize.width - padding,
                y: padding,
                width: lockSize.width,
                height: lockSize.height
            )
            lock.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)
        }

        output.unlockFocus()
        return output
    }
    
    // MARK: - Layout
    
    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: toolbarHeight)
    }
}
