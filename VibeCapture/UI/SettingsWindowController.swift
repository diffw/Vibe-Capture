import AppKit
import CoreImage
import QuartzCore

final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private let settingsVC = SettingsViewController()

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = L("settings.window_title")
        window.isReleasedWhenClosed = false
        window.center()
        window.contentViewController = settingsVC
        super.init(window: window)
        window.delegate = self
    }

    required init?(coder: NSCoder) { nil }

    func show(focusAutoCleanup: Bool = false) {
        guard let window else { return }
        AppLog.log(.info, "settings", "SettingsWindowController.show title=\(window.title)")
        NSApp.activate(ignoringOtherApps: true)
        window.center()
        window.makeKeyAndOrderFront(nil)
        if focusAutoCleanup {
            settingsVC.focusAutoCleanupSection()
        }
    }

    func focusAutoCleanupSection() {
        settingsVC.focusAutoCleanupSection()
    }
}

final class PendingNavigationState {
    static let shared = PendingNavigationState()
    private init() {}

    var openCleanupSettingsAfterUpgrade = false
}

final class LibraryWindowController: NSWindowController, NSWindowDelegate {
    static let defaultContentSize = NSSize(width: 980, height: 680)
    static let minimumContentSize = NSSize(width: 760, height: 520)

    private let libraryVC = LibraryViewController()

    init() {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: Self.defaultContentSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.setAccessibilityIdentifier("library.window")
        window.title = "Library"
        window.isReleasedWhenClosed = false
        window.contentMinSize = Self.minimumContentSize
        window.contentViewController = libraryVC
        // AppKit may shrink the initial content size to the hosted view's fitting size.
        // Re-apply the intended default after wiring the content controller.
        window.setContentSize(Self.defaultContentSize)
        window.center()
        super.init(window: window)
        window.delegate = self
    }

    required init?(coder: NSCoder) { nil }

    func show() {
        guard let window else { return }
        libraryVC.reloadContent()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func reload() {
        libraryVC.reloadContent()
    }
}

private extension NSUserInterfaceItemIdentifier {
    static let libraryCollectionItem = NSUserInterfaceItemIdentifier("library.collection.item")
}

struct LibraryActionState {
    let showsSelectionActions: Bool
    let copyEnabled: Bool
    let openEnabled: Bool
    let keepEnabled: Bool
    let deleteEnabled: Bool
    let keepTitle: String
}

enum LibraryKeyboardAction: Equatable {
    case none
    case copySelection
    case openFromSpace
    case openFromReturn
    case deleteSelection
}

func resolveLibraryActionState(selectionCount: Int, allSelectedKept: Bool) -> LibraryActionState {
    let hasSelection = selectionCount > 0
    let isSingleSelection = selectionCount == 1
    let keepTitle = hasSelection && allSelectedKept ? "Unkeep" : "Keep"
    return LibraryActionState(
        showsSelectionActions: hasSelection,
        copyEnabled: hasSelection,
        openEnabled: isSingleSelection,
        keepEnabled: hasSelection,
        deleteEnabled: hasSelection,
        keepTitle: keepTitle
    )
}

func resolveLibraryCopyHUDKey(copiedCount: Int) -> String {
    copiedCount > 1 ? "hud.images_copied" : "hud.image_copied"
}

func resolveLibraryKeyboardAction(keyCode: UInt16, modifierFlags: NSEvent.ModifierFlags) -> LibraryKeyboardAction {
    if modifierFlags.contains(.command), (keyCode == 51 || keyCode == 117) {
        return .deleteSelection
    }
    if modifierFlags.contains(.command), keyCode == 8 {
        return .copySelection
    }
    if keyCode == 49 {
        return .openFromSpace
    }
    if keyCode == 36 {
        return .openFromReturn
    }
    return .none
}

func resolveLibraryPrimarySelectedIndex(selectedIndexes: [Int], selectedItemCount: Int) -> Int? {
    guard selectedItemCount == 1 else { return nil }
    return selectedIndexes.first
}

func resolveLibraryMarqueeSelection(
    initialSelection: Set<IndexPath>,
    hitSelection: Set<IndexPath>,
    isCommandModifierActive: Bool
) -> Set<IndexPath> {
    isCommandModifierActive ? initialSelection.symmetricDifference(hitSelection) : hitSelection
}

func resolveLibraryMarqueeRect(start: NSPoint, current: NSPoint) -> NSRect {
    NSRect(
        x: min(start.x, current.x),
        y: min(start.y, current.y),
        width: abs(current.x - start.x),
        height: abs(current.y - start.y)
    )
}

struct LibraryMarqueeStyle {
    let fillColor: NSColor
    let strokeColor: NSColor
}

struct LibraryKeepBadgeStyle {
    let symbolName: String
    let iconTintColor: NSColor
    let backgroundColor: NSColor
    let borderColor: NSColor
}

struct LibraryKeepActionButtonStyle {
    let symbolName: String
    let iconTintColor: NSColor
    let backgroundColor: NSColor
    let borderColor: NSColor
}

struct LibraryKeepControlMetrics {
    let keptBadgeDiameter: CGFloat
    let keepActionButtonHeight: CGFloat
}

enum LibraryKeepControlState: Equatable {
    case hidden
    case keepActionButton
    case keptBadge
}

func resolveLibraryMarqueeStyle() -> LibraryMarqueeStyle {
    // Match desktop-style marquee: neutral tint, low contrast fill, subtle border.
    LibraryMarqueeStyle(
        fillColor: NSColor.tertiaryLabelColor.withAlphaComponent(0.08),
        strokeColor: NSColor.secondaryLabelColor.withAlphaComponent(0.28)
    )
}

func resolveLibraryKeepBadgeStyle() -> LibraryKeepBadgeStyle {
    LibraryKeepBadgeStyle(
        symbolName: "flag.fill",
        iconTintColor: .white,
        backgroundColor: .systemOrange,
        borderColor: NSColor.black.withAlphaComponent(0.18)
    )
}

func resolveLibraryKeepActionButtonStyle() -> LibraryKeepActionButtonStyle {
    LibraryKeepActionButtonStyle(
        symbolName: "flag.fill",
        iconTintColor: .darkGray,
        backgroundColor: .white,
        borderColor: NSColor.black.withAlphaComponent(0.18)
    )
}

func resolveLibraryKeepControlMetrics() -> LibraryKeepControlMetrics {
    LibraryKeepControlMetrics(
        keptBadgeDiameter: 28,
        keepActionButtonHeight: 28
    )
}

func resolveLibraryKeepControlState(
    isKept: Bool,
    isHoveredOnPreview: Bool,
    isSelected: Bool
) -> LibraryKeepControlState {
    if isKept {
        return .keptBadge
    }
    if isHoveredOnPreview || isSelected {
        return .keepActionButton
    }
    return .hidden
}

func resolveLibraryKeepTooltipText(isKept: Bool) -> String {
    isKept ? "Unkeep" : "Keep"
}

func resolveLibraryShouldScheduleReload(
    notificationReason: String?,
    suppressLocalKeepReload: Bool
) -> Bool {
    if notificationReason == "keep", suppressLocalKeepReload {
        return false
    }
    return true
}

func resolveLibrarySelectionCountText(_ selectionCount: Int) -> String {
    selectionCount == 1 ? "1 selected" : "\(selectionCount) selected"
}

struct LibraryFilterLabelState {
    let allLabel: String
    let keptLabel: String
}

func resolveLibraryFilterLabelState(allCount: Int, keptCount: Int) -> LibraryFilterLabelState {
    LibraryFilterLabelState(
        allLabel: "All (\(allCount))",
        keptLabel: "Kept (\(keptCount))"
    )
}

func resolveLibraryItemBorderColor(isSelected: Bool, isKept: Bool) -> NSColor {
    if isSelected {
        return .controlAccentColor
    }
    // Kept state is indicated by badge only; keep neutral card border.
    _ = isKept
    return .separatorColor
}

private final class LibraryCollectionView: NSCollectionView {
    var onSelectionDragStateChanged: ((Bool) -> Void)?
    var onItemDoubleClicked: ((IndexPath) -> Void)?
    private var isTrackingSelectionDrag = false
    private var dragStartPoint: NSPoint?
    private var initialSelection: Set<IndexPath> = []
    private let marqueeLayer = CAShapeLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupMarqueeLayer()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupMarqueeLayer()
    }

    override func layout() {
        super.layout()
        marqueeLayer.frame = bounds
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyMarqueeStyle()
    }

