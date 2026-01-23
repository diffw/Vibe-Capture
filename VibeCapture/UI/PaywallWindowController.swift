import AppKit
import QuartzCore
import StoreKit

private let paywallBrandColor = NSColor(red: 1.0, green: 0.553, blue: 0.463, alpha: 1.0) // #FF8D76
private let paywallBrandGradientEnd = NSColor.systemPurple

final class PaywallWindowController: NSWindowController, NSWindowDelegate {
    static let shared = PaywallWindowController()

    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let statusLabel = NSTextField(labelWithString: "")

    private let freeColumnTitle = NSTextField(labelWithString: "")
    private let proColumnTitle = NSTextField(labelWithString: "")
    private let compareStack = NSStackView()
    private let compareContentStack = NSStackView()

    private let yearlyCard = PlanCardView()
    private let monthlyCard = PlanCardView()
    private let lifetimeCard = PlanCardView()

    private let ctaButton = PaywallCTAButton()
    private let restoreButton = NSButton(title: "", target: nil, action: nil)
    private let manageButton = NSButton(title: "", target: nil, action: nil)
    private let closeButton = NSButton(title: "", target: nil, action: nil)

    private let termsButton = NSButton(title: "", target: nil, action: nil)
    private let privacyButton = NSButton(title: "", target: nil, action: nil)

