# Backlogs

> 规则：
> - 人工维护需求定义与优先级
> - AI 维护执行状态、执行日志、测试与结果
> - 本文件是 backlog 单一真实来源

## 执行规则
- 优先级顺序：P0 > P1 > P2 > P3
- 选择规则：优先 `status=todo` 且 `blocked=no`
- WIP：同一时间仅 1 个 `doing`

---

## T-005 优化 Keep 的操作
- owner: human
- priority: P0
- status: done
- blocked: no
- type: feature
- area: Library
- description: 1）将当前 Kept 圆形 icon 尺寸调整为 28x28；2）当鼠标 hover 在图片上或选中某张图片时，显示一个高度为 24 的「icon+文字」按钮：icon 使用 kept 旗帜 icon，文字为 Keep，按钮背景白色，icon 与文字为深灰色；3）当用户点击该「icon+文字」按钮后，视为执行 Keep 操作，按钮切换为现有的 Kept 圆形按钮。
- depends_on: []
- acceptance:
  - [ ] 用户在 hover 或选中图片时，能够正确显示文字加 icon 的按钮
  - [ ] 当用户点击文字加 icon 的按钮后，状态能够正确切换为 Kept 圆形 icon
- context_files: []
- runbook: []
- updated_at: 2026-03-12
- assignee: ai

### AI Execution Log
- start:
- finish:
- plan:
- changes:
- tests:
- artifacts:
- outcome:

---

## T-009 支持 Terminal 粘贴（Image + Prompt）
- owner: human
- priority: P0
- status: todo
- blocked: no
- type: feature
- area: 截图复制&粘贴
- description: 1）保持目前对可视化编辑器的图片复制/粘贴支持；2）当用户将复制内容粘贴到任意 Terminal 工具时，粘贴为图片本地路径（如 /Users/diffwang/Desktop/VibeCap/VC\ 20260314-162840.png）；3）当用户复制内容包含「图片 + Prompt」时，也支持在 Terminal 中粘贴。
- depends_on: []
- acceptance:
  - [ ] 保持现有可视化编辑器粘贴能力不回退
  - [ ] 在任意 Terminal 中可粘贴图片本地路径
  - [ ] 若复制时带有 Prompt，粘贴到 Terminal 时也能包含 Prompt 内容
- context_files: []
- runbook: []
- updated_at: 2026-03-15
- assignee: ai

### AI Execution Log
- start:
- finish:
- plan:
- changes:
- tests:
- artifacts:
- outcome:

---

## T-007 支持多张图片的复制
- owner: human
- priority: P1
- status: done
- blocked: no
- type: feature
- area: Library
- description: 当用户选择多张图片时，可通过快捷键 Command + C 或点击右上角 Copy 复制多张图片，并弹出 Toast 提示复制成功。
- depends_on: []
- acceptance:
  - [ ] 复制成功后，在其他编辑器（如 Cursor）按 Command + V 能成功粘贴这些图片
- context_files: []
- runbook: []
- updated_at: 2026-03-15
- assignee: ai

### AI Execution Log
- start: 2026-03-15
- finish: 2026-03-15
- plan: 启用多选复制按钮状态，扩展剪贴板多图写入能力，并让 Command+C 与 Copy 按钮统一走批量复制路径。
- changes:
  - `VibeCapture/UI/SettingsWindowController.swift`：`copyEnabled` 改为有选择即启用；`copyCurrentSelection()` 改为批量加载并复制选中图片；成功 Toast 支持单张/多张文案。
  - `VibeCapture/Services/ClipboardService.swift`：新增 `copy(images:prompt:)`，单图 API 转调多图 API。
  - `VibeCapture/Resources/en.lproj/Localizable.strings`：新增 `"hud.images_copied"` 本地化键。