    override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        let clickedItem = indexPathForItem(at: location)
        if event.clickCount == 2, let clickedItem {
            onItemDoubleClicked?(clickedItem)
        }
        if clickedItem == nil {
            dragStartPoint = location
            initialSelection = selectionIndexPaths
            marqueeLayer.isHidden = false
            updateMarqueePath(with: NSRect(origin: location, size: .zero))
            if !event.modifierFlags.contains(.command) {
                selectItems(at: Set<IndexPath>(), scrollPosition: [])
            }
        } else {
            dragStartPoint = nil
            initialSelection = Set<IndexPath>()
            marqueeLayer.isHidden = true
            marqueeLayer.path = nil
        }
        super.mouseDown(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = dragStartPoint else {
            super.mouseDragged(with: event)
            return
        }

        let current = convert(event.locationInWindow, from: nil)
        let selectionRect = resolveLibraryMarqueeRect(start: start, current: current)
        updateMarqueePath(with: selectionRect)
        let hitIndexPaths = indexPathsIntersecting(selectionRect)
        let isCommandModifierActive = event.modifierFlags.contains(.command)
        let newSelection = resolveLibraryMarqueeSelection(
            initialSelection: initialSelection,
            hitSelection: hitIndexPaths,
            isCommandModifierActive: isCommandModifierActive
        )

        let currentSelection = selectionIndexPaths
        if currentSelection != newSelection {
            let toDeselect = currentSelection.subtracting(newSelection)
            let toSelect = newSelection.subtracting(currentSelection)
            if !toDeselect.isEmpty {
                deselectItems(at: toDeselect)
            }
            if !toSelect.isEmpty {
                selectItems(at: toSelect, scrollPosition: [])
            }
        }

        if !isTrackingSelectionDrag {
            isTrackingSelectionDrag = true
            onSelectionDragStateChanged?(true)
        }
    }

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        dragStartPoint = nil
        initialSelection = Set<IndexPath>()
        marqueeLayer.isHidden = true
        marqueeLayer.path = nil
        if isTrackingSelectionDrag {
            isTrackingSelectionDrag = false
            onSelectionDragStateChanged?(false)
        }
    }

    private func indexPathsIntersecting(_ rect: NSRect) -> Set<IndexPath> {
        guard let layout = collectionViewLayout else { return Set<IndexPath>() }
        let attributes = layout.layoutAttributesForElements(in: rect) ?? []
        return Set(
            attributes.compactMap { attribute in
                guard attribute.representedElementCategory == .item else { return nil }
                return attribute.indexPath
            }
        )
    }

    private func setupMarqueeLayer() {
        wantsLayer = true
        marqueeLayer.lineWidth = 1
        marqueeLayer.zPosition = 10_000
        marqueeLayer.isHidden = true
        marqueeLayer.fillColor = NSColor.clear.cgColor
        marqueeLayer.strokeColor = NSColor.clear.cgColor
        layer?.addSublayer(marqueeLayer)
        applyMarqueeStyle()
    }

    private func applyMarqueeStyle() {
        let style = resolveLibraryMarqueeStyle()
        marqueeLayer.fillColor = style.fillColor.cgColor
        marqueeLayer.strokeColor = style.strokeColor.cgColor
    }

    private func updateMarqueePath(with rect: NSRect) {
        marqueeLayer.path = CGPath(rect: rect, transform: nil)
    }
}

private final class HoverTrackingImageView: NSImageView {
    var onHoverChanged: ((Bool) -> Void)?
    private var hoverTrackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTrackingArea {
            removeTrackingArea(hoverTrackingArea)
        }
        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.inVisibleRect, .activeInKeyWindow, .mouseEnteredAndExited],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        hoverTrackingArea = trackingArea
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        onHoverChanged?(true)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        onHoverChanged?(false)
    }
}

private final class LibraryHoverTooltip: NSView {
    static let shared = LibraryHoverTooltip()
    private let label = NSTextField(labelWithString: "")
    private var hideTimer: Timer?

    private lazy var tooltipWindow: NSWindow = {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 80, height: 28),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .popUpMenu
        window.ignoresMouseEvents = true
        window.contentView = self
        return window
    }()

    private override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.8).cgColor
        layer?.cornerRadius = 6

        label.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        label.textColor = .white
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6)
        ])
    }

    required init?(coder: NSCoder) { nil }

    func show(text: String, relativeTo view: NSView) {
        hideTimer?.invalidate()
        label.stringValue = text
        let textSize = label.intrinsicContentSize
        let width = textSize.width + 20
        let height = textSize.height + 12

        guard let window = view.window else { return }
        let frameInWindow = view.convert(view.bounds, to: nil)
        let frameOnScreen = window.convertToScreen(frameInWindow)
        var x = frameOnScreen.midX - width / 2
        let y = frameOnScreen.maxY + 6
        if let screen = window.screen {
            let visible = screen.visibleFrame
            if x < visible.minX + 4 {
                x = visible.minX + 4
            }
            if x + width > visible.maxX - 4 {
                x = visible.maxX - width - 4
            }
        }

        frame = NSRect(x: 0, y: 0, width: width, height: height)
        tooltipWindow.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
        tooltipWindow.orderFront(nil)
    }

    func hide() {
        hideTimer?.invalidate()
        tooltipWindow.orderOut(nil)
    }

    func hideAfterDelay(_ delay: TimeInterval = 0.1) {
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.hide()
        }
    }
}

private final class HoverTooltipContainerView: NSView {
    var tooltipText: String?
    var onPressed: (() -> Void)?
    private var tooltipTrackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tooltipTrackingArea {
            removeTrackingArea(tooltipTrackingArea)
        }
        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.inVisibleRect, .activeInKeyWindow, .mouseEnteredAndExited],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        tooltipTrackingArea = trackingArea
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        guard let tooltipText, !tooltipText.isEmpty else { return }
        LibraryHoverTooltip.shared.show(text: tooltipText, relativeTo: self)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        LibraryHoverTooltip.shared.hideAfterDelay()
    }

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        guard event.type == .leftMouseUp else { return }
        onPressed?()
    }
}

private final class LibraryCollectionItem: NSCollectionViewItem {
    private let fileService = LibraryFileService.shared
    private let thumbnailService = ThumbnailService.shared
    private let previewImageView = HoverTrackingImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let keepBadgeContainerView = HoverTooltipContainerView()
    private let keepBadgeIconView = NSImageView()
    private var imageHeightConstraint: NSLayoutConstraint?
    private var isKeptItem = false
    private var isHoveredOnPreview = false
    private var onKeepRequested: (() -> Void)?
    private var reuseToken = UUID()
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    override var isSelected: Bool {
        didSet {
            updateSelectionStyle()
            updateKeepControlVisibility()
        }
    }

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.layer?.cornerRadius = 8
        view.layer?.borderWidth = 1
        view.layer?.borderColor = NSColor.separatorColor.cgColor
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        previewImageView.imageScaling = .scaleProportionallyUpOrDown
        previewImageView.wantsLayer = true
        previewImageView.layer?.cornerRadius = 6
        previewImageView.layer?.masksToBounds = true
        previewImageView.translatesAutoresizingMaskIntoConstraints = false
        previewImageView.onHoverChanged = { [weak self] isHovering in
            guard let self else { return }
            self.isHoveredOnPreview = isHovering
            self.updateKeepControlVisibility()
        }

        titleLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        titleLabel.lineBreakMode = .byTruncatingMiddle
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        subtitleLabel.font = NSFont.systemFont(ofSize: 11)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.lineBreakMode = .byTruncatingTail
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        let keepStyle = resolveLibraryKeepBadgeStyle()
        let keepMetrics = resolveLibraryKeepControlMetrics()
        keepBadgeContainerView.wantsLayer = true
        keepBadgeContainerView.layer?.backgroundColor = keepStyle.backgroundColor.cgColor
        keepBadgeContainerView.layer?.borderColor = keepStyle.borderColor.cgColor
        keepBadgeContainerView.layer?.borderWidth = 1
        keepBadgeContainerView.translatesAutoresizingMaskIntoConstraints = false
        keepBadgeContainerView.tooltipText = resolveLibraryKeepTooltipText(isKept: false)
        keepBadgeContainerView.onPressed = { [weak self] in
            self?.onKeepRequested?()
        }
        keepBadgeContainerView.setAccessibilityIdentifier("library.item.keepBadge")

