import AppKit

final class ShortcutRecorderView: NSView {
    var onChange: ((KeyCombo) -> Void)?

    private var currentCombo: KeyCombo = SettingsStore.shared.captureHotKey {
        didSet { updateUI() }
    }

    private var isRecording = false {
        didSet { updateUI() }
    }

    private let titleLabel = NSTextField(labelWithString: "")
    private let recordButton = NSButton(title: "", target: nil, action: nil)
    private let helpLabel = NSTextField(labelWithString: "")

    override var acceptsFirstResponder: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) { nil }

    func setCombo(_ combo: KeyCombo) {
        currentCombo = combo
    }

    private func setup() {
        titleLabel.stringValue = L("settings.shortcut.title")
        titleLabel.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.alignment = .left

        recordButton.bezelStyle = .rounded
        recordButton.setButtonType(.momentaryPushIn)
        recordButton.target = self
        recordButton.action = #selector(toggleRecording)

        helpLabel.stringValue = L("settings.shortcut.help")
        helpLabel.font = NSFont.systemFont(ofSize: 11)
        helpLabel.textColor = .tertiaryLabelColor
        helpLabel.alignment = .left

        let row = NSStackView(views: [recordButton, NSView()])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        row.distribution = .fill

        let stack = NSStackView(views: [titleLabel, row, helpLabel])
        stack.orientation = .vertical
        stack.spacing = 6
        stack.alignment = .leading

        addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            recordButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 180)
        ])

        updateUI()
    }

    private func updateUI() {
        if isRecording {
            recordButton.title = L("settings.shortcut.recording")
            recordButton.contentTintColor = .systemBlue
            helpLabel.isHidden = false
        } else {
            recordButton.title = currentCombo.displayString
            recordButton.contentTintColor = nil
            helpLabel.isHidden = true
        }
    }

    @objc private func toggleRecording() {
        isRecording.toggle()
        if isRecording {
            window?.makeFirstResponder(self)
        }
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }

        if event.keyCode == 53 { // Esc cancels
            isRecording = false
            return
        }

        let modifiers = event.modifierFlags.intersection(KeyCombo.allowedModifierFlags)
        guard !modifiers.isEmpty else {
            NSSound.beep()
            HUDService.shared.show(message: L("error.modifier_required"), style: .error, duration: 1.0)
            return
        }

        let combo = KeyCombo(keyCode: UInt32(event.keyCode), modifiers: modifiers)
        currentCombo = combo
        isRecording = false
        onChange?(combo)
    }
}


