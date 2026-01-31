# VibeCap — 当前实现的事实级产品规格（反向工程）

> 目的：从代码实现反推“已经发生的行为与规则”，作为后续迭代的事实来源（SSOT）。
>
> 范围：本文件描述 `VibeCapture/` 当前实现的功能与约束；不包含未来规划与改进建议。
>
> 约定：无法 100% 确认的点以「从代码推断的隐式行为」标注。

---

## 1. 功能系统概览

### 1.1 产品形态
- **应用类型**：菜单栏应用（`NSApp.setActivationPolicy(.accessory)`），无 Dock 图标与主窗口常驻（事实：`AppDelegate.applicationDidFinishLaunching` 设置）。
- **入口**：
  - 菜单栏图标点击弹出菜单（`NSStatusItem`）。
  - 全局快捷键触发截图（`ShortcutManager` + Carbon `RegisterEventHotKey`）。
- **一次性启动提示**：首次启动会显示 HUD 提示应用已在运行（UserDefaults key: `didShowLaunchHUD`）。

### 1.2 主要子功能
- **截图选区捕获**：全屏覆盖层选择矩形区域，随后截取该区域截图。
- **捕获预览/编辑 Modal**：展示截图、输入 prompt、添加标注、保存、复制。
- **标注系统**：箭头/圆/矩形/编号与编号箭头；具备选中、拖动、缩放、清空等交互。
- **保存系统**：将截图（可含标注）保存到用户选择的文件夹（安全书签）。
- **复制系统**：
  - 基础复制：复制图片到剪贴板（以及在特定条件下自动保存）。
  - Copy & Arm：将 prompt 文本先写入剪贴板并进入“armed”状态，等待用户下一次 ⌘V 后自动按序粘贴图片，并在结束后恢复原剪贴板（默认开启）。
- **设置页**：快捷键设置、保存开关与保存目录、开机启动、IAP（升级/恢复/管理）。
- **付费墙**：展示计划与购买入口；受 StoreKit 2 产品加载状态影响。
- **本地化**：内置 20 种语言；支持“系统语言/手动覆盖”，切换后通过重启生效。

---

## 2. 用户操作模型

### 2.1 触发截图（Capture Area）
- **触发方式**：
  - 菜单栏：点击 `Capture Area` 菜单项。
  - 快捷键：按用户配置的全局热键（默认值见 `KeyCombo.defaultCapture`；从代码调用点可见 `SettingsStore.captureHotKey`）。
- **前置条件**：
  - 需要系统“屏幕录制”权限：`CGPreflightScreenCaptureAccess()` 必须为 true。
- **权限缺失时行为**：
  - 弹窗提示并引导打开系统设置“屏幕录制”页（`PermissionsUI.showScreenRecordingPermissionAlert()`）。
  - 该次截图流程终止（不会进入选区覆盖层）。

### 2.2 选区覆盖层（Overlay）交互
- **开始**：进入覆盖层后，鼠标光标变为十字（`NSCursor.crosshair.push()`）。
- **选区**：
  - 鼠标按下记录起点。
  - 鼠标拖动形成矩形选区；坐标被限制在起始屏幕范围内（多屏环境下以起始屏幕 frame 为 clamp 边界）。
  - 鼠标抬起结束：
    - 若未形成选区或选区宽/高 < 5px，则取消并退出（完成回调收到 `rect=nil`）。
    - 否则进入截图阶段（回调提供 rect 与 overlayWindowID，并要求调用 cleanup）。
- **取消**：
  - 在覆盖层按 ESC 立即取消（全局键盘监听 `NSEvent.addGlobalMonitorForEvents(.keyDown)`，keyCode 53）。
- **视觉**：
  - 覆盖层会显示当前鼠标坐标（X/Y）以及正在拖拽时选区尺寸（W×H）。

### 2.3 捕获预览/编辑 Modal（Capture Modal）
Modal 展示内容与操作：
- **截图预览**：截图以圆角方式显示，标注画布覆盖其上。
- **标注工具栏**：在截图下方（同一容器内）提供标注工具/颜色/清空。
- **Prompt 输入**：固定高度（约 3 行）的文本输入区域，带 placeholder。
- **底部按钮**：
  - Close：关闭 modal（结果：cancelled）。
  - Save Image：保存并弹出预览面板。
  - Copy：根据权限/是否有 prompt 执行不同复制策略（详见第 6 节）。
  - Copy Prompt：仅在特定条件出现（详见第 4 节）。
