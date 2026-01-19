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
    
    /// Brand color for selected state
    private let brandColor = NSColor(red: 1.0, green: 0.553, blue: 0.463, alpha: 1.0) // #FF8D76
    /// Default icon color (same as system icons like dropdown chevron)
    private let defaultIconColor = NSColor.labelColor
    
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
        layer?.backgroundColor = NSColor.clear.cgColor  // Transparent background
        
        setupToolButtons()
        setupColorButton()
        setupClearAllButton()
        setupLayout()
        
        updateToolButtonStates()
        updateColorButton()
        updateClearAllVisibility()
    }
    
    // MARK: - Setup
    
    private func setupToolButtons() {
        // Arrow button
        configureToolButton(arrowButton, symbolName: "arrow.up.right", tooltip: "Arrow Tool")
        arrowButton.target = self
        arrowButton.action = #selector(arrowButtonPressed)
        
        // Circle button
        configureToolButton(circleButton, symbolName: "circle", tooltip: "Circle Tool")
        circleButton.target = self
        circleButton.action = #selector(circleButtonPressed)
        
        // Rectangle button
        configureToolButton(rectangleButton, symbolName: "rectangle", tooltip: "Rectangle Tool")
        rectangleButton.target = self
        rectangleButton.action = #selector(rectangleButtonPressed)
        
        // Number button
        configureToolButton(numberButton, symbolName: "1.circle", tooltip: "Number Tool")
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
        colorButton.toolTip = "Annotation Color"
        colorButton.target = self
        colorButton.action = #selector(colorButtonPressed)
        colorButton.translatesAutoresizingMaskIntoConstraints = false
        
        updateColorButton()
    }
    
    private func setupClearAllButton() {
        clearAllButton.bezelStyle = .toolbar
        clearAllButton.isBordered = true
        clearAllButton.title = "Clear All"
        clearAllButton.toolTip = "Clear All Annotations"
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
        if selectedTool == .circle {
            selectedTool = .none
        } else {
            selectedTool = .circle
        }
        delegate?.toolbarDidSelectTool(selectedTool)
    }
    
    @objc private func rectangleButtonPressed() {
        if selectedTool == .rectangle {
            selectedTool = .none
        } else {
            selectedTool = .rectangle
        }
        delegate?.toolbarDidSelectTool(selectedTool)
    }
    
    @objc private func numberButtonPressed() {
        if selectedTool == .number {
            selectedTool = .none
        } else {
            selectedTool = .number
        }
        delegate?.toolbarDidSelectTool(selectedTool)
    }
    
    @objc private func colorButtonPressed() {
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
    
    // MARK: - UI Updates
    
    private func updateToolButtonStates() {
        // Update arrow button
        let arrowSelected = selectedTool == .arrow
        let arrowColor = arrowSelected ? brandColor : defaultIconColor
        let arrowConfig = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
            .applying(.init(paletteColors: [arrowColor]))
        arrowButton.image = NSImage(systemSymbolName: "arrow.up.right", accessibilityDescription: "Arrow Tool")?
            .withSymbolConfiguration(arrowConfig)
        arrowButton.contentTintColor = arrowColor
        
        // Update circle button
        let circleSelected = selectedTool == .circle
        let circleColor = circleSelected ? brandColor : defaultIconColor
        let circleConfig = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
            .applying(.init(paletteColors: [circleColor]))
        circleButton.image = NSImage(systemSymbolName: "circle", accessibilityDescription: "Circle Tool")?
            .withSymbolConfiguration(circleConfig)
        circleButton.contentTintColor = circleColor
        
        // Update rectangle button
        let rectangleSelected = selectedTool == .rectangle
        let rectangleColor = rectangleSelected ? brandColor : defaultIconColor
        let rectangleConfig = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
            .applying(.init(paletteColors: [rectangleColor]))
        rectangleButton.image = NSImage(systemSymbolName: "rectangle", accessibilityDescription: "Rectangle Tool")?
            .withSymbolConfiguration(rectangleConfig)
        rectangleButton.contentTintColor = rectangleColor
        
        // Update number button
        let numberSelected = selectedTool == .number
        let numberColor = numberSelected ? brandColor : defaultIconColor
        let numberConfig = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
            .applying(.init(paletteColors: [numberColor]))
        numberButton.image = NSImage(systemSymbolName: "1.circle", accessibilityDescription: "Number Tool")?
            .withSymbolConfiguration(numberConfig)
        numberButton.contentTintColor = numberColor
    }
    
    private func updateColorButton() {
        // Create composite image: color dot + chevron
        let dotImage = createColorDotImage(color: selectedColor, size: colorDotSize)
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
        colorButton.image = combinedImage
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
        selectedTool = tool
    }
    
    /// Set the selected color (called externally to sync state)
    func setSelectedColor(_ color: AnnotationColor) {
        selectedColor = color
    }
    
    // MARK: - Layout
    
    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: toolbarHeight)
    }
}