    private var proStatusObserver: Any?
    private var products: [String: Product] = [:]
    private var selectedProductID: String = EntitlementsService.ProductID.yearly

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 520),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = L("paywall.window_title")
        window.isReleasedWhenClosed = false
        // Keep above the capture modal (which uses `.floating`).
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
        // Ensure it appears above floating capture windows.
        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
        Task { await loadProductsAndRefreshUI() }
    }

    func windowWillClose(_ notification: Notification) {
        // Keep controller alive (singleton). No-op.
    }

    // MARK: - UI

    private func buildContentView() -> NSView {
        let content = NSView()

        titleLabel.stringValue = L("paywall.title")
        titleLabel.font = NSFont.systemFont(ofSize: 22, weight: .semibold)

        subtitleLabel.stringValue = L("paywall.subtitle")
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.font = NSFont.systemFont(ofSize: 12)
        subtitleLabel.maximumNumberOfLines = 2

        statusLabel.stringValue = ""
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.font = NSFont.systemFont(ofSize: 11)
        statusLabel.maximumNumberOfLines = 2

        setupCompareSection()
        setupPlanCards()
        setupLegalButtons()

        // Default selection: Yearly (recommended)
        selectedProductID = EntitlementsService.ProductID.yearly
        updatePlanSelectionUI()

        ctaButton.translatesAutoresizingMaskIntoConstraints = false
        ctaButton.onClick = { [weak self] in
            self?.performPurchase()
        }

        restoreButton.title = L("paywall.action.restore")
        restoreButton.target = self
        restoreButton.action = #selector(restorePressed)
        restoreButton.isBordered = false
        restoreButton.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        restoreButton.contentTintColor = .secondaryLabelColor

        manageButton.title = L("paywall.action.manage")
        manageButton.target = self
        manageButton.action = #selector(managePressed)
        manageButton.isBordered = false
        manageButton.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        manageButton.contentTintColor = .secondaryLabelColor

        closeButton.title = L("paywall.action.close")
        closeButton.target = self
        closeButton.action = #selector(closePressed)

        let plansRow = NSStackView(views: [yearlyCard, monthlyCard, lifetimeCard])
        plansRow.orientation = .horizontal
        plansRow.alignment = .top
        plansRow.spacing = 10
        plansRow.distribution = .fillEqually

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .vertical)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

        let bottomRow = NSStackView(views: [
            termsButton,
            dotSeparatorLabel(),
            privacyButton,
            NSView(),
            restoreButton,
            dotSeparatorLabel(),
            manageButton,
            dotSeparatorLabel(),
            closeButton,
        ])
        bottomRow.orientation = .horizontal
        bottomRow.alignment = .centerY
        bottomRow.spacing = 6

        let stack = NSStackView(views: [
            titleLabel,
            subtitleLabel,
            compareStack,
            plansRow,
            spacer,
            ctaButton,
            statusLabel,
            bottomRow,
        ])
        stack.orientation = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.alignment = .leading

        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -16),

            stack.widthAnchor.constraint(equalTo: content.widthAnchor, constant: -32),

            compareStack.widthAnchor.constraint(equalTo: stack.widthAnchor),
            plansRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            ctaButton.widthAnchor.constraint(equalTo: stack.widthAnchor),
            bottomRow.widthAnchor.constraint(equalTo: stack.widthAnchor),

            ctaButton.heightAnchor.constraint(equalToConstant: 64),
        ])

        refreshEntitlementUI()
        refreshPaywallUI()
        return content
    }

    private func refreshPaywallUI() {
        // Compare section is static text; plans depend on products.
        refreshPlanCards()
        updatePlanSelectionUI()
        refreshCTA()
    }

    private func refreshEntitlementUI() {
        let isPro = EntitlementsService.shared.isPro
        ctaButton.isEnabled = !isPro
        if isPro {
            statusLabel.stringValue = L("paywall.status.already_pro")
        } else {
            statusLabel.stringValue = ""
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
            refreshPaywallUI()
        } catch {
            statusLabel.stringValue = L("paywall.error.generic")
        }
        refreshEntitlementUI()
    }

    // MARK: - Actions

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
            self.refreshEntitlementUI()
            self.refreshPaywallUI()
        }
    }

    @objc private func purchasePressed() {
        performPurchase()
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

    @objc private func closePressed() {
        window?.performClose(nil)
    }

    // MARK: - Observing

    private func startProStatusObserver() {
        guard proStatusObserver == nil else { return }
        proStatusObserver = NotificationCenter.default.addObserver(
            forName: .proStatusDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshEntitlementUI()
            self?.refreshPaywallUI()
        }
    }

    // MARK: - Sections

    private func setupCompareSection() {
        compareContentStack.orientation = .vertical
        compareContentStack.spacing = 8
        compareContentStack.translatesAutoresizingMaskIntoConstraints = false

        freeColumnTitle.stringValue = L("paywall.compare.free")
        freeColumnTitle.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        freeColumnTitle.textColor = .secondaryLabelColor

        proColumnTitle.stringValue = L("paywall.compare.pro")
        proColumnTitle.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        proColumnTitle.textColor = paywallBrandColor

        let header = compareRow(left: freeColumnTitle, right: proColumnTitle, isHeader: true)
        compareContentStack.addArrangedSubview(header)

        // Row 1: Annotation tools
        compareContentStack.addArrangedSubview(
            compareRowText(
                feature: L("paywall.feature.annotations"),
                free: L("paywall.feature.annotations.free"),
                pro: L("paywall.feature.annotations.pro"),
                proState: .available
            )
        )
        compareContentStack.addArrangedSubview(rowSeparator())

        // Row 2: Custom apps
        compareContentStack.addArrangedSubview(
            compareRowText(
                feature: L("paywall.feature.custom_apps"),
                free: L("paywall.feature.custom_apps.free"),
                pro: L("paywall.feature.custom_apps.pro"),
                proState: .available
            )
        )
        compareContentStack.addArrangedSubview(rowSeparator())

        // Row 3: Download manager (coming soon)
        compareContentStack.addArrangedSubview(
            compareRowText(
                feature: L("paywall.feature.download_manager"),
                free: L("paywall.feature.unavailable"),
                pro: L("paywall.feature.coming_soon"),
                proState: .comingSoon
            )
        )
        compareContentStack.addArrangedSubview(rowSeparator())

        // Row 4: Send queue (coming soon)
        compareContentStack.addArrangedSubview(
            compareRowText(
                feature: L("paywall.feature.send_queue"),
                free: L("paywall.feature.unavailable"),
                pro: L("paywall.feature.coming_soon"),
                proState: .comingSoon
            )
        )

        // Put compare section inside a subtle container (Auto Layout, top-aligned).
        let box = NSView()
        box.wantsLayer = true
        box.layer?.cornerRadius = 10
        box.layer?.borderWidth = 1
        box.layer?.borderColor = NSColor.separatorColor.cgColor
        box.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        box.translatesAutoresizingMaskIntoConstraints = false

        box.addSubview(compareContentStack)
        NSLayoutConstraint.activate([
            compareContentStack.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 12),
            compareContentStack.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -12),
            compareContentStack.topAnchor.constraint(equalTo: box.topAnchor, constant: 12),
            compareContentStack.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -12),
        ])

        compareStack.orientation = .vertical
        compareStack.spacing = 0
        compareStack.translatesAutoresizingMaskIntoConstraints = false
        compareStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        compareStack.addArrangedSubview(box)

        // Prevent the compare section from stretching vertically.
        compareStack.setContentHuggingPriority(.required, for: .vertical)
        box.setContentHuggingPriority(.required, for: .vertical)
    }

    private enum ProState {
        case available
        case comingSoon
    }

    private func compareRowText(feature: String, free: String, pro: String, proState: ProState) -> NSView {
        let featureLabel = NSTextField(labelWithString: feature)
        featureLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)

        let freeView: NSView
        let proView: NSView

        switch proState {
        case .available:
            freeView = compareValueView(
                text: free,
                symbolName: "checkmark.circle.fill",
                symbolTint: NSColor.secondaryLabelColor
            )
            proView = compareValueView(
                text: pro,
                symbolName: "checkmark.circle.fill",
                symbolTint: paywallBrandColor
            )
        case .comingSoon:
            freeView = compareValueView(
                text: free,
                symbolName: "minus.circle",
                symbolTint: NSColor.tertiaryLabelColor
            )
            proView = pill(
                text: L("paywall.feature.coming_soon"),
                background: NSColor.systemGray.withAlphaComponent(0.15),
                foreground: .secondaryLabelColor
            )
        }

        let row = compareRow(left: freeView, right: proView, isHeader: false, featureLabel: featureLabel)
        return row
    }

    private func compareRow(left: NSView, right: NSView, isHeader: Bool, featureLabel: NSView? = nil) -> NSView {
        let grid = NSStackView()
        grid.orientation = .horizontal
        grid.alignment = .top
        grid.spacing = 12

        let feature = featureLabel ?? NSView()
        if featureLabel == nil {
            feature.setFrameSize(NSSize(width: 0, height: 0))
        }

        let leftCol = NSStackView(views: [left])
        leftCol.orientation = .vertical
        let rightCol = NSStackView(views: [right])
        rightCol.orientation = .vertical

        grid.addArrangedSubview(feature)
        grid.addArrangedSubview(leftCol)
        grid.addArrangedSubview(rightCol)

        feature.translatesAutoresizingMaskIntoConstraints = false
        left.translatesAutoresizingMaskIntoConstraints = false
        right.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            feature.widthAnchor.constraint(equalToConstant: 180),
            leftCol.widthAnchor.constraint(equalToConstant: 160),
        ])

        if isHeader {
            let sep = NSBox()
            sep.boxType = .separator
            let stack = NSStackView(views: [grid, sep])
            stack.orientation = .vertical
            stack.spacing = 8
            return stack
        }
        return grid
    }

    private func rowSeparator() -> NSBox {
        let sep = NSBox()
        sep.boxType = .separator
        return sep
    }

    private func compareValueView(text: String, symbolName: String, symbolTint: NSColor) -> NSView {
        let iconConfig = NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(iconConfig)

        let imageView = NSImageView(image: image ?? NSImage())
        imageView.contentTintColor = symbolTint
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: 14),
            imageView.heightAnchor.constraint(equalToConstant: 14),
        ])

        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: 12)
        label.textColor = .labelColor
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 2

        let stack = NSStackView(views: [imageView, label])
        stack.orientation = .horizontal
        stack.alignment = .top
        stack.spacing = 6
        return stack
    }

    private func setupPlanCards() {
        yearlyCard.onSelect = { [weak self] in self?.selectPlan(EntitlementsService.ProductID.yearly) }
        monthlyCard.onSelect = { [weak self] in self?.selectPlan(EntitlementsService.ProductID.monthly) }
        lifetimeCard.onSelect = { [weak self] in self?.selectPlan(EntitlementsService.ProductID.lifetime) }

        yearlyCard.badgeText = L("paywall.badge.recommended")
        monthlyCard.badgeText = nil
        lifetimeCard.badgeText = nil
    }

    private func setupLegalButtons() {
        termsButton.title = L("paywall.legal.terms")
        termsButton.isBordered = false
        termsButton.target = self
        termsButton.action = #selector(openTerms)

        privacyButton.title = L("paywall.legal.privacy")
        privacyButton.isBordered = false
        privacyButton.target = self
        privacyButton.action = #selector(openPrivacy)
    }

    private func selectPlan(_ productID: String) {
        selectedProductID = productID
        updatePlanSelectionUI()
        refreshPlanCards()
    }

    private func updatePlanSelectionUI() {
        yearlyCard.isSelected = (selectedProductID == EntitlementsService.ProductID.yearly)
        monthlyCard.isSelected = (selectedProductID == EntitlementsService.ProductID.monthly)
        lifetimeCard.isSelected = (selectedProductID == EntitlementsService.ProductID.lifetime)
    }

    private func refreshPlanCards() {
        let yearly = products[EntitlementsService.ProductID.yearly]
        let monthly = products[EntitlementsService.ProductID.monthly]
        let lifetime = products[EntitlementsService.ProductID.lifetime]

        yearlyCard.title = L("paywall.option.yearly")
        monthlyCard.title = L("paywall.option.monthly")
        lifetimeCard.title = L("paywall.option.lifetime")

        yearlyCard.priceText = yearly?.displayPrice ?? L("paywall.price.loading")
        monthlyCard.priceText = monthly?.displayPrice ?? L("paywall.price.loading")
        lifetimeCard.priceText = lifetime?.displayPrice ?? L("paywall.price.loading")

        // Subtitles
        yearlyCard.subtitleText = L("paywall.plan.per_year")
        monthlyCard.subtitleText = L("paywall.plan.per_month")
        lifetimeCard.subtitleText = L("paywall.plan.one_time")

        // Yearly: show savings + equivalent monthly (best practice)
        if let yearly, let monthly {
            let savings = savingsPercent(yearly: yearly, monthly: monthly)
            let eqMonthly = equivalentMonthlyText(yearly: yearly)
            yearlyCard.detailLines = [
                L("paywall.plan.save_percent", savings),
                L("paywall.plan.equivalent_monthly", eqMonthly),
            ]
        } else {
            yearlyCard.detailLines = [
                L("paywall.plan.save_percent.loading"),
                L("paywall.plan.equivalent_monthly.loading"),
            ]
        }

        monthlyCard.detailLines = []
        lifetimeCard.detailLines = []
    }

    private func refreshCTA() {
        if EntitlementsService.shared.isPro {
            ctaButton.titleText = L("paywall.status.already_pro")
            ctaButton.subtitleText = ""
            return
        }

        // Strong CTA: emphasize yearly savings when possible.
        if selectedProductID == EntitlementsService.ProductID.yearly,
           let yearly = products[EntitlementsService.ProductID.yearly],
           let monthly = products[EntitlementsService.ProductID.monthly] {
            let savings = savingsPercent(yearly: yearly, monthly: monthly)
            ctaButton.titleText = L("paywall.cta.title_with_savings", savings)
            let eqMonthly = equivalentMonthlyText(yearly: yearly)
            ctaButton.subtitleText = L("paywall.cta.subtitle_yearly_equivalent", eqMonthly)
            return
        }

        // Fallback: show selected plan + price.
        ctaButton.titleText = L("paywall.action.upgrade_to_pro")
        if let product = products[selectedProductID] {
            let unit: String
            switch selectedProductID {
            case EntitlementsService.ProductID.monthly:
                unit = L("paywall.plan.per_month")
            case EntitlementsService.ProductID.yearly:
                unit = L("paywall.plan.per_year")
            default:
                unit = L("paywall.plan.one_time")
            }
            ctaButton.subtitleText = "\(product.displayPrice) · \(unit)"
        } else {
            ctaButton.subtitleText = L("paywall.price.loading")
        }
    }

    private func savingsPercent(yearly: Product, monthly: Product) -> String {
        // Best practice: compare yearly vs monthly * 12
        let yearlyValue = NSDecimalNumber(decimal: yearly.price).doubleValue
        let monthlyValue = NSDecimalNumber(decimal: monthly.price).doubleValue
        guard monthlyValue > 0 else { return "0%" }
        let monthlyAnnual = monthlyValue * 12
        guard monthlyAnnual > 0 else { return "0%" }
        let savings = max(0, 1 - (yearlyValue / monthlyAnnual))
        let pct = Int((savings * 100).rounded())
        return "\(pct)%"
    }

    private func equivalentMonthlyText(yearly: Product) -> String {
        let eq = yearly.price / 12
        // Format using the yearly product's currency/locale style.
        return eq.formatted(yearly.priceFormatStyle)
    }

    private func dotSeparatorLabel() -> NSTextField {
        let label = NSTextField(labelWithString: "·")
        label.textColor = .tertiaryLabelColor
        return label
    }

    private func pill(text: String, background: NSColor, foreground: NSColor) -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.cornerRadius = 8
        container.layer?.backgroundColor = background.cgColor
        container.translatesAutoresizingMaskIntoConstraints = false

        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: 10, weight: .semibold)
        label.textColor = foreground
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 3),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -3),
        ])

        return container
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
}