        if #available(macOS 11.0, *) {
            keepBadgeIconView.image = NSImage(
                systemSymbolName: keepStyle.symbolName,
                accessibilityDescription: "Kept"
            )
        }
        keepBadgeIconView.contentTintColor = keepStyle.iconTintColor
        keepBadgeIconView.imageScaling = .scaleProportionallyDown
        keepBadgeIconView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(previewImageView)
        view.addSubview(titleLabel)
        view.addSubview(subtitleLabel)
        view.addSubview(keepBadgeContainerView)
        keepBadgeContainerView.addSubview(keepBadgeIconView)

        NSLayoutConstraint.activate([
            previewImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            previewImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            previewImageView.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),

            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            titleLabel.topAnchor.constraint(equalTo: previewImageView.bottomAnchor, constant: 8),

            subtitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            subtitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),

            keepBadgeContainerView.topAnchor.constraint(equalTo: previewImageView.topAnchor, constant: 6),
            keepBadgeContainerView.trailingAnchor.constraint(equalTo: previewImageView.trailingAnchor, constant: -6),
            keepBadgeContainerView.widthAnchor.constraint(equalToConstant: keepMetrics.keptBadgeDiameter),
            keepBadgeContainerView.heightAnchor.constraint(equalToConstant: keepMetrics.keptBadgeDiameter),

            keepBadgeIconView.centerXAnchor.constraint(equalTo: keepBadgeContainerView.centerXAnchor),
            keepBadgeIconView.centerYAnchor.constraint(equalTo: keepBadgeContainerView.centerYAnchor),
            keepBadgeIconView.widthAnchor.constraint(equalToConstant: 16),
            keepBadgeIconView.heightAnchor.constraint(equalToConstant: 16)
        ])
        keepBadgeContainerView.layer?.cornerRadius = keepMetrics.keptBadgeDiameter / 2
        imageHeightConstraint = previewImageView.heightAnchor.constraint(equalToConstant: 120)
        imageHeightConstraint?.isActive = true
        applyKeepControlStyle(isKept: false)
        updateKeepControlVisibility()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        reuseToken = UUID()
        onKeepRequested = nil
        isHoveredOnPreview = false
        isKeptItem = false
        previewImageView.image = nil
        keepBadgeContainerView.isHidden = true
    }

    func configure(with item: LibraryItem, onKeepRequested: @escaping () -> Void) {
        let token = UUID()
        reuseToken = token
        previewImageView.image = nil
        titleLabel.stringValue = item.url.lastPathComponent
        subtitleLabel.stringValue = dateFormatter.string(from: item.createdAt)
        self.onKeepRequested = onKeepRequested
        isKeptItem = item.isKept
        isHoveredOnPreview = false
        imageHeightConstraint?.constant = 120
        titleLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        subtitleLabel.isHidden = false
        updateKeepControlVisibility()
        updateSelectionStyle()

        thumbnailService.thumbnail(for: item) { [weak self] thumb in
            guard let self, self.reuseToken == token else { return }
            self.previewImageView.image = thumb
        }
    }

    private func updateSelectionStyle() {
        let borderColor = resolveLibraryItemBorderColor(isSelected: isSelected, isKept: isKeptItem)
        view.layer?.borderColor = borderColor.cgColor
        view.layer?.borderWidth = isSelected ? 2 : 1
    }

    private func updateKeepControlVisibility() {
        let state = resolveLibraryKeepControlState(
            isKept: isKeptItem,
            isHoveredOnPreview: isHoveredOnPreview,
            isSelected: isSelected
        )
        LibraryHoverTooltip.shared.hideAfterDelay(0)
        switch state {
        case .hidden:
            keepBadgeContainerView.isHidden = true
        case .keepActionButton:
            applyKeepControlStyle(isKept: false)
            keepBadgeContainerView.isHidden = false
        case .keptBadge:
            applyKeepControlStyle(isKept: true)
            keepBadgeContainerView.isHidden = false
        }
    }

    private func applyKeepControlStyle(isKept: Bool) {
        let keepStyle = resolveLibraryKeepBadgeStyle()
        let keepActionStyle = resolveLibraryKeepActionButtonStyle()
        let styleSymbolName = isKept ? keepStyle.symbolName : keepActionStyle.symbolName
        let styleIconTintColor = isKept ? keepStyle.iconTintColor : keepActionStyle.iconTintColor
        let styleBackgroundColor = isKept ? keepStyle.backgroundColor : keepActionStyle.backgroundColor
        let styleBorderColor = isKept ? keepStyle.borderColor : keepActionStyle.borderColor

        keepBadgeContainerView.layer?.backgroundColor = styleBackgroundColor.cgColor
        keepBadgeContainerView.layer?.borderColor = styleBorderColor.cgColor
        keepBadgeIconView.contentTintColor = styleIconTintColor
        keepBadgeContainerView.tooltipText = resolveLibraryKeepTooltipText(isKept: isKept)

        if #available(macOS 11.0, *) {
            let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
            keepBadgeIconView.image = NSImage(
                systemSymbolName: styleSymbolName,
                accessibilityDescription: isKept ? "Unkeep" : "Keep"
            )?.withSymbolConfiguration(config)
        }
    }
}

private final class LibraryViewController: NSViewController, NSCollectionViewDataSource, NSCollectionViewDelegate {
    private let fileService = LibraryFileService.shared
    private let keepService = KeepMarkerService.shared
    private let trashService = TrashService.shared

    private var items: [LibraryItem] = []
    private var keyMonitor: Any?
    private var libraryContentObserver: Any?
    private var pendingReloadWorkItem: DispatchWorkItem?
    private var pendingReloadReason: String?
    private var viewerWindowController: ImageViewerWindowController?
    private var suppressLocalKeepReload = false
    private var cachedAllCount = 0

    private let filterControl = NSSegmentedControl(
        labels: ["All", "Kept"],
        trackingMode: .selectOne,
        target: nil,
        action: nil
    )
    private let cleanupButton = NSButton(title: "Cleanup Settings", target: nil, action: nil)
    private let cancelButton = NSButton(title: "Cancel", target: nil, action: nil)
    private let selectionCountLabel = NSTextField(labelWithString: "")
    private let copyButton = NSButton(title: "Copy", target: nil, action: nil)
    private let openButton = NSButton(title: "Open", target: nil, action: nil)
    private let keepButton = NSButton(title: "Keep", target: nil, action: nil)
    private let deleteButton = NSButton(title: "Delete", target: nil, action: nil)
    private let leftToolbarStack = NSStackView()
    private let rightToolbarStack = NSStackView()
    private let normalActionsStack = NSStackView()
    private let selectionActionsStack = NSStackView()

    private let emptyLabel = NSTextField(labelWithString: "")
    private let chooseFolderButton = NSButton(title: "Choose Screenshot Folder…", target: nil, action: nil)

    private let scrollView = NSScrollView()
    private let collectionView = LibraryCollectionView()
    private let flowLayout = NSCollectionViewFlowLayout()
    private var isSelectionDragInProgress = false

