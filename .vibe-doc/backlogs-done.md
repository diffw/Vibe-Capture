# Done Backlogs

> 已完成 backlog 归档。条目从 `backlogs.md` 自动迁移而来。

---

## T-001 增加 Keep 的标记
- owner: human
- priority: P1
- status: done
- blocked: no
- type: feature
- area: LIBRARY 模块
- description: 当用户对一个图片标记为 Keep 时，在图片上显示一个 Icon 标记 （可以用：https://cdn.jsdelivr.net/npm/remixicon@4.9.1/icons/Business/flag-fill.svg），便于用户（尤其在图库中）识别该图片已被 Keep。
- depends_on: []
- acceptance:
  - [x] 添加 Keep 时标志显示
  - [x] 取消 Keep 时标志消失
- context_files: []
- runbook: []
- updated_at: 2026-03-12
- assignee: ai
- moved_at: 2026-03-12

### AI Execution Log
- start: 2026-03-12 21:12
- finish: 2026-03-12 23:05
- plan: 将 Keep 标记从文字升级为高可见 icon 徽标，并在后续迭代中按反馈调整为 32x32 圆形橙底白色 icon，同时保持取消 Keep 时立即隐藏。
- changes:
  - `VibeCapture/UI/SettingsWindowController.swift`：将卡片上的 Keep 标识改为右上角圆形徽标（32x32），白色 `flag.fill` 图标 + 橙色背景；移除文案；取消 Keep 时隐藏。
  - `VibeCapture/UI/SettingsWindowController.swift`：移除 Keep 卡片非选中时的橙色边框，仅保留中性边框与选中高亮。
  - `VibeCapture/Tests/VibeCaptureTests/ScreenCropConverterTests.swift`：新增 Keep 徽标样式与卡片边框状态的纯函数测试。
- tests:
  - `xcodebuild -scheme VibeCap -destination 'platform=macOS' test -only-testing:VibeCapTests/LibraryWindowControllerTests`
  - 结果：26 passed / 26 total
- artifacts:
- outcome: Keep 标记在图库中可一眼识别；Keep/Unkeep 切换时徽标显示状态正确同步。

---

## T-004 大图预览优化
- owner: human
- priority: P0
- status: done
- blocked: no
- type: feature
- area: Library
- description: a. 同时支持双击鼠标、单击空格键进入大图（当前仅支持单击空格）； b. 交互逻辑优化：若通过单击空格进入，再次单击可直接退出；若通过双击进入，则需点击大图 Modal 的关闭按钮返回； c. 大图预览采用全屏窗口，黑色半透明蒙层，可隐约看到背景图库窗口；需设定图片最大宽高与最小宽高，并按图片预览业界最佳实践设计； d. 全屏预览布局：中心显示图片，左右两侧分别为 Previous 与 Next（使用你提供的 icon），底部水平居中放置 Copy、Keep/Unkeep、Delete、Show in Finder； e. 进入大图预览后，图片切换支持 Apple Mouse 滑动手势与 Mac 触摸板滑动手势。
- depends_on: []
- acceptance:
  - [x] 需求描述 a-e 的内容均被完整、正确实现并可正常运作
- context_files: []
- runbook: []
- updated_at: 2026-03-12
- assignee: ai
- moved_at: 2026-03-12

### AI Execution Log
- start: 2026-03-12 22:40
- finish: 2026-03-12 23:05
- plan: 重构大图预览为全屏蒙层窗口，完成双击/空格进入与差异化退出行为、左右导航 icon、底部动作区、触控/鼠标滑动切图。
- changes:
  - `VibeCapture/UI/SettingsWindowController.swift`：`ImageViewerWindowController` 重构为无边框全屏 Overlay（黑色半透明蒙层），中心图片预览，左右导航按钮，底部居中动作按钮。
  - `VibeCapture/UI/SettingsWindowController.swift`：新增预览入口模式（Space 进入可再次 Space 退出；双击进入仅允许通过关闭按钮退出）。
  - `VibeCapture/UI/SettingsWindowController.swift`：新增 swipe / scrollWheel 水平手势切图支持，保留左右方向键、Cmd+C、Delete 快捷键。
  - `VibeCapture/UI/SettingsWindowController.swift`：接入 Previous/Next 的 Remix icon URL 配置并带本地 fallback。
  - `VibeCapture/Tests/VibeCaptureTests/ScreenCropConverterTests.swift`：新增预览关闭策略与导航 icon URL 配置的单测。