// MARK: - Plan Card

private final class PlanCardView: NSView {
    var onSelect: (() -> Void)?

    var title: String = "" { didSet { titleLabel.stringValue = title } }
    var priceText: String = "" { didSet { priceLabel.stringValue = priceText } }
    var subtitleText: String = "" { didSet { subtitleLabel.stringValue = subtitleText } }
    var detailLines: [String] = [] { didSet { refreshDetails() } }
    var badgeText: String? { didSet { refreshBadge() } }

    var isSelected: Bool = false { didSet { updateStyle() } }

    private let container = NSBox()
    private let titleLabel = NSTextField(labelWithString: "")
    private let badgeLabel = NSTextField(labelWithString: "")
    private let priceLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let detailsStack = NSStackView()
    private let badgeBox = NSBox()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true

        container.boxType = .custom
        container.borderWidth = 1
        container.cornerRadius = 12
        container.borderColor = NSColor.separatorColor
        container.fillColor = NSColor.controlBackgroundColor
        container.translatesAutoresizingMaskIntoConstraints = false
        addSubview(container)

        titleLabel.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        priceLabel.font = NSFont.systemFont(ofSize: 22, weight: .bold)
        subtitleLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        subtitleLabel.textColor = .secondaryLabelColor

        detailsStack.orientation = .vertical
        detailsStack.spacing = 4