    private enum PreviewOpenSource {
        case spaceKey
        case doubleClick
        case other
    }

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureUI()
        applyStoredMode()
        installKeyMonitor()
        installLibraryContentObserver()
        reloadContent()
    }

    deinit {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }
        if let libraryContentObserver {
            NotificationCenter.default.removeObserver(libraryContentObserver)
        }
        pendingReloadWorkItem?.cancel()
        viewerWindowController?.close()
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        applyGridLayout()
    }

    func reloadContent() {
        do {
            items = try fileService.listItems(filter: SettingsStore.shared.libraryFilterMode)
            emptyLabel.isHidden = !items.isEmpty
            chooseFolderButton.isHidden = true
            scrollView.isHidden = items.isEmpty
            if items.isEmpty {
                emptyLabel.stringValue = "No screenshots found in selected folder."
            }
            collectionView.reloadData()
            refreshFilterLabels()
            updateActionButtons()
        } catch LibraryServiceError.folderNotConfigured {
            items = []
            collectionView.reloadData()
            emptyLabel.isHidden = false
            emptyLabel.stringValue = "No screenshot folder configured yet."
            chooseFolderButton.isHidden = false
            scrollView.isHidden = true
            applyFilterLabels(allCount: 0, keptCount: 0)
            updateActionButtons()
        } catch {
            items = []
            collectionView.reloadData()
            emptyLabel.isHidden = false
            emptyLabel.stringValue = error.localizedDescription
            chooseFolderButton.isHidden = false
            scrollView.isHidden = true
            applyFilterLabels(allCount: 0, keptCount: 0)
            updateActionButtons()
        }
    }

    private func configureUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        leftToolbarStack.orientation = .horizontal
        leftToolbarStack.alignment = .centerY
        leftToolbarStack.spacing = 8
        leftToolbarStack.translatesAutoresizingMaskIntoConstraints = false
        leftToolbarStack.addArrangedSubview(cancelButton)
        leftToolbarStack.addArrangedSubview(selectionCountLabel)

        normalActionsStack.orientation = .horizontal
        normalActionsStack.alignment = .centerY
        normalActionsStack.spacing = 8
        normalActionsStack.translatesAutoresizingMaskIntoConstraints = false
        normalActionsStack.addArrangedSubview(cleanupButton)

        selectionActionsStack.orientation = .horizontal
        selectionActionsStack.alignment = .centerY
        selectionActionsStack.spacing = 8
        selectionActionsStack.translatesAutoresizingMaskIntoConstraints = false
        selectionActionsStack.addArrangedSubview(copyButton)
        selectionActionsStack.addArrangedSubview(openButton)
        selectionActionsStack.addArrangedSubview(deleteButton)
        selectionActionsStack.addArrangedSubview(keepButton)
        selectionActionsStack.isHidden = true

        rightToolbarStack.orientation = .horizontal
        rightToolbarStack.alignment = .centerY
        rightToolbarStack.spacing = 0
        rightToolbarStack.translatesAutoresizingMaskIntoConstraints = false
        rightToolbarStack.addArrangedSubview(normalActionsStack)
        rightToolbarStack.addArrangedSubview(selectionActionsStack)

        emptyLabel.font = NSFont.systemFont(ofSize: 14)
        emptyLabel.textColor = .secondaryLabelColor
        emptyLabel.alignment = .center
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false

        chooseFolderButton.target = self
        chooseFolderButton.action = #selector(chooseFolderPressed)
        chooseFolderButton.translatesAutoresizingMaskIntoConstraints = false

        filterControl.translatesAutoresizingMaskIntoConstraints = false
        filterControl.target = self
        filterControl.action = #selector(filterModeChanged)
        filterControl.identifier = NSUserInterfaceItemIdentifier("library.control.filter")
        filterControl.setAccessibilityIdentifier("library.control.filter")
        cleanupButton.target = self
        cleanupButton.action = #selector(cleanupPressed)
        cleanupButton.setAccessibilityIdentifier("library.button.cleanup")
        cancelButton.target = self
        cancelButton.action = #selector(cancelSelectionPressed)
        cancelButton.title = ""
        if #available(macOS 11.0, *) {
            cancelButton.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close selection")
        }
        cancelButton.imagePosition = .imageOnly
        cancelButton.contentTintColor = .secondaryLabelColor
        cancelButton.bezelStyle = .texturedRounded
        cancelButton.identifier = NSUserInterfaceItemIdentifier("library.button.cancel")
        cancelButton.setAccessibilityIdentifier("library.button.cancel")
        cancelButton.isHidden = true
        selectionCountLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        selectionCountLabel.textColor = .secondaryLabelColor
        selectionCountLabel.isHidden = true
        selectionCountLabel.setAccessibilityIdentifier("library.label.selectionCount")
        copyButton.target = self
        copyButton.action = #selector(copyPressed)
        copyButton.identifier = NSUserInterfaceItemIdentifier("library.button.copy")
        copyButton.setAccessibilityIdentifier("library.button.copy")
        openButton.target = self
        openButton.action = #selector(openPressed)
        openButton.identifier = NSUserInterfaceItemIdentifier("library.button.open")
        openButton.setAccessibilityIdentifier("library.button.open")
        keepButton.target = self
        keepButton.action = #selector(keepPressed)
        keepButton.identifier = NSUserInterfaceItemIdentifier("library.button.keep")
        keepButton.setAccessibilityIdentifier("library.button.keep")
        deleteButton.target = self
        deleteButton.action = #selector(deletePressed)
        deleteButton.identifier = NSUserInterfaceItemIdentifier("library.button.delete")
        deleteButton.setAccessibilityIdentifier("library.button.delete")

        flowLayout.minimumLineSpacing = 10
        flowLayout.minimumInteritemSpacing = 10
        collectionView.collectionViewLayout = flowLayout
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.isSelectable = true
        collectionView.allowsMultipleSelection = true
        collectionView.onItemDoubleClicked = { [weak self] indexPath in
            guard let self, indexPath.item >= 0, indexPath.item < self.items.count else { return }
            self.collectionView.selectItems(at: [indexPath], scrollPosition: [])
            self.updateActionButtons()
            self.openCurrentSelection(source: .doubleClick)
        }
        collectionView.onSelectionDragStateChanged = { [weak self] isDragging in
            guard let self else { return }
            self.isSelectionDragInProgress = isDragging
            if !isDragging {
                self.updateActionButtons()
            }
        }
        collectionView.setAccessibilityIdentifier("library.collection")
        collectionView.register(LibraryCollectionItem.self, forItemWithIdentifier: .libraryCollectionItem)

        scrollView.documentView = collectionView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(leftToolbarStack)
        view.addSubview(filterControl)
        view.addSubview(rightToolbarStack)
        view.addSubview(scrollView)
        view.addSubview(emptyLabel)
        view.addSubview(chooseFolderButton)

        NSLayoutConstraint.activate([
            filterControl.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
            filterControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            leftToolbarStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            leftToolbarStack.centerYAnchor.constraint(equalTo: filterControl.centerYAnchor),
            leftToolbarStack.trailingAnchor.constraint(lessThanOrEqualTo: filterControl.leadingAnchor, constant: -10),

            rightToolbarStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            rightToolbarStack.centerYAnchor.constraint(equalTo: filterControl.centerYAnchor),
            filterControl.trailingAnchor.constraint(lessThanOrEqualTo: rightToolbarStack.leadingAnchor, constant: -10),

            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            scrollView.topAnchor.constraint(equalTo: filterControl.bottomAnchor, constant: 12),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -12),

            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -16),

            chooseFolderButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            chooseFolderButton.topAnchor.constraint(equalTo: emptyLabel.bottomAnchor, constant: 10)
        ])
    }

    private func applyStoredMode() {
        filterControl.selectedSegment = (SettingsStore.shared.libraryFilterMode == .all) ? 0 : 1
        applyGridLayout()
    }

    private func refreshFilterLabels() {
        let currentFilter = SettingsStore.shared.libraryFilterMode
        do {
            let allCount: Int
            let keptCount: Int
            switch currentFilter {
            case .all:
                allCount = items.count
                keptCount = items.filter(\.isKept).count
            case .kept:
                keptCount = items.count
                allCount = try fileService.countImageFiles()
            }
            cachedAllCount = allCount
            applyFilterLabels(allCount: allCount, keptCount: keptCount)
        } catch {
            cachedAllCount = 0
            applyFilterLabels(allCount: 0, keptCount: 0)
        }
    }

    private func applyFilterLabels(allCount: Int, keptCount: Int) {
        let labelState = resolveLibraryFilterLabelState(allCount: allCount, keptCount: keptCount)
        filterControl.setLabel(labelState.allLabel, forSegment: 0)
        filterControl.setLabel(labelState.keptLabel, forSegment: 1)
    }

    private func applyGridLayout() {
        flowLayout.itemSize = NSSize(width: 180, height: 180)
        flowLayout.sectionInset = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
    }

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            guard let window = self.view.window, window.isKeyWindow else { return event }

            switch resolveLibraryKeyboardAction(keyCode: event.keyCode, modifierFlags: event.modifierFlags) {
            case .deleteSelection:
                self.deleteCurrentSelection()
                return nil
            case .copySelection:
                self.copyCurrentSelection()
                return nil
            case .openFromSpace:
                if let viewer = self.viewerWindowController, viewer.isWindowVisible {
                    if viewer.canCloseWithSpaceToggle {
                        viewer.close()
                    }
                    return nil
                }
                self.openCurrentSelection(source: .spaceKey)
                return nil
            case .openFromReturn:
                self.openCurrentSelection(source: .other)
                return nil
            case .none:
                return event
            }
        }
    }

    private func installLibraryContentObserver() {
        guard libraryContentObserver == nil else { return }
        libraryContentObserver = NotificationCenter.default.addObserver(
            forName: .libraryContentDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            guard self.view.window?.isVisible == true else { return }
            let reason = notification.userInfo?["reason"] as? String
            let shouldSchedule = resolveLibraryShouldScheduleReload(
                notificationReason: reason,
                suppressLocalKeepReload: self.suppressLocalKeepReload
            )
            guard shouldSchedule else { return }
            self.scheduleReloadContent(reason: reason)
        }
    }

    private func scheduleReloadContent(reason: String?) {
        pendingReloadWorkItem?.cancel()
        pendingReloadReason = reason
        let work = DispatchWorkItem { [weak self] in
            self?.pendingReloadReason = nil
            self?.reloadContent()
        }
        pendingReloadWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
    }

    private func updateFilterLabelsAfterKeepMutation() {
        let mode = SettingsStore.shared.libraryFilterMode
        switch mode {
        case .all:
            let allCount = items.count
            let keptCount = items.filter(\.isKept).count
            cachedAllCount = allCount
            applyFilterLabels(allCount: allCount, keptCount: keptCount)
        case .kept:
            let allCount = max(0, cachedAllCount)
            let keptCount = items.count
            applyFilterLabels(allCount: allCount, keptCount: keptCount)
        }
    }

    private func applyKeepMutationToVisibleData(indexes: [Int], target: Bool) {
        guard !indexes.isEmpty else { return }
        let validIndexes = indexes.filter { $0 >= 0 && $0 < items.count }.sorted()
        guard !validIndexes.isEmpty else { return }

        switch SettingsStore.shared.libraryFilterMode {
        case .all:
            for index in validIndexes {
                items[index].isKept = target
            }
            let indexPaths = Set(validIndexes.map { IndexPath(item: $0, section: 0) })
            collectionView.reloadItems(at: indexPaths)
        case .kept:
            if target {
                for index in validIndexes {
                    items[index].isKept = true
                }
                let indexPaths = Set(validIndexes.map { IndexPath(item: $0, section: 0) })
                collectionView.reloadItems(at: indexPaths)
            } else {
                for index in validIndexes.reversed() {
                    items.remove(at: index)
                }
                collectionView.deselectAll(nil)
                collectionView.reloadData()
            }
        }

        emptyLabel.isHidden = !items.isEmpty
        scrollView.isHidden = items.isEmpty
        if items.isEmpty {
            emptyLabel.stringValue = "No screenshots found in selected folder."
        }
        updateFilterLabelsAfterKeepMutation()
        updateActionButtons()
    }

    private var selectedIndexes: [Int] {
        collectionView.selectionIndexPaths
            .map(\.item)
            .filter { $0 >= 0 && $0 < items.count }
            .sorted()
    }

    private var selectedItems: [LibraryItem] {
        selectedIndexes.map { items[$0] }
    }

    private func updateActionButtons() {
        let selectionCount = selectedItems.count
        let state = resolveLibraryActionState(
            selectionCount: selectionCount,
            allSelectedKept: selectedItems.allSatisfy(\.isKept)
        )

        // For marquee drag selection, defer visibility changes until drag ends
        // to avoid flickering while selected count is changing continuously.
        if !isSelectionDragInProgress {
            filterControl.isHidden = state.showsSelectionActions
            cancelButton.isHidden = !state.showsSelectionActions
            selectionCountLabel.isHidden = !state.showsSelectionActions
            normalActionsStack.isHidden = state.showsSelectionActions
            selectionActionsStack.isHidden = !state.showsSelectionActions
        }
        selectionCountLabel.stringValue = resolveLibrarySelectionCountText(selectionCount)
        cancelButton.isEnabled = !cancelButton.isHidden && selectionCount > 0
        copyButton.isEnabled = !selectionActionsStack.isHidden && state.copyEnabled
        openButton.isEnabled = !selectionActionsStack.isHidden && state.openEnabled
        keepButton.isEnabled = !selectionActionsStack.isHidden && state.keepEnabled
        deleteButton.isEnabled = !selectionActionsStack.isHidden && state.deleteEnabled
        keepButton.title = state.keepTitle
    }

    private func copyCurrentSelection() {
        let indexes = selectedIndexes
        guard !indexes.isEmpty else {
            return
        }
        do {
            let images = try indexes.map { try fileService.loadImage(for: items[$0]) }
            try ClipboardService.shared.copy(images: images, prompt: "")
            let toastKey = resolveLibraryCopyHUDKey(copiedCount: images.count)
            let message = images.count > 1 ? L(toastKey, images.count) : L(toastKey)
            HUDService.shared.show(message: message, style: .success, duration: 1.0)
        } catch {
            HUDService.shared.show(message: error.localizedDescription, style: .error, duration: 1.4)
        }
    }

    private func openCurrentSelection(source: PreviewOpenSource = .other) {
        guard
            let index = resolveLibraryPrimarySelectedIndex(
                selectedIndexes: selectedIndexes,
                selectedItemCount: selectedItems.count
            ),
            index >= 0, index < items.count
        else {
            return
        }
        viewerWindowController?.close()
        let entryMode: ImageViewerEntryMode = (source == .spaceKey)
            ? .spaceToggleClosable
            : .closeButtonOnly
        let viewer = ImageViewerWindowController(
            items: items,
            initialIndex: index,
            entryMode: entryMode,
            anchorWindowFrame: view.window?.frame
        )
        viewer.onKeepChanged = { [weak self] url, isKept in
            guard let self else { return }
            if self.pendingReloadReason == "keep" {
                self.pendingReloadWorkItem?.cancel()
                self.pendingReloadWorkItem = nil
                self.pendingReloadReason = nil
            }
            if let itemIndex = self.items.firstIndex(where: { $0.url == url }) {
                self.applyKeepMutationToVisibleData(indexes: [itemIndex], target: isKept)
            } else {
                self.reloadContent()
            }
        }
        viewer.onItemDeleted = { [weak self] url in
            guard let self else { return }
            self.items.removeAll(where: { $0.url == url })
            self.reloadContent()
        }
        viewer.onClosed = { [weak self] in
            self?.viewerWindowController = nil
        }
        viewerWindowController = viewer
        viewer.show()
    }

    private func toggleKeepForItem(url: URL) {
        guard let itemIndex = items.firstIndex(where: { $0.url == url }) else { return }
        if !CapabilityService.shared.canUse(.libraryKeep) {
            PaywallWindowController.shared.show()
            return
        }

        let target = !items[itemIndex].isKept
        do {
            suppressLocalKeepReload = true
            defer { suppressLocalKeepReload = false }
            try keepService.setKept(target, for: url)
            applyKeepMutationToVisibleData(indexes: [itemIndex], target: target)
        } catch {
            HUDService.shared.show(message: error.localizedDescription, style: .error, duration: 1.4)
        }
    }

    private func toggleKeepForCurrentSelection() {
        let indexes = selectedIndexes
        guard !indexes.isEmpty else { return }
        if !CapabilityService.shared.canUse(.libraryKeep) {
            PaywallWindowController.shared.show()
            return
        }

        let target = !indexes.allSatisfy { items[$0].isKept }
        var updatedCount = 0
        var failureCount = 0
        var updatedIndexes: [Int] = []

        suppressLocalKeepReload = true
        defer { suppressLocalKeepReload = false }

        for index in indexes {
            do {
                try keepService.setKept(target, for: items[index].url)
                updatedCount += 1
                updatedIndexes.append(index)
            } catch {
                failureCount += 1
            }
        }

        if updatedCount > 0 {
            applyKeepMutationToVisibleData(indexes: updatedIndexes, target: target)
        }

        let noun = updatedCount == 1 ? "item" : "items"
        let message: String
        let style: HUDService.Style
        if failureCount == 0 {
            message = target
                ? "Marked \(updatedCount) \(noun) as kept."
                : "Removed \(updatedCount) \(noun) from kept."
            style = .info
        } else if updatedCount > 0 {
            message = "Updated \(updatedCount) \(noun), \(failureCount) failed."
            style = .error
        } else {
            message = "Failed to update selected items."
            style = .error
        }
        HUDService.shared.show(message: message, style: style, duration: 1.2)
    }

    private func deleteCurrentSelection() {
        let indexes = selectedIndexes
        guard !indexes.isEmpty else { return }
        let selected = indexes.map { items[$0] }
        if resolveDeleteRequiresConfirmation(itemCount: selected.count) {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "Delete \(selected.count) Screenshots?"
            alert.informativeText = "The screenshot will be moved to Trash."
            alert.addButton(withTitle: "Delete")
            alert.addButton(withTitle: "Cancel")
            let response = alert.runModal()
            guard response == .alertFirstButtonReturn else { return }
        }

        var movedCount = 0
        var failureCount = 0
        for item in selected {
            do {
                try trashService.moveToTrash(item.url)
                movedCount += 1
            } catch {
                failureCount += 1
            }
        }

        if movedCount > 0 {
            reloadContent()
        }

        let noun = movedCount == 1 ? "item" : "items"
        let message: String
        let style: HUDService.Style
        if failureCount == 0 {
            message = movedCount == 1 ? "Moved to Trash" : "Moved \(movedCount) \(noun) to Trash"
            style = .info
        } else if movedCount > 0 {
            message = "Moved \(movedCount) \(noun) to Trash, \(failureCount) failed."
            style = .error
        } else {
            message = "Failed to move selected items to Trash."
            style = .error
        }
        HUDService.shared.show(message: message, style: style, duration: 1.2)
    }

    // MARK: - Actions

    @objc private func filterModeChanged() {
        let mode: LibraryFilterMode = (filterControl.selectedSegment == 1) ? .kept : .all
        SettingsStore.shared.libraryFilterMode = mode
        reloadContent()
    }

    @objc private func cleanupPressed() {
        if !CapabilityService.shared.canUse(.libraryAutoCleanup) {
            PendingNavigationState.shared.openCleanupSettingsAfterUpgrade = true
            PaywallWindowController.shared.show()
            return
        }
        NotificationCenter.default.post(name: .requestOpenCleanupSettings, object: nil)
    }

    @objc private func openPressed() {
        openCurrentSelection(source: .other)
    }

    @objc private func copyPressed() {
        copyCurrentSelection()
    }

    @objc private func cancelSelectionPressed() {
        collectionView.deselectAll(nil)
        updateActionButtons()
    }

    @objc private func keepPressed() {
        toggleKeepForCurrentSelection()
    }

    @objc private func deletePressed() {
        deleteCurrentSelection()
    }

    @objc private func chooseFolderPressed() {
        do {
            if let _ = try ScreenshotSaveService.shared.chooseAndStoreFolder() {
                reloadContent()
            }
        } catch {
            HUDService.shared.show(message: error.localizedDescription, style: .error, duration: 1.4)
        }
    }

    // MARK: - NSCollectionViewDataSource

    func numberOfSections(in collectionView: NSCollectionView) -> Int { 1 }

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        items.count
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItem(
            withIdentifier: .libraryCollectionItem,
            for: indexPath
        )
        guard let libraryItem = item as? LibraryCollectionItem else { return item }
        let current = items[indexPath.item]
        libraryItem.configure(with: current) { [weak self] in
            self?.toggleKeepForItem(url: current.url)
        }
        return libraryItem
    }

    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        updateActionButtons()
    }

    func collectionView(_ collectionView: NSCollectionView, didDeselectItemsAt indexPaths: Set<IndexPath>) {
        updateActionButtons()
    }
}