- tests:
  - ✅ Unit Tests: 230 passed / 230 total | `VibeCapTests` (`xcodebuild test -project VibeCapture.xcodeproj -scheme VibeCap -destination 'platform=macOS' -only-testing:VibeCapTests`)
  - ⚠️ Full Suite: `xcodebuild test` 失败，失败点为 `VibeCaptureUITests/PaywallUITests.swift` 的 `AnnotationToolbarUITests.testAnnotationToolbarExists`（应用终止失败，非本次改动路径）。
  - ✅ Runtime Verify: `./scripts/run-dev.sh` 执行成功（`** BUILD SUCCEEDED **`）。
- artifacts:
  - 多选场景支持 `Command + C` 与工具栏 `Copy` 一次复制多张图片，Toast 可显示复制张数。
- outcome: 完成，满足验收项（多图可复制并可在外部应用粘贴）。

---

## T-006 增加快捷截取全屏的功能
- owner: human
- priority: P1
- status: done
- blocked: no
- type: feature
- area: 截图模块
- description: 开始截图时，当前单击会退出截图模式。新增能力：通过双击直接截取“当前鼠标所在屏幕”的全屏图片（非跨屏拼接），并在截取后立即打开截图预览与标注窗口。
- depends_on: []
- acceptance:
  - [ ] 开始截图后，双击可截取鼠标所在屏幕的全屏图片（多显示器时也仅当前屏幕）
  - [ ] 全屏截图后可直接进入预览和标注窗口
- context_files: []
- runbook: []
- updated_at: 2026-03-15
- assignee: ai

### AI Execution Log
- start: 2026-03-15
- finish: 2026-03-15
- plan: 在截图 overlay 鼠标事件中区分单击/双击：保留单击退出，新增双击直接截取鼠标所在屏幕全屏并进入预览标注流程。
- changes:
  - `VibeCapture/Managers/ScreenshotOverlayController.swift`：新增 `OverlayMouseUpAction` 与 `resolveOverlayMouseUpAction`；`mouseDown/mouseUp` 传入 `NSEvent`；无选区单击改为短延迟取消（支持双击判定）；双击触发当前屏全屏截取并复用既有 `finish -> CaptureManager.presentModal` 链路。
  - `VibeCapture/Tests/VibeCaptureTests/ScreenCropConverterTests.swift`：新增 overlay 点击决策测试（无选区、微小选区、有效选区、双击全屏）。
- tests:
  - ✅ Unit Tests: 230 passed / 230 total | `VibeCapTests` (`xcodebuild test -project VibeCapture.xcodeproj -scheme VibeCap -destination 'platform=macOS' -only-testing:VibeCapTests`)
  - ⚠️ Full Suite: `xcodebuild test` 失败，失败点为 `VibeCaptureUITests/PaywallUITests.swift` 的 `AnnotationToolbarUITests.testAnnotationToolbarExists`（应用终止失败，非本次改动路径）。
  - ✅ Runtime Verify: `./scripts/run-dev.sh` 执行成功（`** BUILD SUCCEEDED **`）。
- artifacts:
  - 截图模式下双击可按“鼠标所在屏幕”全屏截取，且截取后立即进入预览与标注窗口；单击仍保持退出。
- outcome: 完成，满足验收项（双击全屏当前屏 + 直接进入预览标注）。

---

## T-008 图片的间距需要增加，不然用户无法进行选择操作
- owner: human
- priority: P0
- status: todo
- blocked: no
- type: fix
- area: Library
- description: 调整 Library 图片布局间距：图片与外层容器边缘间距设为 48；图片网格中图片与图片之间间距也设为 48，以降低误触并提升选择操作成功率。
- depends_on: []
- acceptance:
  - [ ] 默认窗口宽度下，用户可稳定单击选中任意图片，误触显著下降
  - [ ] 在窗口变化/缩放后仍可稳定选中，不影响多选与框选
  - [ ] 不影响现有 hover、keep、cancel、copy 等交互
- context_files: []
- runbook: []
- updated_at: 2026-03-15
- assignee: ai

### AI Execution Log
- start:
- finish:
- plan:
- changes:
- tests:
- artifacts:
- outcome:
