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
    let openEnabled: Bool
    let keepEnabled: Bool
    let deleteEnabled: Bool
    let keepTitle: String
}

enum LibraryKeyboardAction: Equatable {
    case none
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
        openEnabled: isSingleSelection,
        keepEnabled: hasSelection,
        deleteEnabled: hasSelection,
        keepTitle: keepTitle
    )
}

func resolveLibraryKeyboardAction(keyCode: UInt16, modifierFlags: NSEvent.ModifierFlags) -> LibraryKeyboardAction {
    if modifierFlags.contains(.command), (keyCode == 51 || keyCode == 117) {
        return .deleteSelection
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

private final class LibraryCollectionItem: NSCollectionViewItem {
    private let fileService = LibraryFileService.shared
    private let previewImageView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let keepBadgeContainerView = NSView()
    private let keepBadgeIconView = NSImageView()
    private var imageHeightConstraint: NSLayoutConstraint?
    private var isKeptItem = false
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    override var isSelected: Bool {
        didSet { updateSelectionStyle() }
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

        titleLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        titleLabel.lineBreakMode = .byTruncatingMiddle
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        subtitleLabel.font = NSFont.systemFont(ofSize: 11)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.lineBreakMode = .byTruncatingTail
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        let keepStyle = resolveLibraryKeepBadgeStyle()
        keepBadgeContainerView.wantsLayer = true
        keepBadgeContainerView.layer?.backgroundColor = keepStyle.backgroundColor.cgColor
        keepBadgeContainerView.layer?.borderColor = keepStyle.borderColor.cgColor
        keepBadgeContainerView.layer?.borderWidth = 1
        keepBadgeContainerView.translatesAutoresizingMaskIntoConstraints = false
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
            keepBadgeContainerView.widthAnchor.constraint(equalToConstant: 32),
            keepBadgeContainerView.heightAnchor.constraint(equalToConstant: 32),

            keepBadgeIconView.centerXAnchor.constraint(equalTo: keepBadgeContainerView.centerXAnchor),
            keepBadgeIconView.centerYAnchor.constraint(equalTo: keepBadgeContainerView.centerYAnchor),
            keepBadgeIconView.widthAnchor.constraint(equalToConstant: 18),
            keepBadgeIconView.heightAnchor.constraint(equalToConstant: 18)
        ])
        keepBadgeContainerView.layer?.cornerRadius = 16
        imageHeightConstraint = previewImageView.heightAnchor.constraint(equalToConstant: 120)
        imageHeightConstraint?.isActive = true
    }

    func configure(with item: LibraryItem) {
        previewImageView.image = try? fileService.loadImage(for: item)
        titleLabel.stringValue = item.url.lastPathComponent
        subtitleLabel.stringValue = dateFormatter.string(from: item.createdAt)
        isKeptItem = item.isKept
        keepBadgeContainerView.isHidden = !item.isKept
        imageHeightConstraint?.constant = 120
        titleLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        subtitleLabel.isHidden = false
        updateSelectionStyle()
    }

    private func updateSelectionStyle() {
        let borderColor = resolveLibraryItemBorderColor(isSelected: isSelected, isKept: isKeptItem)
        view.layer?.borderColor = borderColor.cgColor
        view.layer?.borderWidth = isSelected ? 2 : 1
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
    private var viewerWindowController: ImageViewerWindowController?

    private let filterControl = NSSegmentedControl(
        labels: ["All", "Kept"],
        trackingMode: .selectOne,
        target: nil,
        action: nil
    )
    private let cleanupButton = NSButton(title: "Cleanup Settings", target: nil, action: nil)
    private let cancelButton = NSButton(title: "Cancel", target: nil, action: nil)
    private let selectionCountLabel = NSTextField(labelWithString: "")
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
        openButton.target = self
        openButton.action = #selector(openPressed)
        openButton.setAccessibilityIdentifier("library.button.open")
        keepButton.target = self
        keepButton.action = #selector(keepPressed)
        keepButton.setAccessibilityIdentifier("library.button.keep")
        deleteButton.target = self
        deleteButton.action = #selector(deletePressed)
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
                allCount = try fileService.listItems(filter: .all).count
            }
            applyFilterLabels(allCount: allCount, keptCount: keptCount)
        } catch {
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
        ) { [weak self] _ in
            guard let self else { return }
            guard self.view.window?.isVisible == true else { return }
            self.scheduleReloadContent()
        }
    }

    private func scheduleReloadContent() {
        pendingReloadWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.reloadContent()
        }
        pendingReloadWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
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
        openButton.isEnabled = !selectionActionsStack.isHidden && state.openEnabled
        keepButton.isEnabled = !selectionActionsStack.isHidden && state.keepEnabled
        deleteButton.isEnabled = !selectionActionsStack.isHidden && state.deleteEnabled
        keepButton.title = state.keepTitle
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
            anchorWindowFrame: view.window?.frame,
            anchorWindowNumber: view.window?.windowNumber
        )
        viewer.onKeepChanged = { [weak self] url, isKept in
            guard let self else { return }
            if let itemIndex = self.items.firstIndex(where: { $0.url == url }) {
                self.items[itemIndex].isKept = isKept
            }
            self.reloadContent()
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

        for index in indexes {
            do {
                try keepService.setKept(target, for: items[index].url)
                items[index].isKept = target
                updatedCount += 1
            } catch {
                failureCount += 1
            }
        }

        if updatedCount > 0 {
            reloadContent()
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
        let alert = NSAlert()
        alert.alertStyle = .warning
        if selected.count == 1 {
            alert.messageText = "Delete Screenshot?"
        } else {
            alert.messageText = "Delete \(selected.count) Screenshots?"
        }
        alert.informativeText = "The screenshot will be moved to Trash."
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }

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
        libraryItem.configure(with: items[indexPath.item])
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

struct ImageViewerBackdropStyle {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    let tintAlpha: CGFloat
    let snapshotBlurRadius: Double
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
    // Use a lighter material plus very subtle tint so background structures stay visible.
    ImageViewerBackdropStyle(
        material: .underWindowBackground,
        blendingMode: .behindWindow,
        tintAlpha: 0.08,
        snapshotBlurRadius: 34,
        transitionDuration: 0.16
    )
}

private final class ViewerOverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

private final class ImageViewerWindowController: NSWindowController, NSWindowDelegate {
    private var items: [LibraryItem]
    private var currentIndex: Int
    private var keyMonitor: Any?
    private var swipeMonitor: Any?
    private var lastSwipeAt: Date = .distantPast
    private var isClosingAnimated = false
    private let entryMode: ImageViewerEntryMode
    private let anchorWindowFrame: NSRect?
    private let anchorWindowNumber: Int?
    private let backdropRenderMode: ImageViewerBackdropRenderMode
    private let backdropStyle = resolveImageViewerBackdropStyle()

    var onKeepChanged: ((URL, Bool) -> Void)?
    var onItemDeleted: ((URL) -> Void)?
    var onClosed: (() -> Void)?

    var canCloseWithSpaceToggle: Bool { entryMode == .spaceToggleClosable }
    var isWindowVisible: Bool { window?.isVisible == true }

    private let blurView = NSVisualEffectView()
    private let backdropSnapshotView = NSImageView()
    private let dimTintView = NSView()
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
        anchorWindowFrame: NSRect?,
        anchorWindowNumber: Int?
    ) {
        self.items = items
        self.currentIndex = max(0, min(initialIndex, max(0, items.count - 1)))
        self.entryMode = entryMode
        self.anchorWindowFrame = anchorWindowFrame
        self.anchorWindowNumber = anchorWindowNumber
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
        window.level = .floating
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        super.init(window: window)
        window.delegate = self
        configureUI()
        refreshUI()
        installKeyMonitor()
        installSwipeMonitor()
    }

    required init?(coder: NSCoder) { nil }

    deinit {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }
        if let swipeMonitor {
            NSEvent.removeMonitor(swipeMonitor)
        }
    }

    func windowWillClose(_ notification: Notification) {
        onClosed?()
    }

    func windowDidResize(_ notification: Notification) {
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
        refreshBackdropSnapshotIfNeeded(for: expectedFrame)
        layoutOverlay()

        NSApp.activate(ignoringOtherApps: true)
        window.alphaValue = 0
        window.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = backdropStyle.transitionDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1
        }
        DispatchQueue.main.async { [weak self, weak window] in
            guard let self, let window else { return }
            window.setFrame(expectedFrame, display: false)
            self.refreshBackdropSnapshotIfNeeded(for: expectedFrame)
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

        backdropSnapshotView.imageScaling = .scaleAxesIndependently
        backdropSnapshotView.isHidden = backdropRenderMode != .capturedBlurSnapshot

        dimTintView.wantsLayer = true
        dimTintView.layer?.backgroundColor = NSColor.black.withAlphaComponent(backdropStyle.tintAlpha).cgColor

        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = 10
        imageView.layer?.masksToBounds = true
        imageView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.12).cgColor

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

        let maxImageWidth = max(1, bounds.width * 0.82)
        let maxImageHeight = max(1, bounds.height * 0.78)
        var imageWidth = max(420, min(maxImageWidth, bounds.width - 120))
        var imageHeight = max(260, min(maxImageHeight, bounds.height - 120))
        imageWidth = min(imageWidth, max(1, bounds.width - 32))
        imageHeight = min(imageHeight, max(1, bounds.height - 72))
        imageView.frame = NSRect(
            x: round((bounds.width - imageWidth) * 0.5),
            y: round((bounds.height - imageHeight) * 0.5),
            width: imageWidth,
            height: imageHeight
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

    private func refreshBackdropSnapshotIfNeeded(for frame: NSRect) {
        guard backdropRenderMode == .capturedBlurSnapshot else { return }
        let snapshot = makeBlurredBackdropSnapshot(frame: frame)
        backdropSnapshotView.image = snapshot
        if snapshot == nil {
            AppLog.log(.warn, "library.viewer", "Blur snapshot capture failed; fallback image unavailable.")
        }
    }

    private func makeBlurredBackdropSnapshot(frame: NSRect) -> NSImage? {
        guard let captured = makeBackdropCaptureImage(frame: frame) else { return nil }
        let ciImage = CIImage(cgImage: captured)
        let blurred = ciImage
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: backdropStyle.snapshotBlurRadius])
            .cropped(to: ciImage.extent)
        guard let output = ciContext.createCGImage(blurred, from: ciImage.extent) else {
            return nil
        }
        return NSImage(cgImage: output, size: frame.size)
    }

    private func makeBackdropCaptureImage(frame: NSRect) -> CGImage? {
        if let window, window.windowNumber > 0 {
            if let belowOverlayImage = CGWindowListCreateImage(
                .null,
                .optionOnScreenBelowWindow,
                CGWindowID(window.windowNumber),
                [.bestResolution, .boundsIgnoreFraming]
            ) {
                return belowOverlayImage
            }
        }

        if let onScreenImage = CGWindowListCreateImage(
            frame.integral,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.bestResolution, .boundsIgnoreFraming]
        ) {
            return onScreenImage
        }

        if let anchorWindowNumber,
           let anchorWindowImage = CGWindowListCreateImage(
            .null,
            .optionIncludingWindow,
            CGWindowID(anchorWindowNumber),
            [.bestResolution, .boundsIgnoreFraming]
           ) {
            return anchorWindowImage
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
        prevButton.isEnabled = currentIndex > 0
        nextButton.isEnabled = currentIndex < (items.count - 1)
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
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Delete Screenshot?"
        alert.informativeText = "The screenshot will be moved to Trash."
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

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