enum ImageViewerEntryMode {
    case spaceToggleClosable
    case closeButtonOnly
}

func resolveImageViewerCloseAction(for keyCode: UInt16, entryMode: ImageViewerEntryMode) -> Bool {
    switch keyCode {
    case 53: // esc
        return true
    case 49: // space
        return entryMode == .spaceToggleClosable
    default:
        return false
    }
}

struct ImageViewerNavigationIconAssets {
    let previous: String
    let next: String
}

func resolveImageViewerNavigationIconAssets() -> ImageViewerNavigationIconAssets {
    ImageViewerNavigationIconAssets(
        previous: "arrow-left-line",
        next: "arrow-right-line"
    )
}

enum ImageViewerSwipeNavigation: Equatable {
    case previous
    case next
}

func resolveImageViewerSwipeNavigation(deltaX: CGFloat) -> ImageViewerSwipeNavigation {
    // Requirement-aligned mapping: swipe left => next, swipe right => previous.
    deltaX > 0 ? .next : .previous
}

private func resolveIntersectionArea(_ lhs: NSRect, _ rhs: NSRect) -> CGFloat {
    let intersection = lhs.intersection(rhs)
    guard !intersection.isNull else { return 0 }
    return intersection.width * intersection.height
}

func resolveImageViewerOverlayFrame(
    anchorWindowFrame: NSRect?,
    mouseLocation: NSPoint,
    screenFrames: [NSRect],
    mainScreenFrame: NSRect?
) -> NSRect {
    if let anchorWindowFrame {
        let bestAnchorScreen = screenFrames.max(by: {
            resolveIntersectionArea($0, anchorWindowFrame) < resolveIntersectionArea($1, anchorWindowFrame)
        })
        if let bestAnchorScreen, resolveIntersectionArea(bestAnchorScreen, anchorWindowFrame) > 0 {
            return bestAnchorScreen
        }
    }
    if let hovered = screenFrames.first(where: { NSMouseInRect(mouseLocation, $0, false) }) {
        return hovered
    }
    if let mainScreenFrame {
        return mainScreenFrame
    }
    if let firstScreenFrame = screenFrames.first {
        return firstScreenFrame
    }
    // Conservative fallback for unexpected headless/bootstrapping states.
    return NSRect(x: 0, y: 0, width: 1440, height: 900)
}

