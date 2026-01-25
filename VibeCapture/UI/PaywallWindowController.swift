import AppKit
import StoreKit

private let brandColor = NSColor(red: 1.0, green: 0.553, blue: 0.463, alpha: 1.0) // #FF8D76
private let paywallBackgroundColor = NSColor.white
private let cardBackgroundColor = NSColor.white

final class PaywallWindowController: NSWindowController, NSWindowDelegate {
    static let shared = PaywallWindowController()

    // MARK: - State

    private var proStatusObserver: Any?
    private var products: [String: Product] = [:]
    private var selectedProductID: String = EntitlementsService.ProductID.yearly
    private var modalSelectedProductID: String = EntitlementsService.ProductID.yearly // Temporary selection in modal
    private var isEligibleForTrial: Bool = false
    private var productsLoadState: ProductsLoadState = .loading
    private var didRetryProductsLoadAfterError = false

    private enum ProductsLoadState {
        case loading
        case loaded
        case failed
    }

    // MARK: - Root Container

    private let rootView = NSView()

    // MARK: - Step 1: Main View

    private let step1View = NSView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let trialBadgeContainer = NSView()
    private let trialBadgeLabel = NSTextField(labelWithString: "")
    private let ctaButton = NSButton()
    private let priceSelectorButton = NSButton()

    // MARK: - Pro Status (for existing Pro users)

    private let proStatusContainer = NSBox()
    private let proStatusStack = NSStackView()

    // MARK: - Legal Links

    private let legalStack = NSStackView()
    private let termsButton = NSButton(title: "", target: nil, action: nil)
    private let privacyButton = NSButton(title: "", target: nil, action: nil)
    private let restoreButton = NSButton(title: "", target: nil, action: nil)
    private let manageButton = NSButton(title: "", target: nil, action: nil)

    // MARK: - Step 2: Plan Choose (Overlay within same window)

