import AppKit

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

func resolveLibraryMarqueeStyle() -> LibraryMarqueeStyle {
    // Match desktop-style marquee: neutral tint, low contrast fill, subtle border.
    LibraryMarqueeStyle(
        fillColor: NSColor.tertiaryLabelColor.withAlphaComponent(0.08),
        strokeColor: NSColor.secondaryLabelColor.withAlphaComponent(0.28)
    )
}

private final class LibraryCollectionView: NSCollectionView {
    var onSelectionDragStateChanged: ((Bool) -> Void)?
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
    private let keepBadgeLabel = NSTextField(labelWithString: "📌 Kept")
    private var imageHeightConstraint: NSLayoutConstraint?
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

        keepBadgeLabel.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        keepBadgeLabel.textColor = NSColor.systemOrange
        keepBadgeLabel.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(previewImageView)
        view.addSubview(titleLabel)
        view.addSubview(subtitleLabel)
        view.addSubview(keepBadgeLabel)

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

            keepBadgeLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            keepBadgeLabel.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 4),
            keepBadgeLabel.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -8)
        ])
        imageHeightConstraint = previewImageView.heightAnchor.constraint(equalToConstant: 120)
        imageHeightConstraint?.isActive = true
    }

    func configure(with item: LibraryItem) {
        previewImageView.image = try? fileService.loadImage(for: item)
        titleLabel.stringValue = item.url.lastPathComponent
        subtitleLabel.stringValue = dateFormatter.string(from: item.createdAt)
        keepBadgeLabel.isHidden = !item.isKept
        imageHeightConstraint?.constant = 120
        titleLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        subtitleLabel.isHidden = false
    }

    private func updateSelectionStyle() {
        view.layer?.borderColor = isSelected
            ? NSColor.controlAccentColor.cgColor
            : NSColor.separatorColor.cgColor
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
    private let refreshButton = NSButton(title: "Refresh", target: nil, action: nil)
    private let openButton = NSButton(title: "Open", target: nil, action: nil)
    private let keepButton = NSButton(title: "Keep", target: nil, action: nil)
    private let deleteButton = NSButton(title: "Delete", target: nil, action: nil)
    private let normalActionsStack = NSStackView()
    private let selectionActionsStack = NSStackView()

    private let emptyLabel = NSTextField(labelWithString: "")
    private let chooseFolderButton = NSButton(title: "Choose Screenshot Folder…", target: nil, action: nil)

    private let scrollView = NSScrollView()
    private let collectionView = LibraryCollectionView()
    private let flowLayout = NSCollectionViewFlowLayout()
    private var isSelectionDragInProgress = false

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
            updateActionButtons()
        } catch LibraryServiceError.folderNotConfigured {
            items = []
            collectionView.reloadData()
            emptyLabel.isHidden = false
            emptyLabel.stringValue = "No screenshot folder configured yet."
            chooseFolderButton.isHidden = false
            scrollView.isHidden = true
            updateActionButtons()
        } catch {
            items = []
            collectionView.reloadData()
            emptyLabel.isHidden = false
            emptyLabel.stringValue = error.localizedDescription
            chooseFolderButton.isHidden = false
            scrollView.isHidden = true
            updateActionButtons()
        }
    }

    private func configureUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        normalActionsStack.orientation = .horizontal
        normalActionsStack.alignment = .centerY
        normalActionsStack.spacing = 8
        normalActionsStack.translatesAutoresizingMaskIntoConstraints = false
        normalActionsStack.addArrangedSubview(cleanupButton)
        normalActionsStack.addArrangedSubview(refreshButton)

        selectionActionsStack.orientation = .horizontal
        selectionActionsStack.alignment = .centerY
        selectionActionsStack.spacing = 8
        selectionActionsStack.translatesAutoresizingMaskIntoConstraints = false
        selectionActionsStack.addArrangedSubview(openButton)
        selectionActionsStack.addArrangedSubview(deleteButton)
        selectionActionsStack.addArrangedSubview(keepButton)
        selectionActionsStack.isHidden = true

        let toolbarStack = NSStackView(views: [
            filterControl,
            NSView(),
            normalActionsStack,
            selectionActionsStack
        ])
        toolbarStack.orientation = .horizontal
        toolbarStack.alignment = .centerY
        toolbarStack.spacing = 8
        toolbarStack.translatesAutoresizingMaskIntoConstraints = false

        emptyLabel.font = NSFont.systemFont(ofSize: 14)
        emptyLabel.textColor = .secondaryLabelColor
        emptyLabel.alignment = .center
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false

        chooseFolderButton.target = self
        chooseFolderButton.action = #selector(chooseFolderPressed)
        chooseFolderButton.translatesAutoresizingMaskIntoConstraints = false

        filterControl.target = self
        filterControl.action = #selector(filterModeChanged)
        filterControl.setAccessibilityIdentifier("library.control.filter")
        cleanupButton.target = self
        cleanupButton.action = #selector(cleanupPressed)
        cleanupButton.setAccessibilityIdentifier("library.button.cleanup")
        refreshButton.target = self
        refreshButton.action = #selector(refreshPressed)
        refreshButton.setAccessibilityIdentifier("library.button.refresh")
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

        view.addSubview(toolbarStack)
        view.addSubview(scrollView)
        view.addSubview(emptyLabel)
        view.addSubview(chooseFolderButton)

        NSLayoutConstraint.activate([
            toolbarStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            toolbarStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            toolbarStack.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),

            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            scrollView.topAnchor.constraint(equalTo: toolbarStack.bottomAnchor, constant: 12),
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

    private func applyGridLayout() {
        flowLayout.itemSize = NSSize(width: 180, height: 180)
        flowLayout.sectionInset = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
    }

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            guard let window = self.view.window, window.isKeyWindow else { return event }

            if event.modifierFlags.contains(.command),
               (event.keyCode == 51 || event.keyCode == 117) {
                self.deleteCurrentSelection()
                return nil
            }

            if event.keyCode == 36 || event.keyCode == 49 { // Return / Space
                self.openCurrentSelection()
                return nil
            }

            return event
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
            normalActionsStack.isHidden = state.showsSelectionActions
            selectionActionsStack.isHidden = !state.showsSelectionActions
        }
        openButton.isEnabled = !selectionActionsStack.isHidden && state.openEnabled
        keepButton.isEnabled = !selectionActionsStack.isHidden && state.keepEnabled
        deleteButton.isEnabled = !selectionActionsStack.isHidden && state.deleteEnabled
        keepButton.title = state.keepTitle
    }

    private func openCurrentSelection() {
        guard selectedItems.count == 1, let index = selectedIndexes.first else { return }
        let viewer = ImageViewerWindowController(items: items, initialIndex: index)
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

    @objc private func refreshPressed() {
        reloadContent()
    }

    @objc private func openPressed() {
        openCurrentSelection()
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
        if NSApp.currentEvent?.clickCount == 2 {
            openCurrentSelection()
        }
    }

    func collectionView(_ collectionView: NSCollectionView, didDeselectItemsAt indexPaths: Set<IndexPath>) {
        updateActionButtons()
    }
}