func resolveImageViewerIndexAfterDelete(currentIndex: Int, itemCountAfterDeletion: Int) -> Int? {
    guard itemCountAfterDeletion > 0 else { return nil }
    return min(max(0, currentIndex), itemCountAfterDeletion - 1)
}

func resolveDeleteRequiresConfirmation(itemCount: Int) -> Bool {
    itemCount > 1
}

struct ImageViewerBackdropStyle {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    let tintAlpha: CGFloat
    let snapshotBlurRadius: Double
    let snapshotDownsampleScale: CGFloat
    let transitionDuration: TimeInterval
}

enum ImageViewerBackdropRenderMode: Equatable {
    case systemMaterial
    case capturedBlurSnapshot
}

func resolveImageViewerBackdropRenderMode(
    reduceTransparencyEnabled: Bool
) -> ImageViewerBackdropRenderMode {
    reduceTransparencyEnabled ? .capturedBlurSnapshot : .systemMaterial
}

func resolveImageViewerBackdropStyle() -> ImageViewerBackdropStyle {
    // Keep a dark overlay and layer blur behind it for depth.
    ImageViewerBackdropStyle(
        material: .underWindowBackground,
        blendingMode: .behindWindow,
        tintAlpha: 0.5,
        snapshotBlurRadius: 100,
        snapshotDownsampleScale: 0.35,
        transitionDuration: 0.16
    )
}

func resolveImageViewerValidatedDownsampleScale(_ value: CGFloat) -> CGFloat {
    min(1, max(0.1, value))
}

func resolveImageViewerBlurRadiusForDownsample(
    snapshotBlurRadius: Double,
    downsampleScale: CGFloat
) -> Double {
    max(0, snapshotBlurRadius * Double(resolveImageViewerValidatedDownsampleScale(downsampleScale)))
}

func resolveImageViewerShouldRefreshBackdropSnapshot(
    previousFrame: NSRect?,
    currentFrame: NSRect,
    hasSnapshotImage: Bool,
    forceRefresh: Bool
) -> Bool {
    if forceRefresh { return true }
    guard hasSnapshotImage else { return true }
    guard let previousFrame else { return true }
    return previousFrame.integral != currentFrame.integral
}

func resolveImageViewerOverlayWindowLevel() -> NSWindow.Level {
    .floating
}

func resolveImageViewerOverlayCollectionBehavior() -> NSWindow.CollectionBehavior {
    [.moveToActiveSpace, .fullScreenAuxiliary]
}

enum ImageViewerBackdropCapturePolicy: Equatable {
    case onScreenBelowOverlayWindow
    case onScreenOnly
}

func resolveImageViewerBackdropCapturePolicies(
    hasOverlayWindowNumber: Bool
) -> [ImageViewerBackdropCapturePolicy] {
    hasOverlayWindowNumber
        ? [.onScreenBelowOverlayWindow, .onScreenOnly]
        : [.onScreenOnly]
}

func resolveImageViewerBackdropSnapshotScaling() -> NSImageScaling {
    .scaleAxesIndependently
}

func resolveImageViewerImageContainerBackgroundColor() -> NSColor? {
    nil
}

func resolveImageViewerImageCornerRadius() -> CGFloat {
    8
}

func resolveImageViewerImageScaling() -> NSImageScaling {
    .scaleProportionallyDown
}

func resolveImageViewerMaxContainerSize(overlayBounds: NSRect) -> NSSize {
    guard overlayBounds.width > 1, overlayBounds.height > 1 else { return .zero }
    let maxWidth = max(1, min(overlayBounds.width * 0.82, overlayBounds.width - 32))
    let maxHeight = max(1, min(overlayBounds.height * 0.78, overlayBounds.height - 72))
    return NSSize(width: maxWidth, height: maxHeight)
}

func resolveImageViewerDisplayedImageSize(
    imageSize: NSSize?,
    maxContainerSize: NSSize
) -> NSSize {
    guard maxContainerSize.width > 0, maxContainerSize.height > 0 else { return .zero }
    guard let imageSize, imageSize.width > 0, imageSize.height > 0 else { return maxContainerSize }

    let widthScale = maxContainerSize.width / imageSize.width
    let heightScale = maxContainerSize.height / imageSize.height
    let scale = min(1, widthScale, heightScale) // Never upscale images.
    return NSSize(
        width: max(1, floor(imageSize.width * scale)),
        height: max(1, floor(imageSize.height * scale))
    )
}

func resolveImageViewerShouldCloseOnBackgroundClick(
    hitView: NSView?,
    imageView: NSView,
    interactiveViews: [NSView]
) -> Bool {
    guard let hitView else { return true }
    if hitView === imageView || hitView.isDescendant(of: imageView) {
        return false
    }
    for view in interactiveViews where hitView === view || hitView.isDescendant(of: view) {
        return false
    }
    return true
}

func resolveImageViewerNavigationButtonAlpha(isEnabled: Bool) -> CGFloat {
    isEnabled ? 1.0 : 0.28
}

/// Convert an AppKit (bottom-left origin, Y-up) rect to CG screen-space
/// (top-left origin, Y-down) used by `CGWindowListCreateImage`.
func resolveImageViewerCGCaptureRect(
    appKitRect: NSRect,
    primaryScreenHeight: CGFloat
) -> CGRect {
    CGRect(
        x: appKitRect.origin.x,
        y: primaryScreenHeight - appKitRect.maxY,
        width: appKitRect.width,
        height: appKitRect.height
    )
}

private final class SolidTintView: NSView {
    var fillColor: NSColor = .clear { didSet { needsDisplay = true } }
    override func draw(_ dirtyRect: NSRect) {
        fillColor.setFill()
        dirtyRect.fill()
    }
}

private final class ViewerOverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }
}

private final class ImageViewerWindowController: NSWindowController, NSWindowDelegate {
    private var items: [LibraryItem]
    private var currentIndex: Int
    private var keyMonitor: Any?
    private var swipeMonitor: Any?
    private var clickMonitor: Any?
    private var lastSwipeAt: Date = .distantPast
    private var lastBackdropSnapshotFrame: NSRect?
    private var isClosingAnimated = false
    private let entryMode: ImageViewerEntryMode
    private let anchorWindowFrame: NSRect?
    private let backdropRenderMode: ImageViewerBackdropRenderMode
    private let backdropStyle = resolveImageViewerBackdropStyle()

    var onKeepChanged: ((URL, Bool) -> Void)?
    var onItemDeleted: ((URL) -> Void)?
    var onClosed: (() -> Void)?

    var canCloseWithSpaceToggle: Bool { entryMode == .spaceToggleClosable }
    var isWindowVisible: Bool { window?.isVisible == true }

    private let blurView = NSVisualEffectView()
    private let backdropSnapshotView = NSImageView()
    private let dimTintView = SolidTintView()
    private let imageView = NSImageView()
    private let closeButton = NSButton(title: "", target: nil, action: nil)
    private let prevButton = NSButton(title: "", target: nil, action: nil)
    private let nextButton = NSButton(title: "", target: nil, action: nil)
    private let keepButton = NSButton(title: "Keep", target: nil, action: nil)
    private let copyButton = NSButton(title: "Copy", target: nil, action: nil)
    private let deleteButton = NSButton(title: "Delete", target: nil, action: nil)
    private let finderButton = NSButton(title: "Show in Finder", target: nil, action: nil)
    private lazy var actionRow: NSStackView = {
        let row = NSStackView(views: [copyButton, keepButton, deleteButton, finderButton])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        return row
    }()

    private let navigationIconAssets = resolveImageViewerNavigationIconAssets()

    private let keepService = KeepMarkerService.shared
    private let trashService = TrashService.shared
    private let fileService = LibraryFileService.shared
    private let ciContext = CIContext(options: nil)

