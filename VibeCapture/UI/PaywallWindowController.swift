import AppKit
import StoreKit

private let brandColor = NSColor(red: 1.0, green: 0.553, blue: 0.463, alpha: 1.0) // #FF8D76
private let modalBackgroundColor = NSColor(red: 0.933, green: 0.933, blue: 0.933, alpha: 1.0) // #eee
private let cardBackgroundColor = NSColor.white

final class PaywallWindowController: NSWindowController, NSWindowDelegate {
    static let shared = PaywallWindowController()

    // MARK: - Pro Status (for existing Pro users)
    private let proStatusContainer = NSBox()
    private let proStatusStack = NSStackView()

    // MARK: - Plan Selection
    private let planContainer = NSBox()
    private let monthlyRow = PlanOptionRow()
    private let yearlyRow = PlanOptionRow()
    private let lifetimeRow = PlanOptionRow()

    // MARK: - Feature List
    private let featureContainer = NSBox()
    private let featureStack = NSStackView()

    // MARK: - Bottom
    private let ctaButton = NSButton()
    private let legalStack = NSStackView()
    private let termsButton = NSButton(title: "", target: nil, action: nil)
    private let privacyButton = NSButton(title: "", target: nil, action: nil)
    private let restoreButton = NSButton(title: "", target: nil, action: nil)
    private let manageButton = NSButton(title: "", target: nil, action: nil)

    private let statusLabel = NSTextField(labelWithString: "")