        badgeLabel.font = NSFont.systemFont(ofSize: 10, weight: .semibold)
        badgeLabel.textColor = NSColor.white
        badgeBox.boxType = .custom
        badgeBox.borderWidth = 0
        badgeBox.cornerRadius = 8
        badgeBox.fillColor = paywallBrandColor
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        badgeBox.addSubview(badgeLabel)
        NSLayoutConstraint.activate([
            badgeLabel.leadingAnchor.constraint(equalTo: badgeBox.leadingAnchor, constant: 8),
            badgeLabel.trailingAnchor.constraint(equalTo: badgeBox.trailingAnchor, constant: -8),
            badgeLabel.topAnchor.constraint(equalTo: badgeBox.topAnchor, constant: 3),
            badgeLabel.bottomAnchor.constraint(equalTo: badgeBox.bottomAnchor, constant: -3),
        ])
        badgeBox.isHidden = true

        let topRow = NSStackView(views: [titleLabel, NSView(), badgeBox])
        topRow.orientation = .horizontal
        topRow.alignment = .centerY

        let stack = NSStackView(views: [topRow, priceLabel, subtitleLabel, detailsStack])
        stack.orientation = .vertical
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: leadingAnchor),
            container.trailingAnchor.constraint(equalTo: trailingAnchor),
            container.topAnchor.constraint(equalTo: topAnchor),
            container.bottomAnchor.constraint(equalTo: bottomAnchor),

            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor, constant: -12),
        ])

        let click = NSClickGestureRecognizer(target: self, action: #selector(clicked))
        addGestureRecognizer(click)

        updateStyle()
    }

    private func refreshDetails() {
        detailsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for line in detailLines {
            let l = NSTextField(labelWithString: line)
            l.font = NSFont.systemFont(ofSize: 11, weight: .medium)
            l.textColor = .secondaryLabelColor
            detailsStack.addArrangedSubview(l)
        }
    }

    private func refreshBadge() {
        if let badgeText, !badgeText.isEmpty {
            badgeLabel.stringValue = badgeText
            badgeBox.isHidden = false
        } else {
            badgeBox.isHidden = true
        }
    }

    private func updateStyle() {
        if isSelected {
            container.borderColor = paywallBrandColor
            container.fillColor = paywallBrandColor.withAlphaComponent(0.10)
        } else {
            container.borderColor = NSColor.separatorColor
            container.fillColor = NSColor.controlBackgroundColor
        }
    }

    @objc private func clicked() {
        onSelect?()
    }
}