    init(
        items: [LibraryItem],
        initialIndex: Int,
        entryMode: ImageViewerEntryMode,
        anchorWindowFrame: NSRect?
    ) {
        self.items = items
        self.currentIndex = max(0, min(initialIndex, max(0, items.count - 1)))
        self.entryMode = entryMode
        self.anchorWindowFrame = anchorWindowFrame
        self.backdropRenderMode = resolveImageViewerBackdropRenderMode(
            reduceTransparencyEnabled: NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
        )

        let initialFrame = resolveImageViewerOverlayFrame(
            anchorWindowFrame: anchorWindowFrame,
            mouseLocation: NSEvent.mouseLocation,
            screenFrames: NSScreen.screens.map(\.frame),
            mainScreenFrame: NSScreen.main?.frame
        )
        let window = ViewerOverlayWindow(
            contentRect: initialFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.setAccessibilityIdentifier("library.viewer.window")
        window.isReleasedWhenClosed = false
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.level = resolveImageViewerOverlayWindowLevel()
        window.collectionBehavior = resolveImageViewerOverlayCollectionBehavior()
        super.init(window: window)
        window.delegate = self
        configureUI()
        refreshUI()
        installKeyMonitor()
        installSwipeMonitor()
        installClickMonitor()
    }

    required init?(coder: NSCoder) { nil }

    deinit {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }
        if let swipeMonitor {
            NSEvent.removeMonitor(swipeMonitor)
        }
        if let clickMonitor {
            NSEvent.removeMonitor(clickMonitor)
        }
    }

    func windowWillClose(_ notification: Notification) {
        onClosed?()
    }

    func windowDidResize(_ notification: Notification) {
        if let frame = window?.frame {
            refreshBackdropSnapshotIfNeeded(for: frame)
        }
        layoutOverlay()
    }