    // MARK: - State
    private var proStatusObserver: Any?
    private var products: [String: Product] = [:]
    private var selectedProductID: String = EntitlementsService.ProductID.lifetime

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 520),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = L("paywall.window_title")
        window.isReleasedWhenClosed = false
        // Fixed width, flexible height
        window.setContentSize(NSSize(width: 380, height: 520))
        window.contentMinSize = NSSize(width: 380, height: 480)
        window.contentMaxSize = NSSize(width: 380, height: 700)
        window.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 1)
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.center()
        super.init(window: window)
        window.delegate = self
        window.contentView = buildContentView()
        startProStatusObserver()
    }

    required init?(coder: NSCoder) { nil }

    func show() {
        guard let window else { return }
        NSApp.activate(ignoringOtherApps: true)
        window.center()
        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
        startLocalEventMonitor()
        Task { await loadProductsAndRefreshUI() }
    }

    func windowWillClose(_ notification: Notification) {
        stopLocalEventMonitor()
    }

    // MARK: - Keyboard (ESC to close)

    private var localEventMonitor: Any?

    private func startLocalEventMonitor() {
        guard localEventMonitor == nil else { return }
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let window = self.window, window.isKeyWindow else { return event }
            if event.keyCode == 53 { // ESC
                window.close()
                return nil
            }
            return event
        }
    }

    private func stopLocalEventMonitor() {
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
    }

    // MARK: - Build UI

    private func buildContentView() -> NSView {
        let content = NSView()
        content.wantsLayer = true
        content.layer?.backgroundColor = modalBackgroundColor.cgColor

        // Title
        let titleLabel = NSTextField(labelWithString: L("paywall.title"))
        titleLabel.font = NSFont.systemFont(ofSize: 20, weight: .semibold)
        titleLabel.alignment = .center

        // Subtitle (persuasive)
        let subtitleLabel = NSTextField(labelWithString: L("paywall.subtitle"))
        subtitleLabel.font = NSFont.systemFont(ofSize: 13)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.alignment = .center

        // Title stack
        let titleStack = NSStackView(views: [titleLabel, subtitleLabel])
        titleStack.orientation = .vertical
        titleStack.spacing = 4
        titleStack.alignment = .centerX

        // Pro status card (for existing Pro users)
        setupProStatusCard()

        // Plan selection container
        setupPlanSelection()

        // Feature list
        setupFeatureList()

        // Legal links (below feature list)
        setupLegalSection()

        // CTA Button
        setupCTAButton()

        // Status label
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.font = NSFont.systemFont(ofSize: 11)
        statusLabel.alignment = .center

        // Scrollable content area
        let scrollContent = NSStackView(views: [
            titleStack,
            proStatusContainer,
            planContainer,
            featureContainer,
            legalStack,
        ])
        scrollContent.orientation = .vertical
        scrollContent.spacing = 16
        scrollContent.alignment = .centerX
        scrollContent.translatesAutoresizingMaskIntoConstraints = false
        scrollContent.edgeInsets = NSEdgeInsets(top: 20, left: 24, bottom: 20, right: 24)

        // Document view for scroll
        let documentView = NSView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(scrollContent)

        NSLayoutConstraint.activate([
            scrollContent.topAnchor.constraint(equalTo: documentView.topAnchor),
            scrollContent.bottomAnchor.constraint(equalTo: documentView.bottomAnchor),
            scrollContent.leadingAnchor.constraint(equalTo: documentView.leadingAnchor),
            scrollContent.trailingAnchor.constraint(equalTo: documentView.trailingAnchor),
        ])

        // Scroll view
        let scrollView = NSScrollView()
        scrollView.documentView = documentView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        // Bottom toolbar (fixed CTA)
        let toolbar = NSView()
        toolbar.wantsLayer = true
        toolbar.layer?.backgroundColor = cardBackgroundColor.cgColor
        toolbar.translatesAutoresizingMaskIntoConstraints = false

        // Top border for toolbar
        let topBorder = NSView()
        topBorder.wantsLayer = true
        topBorder.layer?.backgroundColor = NSColor.separatorColor.cgColor
        topBorder.translatesAutoresizingMaskIntoConstraints = false
        toolbar.addSubview(topBorder)
        toolbar.addSubview(ctaButton)

        NSLayoutConstraint.activate([
            topBorder.topAnchor.constraint(equalTo: toolbar.topAnchor),
            topBorder.leadingAnchor.constraint(equalTo: toolbar.leadingAnchor),
            topBorder.trailingAnchor.constraint(equalTo: toolbar.trailingAnchor),
            topBorder.heightAnchor.constraint(equalToConstant: 1),

            ctaButton.topAnchor.constraint(equalTo: toolbar.topAnchor, constant: 12),
            ctaButton.bottomAnchor.constraint(equalTo: toolbar.bottomAnchor, constant: -12),
            ctaButton.leadingAnchor.constraint(equalTo: toolbar.leadingAnchor, constant: 24),
            ctaButton.trailingAnchor.constraint(equalTo: toolbar.trailingAnchor, constant: -24),
            ctaButton.heightAnchor.constraint(equalToConstant: 48),
        ])

        content.addSubview(scrollView)
        content.addSubview(toolbar)

        // Fixed width for content
        let contentWidth: CGFloat = 380

        NSLayoutConstraint.activate([
            // Content fixed width
            content.widthAnchor.constraint(equalToConstant: contentWidth),

            scrollView.topAnchor.constraint(equalTo: content.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: toolbar.topAnchor),

            toolbar.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            toolbar.bottomAnchor.constraint(equalTo: content.bottomAnchor),

            // Width relative to scroll content (which will be contentWidth - padding)
            proStatusContainer.widthAnchor.constraint(equalToConstant: contentWidth - 48),
            planContainer.widthAnchor.constraint(equalToConstant: contentWidth - 48),
            featureContainer.widthAnchor.constraint(equalToConstant: contentWidth - 48),
            legalStack.widthAnchor.constraint(equalToConstant: contentWidth - 48),

            documentView.widthAnchor.constraint(equalToConstant: contentWidth),
        ])

        refreshUI()
        return content
    }

    // MARK: - Pro Status Card

    private func setupProStatusCard() {
        proStatusContainer.boxType = .custom
        proStatusContainer.borderWidth = 0
        proStatusContainer.cornerRadius = 12
        proStatusContainer.fillColor = cardBackgroundColor
        proStatusContainer.translatesAutoresizingMaskIntoConstraints = false

        proStatusStack.orientation = .vertical
        proStatusStack.spacing = 8
        proStatusStack.alignment = .leading
        proStatusStack.translatesAutoresizingMaskIntoConstraints = false

        proStatusContainer.addSubview(proStatusStack)
        NSLayoutConstraint.activate([
            proStatusStack.topAnchor.constraint(equalTo: proStatusContainer.topAnchor, constant: 16),
            proStatusStack.bottomAnchor.constraint(equalTo: proStatusContainer.bottomAnchor, constant: -16),
            proStatusStack.leadingAnchor.constraint(equalTo: proStatusContainer.leadingAnchor, constant: 16),
            proStatusStack.trailingAnchor.constraint(equalTo: proStatusContainer.trailingAnchor, constant: -16),
        ])

        // Initially hidden, shown only for Pro users
        proStatusContainer.isHidden = true
    }

    private func updateProStatusCard() {
        let status = EntitlementsService.shared.status
        let isPro = status.tier == .pro

        proStatusContainer.isHidden = !isPro
        planContainer.isHidden = isPro

        if !isPro {
            return
        }

        // Clear existing content
        proStatusStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        // Checkmark + "You're Pro"
        let checkmark = NSImageView()
        let checkConfig = NSImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        checkmark.image = NSImage(systemSymbolName: "checkmark.seal.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(checkConfig)
        checkmark.contentTintColor = brandColor

        let titleLabel = NSTextField(labelWithString: L("paywall.pro_status.title"))
        titleLabel.font = NSFont.systemFont(ofSize: 16, weight: .semibold)

        let titleRow = NSStackView(views: [checkmark, titleLabel])
        titleRow.orientation = .horizontal
        titleRow.spacing = 8
        titleRow.alignment = .centerY

        proStatusStack.addArrangedSubview(titleRow)

        // Subscription type
        let typeLabel = NSTextField(labelWithString: L("paywall.pro_status.type", status.sourceDisplayName))
        typeLabel.font = NSFont.systemFont(ofSize: 13)
        typeLabel.textColor = .secondaryLabelColor
        proStatusStack.addArrangedSubview(typeLabel)

        // Expiration/renewal date (for subscriptions, not lifetime)
        if let expirationDate = status.expirationDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .long
            formatter.timeStyle = .none
            let dateString = formatter.string(from: expirationDate)

            let renewLabel = NSTextField(labelWithString: L("paywall.pro_status.renews", dateString))
            renewLabel.font = NSFont.systemFont(ofSize: 13)
            renewLabel.textColor = .secondaryLabelColor
            proStatusStack.addArrangedSubview(renewLabel)
        }
    }

    // MARK: - Plan Selection

    private func setupPlanSelection() {
        planContainer.boxType = .custom
        planContainer.borderWidth = 0
        planContainer.cornerRadius = 12
        planContainer.fillColor = cardBackgroundColor
        planContainer.translatesAutoresizingMaskIntoConstraints = false

        // Configure rows
        monthlyRow.configure(
            title: L("paywall.option.monthly"),
            badge: nil,
            price: L("paywall.price.loading")
        )
        monthlyRow.onSelect = { [weak self] in self?.selectPlan(EntitlementsService.ProductID.monthly) }

        yearlyRow.configure(
            title: L("paywall.option.yearly"),
            badge: nil, // Will be set when products load
            price: L("paywall.price.loading")
        )
        yearlyRow.onSelect = { [weak self] in self?.selectPlan(EntitlementsService.ProductID.yearly) }

        lifetimeRow.configure(
            title: L("paywall.option.lifetime"),
            badge: L("paywall.badge.best_value"),
            price: L("paywall.price.loading")
        )
        lifetimeRow.onSelect = { [weak self] in self?.selectPlan(EntitlementsService.ProductID.lifetime) }

        let separator1 = createSeparator()
        let separator2 = createSeparator()

        let stack = NSStackView(views: [monthlyRow, separator1, yearlyRow, separator2, lifetimeRow])
        stack.orientation = .vertical
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false

        planContainer.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: planContainer.topAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: planContainer.bottomAnchor, constant: -8),
            stack.leadingAnchor.constraint(equalTo: planContainer.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: planContainer.trailingAnchor),

            monthlyRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            yearlyRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            lifetimeRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])

        updatePlanSelectionUI()
    }

    private func createSeparator() -> NSBox {
        let sep = NSBox()
        sep.boxType = .separator
        return sep
    }

    // MARK: - Feature List

    private func setupFeatureList() {
        // Container with same style as plan selection
        featureContainer.boxType = .custom
        featureContainer.borderWidth = 0
        featureContainer.cornerRadius = 12
        featureContainer.fillColor = cardBackgroundColor
        featureContainer.translatesAutoresizingMaskIntoConstraints = false

        featureStack.orientation = .vertical
        featureStack.spacing = 0
        featureStack.translatesAutoresizingMaskIntoConstraints = false

        // Feature 1: Full annotation
        let annotationRow = FeatureRow(
            iconName: "pencil.tip.crop.circle",
            title: L("paywall.feature.annotations.title"),
            subtitle: L("paywall.feature.annotations.subtitle")
        )

        // Feature 2: Unlimited Send list
        let sendListRow = FeatureRow(
            iconName: "list.bullet.rectangle",
            title: L("paywall.feature.send_list.title"),
            subtitle: L("paywall.feature.send_list.subtitle")
        )

        let sep = createSeparator()

        featureStack.addArrangedSubview(annotationRow)
        featureStack.addArrangedSubview(sep)
        featureStack.addArrangedSubview(sendListRow)

        featureContainer.addSubview(featureStack)
        NSLayoutConstraint.activate([
            featureStack.topAnchor.constraint(equalTo: featureContainer.topAnchor, constant: 8),
            featureStack.bottomAnchor.constraint(equalTo: featureContainer.bottomAnchor, constant: -8),
            featureStack.leadingAnchor.constraint(equalTo: featureContainer.leadingAnchor),
            featureStack.trailingAnchor.constraint(equalTo: featureContainer.trailingAnchor),

            // 关键：确保每行宽度一致，与 PlanOptionRow 相同处理
            annotationRow.widthAnchor.constraint(equalTo: featureStack.widthAnchor),
            sendListRow.widthAnchor.constraint(equalTo: featureStack.widthAnchor),
        ])
    }

    // MARK: - CTA Button

    private func setupCTAButton() {
        ctaButton.bezelStyle = .regularSquare
        ctaButton.isBordered = false
        ctaButton.wantsLayer = true
        ctaButton.layer?.cornerRadius = 12
        ctaButton.layer?.backgroundColor = brandColor.cgColor
        ctaButton.contentTintColor = .white
        ctaButton.font = NSFont.systemFont(ofSize: 15, weight: .semibold)
        ctaButton.target = self
        ctaButton.action = #selector(ctaPressed)
        ctaButton.translatesAutoresizingMaskIntoConstraints = false

        updateCTAButton()
    }

    // MARK: - Legal Section

    private func setupLegalSection() {
        termsButton.title = L("paywall.legal.terms")
        termsButton.isBordered = false
        termsButton.target = self
        termsButton.action = #selector(openTerms)
        termsButton.font = NSFont.systemFont(ofSize: 11)
        termsButton.contentTintColor = .secondaryLabelColor

        privacyButton.title = L("paywall.legal.privacy")
        privacyButton.isBordered = false
        privacyButton.target = self
        privacyButton.action = #selector(openPrivacy)
        privacyButton.font = NSFont.systemFont(ofSize: 11)
        privacyButton.contentTintColor = .secondaryLabelColor

        restoreButton.title = L("paywall.action.restore")
        restoreButton.isBordered = false
        restoreButton.target = self
        restoreButton.action = #selector(restorePressed)
        restoreButton.font = NSFont.systemFont(ofSize: 11)
        restoreButton.contentTintColor = .secondaryLabelColor

        manageButton.title = L("paywall.action.manage")
        manageButton.isBordered = false
        manageButton.target = self
        manageButton.action = #selector(managePressed)
        manageButton.font = NSFont.systemFont(ofSize: 11)
        manageButton.contentTintColor = .secondaryLabelColor

        legalStack.orientation = .horizontal
        legalStack.spacing = 4
        legalStack.alignment = .centerY

        rebuildLegalStack()
    }

    private func rebuildLegalStack() {
        legalStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        // Left side: Terms · Privacy
        legalStack.addArrangedSubview(termsButton)
        legalStack.addArrangedSubview(dotLabel())
        legalStack.addArrangedSubview(privacyButton)

        // Spacer
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        legalStack.addArrangedSubview(spacer)

        // Right side: Restore (and Manage for Pro users)
        legalStack.addArrangedSubview(restoreButton)

        // Only show Manage for Pro users
        if EntitlementsService.shared.isPro {
            legalStack.addArrangedSubview(dotLabel())
            legalStack.addArrangedSubview(manageButton)
        }
    }

    private func dotLabel() -> NSTextField {
        let label = NSTextField(labelWithString: "·")
        label.textColor = .tertiaryLabelColor
        label.font = NSFont.systemFont(ofSize: 11)
        return label
    }

    // MARK: - Actions

    @objc private func ctaPressed() {
        performPurchase()
    }

    private func performPurchase() {
        guard let window else { return }
        guard let product = products[selectedProductID] else {
            statusLabel.stringValue = L("paywall.price.loading")
            Task { await loadProductsAndRefreshUI() }
            return
        }

        ctaButton.isEnabled = false
        statusLabel.stringValue = L("paywall.status.purchasing")

        Task { [weak self] in
            guard let self else { return }
            await self.purchase(product: product, from: window)
            self.refreshUI()
        }
    }

    @MainActor
    private func purchase(product: Product, from window: NSWindow) async {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try EntitlementsService.verify(verification)
                await transaction.finish()
                await EntitlementsService.shared.refreshEntitlements()
                statusLabel.stringValue = L("paywall.status.success")
            case .userCancelled:
                statusLabel.stringValue = ""
            case .pending:
                statusLabel.stringValue = L("paywall.status.pending")
            @unknown default:
                statusLabel.stringValue = L("paywall.error.generic")
            }
        } catch {
            statusLabel.stringValue = L("paywall.error.generic")
        }
    }

    @objc private func restorePressed() {
        PurchaseService.shared.restorePurchases(from: window)
    }

    @objc private func managePressed() {
        PurchaseService.shared.openManageSubscriptions(from: window)
    }

    @objc private func openTerms() {
        if let url = URL(string: "http://vibecap.dev/terms") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func openPrivacy() {
        if let url = URL(string: "http://vibecap.dev/privacy") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Data

    @MainActor
    private func loadProductsAndRefreshUI() async {
        do {
            try await PurchaseService.shared.loadProductsIfNeeded()
            products = [
                EntitlementsService.ProductID.monthly: PurchaseService.shared.product(id: EntitlementsService.ProductID.monthly),
                EntitlementsService.ProductID.yearly: PurchaseService.shared.product(id: EntitlementsService.ProductID.yearly),
                EntitlementsService.ProductID.lifetime: PurchaseService.shared.product(id: EntitlementsService.ProductID.lifetime),
            ].compactMapValues { $0 }
            refreshUI()
        } catch {
            statusLabel.stringValue = L("paywall.error.generic")
        }
    }

    // MARK: - UI Updates

    private func selectPlan(_ productID: String) {
        selectedProductID = productID
        updatePlanSelectionUI()
        updateCTAButton()
    }

    private func updatePlanSelectionUI() {
        monthlyRow.isSelected = (selectedProductID == EntitlementsService.ProductID.monthly)
        yearlyRow.isSelected = (selectedProductID == EntitlementsService.ProductID.yearly)
        lifetimeRow.isSelected = (selectedProductID == EntitlementsService.ProductID.lifetime)
    }

    private func refreshUI() {
        updateProStatusCard()
        refreshPlanPrices()
        updatePlanSelectionUI()
        updateCTAButton()
        refreshEntitlementUI()
        rebuildLegalStack()
    }

    private func refreshPlanPrices() {
        let monthly = products[EntitlementsService.ProductID.monthly]
        let yearly = products[EntitlementsService.ProductID.yearly]
        let lifetime = products[EntitlementsService.ProductID.lifetime]

        // Monthly
        if let monthly {
            monthlyRow.configure(
                title: L("paywall.option.monthly"),
                badge: nil,
                price: "\(monthly.displayPrice)/\(L("paywall.unit.month"))"
            )
        }

        // Yearly with savings badge
        if let yearly, let monthly {
            let savingsText = savingsText(yearly: yearly, monthly: monthly)
            yearlyRow.configure(
                title: L("paywall.option.yearly"),
                badge: savingsText,
                price: "\(yearly.displayPrice)/\(L("paywall.unit.year"))"
            )
        } else if let yearly {
            yearlyRow.configure(
                title: L("paywall.option.yearly"),
                badge: nil,
                price: "\(yearly.displayPrice)/\(L("paywall.unit.year"))"
            )
        }

        // Lifetime
        if let lifetime {
            lifetimeRow.configure(
                title: L("paywall.option.lifetime"),
                badge: L("paywall.badge.best_value"),
                price: lifetime.displayPrice
            )
        }
    }

    private func updateCTAButton() {
        let isPro = EntitlementsService.shared.isPro

        if isPro {
            ctaButton.title = L("paywall.status.already_pro")
            ctaButton.isEnabled = false
            ctaButton.layer?.backgroundColor = NSColor.systemGray.cgColor
            return
        }

        ctaButton.isEnabled = true
        ctaButton.layer?.backgroundColor = brandColor.cgColor

        guard let product = products[selectedProductID] else {
            ctaButton.title = L("paywall.price.loading")
            return
        }

        switch selectedProductID {
        case EntitlementsService.ProductID.monthly:
            ctaButton.title = L("paywall.cta.subscribe_monthly", product.displayPrice)
        case EntitlementsService.ProductID.yearly:
            ctaButton.title = L("paywall.cta.subscribe_yearly", product.displayPrice)
        case EntitlementsService.ProductID.lifetime:
            ctaButton.title = L("paywall.cta.unlock_lifetime", product.displayPrice)
        default:
            ctaButton.title = L("paywall.action.upgrade_to_pro")
        }
    }

    private func refreshEntitlementUI() {
        // Status shown in CTA button, no separate label needed
    }

    private func savingsText(yearly: Product, monthly: Product) -> String {
        let yearlyValue = NSDecimalNumber(decimal: yearly.price).doubleValue
        let monthlyValue = NSDecimalNumber(decimal: monthly.price).doubleValue
        guard monthlyValue > 0 else { return "" }
        let monthlyAnnual = monthlyValue * 12
        guard monthlyAnnual > 0 else { return "" }
        let savings = max(0, 1 - (yearlyValue / monthlyAnnual))
        let pct = Int((savings * 100).rounded())
        return L("paywall.badge.save_percent", "\(pct)")
    }

    // MARK: - Observing

    private func startProStatusObserver() {
        guard proStatusObserver == nil else { return }
        proStatusObserver = NotificationCenter.default.addObserver(
            forName: .proStatusDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshUI()
        }
    }
}

// MARK: - Plan Option Row

private final class PlanOptionRow: NSView {
    var onSelect: (() -> Void)?
    var isSelected: Bool = false { didSet { updateStyle() } }

    private let radioImage = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let badgeLabel = NSTextField(labelWithString: "")
    private let badgeContainer = NSView()
    private let priceLabel = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func configure(title: String, badge: String?, price: String) {
        titleLabel.stringValue = title
        priceLabel.stringValue = price

        if let badge, !badge.isEmpty {
            badgeLabel.stringValue = badge
            badgeContainer.isHidden = false
        } else {
            badgeContainer.isHidden = true
        }
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false

        // Radio image
        radioImage.translatesAutoresizingMaskIntoConstraints = false

        // Title
        titleLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        // Badge
        badgeContainer.wantsLayer = true
        badgeContainer.layer?.cornerRadius = 4
        badgeContainer.layer?.backgroundColor = NSColor.systemGreen.withAlphaComponent(0.15).cgColor
        badgeContainer.translatesAutoresizingMaskIntoConstraints = false
        badgeContainer.isHidden = true

        badgeLabel.font = NSFont.systemFont(ofSize: 10, weight: .semibold)
        badgeLabel.textColor = NSColor.systemGreen
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        badgeContainer.addSubview(badgeLabel)

        NSLayoutConstraint.activate([
            badgeLabel.leadingAnchor.constraint(equalTo: badgeContainer.leadingAnchor, constant: 6),
            badgeLabel.trailingAnchor.constraint(equalTo: badgeContainer.trailingAnchor, constant: -6),
            badgeLabel.topAnchor.constraint(equalTo: badgeContainer.topAnchor, constant: 2),
            badgeLabel.bottomAnchor.constraint(equalTo: badgeContainer.bottomAnchor, constant: -2),
        ])

        // Price
        priceLabel.font = NSFont.systemFont(ofSize: 14, weight: .regular)
        priceLabel.textColor = .secondaryLabelColor
        priceLabel.alignment = .right
        priceLabel.translatesAutoresizingMaskIntoConstraints = false

        // Left side: radio + title + badge
        let leftStack = NSStackView(views: [radioImage, titleLabel, badgeContainer])
        leftStack.orientation = .horizontal
        leftStack.spacing = 8
        leftStack.alignment = .centerY
        leftStack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(leftStack)
        addSubview(priceLabel)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 44),

            radioImage.widthAnchor.constraint(equalToConstant: 20),
            radioImage.heightAnchor.constraint(equalToConstant: 20),

            leftStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            leftStack.centerYAnchor.constraint(equalTo: centerYAnchor),

            priceLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            priceLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        // Click gesture
        let click = NSClickGestureRecognizer(target: self, action: #selector(clicked))
        addGestureRecognizer(click)

        updateStyle()
    }

    private func updateStyle() {
        let symbolName = isSelected ? "checkmark.circle.fill" : "circle"
        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        let tintColor: NSColor = isSelected ? brandColor : .tertiaryLabelColor

        radioImage.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
        radioImage.contentTintColor = tintColor
    }

    @objc private func clicked() {
        onSelect?()
    }
}

// MARK: - Feature Row

private final class FeatureRow: NSView {
    init(iconName: String, title: String, subtitle: String) {
        super.init(frame: .zero)
        setup(iconName: iconName, title: title, subtitle: subtitle)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    private func setup(iconName: String, title: String, subtitle: String) {
        translatesAutoresizingMaskIntoConstraints = false

        // Icon container with fixed width for consistent alignment
        let iconContainer = NSView()
        iconContainer.translatesAutoresizingMaskIntoConstraints = false

        let iconView = NSImageView()
        let config = NSImage.SymbolConfiguration(pointSize: 22, weight: .medium)
        iconView.image = NSImage(systemSymbolName: iconName, accessibilityDescription: title)?
            .withSymbolConfiguration(config)
        iconView.contentTintColor = brandColor
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.addSubview(iconView)

        // Title
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        // Subtitle
        let subtitleLabel = NSTextField(labelWithString: subtitle)
        subtitleLabel.font = NSFont.systemFont(ofSize: 12)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.maximumNumberOfLines = 2
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        let textStack = NSStackView(views: [titleLabel, subtitleLabel])
        textStack.orientation = .vertical
        textStack.spacing = 2
        textStack.alignment = .leading
        textStack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(iconContainer)
        addSubview(textStack)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: 60),

            // Icon container - fixed width ensures consistent text alignment
            iconContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            iconContainer.widthAnchor.constraint(equalToConstant: 36),
            iconContainer.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            iconContainer.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),

            // Icon centered in container
            iconView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),

            // Text stack - fixed leading anchor relative to icon container
            textStack.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 12),
            textStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            textStack.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }
}
