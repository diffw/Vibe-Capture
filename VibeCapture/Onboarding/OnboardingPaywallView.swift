import AppKit
import StoreKit

final class OnboardingPaywallView: NSView {
    enum Mode {
        /// Default onboarding usage: self-load products and handle purchase/restore internally.
        case onboarding
        /// Hosted usage (e.g., main paywall): host owns product loading/purchase, this view only renders and forwards events.
        case hosted
    }

    // External callbacks (used in hosted mode).
    var onPrimary: (() -> Void)?
    var onPriceTap: (() -> Void)?
    var onRestoreTap: (() -> Void)?
    var onTermsTap: (() -> Void)?
    var onPrivacyTap: (() -> Void)?

    var onFinished: (() -> Void)?
    var onContentSizeChange: (() -> Void)?

    private let mode: Mode

    private let logoImageView = NSImageView()
    private let titleLabel = NSTextField(wrappingLabelWithString: "")
    private let subtitleLabel = NSTextField(wrappingLabelWithString: "")

    private let featureCard = NSView()
    private let featureBgImageView = NSImageView()
    private let proBadgeLabel = NSTextField(labelWithString: "")

    private let ctaButton = OnboardingPillButton()
    private let pricingLabel = NSTextField(labelWithString: "")
    private let pricingArrowImageView = NSImageView()

    private let termsButton = NSButton(title: "", target: nil, action: nil)
    private let privacyButton = NSButton(title: "", target: nil, action: nil)
    private let restoreButton = NSButton(title: "", target: nil, action: nil)

    private var yearlyProduct: Product?
    private var trialDays: Int?
    private var lastFittingHeight: CGFloat = 0

    // Plan modal (onboarding mode only)
    private let planModalOverlay = NSView()
    private let planModalContainer = NSView()
    private let planModalCTAButton = NSButton()
    private let planModalHintLabel = NSTextField(wrappingLabelWithString: "")
    private var planRows: [String: OnboardingPlanRowView] = [:]
    private var allProducts: [String: Product] = [:]
    private var modalSelectedProductID = EntitlementsService.ProductID.yearly
    private var isEligibleForTrial: Bool { trialDays != nil && (trialDays ?? 0) > 0 }

    override init(frame frameRect: NSRect) {
        self.mode = .onboarding
        super.init(frame: frameRect)
        setup()
        refreshProductsIfNeeded()
    }

    init(mode: Mode) {
        self.mode = mode
        super.init(frame: .zero)
        setup()
        refreshProductsIfNeeded()
    }

    required init?(coder: NSCoder) { nil }

    override func layout() {
        super.layout()
        guard !isHidden else { return }
        let height = fittingSize.height
        if abs(height - lastFittingHeight) > 0.5 {
            lastFittingHeight = height
            AppLog.log(.info, "onboarding", "OnboardingPaywallView.layout fittingSize=(\(Int(fittingSize.width))x\(Int(fittingSize.height)))")
            onContentSizeChange?()
        }
    }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.white.cgColor

        let primary = NSColor(srgbRed: 115.0 / 255.0, green: 69.0 / 255.0, blue: 46.0 / 255.0, alpha: 1.0) // #73452E
        let secondary = NSColor(srgbRed: 139.0 / 255.0, green: 107.0 / 255.0, blue: 92.0 / 255.0, alpha: 1.0) // #8B6B5C

        logoImageView.imageScaling = .scaleProportionallyUpOrDown
        logoImageView.imageAlignment = .alignLeft
        logoImageView.image = PaywallFigma.image(named: "logo", ext: "svg")

        titleLabel.maximumNumberOfLines = 0
        titleLabel.textColor = primary
        PaywallFigma.configureLabel(titleLabel)
        titleLabel.attributedStringValue = PaywallFigma.attributedText(
            string: L("onboarding.05.title"),
            font: NSFont.systemFont(ofSize: 24, weight: .heavy),
            color: primary,
            lineHeightMultiple: 1.1
        )

        subtitleLabel.maximumNumberOfLines = 0
        subtitleLabel.textColor = primary
        PaywallFigma.configureLabel(subtitleLabel)
        subtitleLabel.attributedStringValue = PaywallFigma.attributedText(
            string: L("onboarding.05.subtitle"),
            font: NSFont.systemFont(ofSize: 16, weight: .regular),
            color: primary,
            lineHeightMultiple: 1.5
        )