- **键盘**（仅当该窗口为 key window 时生效，`CaptureModalWindowController` 本地事件监控）：
  - ESC：优先取消标注创建，然后关闭 modal（代码路径中同时调用 `cancelAnnotationCreation()` 与 `finish(.cancelled)`）。
  - Delete/Backspace：当 firstResponder 不是 `NSTextView` 时删除选中的标注。
  - ⌘S：触发保存。
  - ⌘C：
    - 若 firstResponder 为 `NSTextView` 且有选中文本，走系统默认 Copy。
    - 否则触发“与 Copy 按钮相同的复制逻辑”，并吞掉该事件。

### 2.4 保存后的预览面板（Preview Panel）
- **出现时机**：保存动作开始后立即展示预览面板（fileURL 初始为 nil，保存成功后更新）。
- **位置**：主屏幕右下角偏内（`x = visibleFrame.maxX - width - 16`，`y = visibleFrame.minY + 16`）。
- **自动关闭**：默认 5 秒倒计时自动关闭；鼠标悬停与拖拽时暂停倒计时。
- **交互**：
  - 右上角关闭按钮（带倒计时表现）。
  - “Show in Finder” 按钮：仅当 fileURL 非 nil 时可用，点击后在 Finder 中定位文件。
  - 支持将图片拖拽出去（通过 `DraggableImageView`；从代码推断其拖拽行为）。

### 2.5 设置页（Settings）
- **快捷键**：用户在 UI 中修改快捷键；写入 `SettingsStore.captureHotKey` 并重新注册 Carbon 热键；注册失败会回滚 UI 到已存储值，并弹出错误提示。
- **保存**：
  - Save Enabled 开关：默认 ON（`SettingsStore.saveEnabled` 在 defaults 无值时返回 true）。
  - Choose Folder：打开目录选择器并存储安全书签。
- **开机启动**：使用 `SMAppService.mainApp.register/unregister`；当返回 `.requiresApproval` 时会提示用户打开 Login Items 设置页。
- **IAP**：
  - Upgrade：打开付费墙窗口。
  - Restore：触发 `AppStore.sync()` 并刷新 entitlements。
  - Manage：打开 Apple 订阅管理网页。

---

## 3. 交互状态机（如果存在）

### 3.1 Copy & Arm（ClipboardAutoPasteCore）
状态：`idle` → `armed` → `autoPasting(nextIndex)` → `idle`

- **prepare(text, imageCount)**：缓存 prompt 与图片数量。
- **arm()**：
  - state = `armed`
  - effects：
    - captureClipboard（保存原剪贴板快照）
    - writeTextOnly(preparedText)（仅写入文本）
    - startMonitoring（开启全局 ⌘V 监听：CGEventTap）
    - startTimeout(armTimeoutSeconds)（默认 10s）
- **timeoutFired()**：
  - 若仍为 `armed`，执行 disarm（停止监听 + 取消超时 +（可选）恢复剪贴板）。
- **userPasteDetected()**（检测到用户按下 ⌘V 一次）：
  - 停止监听与取消超时。
  - 若 imageCount == 0：回到 idle，并（可选）恢复剪贴板。
  - 若 imageCount > 0：
    - state = `autoPasting(nextIndex: 0)`
    - 先 scheduleNextPaste(after: userPasteSettlingDelay)（默认 0.25s），随后开始图片粘贴序列。
- **autoPasteTick()**：
  - writeImageOnly(index)
  - simulatePaste（注入一次 ⌘V）
  - 若还有下一张：scheduleNextPaste(after: delayBetweenPastes)（默认 0.25s）
  - 若已结束：scheduleRestoreClipboard(after: max(0.1, delayBetweenPastes))

全局监听实现事实：
- 使用 `CGEvent.tapCreate` 监听 `.keyDown/.keyUp/.flagsChanged`。
- armed 状态下遇到一次 ⌘V，会触发 `core.userPasteDetected()`，但**不吞掉**用户的真实 ⌘V（返回 `passUnretained(event)`），以确保文本粘贴由系统完成。
- 使用 `eventSourceUserData` 写入标记值（`"VIBE"`）区分注入事件，避免自触发。
- 使用 `debounceWindowSeconds`（默认 0.65s）对触发进行去抖。

### 3.2 选区覆盖层（ScreenshotOverlayController）
隐式状态（从代码推断的隐式行为）：
- `idle`（未启动/已 stop）
- `tracking`（已展示 overlay windows、正在监听鼠标移动/拖拽、全局监听 ESC）
- `finishing`（`isFinishing == true`，保证 finish 只执行一次）

### 3.3 标注画布（AnnotationCanvasView）
内部交互状态 `InteractionState`（显式 enum）：
- idle
- creating(startPoint, currentPoint)
- dragging(annotation, startMousePoint, originalPosition)
- resizingArrow / resizingCircle / resizingRectangle / resizingNumberedArrow（带 handle 与参考点）
- pendingNumberCreation / creatingNumberedArrow（编号工具：双击与拖拽区分）

---

## 4. UI / 交互细节规格