    func show() {
        guard let window else { return }
        let expectedFrame = resolveImageViewerOverlayFrame(
            anchorWindowFrame: anchorWindowFrame,
            mouseLocation: NSEvent.mouseLocation,
            screenFrames: NSScreen.screens.map(\.frame),
            mainScreenFrame: NSScreen.main?.frame
        )
        window.setFrame(expectedFrame, display: false)
        layoutOverlay()

        NSApp.activate(ignoringOtherApps: true)
        window.alphaValue = 0
        window.makeKeyAndOrderFront(nil)
        window.setFrame(expectedFrame, display: true)
        refreshBackdropSnapshotIfNeeded(for: window.frame, forceRefresh: true)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = backdropStyle.transitionDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1
        }
        DispatchQueue.main.async { [weak self, weak window] in
            guard let self, let window else { return }
            window.setFrame(expectedFrame, display: false)
            self.refreshBackdropSnapshotIfNeeded(for: window.frame)
            self.layoutOverlay()
        }
    }

    private func configureUI() {
        guard let contentView = window?.contentView else { return }
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.clear.cgColor

        blurView.material = backdropStyle.material
        blurView.blendingMode = backdropStyle.blendingMode
        blurView.state = .active
        blurView.isHidden = backdropRenderMode == .capturedBlurSnapshot

        backdropSnapshotView.imageScaling = resolveImageViewerBackdropSnapshotScaling()
        backdropSnapshotView.isHidden = backdropRenderMode != .capturedBlurSnapshot

        dimTintView.fillColor = NSColor.black.withAlphaComponent(backdropStyle.tintAlpha)

        imageView.imageScaling = resolveImageViewerImageScaling()
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = resolveImageViewerImageCornerRadius()
        imageView.layer?.masksToBounds = true
        imageView.layer?.backgroundColor = resolveImageViewerImageContainerBackgroundColor()?.cgColor

        configureIconButton(closeButton, fallbackSymbolName: "xmark")
        configureIconButton(prevButton, fallbackSymbolName: "arrow.left")
        configureIconButton(nextButton, fallbackSymbolName: "arrow.right")
        closeButton.setAccessibilityIdentifier("library.viewer.close")
        prevButton.setAccessibilityIdentifier("library.viewer.prev")
        nextButton.setAccessibilityIdentifier("library.viewer.next")

        closeButton.target = self
        closeButton.action = #selector(closePressed)
        prevButton.target = self
        prevButton.action = #selector(prevPressed)
        nextButton.target = self
        nextButton.action = #selector(nextPressed)
        keepButton.target = self
        keepButton.action = #selector(keepPressed)
        copyButton.target = self
        copyButton.action = #selector(copyPressed)
        deleteButton.target = self
        deleteButton.action = #selector(deletePressed)
        finderButton.target = self
        finderButton.action = #selector(showInFinderPressed)

        contentView.addSubview(blurView)
        contentView.addSubview(backdropSnapshotView)
        contentView.addSubview(dimTintView)
        contentView.addSubview(imageView)
        contentView.addSubview(closeButton)
        contentView.addSubview(prevButton)
        contentView.addSubview(nextButton)
        contentView.addSubview(actionRow)

        applyNavigationIconsFromBundle()
        layoutOverlay()
    }

    private func layoutOverlay() {
        guard let contentView = window?.contentView else { return }
        let bounds = contentView.bounds
        guard bounds.width > 1, bounds.height > 1 else { return }

        blurView.frame = bounds
        backdropSnapshotView.frame = bounds
        dimTintView.frame = bounds

        let maxContainerSize = resolveImageViewerMaxContainerSize(overlayBounds: bounds)
        let imageSize = resolveImageViewerDisplayedImageSize(
            imageSize: imageView.image?.size,
            maxContainerSize: maxContainerSize
        )
        imageView.frame = NSRect(
            x: round((bounds.width - imageSize.width) * 0.5),
            y: round((bounds.height - imageSize.height) * 0.5),
            width: imageSize.width,
            height: imageSize.height
        )

        let closeSize: CGFloat = 34
        closeButton.frame = NSRect(
            x: bounds.maxX - 20 - closeSize,
            y: bounds.maxY - 20 - closeSize,
            width: closeSize,
            height: closeSize
        )

        let navSize: CGFloat = 40
        prevButton.frame = NSRect(
            x: 24,
            y: round(imageView.frame.midY - navSize * 0.5),
            width: navSize,
            height: navSize
        )
        nextButton.frame = NSRect(
            x: bounds.maxX - 24 - navSize,
            y: round(imageView.frame.midY - navSize * 0.5),
            width: navSize,
            height: navSize
        )

        let rowSize = actionRow.fittingSize
        actionRow.frame = NSRect(
            x: round((bounds.width - rowSize.width) * 0.5),
            y: 28,
            width: rowSize.width,
            height: rowSize.height
        )
    }

    private func refreshBackdropSnapshotIfNeeded(for frame: NSRect, forceRefresh: Bool = false) {
        guard backdropStyle.snapshotBlurRadius > 0 else {
            backdropSnapshotView.image = nil
            lastBackdropSnapshotFrame = nil
            return
        }
        guard backdropRenderMode == .capturedBlurSnapshot else {
            lastBackdropSnapshotFrame = nil
            return
        }
        let normalizedFrame = frame.integral
        let shouldRefresh = resolveImageViewerShouldRefreshBackdropSnapshot(
            previousFrame: lastBackdropSnapshotFrame,
            currentFrame: normalizedFrame,
            hasSnapshotImage: backdropSnapshotView.image != nil,
            forceRefresh: forceRefresh
        )
        guard shouldRefresh else { return }

        let snapshot = makeBlurredBackdropSnapshot(frame: normalizedFrame)
        backdropSnapshotView.image = snapshot
        if snapshot != nil {
            lastBackdropSnapshotFrame = normalizedFrame
        } else {
            lastBackdropSnapshotFrame = nil
        }
        if snapshot == nil {
            AppLog.log(.warn, "library.viewer", "Blur snapshot capture failed; fallback image unavailable.")
        }
    }

    private func makeBlurredBackdropSnapshot(frame: NSRect) -> NSImage? {
        guard let captured = makeBackdropCaptureImage(frame: frame) else { return nil }
        let ciImage = CIImage(cgImage: captured)
        let downsampleScale = resolveImageViewerValidatedDownsampleScale(backdropStyle.snapshotDownsampleScale)
        let blurRadius = resolveImageViewerBlurRadiusForDownsample(
            snapshotBlurRadius: backdropStyle.snapshotBlurRadius,
            downsampleScale: downsampleScale
        )

        let finalImage: CIImage
        if downsampleScale < 0.999 {
            let downsampled = ciImage.applyingFilter("CILanczosScaleTransform", parameters: [
                kCIInputScaleKey: downsampleScale,
                kCIInputAspectRatioKey: 1.0
            ])
            let downsampledExtent = downsampled.extent
            let blurredDownsampled = downsampled
                .clampedToExtent()
                .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: blurRadius])
                .cropped(to: downsampledExtent)
            finalImage = blurredDownsampled
                .applyingFilter("CILanczosScaleTransform", parameters: [
                    kCIInputScaleKey: 1 / downsampleScale,
                    kCIInputAspectRatioKey: 1.0
                ])
                .cropped(to: ciImage.extent)
        } else {
            finalImage = ciImage
                .clampedToExtent()
                .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: backdropStyle.snapshotBlurRadius])
                .cropped(to: ciImage.extent)
        }

        guard let output = ciContext.createCGImage(finalImage, from: ciImage.extent) else {
            return nil
        }
        return NSImage(cgImage: output, size: frame.size)
    }

    private func makeBackdropCaptureImage(frame: NSRect) -> CGImage? {
        let primaryHeight = NSScreen.screens.first(where: { $0.frame.origin == .zero })?.frame.height
            ?? NSScreen.main?.frame.height ?? frame.maxY
        let captureRect = resolveImageViewerCGCaptureRect(
            appKitRect: frame.integral,
            primaryScreenHeight: primaryHeight
        )
        let policies = resolveImageViewerBackdropCapturePolicies(
            hasOverlayWindowNumber: (window?.windowNumber ?? 0) > 0
        )

        for policy in policies {
            switch policy {
            case .onScreenBelowOverlayWindow:
                guard let window, window.windowNumber > 0 else { continue }
                if let belowOverlayImage = CGWindowListCreateImage(
                    captureRect,
                    .optionOnScreenBelowWindow,
                    CGWindowID(window.windowNumber),
                    [.bestResolution, .boundsIgnoreFraming]
                ) {
                    return belowOverlayImage
                }
            case .onScreenOnly:
                if let onScreenImage = CGWindowListCreateImage(
                    captureRect,
                    .optionOnScreenOnly,
                    kCGNullWindowID,
                    [.bestResolution, .boundsIgnoreFraming]
                ) {
                    return onScreenImage
                }
            }
        }

        return nil
    }

    private func configureIconButton(_ button: NSButton, fallbackSymbolName: String) {
        if #available(macOS 11.0, *) {
            button.image = NSImage(systemSymbolName: fallbackSymbolName, accessibilityDescription: nil)
        }
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
        button.contentTintColor = .white
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.35).cgColor
        button.layer?.cornerRadius = 8
        button.layer?.masksToBounds = true
    }

    private func applyNavigationIconsFromBundle() {
        prevButton.image = makeTemplateIcon(
            named: navigationIconAssets.previous,
            size: 18,
            fallbackSystemName: "arrow.left"
        )
        nextButton.image = makeTemplateIcon(
            named: navigationIconAssets.next,
            size: 18,
            fallbackSystemName: "arrow.right"
        )
    }

    private func makeTemplateIcon(named name: String, size: CGFloat, fallbackSystemName: String) -> NSImage? {
        if let url = Bundle.main.url(forResource: name, withExtension: "svg"),
           let image = NSImage(contentsOf: url) {
            image.size = NSSize(width: size, height: size)
            image.isTemplate = true
            return image
        }
        if #available(macOS 11.0, *) {
            let config = NSImage.SymbolConfiguration(pointSize: size, weight: .medium)
            return NSImage(systemSymbolName: fallbackSystemName, accessibilityDescription: name)?
                .withSymbolConfiguration(config)
        }
        return nil
    }

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            guard let window = self.window, window.isKeyWindow else { return event }

            if event.keyCode == 123 { // left
                self.showPrevious()
                return nil
            }
            if event.keyCode == 124 { // right
                self.showNext()
                return nil
            }
            if event.keyCode == 49 || event.keyCode == 53 { // space / esc
                if resolveImageViewerCloseAction(for: event.keyCode, entryMode: self.entryMode) {
                    self.closeWithAnimation()
                }
                return nil
            }
            if event.modifierFlags.contains(.command),
               event.charactersIgnoringModifiers?.lowercased() == "c" {
                self.copyCurrentImage()
                return nil
            }
            if event.modifierFlags.contains(.command),
               (event.keyCode == 51 || event.keyCode == 117) {
                self.deleteCurrentImage()
                return nil
            }
            return event
        }
    }

    private func installSwipeMonitor() {
        guard swipeMonitor == nil else { return }
        swipeMonitor = NSEvent.addLocalMonitorForEvents(matching: [.swipe, .scrollWheel]) { [weak self] event in
            guard let self else { return event }
            guard let window = self.window, window.isKeyWindow else { return event }

            if event.type == .swipe {
                if abs(event.deltaX) > 0.15 {
                    self.handleHorizontalSwipe(deltaX: event.deltaX)
                    return nil
                }
                return event
            }

            let deltaX = event.scrollingDeltaX
            let deltaY = event.scrollingDeltaY
            guard abs(deltaX) > abs(deltaY), abs(deltaX) > 6 else { return event }
            self.handleHorizontalSwipe(deltaX: deltaX)
            return nil
        }
    }

    private func installClickMonitor() {
        guard clickMonitor == nil else { return }
        clickMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            guard let self else { return event }
            guard let window = self.window, window.isKeyWindow else { return event }
            guard event.window === window else { return event }
            guard let contentView = window.contentView else { return event }

            let location = contentView.convert(event.locationInWindow, from: nil)
            let hitView = contentView.hitTest(location)
            let shouldClose = resolveImageViewerShouldCloseOnBackgroundClick(
                hitView: hitView,
                imageView: self.imageView,
                interactiveViews: [self.closeButton, self.prevButton, self.nextButton, self.actionRow]
            )
            if shouldClose {
                self.closeWithAnimation()
                return nil
            }
            return event
        }
    }

    private func handleHorizontalSwipe(deltaX: CGFloat) {
        let now = Date()
        guard now.timeIntervalSince(lastSwipeAt) > 0.22 else { return }
        lastSwipeAt = now

        switch resolveImageViewerSwipeNavigation(deltaX: deltaX) {
        case .previous:
            showPrevious()
        case .next:
            showNext()
        }
    }

    private func refreshUI() {
        guard !items.isEmpty, currentIndex < items.count else {
            close()
            return
        }
        let current = items[currentIndex]
        imageView.image = try? fileService.loadImage(for: current)
        keepButton.title = current.isKept ? "Unkeep" : "Keep"
        let canGoPrevious = currentIndex > 0
        let canGoNext = currentIndex < (items.count - 1)
        prevButton.isEnabled = canGoPrevious
        nextButton.isEnabled = canGoNext
        prevButton.alphaValue = resolveImageViewerNavigationButtonAlpha(isEnabled: canGoPrevious)
        nextButton.alphaValue = resolveImageViewerNavigationButtonAlpha(isEnabled: canGoNext)
    }

    private func showPrevious() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
        refreshUI()
    }

    private func showNext() {
        guard currentIndex < items.count - 1 else { return }
        currentIndex += 1
        refreshUI()
    }

    private func copyCurrentImage() {
        guard !items.isEmpty, currentIndex < items.count else { return }
        do {
            let image = try fileService.loadImage(for: items[currentIndex])
            try ClipboardService.shared.copy(image: image, prompt: "")
            HUDService.shared.show(message: "Image copied", style: .success, duration: 1.0)
        } catch {
            HUDService.shared.show(message: error.localizedDescription, style: .error, duration: 1.4)
        }
    }

    private func toggleKeepCurrentImage() {
        guard !items.isEmpty, currentIndex < items.count else { return }
        if !CapabilityService.shared.canUse(.libraryKeep) {
            PaywallWindowController.shared.show()
            return
        }

        let item = items[currentIndex]
        let target = !item.isKept
        do {
            try keepService.setKept(target, for: item.url)
            items[currentIndex].isKept = target
            onKeepChanged?(item.url, target)
            refreshUI()
        } catch {
            HUDService.shared.show(message: error.localizedDescription, style: .error, duration: 1.4)
        }
    }

    private func deleteCurrentImage() {
        guard !items.isEmpty, currentIndex < items.count else { return }
        let item = items[currentIndex]

        do {
            try trashService.moveToTrash(item.url)
            items.remove(at: currentIndex)
            onItemDeleted?(item.url)
            guard let nextIndex = resolveImageViewerIndexAfterDelete(
                currentIndex: currentIndex,
                itemCountAfterDeletion: items.count
            ) else {
                closeWithAnimation()
                return
            }
            currentIndex = nextIndex
            refreshUI()
            HUDService.shared.show(message: "Moved to Trash", style: .info, duration: 1.0)
        } catch {
            HUDService.shared.show(message: error.localizedDescription, style: .error, duration: 1.4)
        }
    }

    @objc private func closePressed() {
        closeWithAnimation()
    }

    @objc private func prevPressed() {
        showPrevious()
    }

    @objc private func nextPressed() {
        showNext()
    }

    @objc private func keepPressed() {
        toggleKeepCurrentImage()
    }

    @objc private func copyPressed() {
        copyCurrentImage()
    }

    @objc private func deletePressed() {
        deleteCurrentImage()
    }

    @objc private func showInFinderPressed() {
        guard !items.isEmpty, currentIndex < items.count else { return }
        NSWorkspace.shared.activateFileViewerSelecting([items[currentIndex].url])
    }

    private func closeWithAnimation() {
        guard let window else {
            close()
            return
        }
        guard !isClosingAnimated else { return }
        guard window.isVisible else {
            close()
            return
        }
        isClosingAnimated = true
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = backdropStyle.transitionDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            guard let self else { return }
            self.isClosingAnimated = false
            self.close()
        })
    }
}

