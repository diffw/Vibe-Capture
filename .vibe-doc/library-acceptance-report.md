# VibeCap Library 明早验收报告（草案）

> Date: 2026-03-12  
> Scope: `.vibe-doc/PRD-library.md` 全量验收（F-01 ~ F-11）

## 1) PRD 对照结论

| Flow | 结论 | 关键实现位置 |
|---|---|---|
| F-01 目录设定 | ✅ 完成 | `VibeCapture/Services/ScreenshotSaveService.swift` |
| F-02 网格/列表浏览 | ✅ 完成 | `VibeCapture/UI/SettingsWindowController.swift` (`LibraryViewController`) |
| F-03 大图浏览与切换 | ✅ 完成 | `VibeCapture/UI/SettingsWindowController.swift` (`ImageViewerWindowController`) |
| F-04 Save & Keep | ✅ 完成 | `VibeCapture/UI/CaptureModalViewController.swift`, `VibeCapture/UI/CaptureModalWindowController.swift` |
| F-05 Keep / Unkeep | ✅ 完成 | `VibeCapture/UI/SettingsWindowController.swift`, `VibeCapture/UI/ScreenshotPreviewPanelController.swift` |
| F-06 自动清理设置 | ✅ 完成 | `VibeCapture/UI/SettingsViewController.swift`, `VibeCapture/Settings/SettingsStore.swift` |
| F-07 自动清理执行 | ✅ 完成 | `VibeCapture/Services/ScreenshotSaveService.swift` (`AutoCleanupService`, `CleanupSchedulerService`) |
| F-08 手动删除到废纸篓 | ✅ 完成 | `VibeCapture/UI/SettingsWindowController.swift`, `VibeCapture/Services/ScreenshotSaveService.swift` (`TrashService`) |
| F-09 Upgrade 入口 | ✅ 保持 | `VibeCapture/AppDelegate.swift` |
| F-10 复制到剪贴板 | ✅ 完成 | `VibeCapture/UI/SettingsWindowController.swift`, `VibeCapture/Services/ClipboardService.swift` |
| F-11 Pro Gate + 升级返回设置 | ✅ 完成 | `VibeCapture/UI/SettingsWindowController.swift`, `VibeCapture/AppDelegate.swift` |

## 2) 自动化与测试现状

### 一键脚本

- 已落地：`scripts/run-local-ci.sh`
- 已固化文档：`DEV_WORKFLOW.md`
- 稳定性处理：每次运行清理独立 `DerivedData`，并在各测试阶段前主动清理残留 `VibeCap` 进程
- 当前脚本内容：
  1. localization 校验
  2. build
  3. unit tests（默认跳过 `PurchaseFlowTests`、`LibraryFlowIntegrationTests`）
  4. integration（`LibraryFlowIntegrationTests`）
  5. UI tests（`VibeCapUITests`）

### 实际执行结果（最新可复现）

- `xcodebuild -scheme VibeCap -destination 'platform=macOS' build`  
  - ✅ 通过（`BUILD SUCCEEDED`）

- `xcodebuild -scheme VibeCap -destination 'platform=macOS' test -only-testing:VibeCapTests/CapabilityServiceTests -skip-testing:VibeCapUITests`  
  - ✅ 通过：`Executed 22 tests, with 0 failures`

- `./scripts/run-local-ci.sh`（本轮最新）  
  - ✅ Unit：`Executed 84 tests, with 0 failures`（脚本默认跳过 `PurchaseFlowTests` 与 `LibraryFlowIntegrationTests`）  
  - ✅ Integration：`LibraryFlowIntegrationTests` 2/2 通过  
  - ✅ UI：`Executed 21 tests, with 0 failures`

- 调试结论（test 卡住问题）  
  - ✅ 根因定位为本机会话中的 `testmanagerd` 状态污染（旧测试守护进程未健康回收）  
  - ✅ 重置守护进程并清理残留测试进程后，`xcodebuild test` 可恢复正常启动与执行

## 3) 风险与遗留项

1. **本机 test runner 稳定性风险（P1）**  
   复现过一次 `xcodebuild test` 启动卡住；通过重置 `testmanagerd` 可恢复，仍建议验收前先做进程清理。

2. **`dist/` 构建产物脏变更（P2）**  
   本轮验证产生了大量 `dist/VibeCap.app` 改动，提交前需忽略或清理，仅保留源代码与文档变更。

## 4) 明早验收建议执行顺序

1. 在本地 GUI 正常会话中先执行：`./scripts/run-local-ci.sh`
2. 若 `xcodebuild test` 卡住，先重置测试守护进程并清理残留测试进程后重跑
3. 最终以 F-01~F-11 手工走查 + 自动化结果联合签收