### 4.1 菜单栏菜单结构
- Capture Area
- Upgrade（打开付费墙）
- Settings（打开设置窗口）
- Language 子菜单：
  - System Default
  - supportedLanguages 列表中每一种语言
  - 选择后弹出“需要重启”的提示；用户可立即重启或稍后
- Quit（⌘Q）

### 4.2 Capture Modal 布局与视觉
（以 Auto Layout 约束为准）
- 顶部截图区域贴边显示（无外边距），容器背景为浅灰（0.95）。
- 截图内容有额外圆角 mask（8）与阴影 wrapper。
- 标注工具栏位于截图容器底部（高度 36）。
- Prompt 区：
  - ScrollView 高度 60
  - 背景为 `textBackgroundColor` 且 alpha 0.8
  - placeholder 位于输入区左上，点击会聚焦输入框。

### 4.3 按钮与快捷键提示（Hover-to-reveal）
- Close/Save/Copy 三个按钮上方各有 11pt 的提示文字：
  - Close：`modal.hint.esc_to_close`
  - Save：固定 `"⌘S to save"`
  - Copy：固定 `"⌘C to Copy"`
- 提示默认隐藏（`alphaValue = 0`），布局空间保留（不会引起布局跳动）。
- 鼠标悬停按钮后延迟 `0.25s` 显示提示（淡入 0.12s）；移出立即隐藏（淡出 0.08s）。

### 4.4 Copy Prompt 按钮显示规则
- `copyPromptStack.isHidden = hasAccessibilityPermission || !hasPromptText`
  - **无 Accessibility 权限** 且 **prompt 非空**：显示 Copy Prompt。
  - 其他情况：隐藏 Copy Prompt。

### 4.5 Accessibility 引导 Banner
- 显示条件：`accessibilityHintView.isHidden = hasAccessibilityPermission`。
- 文案：
  - label：`modal.hint.enable_copy_image_prompt`
  - CTA：`modal.button.enable_accessibility`
- 交互：
  - 整个 banner 可点击（手势识别），点击后：
    - 将 capture modal window level 临时降为 `.normal` 且 `orderBack`，避免遮挡系统设置窗口。
    - 请求 Accessibility 权限提示（`AXIsProcessTrustedWithOptions(prompt:true)`）。
    - 打开系统设置 Accessibility 页（deep link）。
  - 当应用再次变为 active 时恢复窗口 level 并将 modal 置前。
- hover：鼠标进入 banner 区域光标变为指针手形（pointing hand）。

---

## 5. 数据与状态模型

### 5.1 CaptureSession
`CaptureSession`：
- `image: NSImage`
- `prompt: String`（在 modal 中由 `promptTextView` 实际承载；session 初始传入为空字符串）
- `createdAt: Date`

### 5.2 SettingsStore（UserDefaults）
键（固定字符串）：
- `captureHotKey`：序列化后的 `KeyCombo`（JSON）。
- `saveEnabled`：Bool（默认 true）。
- `saveFolderBookmark`：Data（security-scoped bookmark）。
- `launchAtLogin`：Bool。

### 5.3 Pro / IAP 状态
`ProStatus`：
- tier：free / pro
- source：none / monthly / yearly / lifetime / unknown
- expirationDate：订阅到期时间（lifetime 为 nil）
- lastRefreshedAt：最后刷新时间

`EntitlementsService`：
- 缓存键：`IAPCachedProStatus`（UserDefaults）
- 规则：lifetime 优先，其次 yearly，其次 monthly；订阅以 `expirationDate > now` 判定有效；被 revoke 的交易会被忽略。
- 刷新时机：
  - app 启动后 start() 触发刷新
  - `Transaction.updates` 流中每次更新触发刷新
  - app 前台激活（didBecomeActive）触发刷新

### 5.4 Capability gating
`CapabilityKey`（字符串）与访问级别：
- free：captureArea / captureSave / captureAutosave / annotationsArrow
- pro：annotationsShapes / annotationsNumbering / annotationsColors

### 5.5 Annotation 模型
`Annotation` 协议（引用语义对象）：
- `id: UUID`
- `color: AnnotationColor`
- `contains(point:tolerance:)`（命中测试，point 为 image 坐标）
- `translated(by:)`
- `draw(in:scale:state:imageSize:)`

已实现类型：
- `ArrowAnnotation`
- `CircleAnnotation`
- `RectangleAnnotation`
- `NumberAnnotation`（number 可变，供重编号）
- `NumberedArrowAnnotation`（number 可变，供重编号）

---

## 6. 业务规则与强约束

### 6.1 屏幕录制权限（Capture）
- 进入选区 overlay 前必须通过 `CGPreflightScreenCaptureAccess()`。
- 若权限缺失，立即弹出权限引导，不继续截图流程。