// MARK: - Paywall CTA Button

private final class PaywallCTAButton: NSControl {
    var onClick: (() -> Void)?

    var titleText: String = "" {
        didSet { titleLabel.stringValue = titleText }
    }

    var subtitleText: String = "" {
        didSet { subtitleLabel.stringValue = subtitleText }
    }

    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")

    private let gradientLayer = CAGradientLayer()
    private var tracking: NSTrackingArea?
    private var isHovered = false { didSet { updateStyle() } }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    override func layout() {
        super.layout()
        gradientLayer.frame = bounds
        gradientLayer.cornerRadius = 14
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let t = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(t)
        tracking = t
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
    }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }
        // Simple pressed feedback.
        layer?.opacity = 0.92
    }

    override func mouseUp(with event: NSEvent) {
        guard isEnabled else { return }
        layer?.opacity = 1.0
        onClick?()
    }

    private func setup() {
        wantsLayer = true
        layer = gradientLayer

        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        gradientLayer.colors = [
            paywallBrandColor.cgColor,
            paywallBrandGradientEnd.cgColor,
        ]

        // Shadow
        gradientLayer.shadowColor = NSColor.black.cgColor
        gradientLayer.shadowOpacity = 0.18
        gradientLayer.shadowRadius = 12
        gradientLayer.shadowOffset = CGSize(width: 0, height: -2)

        titleLabel.font = NSFont.systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.alignment = .center

        subtitleLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        subtitleLabel.textColor = NSColor.white.withAlphaComponent(0.85)
        subtitleLabel.alignment = .center
        subtitleLabel.maximumNumberOfLines = 2

        let stack = NSStackView(views: [titleLabel, subtitleLabel])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        updateStyle()
    }

    private func updateStyle() {
        if isEnabled {
            gradientLayer.colors = [
                paywallBrandColor.cgColor,
                paywallBrandGradientEnd.cgColor,
            ]
            titleLabel.textColor = .white
            subtitleLabel.textColor = NSColor.white.withAlphaComponent(0.85)
            gradientLayer.shadowOpacity = isHovered ? 0.26 : 0.18
        } else {
            gradientLayer.colors = [
                NSColor.quaternaryLabelColor.cgColor,
                NSColor.tertiaryLabelColor.cgColor,
            ]
            titleLabel.textColor = NSColor.secondaryLabelColor
            subtitleLabel.textColor = NSColor.tertiaryLabelColor
            gradientLayer.shadowOpacity = 0.0
        }
    }
}