        setupFeatureCard()

        ctaButton.title = L("onboarding.05.cta.trial")
        ctaButton.target = self
        ctaButton.action = #selector(ctaPressed)
        ctaButton.isEnabled = false
        ctaButton.fillColor = primary
        ctaButton.titleColor = .white
        ctaButton.titleFont = NSFont.systemFont(ofSize: 18, weight: .semibold)
        ctaButton.contentInsets = NSEdgeInsets(top: 13, left: 32, bottom: 13, right: 32)
        ctaButton.cornerRadius = 1000
        ctaButton.imagePosition = .noImage
        ctaButton.setButtonType(.momentaryPushIn)

        pricingLabel.font = NSFont.systemFont(ofSize: 14, weight: .regular)
        pricingLabel.textColor = primary
        pricingLabel.alignment = .center
        PaywallFigma.configureLabel(pricingLabel)
        setPricingText("")

        pricingArrowImageView.imageScaling = .scaleProportionallyDown
        pricingArrowImageView.imageAlignment = .alignCenter
        pricingArrowImageView.image = PaywallFigma.image(named: "arrow-down-s-line", ext: "svg")
        pricingArrowImageView.image?.isTemplate = true
        pricingArrowImageView.contentTintColor = primary
        pricingArrowImageView.translatesAutoresizingMaskIntoConstraints = false

        setupLegal(primary: primary, secondary: secondary)

        addSubview(logoImageView)
        addSubview(titleLabel)
        addSubview(subtitleLabel)
        addSubview(featureCard)
        addSubview(ctaButton)
        // Make pricing tappable (for plan selection)
        let priceTapButton = NSButton(title: "", target: self, action: #selector(priceTapped))
        priceTapButton.isBordered = false
        priceTapButton.bezelStyle = .inline
        priceTapButton.title = ""
        priceTapButton.setButtonType(.momentaryChange)
        priceTapButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(pricingLabel)
        addSubview(pricingArrowImageView)
        addSubview(priceTapButton)
        addSubview(termsButton)
        addSubview(privacyButton)
        addSubview(restoreButton)

        if mode == .onboarding {
            buildPlanModal()
        }

        for v in [logoImageView, titleLabel, subtitleLabel, featureCard, ctaButton, pricingLabel, termsButton, privacyButton, restoreButton] {
            v.translatesAutoresizingMaskIntoConstraints = false
        }

        // Figma layout (frame: 560x695.06, content width: 416 @ x=72, top = 80)
        NSLayoutConstraint.activate([
            logoImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 72),
            logoImageView.topAnchor.constraint(equalTo: topAnchor, constant: 80),
            logoImageView.widthAnchor.constraint(equalToConstant: 157),
            logoImageView.heightAnchor.constraint(equalToConstant: 36),

            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 72),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 148),
            titleLabel.widthAnchor.constraint(equalToConstant: 416),

            subtitleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 72),
            subtitleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 186),
            subtitleLabel.widthAnchor.constraint(equalToConstant: 416),

            featureCard.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 72),
            featureCard.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 12),
            featureCard.widthAnchor.constraint(equalToConstant: 416),

            ctaButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 72),
            ctaButton.topAnchor.constraint(equalTo: featureCard.bottomAnchor, constant: 32),
            ctaButton.widthAnchor.constraint(equalToConstant: 416),
            ctaButton.heightAnchor.constraint(equalToConstant: 48),

            pricingLabel.centerXAnchor.constraint(equalTo: ctaButton.centerXAnchor),
            pricingLabel.topAnchor.constraint(equalTo: ctaButton.bottomAnchor, constant: 10),
            pricingArrowImageView.leadingAnchor.constraint(equalTo: pricingLabel.trailingAnchor, constant: 8),
            pricingArrowImageView.centerYAnchor.constraint(equalTo: pricingLabel.centerYAnchor),
            pricingArrowImageView.widthAnchor.constraint(equalToConstant: 24),
            pricingArrowImageView.heightAnchor.constraint(equalToConstant: 24),

            priceTapButton.leadingAnchor.constraint(equalTo: pricingLabel.leadingAnchor, constant: -6),
            priceTapButton.trailingAnchor.constraint(equalTo: pricingArrowImageView.trailingAnchor, constant: 6),
            priceTapButton.topAnchor.constraint(equalTo: pricingLabel.topAnchor, constant: -4),
            priceTapButton.bottomAnchor.constraint(equalTo: pricingLabel.bottomAnchor, constant: 4),

            termsButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 72),
            termsButton.topAnchor.constraint(equalTo: pricingArrowImageView.bottomAnchor, constant: 32),
            termsButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -80),

            privacyButton.leadingAnchor.constraint(equalTo: termsButton.trailingAnchor, constant: 12),
            privacyButton.centerYAnchor.constraint(equalTo: termsButton.centerYAnchor),

            restoreButton.trailingAnchor.constraint(equalTo: leadingAnchor, constant: 72 + 416),
            restoreButton.centerYAnchor.constraint(equalTo: termsButton.centerYAnchor),
        ])
    }

    private func setupFeatureCard() {
        featureCard.wantsLayer = true
        featureCard.layer?.cornerRadius = 16
        featureCard.layer?.masksToBounds = true

        featureBgImageView.imageScaling = .scaleAxesIndependently
        featureBgImageView.image = PaywallFigma.image(named: "bg_vc", ext: "png")

        proBadgeLabel.stringValue = "VibeCap PRO"
        proBadgeLabel.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        proBadgeLabel.textColor = .white
        PaywallFigma.configureLabel(proBadgeLabel)

        let featuresStack = NSStackView()
        featuresStack.orientation = .vertical
        featuresStack.spacing = 16
        featuresStack.alignment = .leading

        func row(icon: String, title: String, subtitle: String) -> NSView {
            let bullet = NSImageView()
            bullet.imageScaling = .scaleProportionallyUpOrDown
            bullet.image = PaywallFigma.image(named: icon, ext: "svg")
            bullet.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                bullet.widthAnchor.constraint(equalToConstant: 34),
                bullet.heightAnchor.constraint(equalToConstant: 34),
            ])

            let t = NSTextField(labelWithString: title)
            PaywallFigma.configureLabel(t)
            t.maximumNumberOfLines = 0
            t.lineBreakMode = .byWordWrapping
            t.attributedStringValue = PaywallFigma.attributedText(
                string: title,
                font: NSFont.systemFont(ofSize: 15, weight: .semibold),
                color: .white,
                lineHeightMultiple: 1.1
            )
            t.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

            let s = NSTextField(labelWithString: subtitle)
            PaywallFigma.configureLabel(s)
            s.maximumNumberOfLines = 0
            s.lineBreakMode = .byWordWrapping
            s.attributedStringValue = PaywallFigma.attributedText(
                string: subtitle,
                font: NSFont.systemFont(ofSize: 13, weight: .regular),
                color: .white,
                lineHeightMultiple: 1.1
            )
            s.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

            let textStack = NSStackView(views: [t, s])
            textStack.orientation = .vertical
            textStack.spacing = 2
            textStack.alignment = .leading
            textStack.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

            let row = NSStackView(views: [bullet, textStack])
            row.orientation = .horizontal
            row.spacing = 12
            row.alignment = .top
            textStack.translatesAutoresizingMaskIntoConstraints = false
            textStack.widthAnchor.constraint(equalToConstant: 322).isActive = true
            return row
        }

        featuresStack.addArrangedSubview(row(
            icon: "annotation",
            title: L("onboarding.05.feature1.title"),
            subtitle: L("onboarding.05.feature1.body")
        ))
        featuresStack.addArrangedSubview(row(
            icon: "queue",
            title: L("onboarding.05.feature2.title"),
            subtitle: L("onboarding.05.feature2.body")
        ))
        featuresStack.addArrangedSubview(row(
            icon: "cleanup",
            title: L("onboarding.05.feature3.title"),
            subtitle: L("onboarding.05.feature3.body")
        ))

        featureCard.addSubview(featureBgImageView)
        featureCard.addSubview(featuresStack)
        featureCard.addSubview(proBadgeLabel)

        featureBgImageView.translatesAutoresizingMaskIntoConstraints = false
        featuresStack.translatesAutoresizingMaskIntoConstraints = false
        proBadgeLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            featureBgImageView.centerXAnchor.constraint(equalTo: featureCard.centerXAnchor),
            featureBgImageView.centerYAnchor.constraint(equalTo: featureCard.centerYAnchor, constant: 9.47),
            featureBgImageView.widthAnchor.constraint(equalToConstant: 616),
            featureBgImageView.heightAnchor.constraint(equalToConstant: 401),

            featuresStack.leadingAnchor.constraint(equalTo: featureCard.leadingAnchor, constant: 24),
            featuresStack.topAnchor.constraint(equalTo: featureCard.topAnchor, constant: 60.0615),
            featuresStack.widthAnchor.constraint(equalToConstant: 368),
            featuresStack.bottomAnchor.constraint(equalTo: featureCard.bottomAnchor, constant: -24),
            featuresStack.bottomAnchor.constraint(equalTo: featureCard.bottomAnchor, constant: -24),

            proBadgeLabel.leadingAnchor.constraint(equalTo: featureCard.leadingAnchor, constant: 24),
            proBadgeLabel.topAnchor.constraint(equalTo: featureCard.topAnchor, constant: 24),
        ])
    }

    private func setupLegal(primary: NSColor, secondary: NSColor) {
        termsButton.title = L("paywall.legal.terms")
        termsButton.isBordered = false
        termsButton.target = self
        termsButton.action = #selector(openTerms)
        termsButton.font = NSFont.systemFont(ofSize: 12)
        termsButton.contentTintColor = secondary

        privacyButton.title = L("paywall.legal.privacy")
        privacyButton.isBordered = false
        privacyButton.target = self
        privacyButton.action = #selector(openPrivacy)
        privacyButton.font = NSFont.systemFont(ofSize: 12)
        privacyButton.contentTintColor = secondary

        restoreButton.title = L("paywall.action.restore")
        restoreButton.isBordered = false
        restoreButton.target = self
        restoreButton.action = #selector(restorePressed)
        restoreButton.font = NSFont.systemFont(ofSize: 12)
        restoreButton.contentTintColor = secondary
    }

    // MARK: - Plan Modal (onboarding mode)

    private func buildPlanModal() {
        let brandColor = NSColor(red: 1.0, green: 0.553, blue: 0.463, alpha: 1.0) // #FF8D76

        planModalOverlay.wantsLayer = true
        planModalOverlay.layer?.backgroundColor = NSColor.clear.cgColor
        planModalOverlay.translatesAutoresizingMaskIntoConstraints = false
        planModalOverlay.isHidden = true

        // Background dimming view; square corners to fully cover window area.
        let backgroundView = NSView()
        backgroundView.wantsLayer = true
        backgroundView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.4).cgColor
        backgroundView.layer?.cornerRadius = 0
        backgroundView.layer?.masksToBounds = true
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        planModalOverlay.addSubview(backgroundView)

        let overlayClick = NSClickGestureRecognizer(target: self, action: #selector(planModalDismiss))
        backgroundView.addGestureRecognizer(overlayClick)

        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: planModalOverlay.topAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: planModalOverlay.bottomAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: planModalOverlay.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: planModalOverlay.trailingAnchor),
        ])

        // Modal card
        planModalContainer.wantsLayer = true
        planModalContainer.layer?.backgroundColor = NSColor.white.cgColor
        planModalContainer.layer?.cornerRadius = 20
        planModalContainer.layer?.shadowColor = NSColor.black.cgColor
        planModalContainer.layer?.shadowOpacity = 0.2
        planModalContainer.layer?.shadowOffset = CGSize(width: 0, height: -4)
        planModalContainer.layer?.shadowRadius = 16
        planModalContainer.translatesAutoresizingMaskIntoConstraints = false

        let modalTitle = NSTextField(labelWithString: L("paywall.plan_modal.title"))
        modalTitle.font = NSFont.systemFont(ofSize: 20, weight: .bold)
        modalTitle.alignment = .center
        modalTitle.translatesAutoresizingMaskIntoConstraints = false

        let monthlyRow = OnboardingPlanRowView(
            productID: EntitlementsService.ProductID.monthly,
            title: L("paywall.option.monthly"),
            subtitle: L("paywall.plan_modal.monthly_subtitle"),
            badge: nil
        )
        monthlyRow.onSelect = { [weak self] in self?.selectPlan(EntitlementsService.ProductID.monthly) }

        let yearlyRow = OnboardingPlanRowView(
            productID: EntitlementsService.ProductID.yearly,
            title: L("paywall.option.yearly"),
            subtitle: L("paywall.plan_modal.yearly_subtitle"),
            badge: L("paywall.plan_modal.badge_popular")
        )
        yearlyRow.onSelect = { [weak self] in self?.selectPlan(EntitlementsService.ProductID.yearly) }

        let lifetimeRow = OnboardingPlanRowView(
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

        let cancelButton = NSButton(title: L("button.cancel"), target: self, action: #selector(planModalDismiss))
        cancelButton.bezelStyle = .regularSquare
        cancelButton.isBordered = false
        cancelButton.wantsLayer = true
        cancelButton.layer?.cornerRadius = 8
        cancelButton.layer?.backgroundColor = NSColor.systemGray.withAlphaComponent(0.15).cgColor
        cancelButton.contentTintColor = .labelColor
        cancelButton.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false

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

        planModalHintLabel.font = NSFont.systemFont(ofSize: 12)
        planModalHintLabel.textColor = .secondaryLabelColor
        planModalHintLabel.alignment = .center
        planModalHintLabel.maximumNumberOfLines = 2
        planModalHintLabel.lineBreakMode = .byWordWrapping
        PaywallFigma.configureLabel(planModalHintLabel)
        planModalHintLabel.translatesAutoresizingMaskIntoConstraints = false
        planModalHintLabel.isHidden = true

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
        planModalContainer.addSubview(planModalHintLabel)
        planModalContainer.addSubview(buttonStack)
        planModalOverlay.addSubview(planModalContainer)

        addSubview(planModalOverlay)

        let modalWidth: CGFloat = 380

        NSLayoutConstraint.activate([
            planModalOverlay.topAnchor.constraint(equalTo: topAnchor),
            planModalOverlay.bottomAnchor.constraint(equalTo: bottomAnchor),
            planModalOverlay.leadingAnchor.constraint(equalTo: leadingAnchor),
            planModalOverlay.trailingAnchor.constraint(equalTo: trailingAnchor),

            planModalContainer.centerXAnchor.constraint(equalTo: planModalOverlay.centerXAnchor),
            planModalContainer.centerYAnchor.constraint(equalTo: planModalOverlay.centerYAnchor),
            planModalContainer.widthAnchor.constraint(equalToConstant: modalWidth),
            planModalContainer.heightAnchor.constraint(lessThanOrEqualTo: planModalOverlay.heightAnchor, constant: -40),

            modalTitle.topAnchor.constraint(equalTo: planModalContainer.topAnchor, constant: 24),
            modalTitle.centerXAnchor.constraint(equalTo: planModalContainer.centerXAnchor),

            plansStack.topAnchor.constraint(equalTo: modalTitle.bottomAnchor, constant: 20),
            plansStack.leadingAnchor.constraint(equalTo: planModalContainer.leadingAnchor, constant: 16),
            plansStack.trailingAnchor.constraint(equalTo: planModalContainer.trailingAnchor, constant: -16),

            planModalHintLabel.topAnchor.constraint(equalTo: plansStack.bottomAnchor, constant: 12),
            planModalHintLabel.leadingAnchor.constraint(equalTo: planModalContainer.leadingAnchor, constant: 24),
            planModalHintLabel.trailingAnchor.constraint(equalTo: planModalContainer.trailingAnchor, constant: -24),

            buttonStack.topAnchor.constraint(equalTo: planModalHintLabel.bottomAnchor, constant: 16),
            buttonStack.leadingAnchor.constraint(equalTo: planModalContainer.leadingAnchor, constant: 16),
            buttonStack.trailingAnchor.constraint(equalTo: planModalContainer.trailingAnchor, constant: -16),
            buttonStack.bottomAnchor.constraint(equalTo: planModalContainer.bottomAnchor, constant: -20),
        ])
    }

    private func showPlanModal() {
        modalSelectedProductID = EntitlementsService.ProductID.yearly
        updatePlanRowsSelection()
        updatePlanRowsPrices()
        updatePlanModalCTAButton()

        // Hide window close button while modal is visible.
        window?.standardWindowButton(.closeButton)?.isHidden = true

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
                self?.planModalOverlay.isHidden = true
                self?.planModalOverlay.alphaValue = 0
                // Restore window close button.
                self?.window?.standardWindowButton(.closeButton)?.isHidden = false
            })
        } else {
            planModalOverlay.alphaValue = 0
            planModalOverlay.isHidden = true
            window?.standardWindowButton(.closeButton)?.isHidden = false
        }
    }

    private func selectPlan(_ productID: String) {
        modalSelectedProductID = productID
        updatePlanRowsSelection()
        updatePlanModalCTAButton()
    }

    private func updatePlanRowsSelection() {
        for (productID, row) in planRows {
            row.isSelected = (productID == modalSelectedProductID)
        }
    }

    private func updatePlanRowsPrices() {
        for (productID, row) in planRows {
            guard let product = allProducts[productID] else {
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
            if let product = allProducts[modalSelectedProductID] {
                let unit = modalSelectedProductID == EntitlementsService.ProductID.monthly
                    ? L("paywall.unit.month")
                    : L("paywall.unit.year")
                planModalCTAButton.title = L("paywall.plan_modal.cta_subscribe", product.displayPrice, unit)
            } else {
                planModalCTAButton.title = L("paywall.plan_modal.cta_subscribe_generic")
            }
        }
        updatePlanModalTrialHint()
    }

    private func updatePlanModalTrialHint() {
        let isLifetime = modalSelectedProductID == EntitlementsService.ProductID.lifetime
        guard isEligibleForTrial, let trialDays else {
            planModalHintLabel.isHidden = true
            return
        }
        planModalHintLabel.isHidden = isLifetime
        guard !isLifetime else { return }
        planModalHintLabel.attributedStringValue = PaywallFigma.attributedText(
            string: L("paywall.plan_modal.trial_hint", trialDays),
            font: NSFont.systemFont(ofSize: 12, weight: .regular),
            color: .secondaryLabelColor,
            lineHeightMultiple: 1.2,
            alignment: .center
        )
    }

    @objc private func planModalDismiss() {
        hidePlanModal(animated: true)
    }

    @objc private func planModalCTAPressed() {
        hidePlanModal(animated: true)
        guard let product = allProducts[modalSelectedProductID] else {
            showGenericError()
            return
        }
        ctaButton.isEnabled = false
        Task { @MainActor in
            let result = await PurchaseService.shared.purchase(productID: product.id)
            switch result {
            case .success:
                onFinished?()
            case .cancelled:
                ctaButton.isEnabled = true
            case .pending:
                ctaButton.isEnabled = true
            case .failed(let message):
                ctaButton.isEnabled = true
                let alert = NSAlert()
                alert.alertStyle = .warning
                alert.messageText = message
                alert.addButton(withTitle: L("button.ok"))
                if let window {
                    alert.beginSheetModal(for: window, completionHandler: nil)
                } else {
                    alert.runModal()
                }
            }
        }
    }

    // MARK: - Data Loading

    private func refreshProductsIfNeeded() {
        guard mode == .onboarding else { return }
        refreshProducts()
    }

    private func refreshProducts() {
        Task { @MainActor in
            do {
                try await PurchaseService.shared.loadProductsIfNeeded()
                yearlyProduct = PurchaseService.shared.product(id: EntitlementsService.ProductID.yearly)
                if let yearlyProduct {
                    trialDays = await PurchaseService.shared.trialDays(for: yearlyProduct.id)
                }
                // Store all products for plan modal
                for id in [EntitlementsService.ProductID.monthly, EntitlementsService.ProductID.yearly, EntitlementsService.ProductID.lifetime] {
                    if let p = PurchaseService.shared.product(id: id) {
                        allProducts[id] = p
                    }
                }
                refreshPricingCopy()
                ctaButton.isEnabled = true
                if mode == .onboarding {
                    updatePlanRowsPrices()
                    updatePlanModalTrialHint()
                }
            } catch {
                // Best effort: still allow the user to click and surface error.
                pricingLabel.stringValue = L("paywall.error.generic")
                ctaButton.isEnabled = true
            }
        }
    }

    private func refreshPricingCopy() {
        guard let yearlyProduct else {
            setPricingText("")
            return
        }

        var text: String
        if let trialDays, trialDays > 0 {
            text = L("onboarding.05.pricing.trial_then", trialDays, yearlyProduct.displayPrice)
        } else {
            text = L("onboarding.05.pricing.then", yearlyProduct.displayPrice)
        }
        setPricingText(text)
    }

    private func setPricingText(_ text: String) {
        pricingLabel.attributedStringValue = PaywallFigma.attributedText(
            string: text,
            font: NSFont.systemFont(ofSize: 14, weight: .regular),
            color: pricingLabel.textColor ?? .labelColor,
            lineHeightMultiple: 1.1,
            alignment: .center
        )
    }

    // MARK: - Actions

    @objc private func ctaPressed() {

        // Hosted mode: forward to host regardless of product availability.
        if mode == .hosted {
            onPrimary?()
            return
        }

        guard let yearlyProduct else {
            showGenericError()
            return
        }
        ctaButton.isEnabled = false

        Task { @MainActor in
            let result = await PurchaseService.shared.purchase(productID: yearlyProduct.id)
            switch result {
            case .success:
                onFinished?()
            case .cancelled:
                ctaButton.isEnabled = true
            case .pending:
                ctaButton.isEnabled = true
            case .failed(let message):
                ctaButton.isEnabled = true
                let alert = NSAlert()
                alert.alertStyle = .warning
                alert.messageText = message
                alert.addButton(withTitle: L("button.ok"))
                if let window {
                    alert.beginSheetModal(for: window, completionHandler: nil)
                } else {
                    alert.runModal()
                }
            }
        }
    }

    @objc private func restorePressed() {
        if mode == .hosted {
            onRestoreTap?()
        } else {
            PurchaseService.shared.restorePurchases(from: window)
        }
    }

    @objc private func openTerms() {
        if let onTermsTap {
            onTermsTap()
            return
        }
        if let url = URL(string: "https://vibecap.dev/en/terms/") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func openPrivacy() {
        if let onPrivacyTap {
            onPrivacyTap()
            return
        }
        if let url = URL(string: "https://vibecap.dev/en/privacy/") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func priceTapped() {
        if mode == .hosted {
            onPriceTap?()
        } else {
            // In onboarding mode, tapping the price arrow opens the plan selection modal.
            showPlanModal()
        }
    }

    // MARK: - Public setters for hosted mode

    func setPriceText(_ text: String) {
        pricingLabel.stringValue = text
    }

    func setCTATitle(_ title: String) {
        ctaButton.title = title
    }

    func setCTAEnabled(_ enabled: Bool) {
        ctaButton.isEnabled = enabled
    }

    func setTitleText(_ text: String) {
        titleLabel.attributedStringValue = PaywallFigma.attributedText(
            string: text,
            font: NSFont.systemFont(ofSize: 24, weight: .heavy),
            color: titleLabel.textColor ?? NSColor.black,
            lineHeightMultiple: 1.1
        )
    }

    func setSubtitleText(_ text: String) {
        subtitleLabel.attributedStringValue = PaywallFigma.attributedText(
            string: text,
            font: NSFont.systemFont(ofSize: 16, weight: .regular),
            color: subtitleLabel.textColor ?? NSColor.black,
            lineHeightMultiple: 1.5
        )
    }

    // MARK: - Helpers

    private func showGenericError() {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = L("paywall.error.generic")
        alert.addButton(withTitle: L("button.ok"))
        if let window {
            alert.beginSheetModal(for: window, completionHandler: nil)
        } else {
            alert.runModal()
        }
    }

}

private enum PaywallFigma {
    private static var inlineCache: [String: NSImage] = [:]
    private static let inlineSVG: [String: String] = [
        "arrow-right-long-line": """
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor"><path d="M1.99974 13.0001L1.9996 11.0002L18.1715 11.0002L14.2218 7.05044L15.636 5.63623L22 12.0002L15.636 18.3642L14.2218 16.9499L18.1716 13.0002L1.99974 13.0001Z"></path></svg>
""",
        "arrow-down-s-line": """
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor"><path d="M11.9999 13.1714L16.9497 8.22168L18.3639 9.63589L11.9999 15.9999L5.63599 9.63589L7.0502 8.22168L11.9999 13.1714Z"></path></svg>
"""
    ]
    static func image(named assetName: String, ext: String) -> NSImage? {
        var bundles: [Bundle] = [
            Bundle(for: OnboardingPaywallView.self),
            Bundle.main
        ]
        #if SWIFT_PACKAGE
        bundles.append(.module)
        #endif
        let subdirs: [String?] = ["Onboarding", "Resources/Onboarding", nil]

        for bundle in bundles {
            for sub in subdirs {
                let url = bundle.url(forResource: assetName, withExtension: ext, subdirectory: sub)
                if let url, let img = SVGImageFallback.image(contentsOf: url) {
                    return img
                }
            }
        }
        if let cached = inlineCache[assetName] {
            return cached
        }
        if ext == "svg", let svg = inlineSVG[assetName] {
            let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("\(assetName).svg")
            if !FileManager.default.fileExists(atPath: tmp.path) {
                try? svg.write(to: tmp, atomically: true, encoding: .utf8)
            }
            if let img = SVGImageFallback.image(contentsOf: tmp) {
                inlineCache[assetName] = img
                return img
            }
        }
        return nil
    }

    static func configureLabel(_ label: NSTextField) {
        label.isEditable = false
        label.isSelectable = false
        label.isBezeled = false
        label.drawsBackground = false
        label.focusRingType = .none
    }

    static func attributedText(
        string: String,
        font: NSFont,
        color: NSColor,
        lineHeightMultiple: CGFloat,
        alignment: NSTextAlignment = .left
    ) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineHeightMultiple = lineHeightMultiple
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byWordWrapping

        return NSAttributedString(string: string, attributes: [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph,
        ])
    }
}

// MARK: - Plan Row View (for onboarding plan modal)

private let onboardingBrandColor = NSColor(red: 1.0, green: 0.553, blue: 0.463, alpha: 1.0) // #FF8D76

final class OnboardingPlanRowView: NSView {
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
        layer?.backgroundColor = NSColor.white.cgColor
        translatesAutoresizingMaskIntoConstraints = false

        let radioConfig = NSImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        radio.image = NSImage(systemSymbolName: "circle", accessibilityDescription: nil)?
            .withSymbolConfiguration(radioConfig)
        radio.contentTintColor = .tertiaryLabelColor
        radio.translatesAutoresizingMaskIntoConstraints = false

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
            badgeContainer.layer?.backgroundColor = onboardingBrandColor.withAlphaComponent(0.15).cgColor
            badgeContainer.translatesAutoresizingMaskIntoConstraints = false

            let badgeLabel = NSTextField(labelWithString: badge)
            badgeLabel.font = NSFont.systemFont(ofSize: 9, weight: .bold)
            badgeLabel.textColor = onboardingBrandColor
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

        let subtitleLabel = NSTextField(labelWithString: subtitle)
        subtitleLabel.font = NSFont.systemFont(ofSize: 12)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        priceLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        priceLabel.alignment = .right
        priceLabel.translatesAutoresizingMaskIntoConstraints = false

        secondaryPriceLabel.font = NSFont.systemFont(ofSize: 11)
        secondaryPriceLabel.textColor = .secondaryLabelColor
        secondaryPriceLabel.alignment = .right
        secondaryPriceLabel.translatesAutoresizingMaskIntoConstraints = false

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

        let click = NSClickGestureRecognizer(target: self, action: #selector(clicked))
        addGestureRecognizer(click)
        updateAppearance()
    }

    private func updateAppearance() {
        let radioConfig = NSImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        let radioName = isSelected ? "checkmark.circle.fill" : "circle"
        radio.image = NSImage(systemSymbolName: radioName, accessibilityDescription: nil)?
            .withSymbolConfiguration(radioConfig)
        radio.contentTintColor = isSelected ? onboardingBrandColor : .tertiaryLabelColor
        layer?.borderWidth = isSelected ? 2 : 1
        layer?.borderColor = isSelected ? onboardingBrandColor.cgColor : NSColor.separatorColor.cgColor
    }

    @objc private func clicked() {
        onSelect?()
    }
}