### 6.2 保存目录与安全书签
- 保存目录通过 `NSOpenPanel` 选择文件夹并存储 security-scoped bookmark。
- 写文件时对目录调用 `startAccessingSecurityScopedResource()`，结束后停止访问。
- 文件名规则：`"VC yyyyMMdd-HHmmss.png"`，若同名存在则追加 `" 2"`, `" 3"`…（空格 + 数字）。
- 保存采用 `Data.write(..., .atomic)`。

### 6.3 复制（Copy）规则（Capture Modal 内）
#### 6.3.1 Copy 按钮标题规则
- 有 Accessibility 权限：
  - prompt 为空：显示 `modal.button.copy_image`
  - prompt 非空：显示 `modal.button.copy_image_and_prompt`
- 无 Accessibility 权限：
  - 始终显示 `modal.button.copy_image`

#### 6.3.2 Copy 行为规则（performCopyAction）
- 输入：当前截图 + 当前标注列表（保存/复制前均会 render 合成）。
- 无 Accessibility 权限（Basic mode）：
  - 复制图片到剪贴板（不写入 prompt 文本）。
  - 关闭 modal（调用 `onClose`）。
- 有 Accessibility 权限：
  - prompt 为空：复制图片到剪贴板，关闭 modal。
  - prompt 非空：
    - 准备 payload（text=prompt，images=[finalImage]）
    - arm（进入 Copy & Arm）
    - 显示 HUD：`hud.image_prompt_copied`
    - 关闭 modal

#### 6.3.3 Copy Prompt 行为规则
- 将 prompt 文本写入剪贴板（string 类型），并显示 HUD：`hud.prompt_copied`。
- 不包含图片，也不进入 armed 状态。

### 6.4 自动保存（Auto-save）规则（Copy Image 路径内）
当执行“复制图片到剪贴板”时，会尝试自动保存（与 Save 按钮的保存逻辑独立）：
- 仅当 `SettingsStore.saveEnabled == true`。
- 若当前已有保存目录（bookmark 可解析）：
  - 在后台队列将图片转为 CGImage 并写入该目录（不弹出预览面板）。
  - 写入失败会记录日志并在主线程显示 error HUD。
- 若未配置保存目录：
  - 在单次 modal 生命周期内最多显示一次“配置保存目录”的 info HUD（由 `didShowConfigureSaveFolderHint` 控制）。

---

## 7. 边界与异常处理

### 7.1 选区过小/无选区
- overlay mouseUp 时：
  - 无 rect 或 rect.width/height < 5：直接取消（不截图、不进入 modal）。

### 7.2 截图失败
- `CGWindowListCreateImage` 返回 nil：抛出 `ScreenCaptureError.captureFailed`，并显示 HUD（error）。

### 7.3 保存失败/用户取消选择目录
- Save 流程中：
  - 若用户在选择目录时取消：返回 nil，预览面板会被关闭（不显示成功 HUD）。
  - 写入失败：关闭预览面板并显示 error HUD。

### 7.4 Copy & Arm 超时与恢复
- armed 状态默认 10 秒超时，超时后 disarm。
- 默认开启“恢复原剪贴板”（`restoreClipboardAfter = true`）：
  - arm 时会捕获剪贴板快照
  - 结束时会将快照逐 item/type 恢复回 `NSPasteboard.general`

### 7.5 Paywall 产品加载失败
- 进入 paywall 时会异步加载 products：
  - 失败时将 UI 置为 failed state，并弹出一次警告对话框（sheet），用户确认后触发一次 refreshProducts 并重试加载（`didRetryProductsLoadAfterError` 防止多次重复重试）。

---

## 8. 当前实现的天然限制（不是缺点，是事实）

### 8.1 语言切换需要重启
- 语言覆盖设置写入 UserDefaults 后不会在当前进程内热切换 UI 文案；通过弹窗引导用户重启后生效（`LocalizationManager.setLanguageOverride` + `AppDelegate.showRestartAlert`）。

### 8.2 Copy & Arm 的“文本粘贴”依赖用户真实 ⌘V
- armed 触发点为用户下一次 ⌘V；服务实现允许该 ⌘V 事件正常透传，由系统完成文本粘贴。
- 图片粘贴由应用后续注入的 ⌘V 完成（通过剪贴板先写 image-only 再注入）。

### 8.3 标注能力存在 Pro gating
- shapes / numbering / colors 被 CapabilityService 标记为 Pro；在 Free 状态下会显示锁图标，并在尝试使用时打开 paywall。

### 8.4 保存路径访问依赖安全书签
- 写文件使用 security-scoped resource；若 bookmark 解析失败，会被视为“未配置目录”并重新引导选择目录（保存流程会弹出目录选择器）。