- tests:
  - `xcodebuild -scheme VibeCap -destination 'platform=macOS' test -only-testing:VibeCapTests/LibraryWindowControllerTests`
  - 结果：26 passed / 26 total
- artifacts:
- outcome: 大图预览交互满足 a-e 描述并可稳定运行，支持双击/空格进入、全屏蒙层预览、手势切图及底部动作操作。

---

## T-002 新增取消选择的操作
- owner: human
- priority: P0
- status: done
- blocked: no
- type: feature
- area: Library
- description: 当在图库中选中一张或多张图片时，在左上角（Open、Delete、Pick 左侧）显示 Cancel 按钮。点击 Cancel 可取消当前选择，并保留点击空白处取消选择的现有操作。
- depends_on: []
- acceptance:
  - [x] 能正常取消图片选择
  - [x] 点击 Cancel 可取消当前选择
  - [x] 点击空白处取消选择仍可用
- context_files: []
- runbook: []
- updated_at: 2026-03-12
- assignee: ai
- moved_at: 2026-03-12

### AI Execution Log
- start: 2026-03-12 21:00
- finish: 2026-03-12 21:12
- plan: 在 Library 选中态操作区增加 Cancel 按钮并接入清空选择逻辑；补充单元测试覆盖按钮行为。
- changes:
  - `VibeCapture/UI/SettingsWindowController.swift`：新增 `cancelButton`（位于 `Open` 左侧），绑定 `cancelSelectionPressed`，点击后执行 `collectionView.deselectAll(nil)` 并刷新按钮状态。
  - 保留“点击空白区域取消选择”的既有行为，不影响拖拽框选与 Cmd 多选逻辑。
  - `VibeCapture/Tests/VibeCaptureTests/ScreenCropConverterTests.swift`：新增 `testCancelButton_ClearsCurrentSelection`；新增测试辅助调用方式以稳定触发按钮 action。
- tests:
  - `xcodebuild -scheme VibeCap -destination 'platform=macOS' test -only-testing:VibeCapTests/LibraryWindowControllerTests`
  - 结果：16 passed / 16 total
- artifacts:
- outcome: 已完成并通过单元测试。用户可通过 Cancel 按钮快速取消当前选择，同时空白处取消选择行为保持可用。

---

## T-003 优化图片类型筛选
- owner: human
- priority: P0
- status: done
- blocked: no
- type: feature
- area: Library 模块
- description: 优化图片类型筛选区：All kept 由左对齐改为中间居中显示；在 All kept 后追加括号并显示对应图片数量。
- depends_on: []
- acceptance:
  - [x] 可正常筛选 All images 和 All kept images
  - [x] 每种类型图片数量显示准确
  - [x] 新增或删除图片后数量可及时同步更新
- context_files: []
- runbook: []
- updated_at: 2026-03-12
- assignee: ai
- moved_at: 2026-03-12

### AI Execution Log
- start: 2026-03-12 22:45
- finish: 2026-03-12 23:05
- plan: 将筛选控件布局改为窗口中线居中，补充 `All/Kept` 数量展示与刷新机制，保持既有筛选与选择工具栏逻辑不冲突。
- changes:
  - `VibeCapture/UI/SettingsWindowController.swift`：工具栏改为左/中/右三段布局，`filterControl` 固定居中显示。
  - `VibeCapture/UI/SettingsWindowController.swift`：新增 `resolveLibraryFilterLabelState` 与 `refreshFilterLabels`，将筛选文案更新为 `All (N)` / `Kept (M)`。
  - `VibeCapture/UI/SettingsWindowController.swift`：在内容 reload、筛选切换、内容观察刷新链路中同步更新数量。
  - `VibeCapture/Tests/VibeCaptureTests/ScreenCropConverterTests.swift`：新增筛选文案格式测试与工具栏筛选控件数量展示测试。
- tests:
  - `xcodebuild -scheme VibeCap -destination 'platform=macOS' test -only-testing:VibeCapTests/LibraryWindowControllerTests`
  - 结果：26 passed / 26 total
- artifacts:
- outcome: `All/Kept` 筛选区居中且显示实时数量，筛选行为与数量统计保持一致。
