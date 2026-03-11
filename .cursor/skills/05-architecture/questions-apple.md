# Architecture Questions: Apple Platform (iOS / macOS)

These questions apply when the project targets **iOS**, **macOS**, or both.

---

## Category: Platform-Specific - iOS/macOS

| ID | Question | Options | Skip If PRD/IA Contains |
|----|----------|---------|-------------------------|
| AP1 | Distribution method? | A) App Store only B) TestFlight + App Store C) Enterprise (MDM) D) Direct download (Mac) | Distribution strategy |
| AP2 | Minimum iOS version? | A) Latest only B) iOS 16+ C) iOS 15+ D) Older: [specify] | User reach |
| AP3 | Minimum macOS version? | A) Latest only B) macOS 13+ C) macOS 12+ D) Older: [specify] | User reach |
| AP4 | iPad support for iOS app? | A) iPhone only B) iPad compatible (scaled) C) iPad optimized D) iPad-specific features | Platform scope |
| AP5 | Apple Watch support? | A) No B) Companion app C) Standalone features | Platform scope |
| AP6 | Widgets (iOS/macOS)? | A) No B) Single widget C) Multiple widgets D) Configurable widgets | Features |
| AP7 | Siri Shortcuts? | A) No B) Basic shortcuts C) Custom intents D) Full Siri integration | Features |
| AP8 | ShareSheet extension? | A) No B) Receive shares C) Share to other apps D) Both | Features |
| AP9 | iCloud sync (native)? | A) No, custom sync B) Yes, CloudKit C) Yes, iCloud Drive D) Both options | Sync strategy |
| AP10 | Handoff between devices? | A) No B) Yes, basic C) Yes, with state transfer | Cross-device |
| AP11 | Apple Pay support? | A) No B) Yes, in-app purchases C) Yes, physical goods too | Payment method |
| AP12 | HealthKit integration? | A) No B) Read data C) Write data D) Both | If health-related |
| AP13 | Location services? | A) No B) When in use C) Always D) Significant location changes | Location features |
| AP14 | Camera usage? | A) No B) Photo capture C) Video capture D) AR features | Media features |
| AP15 | Background processing? | A) No B) Background fetch C) Background tasks D) Background audio/location | Background needs |