    private let planModalOverlay = NSView()
    private let planModalContainer = NSView()
    private var planRows: [String: PlanRowView] = [:]
    private let planModalCTAButton = NSButton()

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 480),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = L("paywall.window_title")
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 420, height: 480))
        window.contentMinSize = NSSize(width: 420, height: 400)
        window.contentMaxSize = NSSize(width: 420, height: 700)
        window.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 1)
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.center()
        super.init(window: window)
        window.delegate = self
        window.contentView = buildRootView()
        startProStatusObserver()
    }

    required init?(coder: NSCoder) { nil }

    func show() {
        guard let window else { return }
        NSApp.activate(ignoringOtherApps: true)
        window.center()
        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
        hidePlanModal(animated: false)
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
                if !self.planModalOverlay.isHidden {
                    self.hidePlanModal(animated: true)
                } else {
                    window.close()
                }
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

    // MARK: - Build Root View

    private func buildRootView() -> NSView {
        rootView.wantsLayer = true

        // Build Step 1
        buildStep1View()

        // Build Step 2 (Plan Modal Overlay)
        buildPlanModalOverlay()

        rootView.addSubview(step1View)
        rootView.addSubview(planModalOverlay)

        step1View.translatesAutoresizingMaskIntoConstraints = false
        planModalOverlay.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            step1View.topAnchor.constraint(equalTo: rootView.topAnchor),
            step1View.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),
            step1View.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            step1View.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),

            planModalOverlay.topAnchor.constraint(equalTo: rootView.topAnchor),
            planModalOverlay.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),
            planModalOverlay.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            planModalOverlay.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
        ])

        planModalOverlay.isHidden = true
        return rootView
    }

    // MARK: - Build Step 1

    private func buildStep1View() {
        step1View.wantsLayer = true
        step1View.layer?.backgroundColor = paywallBackgroundColor.cgColor

        // Title
        titleLabel.font = NSFont.systemFont(ofSize: 24, weight: .bold)
        titleLabel.alignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        // Subtitle
        subtitleLabel.font = NSFont.systemFont(ofSize: 14)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.alignment = .center
        subtitleLabel.maximumNumberOfLines = 2
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        // Trial badge
        setupTrialBadge()

        // Pro status card
        setupProStatusCard()

        // CTA Button
        setupCTAButton()

        // Price selector
        setupPriceSelector()

        // Legal links
        setupLegalSection()

        // Layout
        let contentStack = NSStackView()
        contentStack.orientation = .vertical
        contentStack.spacing = 20
        contentStack.alignment = .centerX
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        let titleStack = NSStackView(views: [titleLabel, subtitleLabel])
        titleStack.orientation = .vertical
        titleStack.spacing = 8
        titleStack.alignment = .centerX

        contentStack.addArrangedSubview(titleStack)
        contentStack.addArrangedSubview(proStatusContainer)
        contentStack.addArrangedSubview(trialBadgeContainer)

        let bottomStack = NSStackView()
        bottomStack.orientation = .vertical
        bottomStack.spacing = 12
        bottomStack.alignment = .centerX
        bottomStack.translatesAutoresizingMaskIntoConstraints = false

        bottomStack.addArrangedSubview(ctaButton)
        bottomStack.addArrangedSubview(priceSelectorButton)

        step1View.addSubview(contentStack)
        step1View.addSubview(bottomStack)
        step1View.addSubview(legalStack)

        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: step1View.topAnchor, constant: 40),
            contentStack.leadingAnchor.constraint(equalTo: step1View.leadingAnchor, constant: 32),
            contentStack.trailingAnchor.constraint(equalTo: step1View.trailingAnchor, constant: -32),

            titleStack.widthAnchor.constraint(equalTo: contentStack.widthAnchor),

            bottomStack.leadingAnchor.constraint(equalTo: step1View.leadingAnchor, constant: 32),
            bottomStack.trailingAnchor.constraint(equalTo: step1View.trailingAnchor, constant: -32),
            bottomStack.bottomAnchor.constraint(equalTo: legalStack.topAnchor, constant: -20),

            ctaButton.widthAnchor.constraint(equalTo: bottomStack.widthAnchor),
            ctaButton.heightAnchor.constraint(equalToConstant: 48),

            legalStack.leadingAnchor.constraint(equalTo: step1View.leadingAnchor, constant: 24),
            legalStack.trailingAnchor.constraint(equalTo: step1View.trailingAnchor, constant: -24),
            legalStack.bottomAnchor.constraint(equalTo: step1View.bottomAnchor, constant: -16),
        ])

        refreshUI()
    }

    // MARK: - Trial Badge

    private func setupTrialBadge() {
        trialBadgeContainer.wantsLayer = true
        trialBadgeContainer.layer?.backgroundColor = cardBackgroundColor.cgColor
        trialBadgeContainer.layer?.cornerRadius = 16
        trialBadgeContainer.layer?.shadowColor = NSColor.black.cgColor
        trialBadgeContainer.layer?.shadowOpacity = 0.1
        trialBadgeContainer.layer?.shadowOffset = CGSize(width: 0, height: 2)
        trialBadgeContainer.layer?.shadowRadius = 8
        trialBadgeContainer.translatesAutoresizingMaskIntoConstraints = false

        let iconView = NSImageView()
        let iconConfig = NSImage.SymbolConfiguration(pointSize: 32, weight: .medium)
        iconView.image = NSImage(systemSymbolName: "calendar.badge.checkmark", accessibilityDescription: nil)?
            .withSymbolConfiguration(iconConfig)
        iconView.contentTintColor = NSColor.systemGreen
        iconView.translatesAutoresizingMaskIntoConstraints = false

        trialBadgeLabel.font = NSFont.systemFont(ofSize: 18, weight: .semibold)
        trialBadgeLabel.alignment = .center
        trialBadgeLabel.translatesAutoresizingMaskIntoConstraints = false

        let badgeStack = NSStackView(views: [iconView, trialBadgeLabel])
        badgeStack.orientation = .vertical
        badgeStack.spacing = 8
        badgeStack.alignment = .centerX
        badgeStack.translatesAutoresizingMaskIntoConstraints = false

        trialBadgeContainer.addSubview(badgeStack)

        NSLayoutConstraint.activate([
            trialBadgeContainer.widthAnchor.constraint(equalToConstant: 160),
            trialBadgeContainer.heightAnchor.constraint(equalToConstant: 120),
            badgeStack.centerXAnchor.constraint(equalTo: trialBadgeContainer.centerXAnchor),
            badgeStack.centerYAnchor.constraint(equalTo: trialBadgeContainer.centerYAnchor),
        ])
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
            proStatusContainer.widthAnchor.constraint(equalToConstant: 320),
        ])

        proStatusContainer.isHidden = true
    }

    private func updateProStatusCard() {
        let status = EntitlementsService.shared.status
        let isPro = status.tier == .pro

        proStatusContainer.isHidden = !isPro
        trialBadgeContainer.isHidden = isPro

        if !isPro { return }

        proStatusStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

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

        let typeLabel = NSTextField(labelWithString: L("paywall.pro_status.type", status.sourceDisplayName))
        typeLabel.font = NSFont.systemFont(ofSize: 13)
        typeLabel.textColor = .secondaryLabelColor
        proStatusStack.addArrangedSubview(typeLabel)

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

    // MARK: - CTA Button

    private func setupCTAButton() {
        ctaButton.bezelStyle = .regularSquare
        ctaButton.isBordered = false
        ctaButton.wantsLayer = true
        ctaButton.layer?.cornerRadius = 12
        ctaButton.layer?.backgroundColor = brandColor.cgColor
        ctaButton.contentTintColor = .white
        ctaButton.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        ctaButton.target = self
        ctaButton.action = #selector(ctaPressed)
        ctaButton.translatesAutoresizingMaskIntoConstraints = false
    }

    // MARK: - Price Selector

    private func setupPriceSelector() {
        priceSelectorButton.bezelStyle = .inline
        priceSelectorButton.isBordered = false
        priceSelectorButton.font = NSFont.systemFont(ofSize: 13)
        priceSelectorButton.contentTintColor = .secondaryLabelColor
        priceSelectorButton.target = self
        priceSelectorButton.action = #selector(priceSelectorPressed)
        priceSelectorButton.translatesAutoresizingMaskIntoConstraints = false

        let attachment = NSTextAttachment()
        let config = NSImage.SymbolConfiguration(pointSize: 10, weight: .medium)
        attachment.image = NSImage(systemSymbolName: "chevron.up.chevron.down", accessibilityDescription: nil)?
            .withSymbolConfiguration(config)

        let attrString = NSMutableAttributedString(string: "Loading... ")
        attrString.append(NSAttributedString(attachment: attachment))
        priceSelectorButton.attributedTitle = attrString
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
        legalStack.translatesAutoresizingMaskIntoConstraints = false

        rebuildLegalStack()
    }

    private func rebuildLegalStack() {
        legalStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        legalStack.addArrangedSubview(termsButton)
        legalStack.addArrangedSubview(dotLabel())
        legalStack.addArrangedSubview(privacyButton)

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        legalStack.addArrangedSubview(spacer)

        legalStack.addArrangedSubview(restoreButton)

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

    // MARK: - Build Plan Modal Overlay (Step 2)

    private func buildPlanModalOverlay() {
        // Semi-transparent background that captures clicks outside modal
        planModalOverlay.wantsLayer = true
        planModalOverlay.layer?.backgroundColor = NSColor.clear.cgColor

        // Background view (actual dark overlay) - receives clicks to dismiss
        let backgroundView = NSView()
        backgroundView.wantsLayer = true
        backgroundView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.4).cgColor
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        planModalOverlay.addSubview(backgroundView)

        // Send background to back so modal container is on top
        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: planModalOverlay.topAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: planModalOverlay.bottomAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: planModalOverlay.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: planModalOverlay.trailingAnchor),
        ])

        // Click on background to dismiss
        let overlayClick = NSClickGestureRecognizer(target: self, action: #selector(overlayBackgroundClicked))
        backgroundView.addGestureRecognizer(overlayClick)

        // Modal container (white card)
        planModalContainer.wantsLayer = true
        planModalContainer.layer?.backgroundColor = cardBackgroundColor.cgColor
        planModalContainer.layer?.cornerRadius = 20
        planModalContainer.layer?.shadowColor = NSColor.black.cgColor
        planModalContainer.layer?.shadowOpacity = 0.2
        planModalContainer.layer?.shadowOffset = CGSize(width: 0, height: -4)
        planModalContainer.layer?.shadowRadius = 16
        planModalContainer.translatesAutoresizingMaskIntoConstraints = false

        // Title
        let modalTitle = NSTextField(labelWithString: L("paywall.plan_modal.title"))
        modalTitle.font = NSFont.systemFont(ofSize: 20, weight: .bold)
        modalTitle.alignment = .center
        modalTitle.translatesAutoresizingMaskIntoConstraints = false

        // Plan rows
        let monthlyRow = PlanRowView(
            productID: EntitlementsService.ProductID.monthly,
            title: L("paywall.option.monthly"),
            subtitle: L("paywall.plan_modal.monthly_subtitle"),
            badge: nil
        )
        monthlyRow.onSelect = { [weak self] in self?.selectPlan(EntitlementsService.ProductID.monthly) }

        let yearlyRow = PlanRowView(
            productID: EntitlementsService.ProductID.yearly,
            title: L("paywall.option.yearly"),
            subtitle: L("paywall.plan_modal.yearly_subtitle"),
            badge: L("paywall.plan_modal.badge_popular")
        )
        yearlyRow.onSelect = { [weak self] in self?.selectPlan(EntitlementsService.ProductID.yearly) }

        let lifetimeRow = PlanRowView(
            productID: EntitlementsService.ProductID.lifetime,
            title: L("paywall.option.lifetime"),
            subtitle: L("paywall.plan_modal.lifetime_subtitle"),
            badge: nil
        )
        lifetimeRow.onSelect = { [weak self] in self?.selectPlan(EntitlementsService.ProductID.lifetime) }

        planRows[EntitlementsService.ProductID.monthly] = monthlyRow
        planRows[EntitlementsService.ProductID.yearly] = yearlyRow
        planRows[EntitlementsService.ProductID.lifetime] = lifetimeRow

        let plansStack = NSStackView(views: [monthlyRow, yearlyRow, lifetimeRow])
        plansStack.orientation = .vertical
        plansStack.spacing = 8
        plansStack.translatesAutoresizingMaskIntoConstraints = false

        // Cancel button - flat style with gray background
        let cancelButton = NSButton(title: L("button.cancel"), target: self, action: #selector(planModalCancelPressed))
        cancelButton.bezelStyle = .regularSquare
        cancelButton.isBordered = false
        cancelButton.wantsLayer = true
        cancelButton.layer?.cornerRadius = 8
        cancelButton.layer?.backgroundColor = NSColor.systemGray.withAlphaComponent(0.15).cgColor
        cancelButton.contentTintColor = .labelColor
        cancelButton.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false

        // CTA button - flat style with brand color
        planModalCTAButton.bezelStyle = .regularSquare
        planModalCTAButton.isBordered = false
        planModalCTAButton.wantsLayer = true
        planModalCTAButton.layer?.cornerRadius = 8
        planModalCTAButton.layer?.backgroundColor = brandColor.cgColor
        planModalCTAButton.contentTintColor = .white
        planModalCTAButton.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        planModalCTAButton.target = self
        planModalCTAButton.action = #selector(planModalCTAPressed)
        planModalCTAButton.translatesAutoresizingMaskIntoConstraints = false

        // Fixed height for buttons
        let buttonHeight: CGFloat = 40
        cancelButton.heightAnchor.constraint(equalToConstant: buttonHeight).isActive = true
        planModalCTAButton.heightAnchor.constraint(equalToConstant: buttonHeight).isActive = true

        let buttonStack = NSStackView(views: [cancelButton, planModalCTAButton])
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 12
        buttonStack.distribution = .fillEqually
        buttonStack.translatesAutoresizingMaskIntoConstraints = false

        planModalContainer.addSubview(modalTitle)
        planModalContainer.addSubview(plansStack)
        planModalContainer.addSubview(buttonStack)

        planModalOverlay.addSubview(planModalContainer)

        let modalWidth: CGFloat = 380
        let modalHeight: CGFloat = 400

        NSLayoutConstraint.activate([
            planModalContainer.centerXAnchor.constraint(equalTo: planModalOverlay.centerXAnchor),
            planModalContainer.centerYAnchor.constraint(equalTo: planModalOverlay.centerYAnchor),
            planModalContainer.widthAnchor.constraint(equalToConstant: modalWidth),
            planModalContainer.heightAnchor.constraint(equalToConstant: modalHeight),

            modalTitle.topAnchor.constraint(equalTo: planModalContainer.topAnchor, constant: 24),
            modalTitle.centerXAnchor.constraint(equalTo: planModalContainer.centerXAnchor),

            plansStack.topAnchor.constraint(equalTo: modalTitle.bottomAnchor, constant: 20),
            plansStack.leadingAnchor.constraint(equalTo: planModalContainer.leadingAnchor, constant: 16),
            plansStack.trailingAnchor.constraint(equalTo: planModalContainer.trailingAnchor, constant: -16),

            buttonStack.leadingAnchor.constraint(equalTo: planModalContainer.leadingAnchor, constant: 16),
            buttonStack.trailingAnchor.constraint(equalTo: planModalContainer.trailingAnchor, constant: -16),
            buttonStack.bottomAnchor.constraint(equalTo: planModalContainer.bottomAnchor, constant: -20),
        ])
    }

    // MARK: - Actions

    @objc private func ctaPressed() {
        performPurchase()
    }

    @objc private func priceSelectorPressed() {
        showPlanModal()
    }

    @objc private func restorePressed() {
        PurchaseService.shared.restorePurchases(from: window)
    }

    @objc private func managePressed() {
        PurchaseService.shared.openManageSubscriptions(from: window)
    }

    @objc private func openTerms() {
        if let url = URL(string: "https://vibecap.dev/en/terms/") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func openPrivacy() {
        if let url = URL(string: "https://vibecap.dev/en/privacy/") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func overlayBackgroundClicked() {
        hidePlanModal(animated: true)
    }

    @objc private func planModalCancelPressed() {
        // Discard modal selection, keep original selectedProductID
        hidePlanModal(animated: true)
    }

    @objc private func planModalCTAPressed() {
        // Apply modal selection to main state
        selectedProductID = modalSelectedProductID
        hidePlanModal(animated: true)
        refreshUI()
        performPurchase()
    }

    private func selectPlan(_ productID: String) {
        // Only update modal's temporary selection, not the main state
        modalSelectedProductID = productID
        updatePlanRowsSelection()
        updatePlanModalCTAButton()
    }

    private func performPurchase() {
        guard !EntitlementsService.shared.isPro else { return }

        ctaButton.isEnabled = false
        ctaButton.title = L("paywall.status.purchasing")

        Task { [weak self] in
            guard let self else { return }
            let result = await PurchaseService.shared.purchase(productID: self.selectedProductID)

            await MainActor.run {
                self.ctaButton.isEnabled = true
                self.refreshUI()

                switch result {
                case .success:
                    self.window?.close()
                case .pending:
                    self.ctaButton.title = L("paywall.status.pending")
                case .cancelled:
                    break
                case .failed(let message):
                    let alert = NSAlert()
                    alert.alertStyle = .warning
                    alert.messageText = message
                    alert.addButton(withTitle: L("button.ok"))
                    if let window = self.window {
                        alert.beginSheetModal(for: window, completionHandler: nil)
                    } else {
                        alert.runModal()
                    }
                }
            }
        }
    }

    // MARK: - Plan Modal Show/Hide

    private func showPlanModal() {
        // Reset modal selection to current main selection
        modalSelectedProductID = selectedProductID

        updatePlanRowsSelection()
        updatePlanRowsPrices()
        updatePlanModalCTAButton()

        planModalOverlay.alphaValue = 0
        planModalOverlay.isHidden = false

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            planModalOverlay.animator().alphaValue = 1
        }
    }

    private func hidePlanModal(animated: Bool) {
        if animated {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.15
                context.allowsImplicitAnimation = true
                self.planModalOverlay.animator().alphaValue = 0
            }, completionHandler: { [weak self] in
                guard let self else { return }
                self.planModalOverlay.isHidden = true
                self.planModalOverlay.alphaValue = 0
            })
        } else {
            planModalOverlay.alphaValue = 0
            planModalOverlay.isHidden = true
        }
    }

    private func updatePlanRowsSelection() {
        for (productID, row) in planRows {
            row.isSelected = (productID == modalSelectedProductID)
        }
    }

    private func updatePlanRowsPrices() {
        for (productID, row) in planRows {
            guard let product = products[productID] else {
                row.setPrice(L("paywall.price.loading"), secondary: nil)
                continue
            }

            switch productID {
            case EntitlementsService.ProductID.monthly:
                row.setPrice("\(product.displayPrice)/\(L("paywall.unit.month"))", secondary: nil)

            case EntitlementsService.ProductID.yearly:
                let yearlyValue = NSDecimalNumber(decimal: product.price).doubleValue
                let monthlyEquiv = yearlyValue / 12
                let formatter = NumberFormatter()
                formatter.numberStyle = .currency
                formatter.locale = product.priceFormatStyle.locale
                let monthlyStr = formatter.string(from: NSNumber(value: monthlyEquiv))
                row.setPrice(
                    "\(product.displayPrice)/\(L("paywall.unit.year"))",
                    secondary: monthlyStr.map { "\($0)/\(L("paywall.unit.month"))" }
                )

            case EntitlementsService.ProductID.lifetime:
                row.setPrice(product.displayPrice, secondary: L("paywall.plan_modal.paid_once"))

            default:
                break
            }
        }
    }

    private func updatePlanModalCTAButton() {
        let isLifetime = modalSelectedProductID == EntitlementsService.ProductID.lifetime

        if isLifetime {
            planModalCTAButton.title = L("paywall.plan_modal.cta_buy_now")
        } else if isEligibleForTrial {
            planModalCTAButton.title = L("paywall.plan_modal.cta_start_trial")
        } else {
            if let product = products[modalSelectedProductID] {
                let unit = modalSelectedProductID == EntitlementsService.ProductID.monthly
                    ? L("paywall.unit.month")
                    : L("paywall.unit.year")
                planModalCTAButton.title = L("paywall.plan_modal.cta_subscribe", product.displayPrice, unit)
            } else {
                planModalCTAButton.title = L("paywall.plan_modal.cta_subscribe_generic")
            }
        }
    }

    // MARK: - Data Loading

    @MainActor
    private func loadProductsAndRefreshUI() async {
        // Loading state (disable CTA / selector, hide trial until confirmed)
        // Only apply if we don't already have cached products to avoid UI flicker.
        if products.isEmpty || productsLoadState != .loaded {
            productsLoadState = .loading
            isEligibleForTrial = false
            refreshUI()
        }

        do {
            try await PurchaseService.shared.loadProductsIfNeeded()
            products = [
                EntitlementsService.ProductID.monthly: PurchaseService.shared.product(id: EntitlementsService.ProductID.monthly),
                EntitlementsService.ProductID.yearly: PurchaseService.shared.product(id: EntitlementsService.ProductID.yearly),
                EntitlementsService.ProductID.lifetime: PurchaseService.shared.product(id: EntitlementsService.ProductID.lifetime),
            ].compactMapValues { $0 }

            isEligibleForTrial = PurchaseService.shared.isEligibleForTrial
            productsLoadState = .loaded
            didRetryProductsLoadAfterError = false
            refreshUI()
            updatePlanRowsPrices()
        } catch {
            AppLog.log(.error, "paywall", "Failed to load products: \(error.localizedDescription)")

            products = [:]
            isEligibleForTrial = false
            productsLoadState = .failed
            refreshUI()
            updatePlanRowsPrices()

            guard let window else { return }
            guard !didRetryProductsLoadAfterError else { return }
            didRetryProductsLoadAfterError = true

            // Show a single OK alert, then retry once after user acknowledges.
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = L("paywall.error.generic")
            alert.addButton(withTitle: L("button.ok"))
            alert.beginSheetModal(for: window) { [weak self] _ in
                guard let self else { return }
                Task { [weak self] in
                    guard let self else { return }
                    do {
                        try await PurchaseService.shared.refreshProducts()
                    } catch {
                        AppLog.log(.error, "paywall", "refreshProducts failed: \(error.localizedDescription)")
                    }
                    await self.loadProductsAndRefreshUI()
                }
            }
        }
    }

    // MARK: - UI Updates

    private func refreshUI() {
        let isPro = EntitlementsService.shared.isPro

        if isPro {
            titleLabel.stringValue = L("paywall.pro_status.title")
            subtitleLabel.stringValue = ""
            trialBadgeContainer.isHidden = true
        } else if isEligibleForTrial {
            titleLabel.stringValue = L("paywall.step1.title_trial")
            subtitleLabel.stringValue = L("paywall.step1.subtitle_trial")
            trialBadgeContainer.isHidden = false
            trialBadgeLabel.stringValue = L("paywall.step1.trial_badge")
        } else {
            titleLabel.stringValue = L("paywall.step1.title_no_trial")
            subtitleLabel.stringValue = L("paywall.step1.subtitle_no_trial")
            trialBadgeContainer.isHidden = true
        }

        updateProStatusCard()
        updateCTAButton()
        updatePriceSelector()
        rebuildLegalStack()
    }

    private func updateCTAButton() {
        let isPro = EntitlementsService.shared.isPro

        if isPro {
            ctaButton.title = L("paywall.status.already_pro")
            ctaButton.isEnabled = false
            ctaButton.layer?.backgroundColor = NSColor.systemGray.cgColor
            return
        }

        // Disable CTA if products aren't loaded yet (or failed to load)
        if productsLoadState != .loaded {
            ctaButton.isEnabled = false
            ctaButton.layer?.backgroundColor = NSColor.systemGray.cgColor
            if productsLoadState == .loading {
                ctaButton.title = L("paywall.price.loading")
            } else {
                // Failed state: keep a stable CTA label but disabled
                ctaButton.title = L("paywall.step1.cta_no_trial")
            }
            return
        }

        ctaButton.isEnabled = true
        ctaButton.layer?.backgroundColor = brandColor.cgColor

        let isLifetime = selectedProductID == EntitlementsService.ProductID.lifetime

        if isLifetime {
            ctaButton.title = L("paywall.plan_modal.cta_buy_now")
        } else if isEligibleForTrial {
            ctaButton.title = L("paywall.step1.cta_trial")
        } else {
            ctaButton.title = L("paywall.step1.cta_no_trial")
        }
    }

    private func updatePriceSelector() {
        if productsLoadState != .loaded {
            priceSelectorButton.isEnabled = false
            priceSelectorButton.title = L("paywall.price.loading")
            return
        }

        guard let product = products[selectedProductID] else {
            priceSelectorButton.title = L("paywall.price.loading")
            return
        }
        priceSelectorButton.isEnabled = true

        let isLifetime = selectedProductID == EntitlementsService.ProductID.lifetime

        var priceText: String
        if isLifetime {
            priceText = "\(product.displayPrice) · \(L("paywall.plan_modal.paid_once"))"
        } else if isEligibleForTrial {
            let unit = selectedProductID == EntitlementsService.ProductID.monthly
                ? L("paywall.unit.month")
                : L("paywall.unit.year")
            priceText = L("paywall.step1.price_with_trial", product.displayPrice, unit)
        } else {
            let unit = selectedProductID == EntitlementsService.ProductID.monthly
                ? L("paywall.unit.month")
                : L("paywall.unit.year")
            priceText = L("paywall.step1.price_no_trial", product.displayPrice, unit)
        }

        let attachment = NSTextAttachment()
        let config = NSImage.SymbolConfiguration(pointSize: 10, weight: .medium)
        attachment.image = NSImage(systemSymbolName: "chevron.up.chevron.down", accessibilityDescription: nil)?
            .withSymbolConfiguration(config)

        let attrString = NSMutableAttributedString(string: "\(priceText) ")
        attrString.append(NSAttributedString(attachment: attachment))
        attrString.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: NSRange(location: 0, length: attrString.length))
        attrString.addAttribute(.font, value: NSFont.systemFont(ofSize: 13), range: NSRange(location: 0, length: attrString.length))
        priceSelectorButton.attributedTitle = attrString
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