private final class ImageViewerWindowController: NSWindowController {
    private var items: [LibraryItem]
    private var currentIndex: Int
    private var keyMonitor: Any?

    var onKeepChanged: ((URL, Bool) -> Void)?
    var onItemDeleted: ((URL) -> Void)?

    private let imageView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let detailLabel = NSTextField(labelWithString: "")
    private let prevButton = NSButton(title: "← Prev", target: nil, action: nil)
    private let nextButton = NSButton(title: "Next →", target: nil, action: nil)
    private let keepButton = NSButton(title: "Keep", target: nil, action: nil)
    private let copyButton = NSButton(title: "Copy", target: nil, action: nil)
    private let deleteButton = NSButton(title: "Delete", target: nil, action: nil)
    private let finderButton = NSButton(title: "Show in Finder", target: nil, action: nil)

    private let keepService = KeepMarkerService.shared
    private let trashService = TrashService.shared
    private let fileService = LibraryFileService.shared
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    init(items: [LibraryItem], initialIndex: Int) {
        self.items = items
        self.currentIndex = max(0, min(initialIndex, max(0, items.count - 1)))

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 980, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.setAccessibilityIdentifier("library.viewer.window")
        window.title = "Image Viewer"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        configureUI()
        refreshUI()
        installKeyMonitor()
    }

    required init?(coder: NSCoder) { nil }

    deinit {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }
    }

    func show() {
        guard let window else { return }
        NSApp.activate(ignoringOtherApps: true)
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    private func configureUI() {
        guard let contentView = window?.contentView else { return }

        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.wantsLayer = true
        imageView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.04).cgColor
        imageView.layer?.cornerRadius = 8

        titleLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        detailLabel.font = NSFont.systemFont(ofSize: 12)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.translatesAutoresizingMaskIntoConstraints = false

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

        let navRow = NSStackView(views: [prevButton, nextButton, NSView()])
        navRow.orientation = .horizontal
        navRow.alignment = .centerY
        navRow.spacing = 8
        navRow.translatesAutoresizingMaskIntoConstraints = false

        let infoRow = NSStackView(views: [titleLabel, NSView(), detailLabel])
        infoRow.orientation = .horizontal
        infoRow.alignment = .centerY
        infoRow.spacing = 8
        infoRow.translatesAutoresizingMaskIntoConstraints = false

        let actionRow = NSStackView(views: [copyButton, keepButton, deleteButton, finderButton, NSView()])
        actionRow.orientation = .horizontal
        actionRow.alignment = .centerY
        actionRow.spacing = 8
        actionRow.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(navRow)
        contentView.addSubview(imageView)
        contentView.addSubview(infoRow)
        contentView.addSubview(actionRow)

        NSLayoutConstraint.activate([
            navRow.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            navRow.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            navRow.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),

            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            imageView.topAnchor.constraint(equalTo: navRow.bottomAnchor, constant: 10),
            imageView.bottomAnchor.constraint(equalTo: infoRow.topAnchor, constant: -12),

            infoRow.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            infoRow.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            infoRow.bottomAnchor.constraint(equalTo: actionRow.topAnchor, constant: -8),

            actionRow.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            actionRow.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            actionRow.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
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
            if event.keyCode == 53 { // esc
                self.close()
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

    private func refreshUI() {
        guard !items.isEmpty, currentIndex < items.count else {
            close()
            return
        }
        let current = items[currentIndex]
        imageView.image = try? fileService.loadImage(for: current)
        titleLabel.stringValue = current.url.lastPathComponent
        detailLabel.stringValue = dateFormatter.string(from: current.createdAt)
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
            if currentIndex >= items.count {
                currentIndex = max(0, items.count - 1)
            }
            refreshUI()
            HUDService.shared.show(message: "Moved to Trash", style: .info, duration: 1.0)
        } catch {
            HUDService.shared.show(message: error.localizedDescription, style: .error, duration: 1.4)
        }
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
}


