import AppKit
import StoreKit

final class OnboardingPaywallView: NSView {
    var onFinished: (() -> Void)?

    private let logoImageView = NSImageView()
    private let titleLabel = NSTextField(wrappingLabelWithString: "")
    private let subtitleLabel = NSTextField(wrappingLabelWithString: "")

    private let featureCard = NSView()
    private let featureBgImageView = NSImageView()
    private let proBadgeImageView = NSImageView()

    private let ctaButton = OnboardingPillButton()
    private let pricingLabel = NSTextField(labelWithString: "")

    private let termsButton = NSButton(title: "", target: nil, action: nil)
    private let privacyButton = NSButton(title: "", target: nil, action: nil)
    private let restoreButton = NSButton(title: "", target: nil, action: nil)

    private var yearlyProduct: Product?
    private var trialDays: Int?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
        refreshProducts()
    }

    required init?(coder: NSCoder) { nil }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.white.cgColor

        let primary = NSColor(srgbRed: 115.0 / 255.0, green: 69.0 / 255.0, blue: 46.0 / 255.0, alpha: 1.0) // #73452E
        let secondary = NSColor(srgbRed: 139.0 / 255.0, green: 107.0 / 255.0, blue: 92.0 / 255.0, alpha: 1.0) // #8B6B5C

        logoImageView.imageScaling = .scaleProportionallyUpOrDown
        logoImageView.imageAlignment = .alignLeft
        logoImageView.image = PaywallFigma.image(named: "logo", ext: "svg")

        titleLabel.maximumNumberOfLines = 0
        PaywallFigma.configureLabel(titleLabel)
        titleLabel.attributedStringValue = PaywallFigma.attributedText(
            string: L("onboarding.05.title"),
            font: NSFont.systemFont(ofSize: 24, weight: .heavy),
            color: primary,
            lineHeightMultiple: 1.1
        )

        subtitleLabel.maximumNumberOfLines = 0
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

        setupLegal(primary: primary, secondary: secondary)

        addSubview(logoImageView)
        addSubview(titleLabel)
        addSubview(subtitleLabel)
        addSubview(featureCard)
        addSubview(ctaButton)
        addSubview(pricingLabel)
        addSubview(termsButton)
        addSubview(privacyButton)
        addSubview(restoreButton)

        for v in [logoImageView, titleLabel, subtitleLabel, featureCard, ctaButton, pricingLabel, termsButton, privacyButton, restoreButton] {
            v.translatesAutoresizingMaskIntoConstraints = false
        }

        // Figma layout (frame: 560x640, content width: 416 @ x=72, top = 80)
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
            featureCard.topAnchor.constraint(equalTo: topAnchor, constant: 222),
            featureCard.widthAnchor.constraint(equalToConstant: 416),
            featureCard.heightAnchor.constraint(equalToConstant: 188),

            ctaButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 72),
            ctaButton.topAnchor.constraint(equalTo: topAnchor, constant: 442),
            ctaButton.widthAnchor.constraint(equalToConstant: 416),
            ctaButton.heightAnchor.constraint(equalToConstant: 48),

            pricingLabel.centerXAnchor.constraint(equalTo: ctaButton.centerXAnchor),
            pricingLabel.topAnchor.constraint(equalTo: ctaButton.bottomAnchor, constant: 10),

            termsButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 72),
            termsButton.topAnchor.constraint(equalTo: topAnchor, constant: 547),

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
        featureBgImageView.image = PaywallFigma.image(named: "paywall-card-bg", ext: "png")

        proBadgeImageView.imageScaling = .scaleProportionallyUpOrDown
        proBadgeImageView.image = PaywallFigma.image(named: "pro-badge", ext: "svg")

        let featuresStack = NSStackView()
        featuresStack.orientation = .vertical
        featuresStack.spacing = 16
        featuresStack.alignment = .leading

        func row(title: String, subtitle: String) -> NSView {
            let bullet = NSImageView()
            bullet.imageScaling = .scaleProportionallyUpOrDown
            bullet.image = PaywallFigma.image(named: "bullet-circle", ext: "svg")
            bullet.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                bullet.widthAnchor.constraint(equalToConstant: 34),
                bullet.heightAnchor.constraint(equalToConstant: 34),
            ])

            let t = NSTextField(labelWithString: title)
            PaywallFigma.configureLabel(t)
            t.attributedStringValue = PaywallFigma.attributedText(
                string: title,
                font: NSFont.systemFont(ofSize: 16, weight: .bold),
                color: .white,
                lineHeightMultiple: 1.1
            )

            let s = NSTextField(labelWithString: subtitle)
            PaywallFigma.configureLabel(s)
            s.attributedStringValue = PaywallFigma.attributedText(
                string: subtitle,
                font: NSFont.systemFont(ofSize: 14, weight: .regular),
                color: .white,
                lineHeightMultiple: 1.1
            )

            let textStack = NSStackView(views: [t, s])
            textStack.orientation = .vertical
            textStack.spacing = 3
            textStack.alignment = .leading

            let row = NSStackView(views: [bullet, textStack])
            row.orientation = .horizontal
            row.spacing = 12
            row.alignment = .centerY
            return row
        }

        featuresStack.addArrangedSubview(row(title: L("onboarding.05.feature1.title"), subtitle: L("onboarding.05.feature1.body")))
        featuresStack.addArrangedSubview(row(title: L("onboarding.05.feature2.title"), subtitle: L("onboarding.05.feature2.body")))
        featuresStack.addArrangedSubview(row(title: L("onboarding.05.feature3.title"), subtitle: L("onboarding.05.feature3.body")))

        featureCard.addSubview(featureBgImageView)
        featureCard.addSubview(featuresStack)
        featureCard.addSubview(proBadgeImageView)

        featureBgImageView.translatesAutoresizingMaskIntoConstraints = false
        featuresStack.translatesAutoresizingMaskIntoConstraints = false
        proBadgeImageView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            featureBgImageView.centerXAnchor.constraint(equalTo: featureCard.centerXAnchor),
            featureBgImageView.centerYAnchor.constraint(equalTo: featureCard.centerYAnchor, constant: 17),
            featureBgImageView.widthAnchor.constraint(equalToConstant: 500),
            featureBgImageView.heightAnchor.constraint(equalToConstant: 326),

            featuresStack.leadingAnchor.constraint(equalTo: featureCard.leadingAnchor, constant: 24),
            featuresStack.topAnchor.constraint(equalTo: featureCard.topAnchor, constant: 24),
            featuresStack.widthAnchor.constraint(equalToConstant: 284.403),

            proBadgeImageView.trailingAnchor.constraint(equalTo: featureCard.trailingAnchor, constant: -24),
            proBadgeImageView.topAnchor.constraint(equalTo: featureCard.topAnchor, constant: 24),
            proBadgeImageView.widthAnchor.constraint(equalToConstant: 67.597),
            proBadgeImageView.heightAnchor.constraint(equalToConstant: 30.557),
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

    private func refreshProducts() {
        Task { @MainActor in
            do {
                try await PurchaseService.shared.loadProductsIfNeeded()
                yearlyProduct = PurchaseService.shared.product(id: EntitlementsService.ProductID.yearly)
                if let yearlyProduct {
                    trialDays = await PurchaseService.shared.trialDays(for: yearlyProduct.id)
                }
                refreshPricingCopy()
                ctaButton.isEnabled = true
            } catch {
                // Keep CTA disabled; user can close window and still use app.
                pricingLabel.stringValue = L("paywall.error.generic")
                ctaButton.isEnabled = false
            }
        }
    }

    private func refreshPricingCopy() {
        guard let yearlyProduct else {
            pricingLabel.stringValue = ""
            return
        }

        if let trialDays, trialDays > 0 {
            pricingLabel.stringValue = L("onboarding.05.pricing.trial_then", trialDays, yearlyProduct.displayPrice)
        } else {
            pricingLabel.stringValue = L("onboarding.05.pricing.then", yearlyProduct.displayPrice)
        }
    }

    // MARK: - Actions

    @objc private func ctaPressed() {
        guard let yearlyProduct else { return }
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
            case .failed:
                ctaButton.isEnabled = true
            }
        }
    }

    @objc private func restorePressed() {
        PurchaseService.shared.restorePurchases(from: window)
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
}

private enum PaywallFigma {
    static func image(named assetName: String, ext: String) -> NSImage? {
        if let url = Bundle.main.url(forResource: assetName, withExtension: ext, subdirectory: "Onboarding") {
            return SVGImageFallback.image(contentsOf: url)
        }
        if let url = Bundle.main.url(forResource: assetName, withExtension: ext) {
            return SVGImageFallback.image(contentsOf: url)
        }
        if let url = Bundle.main.url(forResource: assetName, withExtension: ext, subdirectory: "Resources/Onboarding") {
            return SVGImageFallback.image(contentsOf: url)
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