// MARK: - Plan Row View

private final class PlanRowView: NSView {
    var onSelect: (() -> Void)?

    var isSelected: Bool = false {
        didSet { updateAppearance() }
    }

    private let radio = NSImageView()
    private let priceLabel = NSTextField(labelWithString: "")
    private let secondaryPriceLabel = NSTextField(labelWithString: "")

    init(productID: String, title: String, subtitle: String, badge: String?) {
        super.init(frame: .zero)
        setup(title: title, subtitle: subtitle, badge: badge)
    }

    required init?(coder: NSCoder) { nil }

    func setPrice(_ primary: String, secondary: String?) {
        priceLabel.stringValue = primary
        secondaryPriceLabel.stringValue = secondary ?? ""
        secondaryPriceLabel.isHidden = (secondary == nil)
    }

    private func setup(title: String, subtitle: String, badge: String?) {
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor
        layer?.backgroundColor = cardBackgroundColor.cgColor
        translatesAutoresizingMaskIntoConstraints = false

        // Radio
        let radioConfig = NSImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        radio.image = NSImage(systemSymbolName: "circle", accessibilityDescription: nil)?
            .withSymbolConfiguration(radioConfig)
        radio.contentTintColor = .tertiaryLabelColor
        radio.translatesAutoresizingMaskIntoConstraints = false

        // Title
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let titleRow = NSStackView(views: [titleLabel])
        titleRow.orientation = .horizontal
        titleRow.spacing = 8
        titleRow.alignment = .centerY

        if let badge {
            let badgeContainer = NSView()
            badgeContainer.wantsLayer = true
            badgeContainer.layer?.cornerRadius = 4
            badgeContainer.layer?.backgroundColor = brandColor.withAlphaComponent(0.15).cgColor
            badgeContainer.translatesAutoresizingMaskIntoConstraints = false

            let badgeLabel = NSTextField(labelWithString: badge)
            badgeLabel.font = NSFont.systemFont(ofSize: 9, weight: .bold)
            badgeLabel.textColor = brandColor
            badgeLabel.translatesAutoresizingMaskIntoConstraints = false

            badgeContainer.addSubview(badgeLabel)
            NSLayoutConstraint.activate([
                badgeLabel.leadingAnchor.constraint(equalTo: badgeContainer.leadingAnchor, constant: 6),
                badgeLabel.trailingAnchor.constraint(equalTo: badgeContainer.trailingAnchor, constant: -6),
                badgeLabel.topAnchor.constraint(equalTo: badgeContainer.topAnchor, constant: 2),
                badgeLabel.bottomAnchor.constraint(equalTo: badgeContainer.bottomAnchor, constant: -2),
            ])

            titleRow.addArrangedSubview(badgeContainer)
        }

        // Subtitle
        let subtitleLabel = NSTextField(labelWithString: subtitle)
        subtitleLabel.font = NSFont.systemFont(ofSize: 12)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        // Price labels
        priceLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        priceLabel.alignment = .right
        priceLabel.translatesAutoresizingMaskIntoConstraints = false

        secondaryPriceLabel.font = NSFont.systemFont(ofSize: 11)
        secondaryPriceLabel.textColor = .secondaryLabelColor
        secondaryPriceLabel.alignment = .right
        secondaryPriceLabel.translatesAutoresizingMaskIntoConstraints = false

        // Layout
        let textStack = NSStackView(views: [titleRow, subtitleLabel])
        textStack.orientation = .vertical
        textStack.spacing = 2
        textStack.alignment = .leading

        let leftStack = NSStackView(views: [radio, textStack])
        leftStack.orientation = .horizontal
        leftStack.spacing = 12
        leftStack.alignment = .centerY
        leftStack.translatesAutoresizingMaskIntoConstraints = false

        let rightStack = NSStackView(views: [priceLabel, secondaryPriceLabel])
        rightStack.orientation = .vertical
        rightStack.spacing = 2
        rightStack.alignment = .trailing
        rightStack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(leftStack)
        addSubview(rightStack)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 72),

            leftStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            leftStack.centerYAnchor.constraint(equalTo: centerYAnchor),

            rightStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            rightStack.centerYAnchor.constraint(equalTo: centerYAnchor),

            radio.widthAnchor.constraint(equalToConstant: 24),
            radio.heightAnchor.constraint(equalToConstant: 24),
        ])

        // Click handler
        let click = NSClickGestureRecognizer(target: self, action: #selector(clicked))
        addGestureRecognizer(click)

        updateAppearance()
    }

    private func updateAppearance() {
        let radioConfig = NSImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        let radioName = isSelected ? "checkmark.circle.fill" : "circle"
        radio.image = NSImage(systemSymbolName: radioName, accessibilityDescription: nil)?
            .withSymbolConfiguration(radioConfig)
        radio.contentTintColor = isSelected ? brandColor : .tertiaryLabelColor

        layer?.borderWidth = isSelected ? 2 : 1
        layer?.borderColor = isSelected ? brandColor.cgColor : NSColor.separatorColor.cgColor
    }

    @objc private func clicked() {
        onSelect?()
    }
}
