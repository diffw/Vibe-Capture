# IAP 功能清单 & 付费卡点规格（长期维护版）

> **适用范围**：Mac App Store（StoreKit 2）  
> **目标**：作为“单一事实源（SSOT）”，同时满足：  
> - **长期维护**：新增功能/卡点时可按规则补齐，避免口口相传  
> - **指导开发**：明确 Capability Key、触发点、UI 行为、数据落点、测试清单  
>
> **状态定义**：  
> - **Free**：未拥有任何 Pro 权益  
> - **Pro**：拥有任一 Pro 权益（订阅（月/年）或买断）  
>
> **版本维护**：每次新增功能或调整卡点，必须更新文档底部 **Change Log**。

---

## 1. 商业模型（已定）

### 1.1 SKU（商品组合）
- **订阅**：月付 + 年付（同一订阅组）
- **买断**：Lifetime（非消耗型）
- **Paywall 推荐**：不默认推荐（Monthly/Yearly/Lifetime 同权展示）

### 1.2 权益等价与优先级（已定）
- **权益等价**：订阅 Pro 与买断 Pro 解锁同一套能力（无差异）
- **优先级**：**买断优先**（只要存在买断交易，即永久 Pro，不受订阅到期影响）

---

## 2. App 标识与 Product IDs（用于 App Store Connect + 代码）

### 2.1 Bundle Identifier（从工程文件读取）
- **Build Settings 最终生效（SSOT）**：`com.nanwang.vibecap`

> 说明：`Info.plist` 里可能存在不同的 `CFBundleIdentifier` 字面量，但 App Store / 签名 / 最终包体通常以 `PRODUCT_BUNDLE_IDENTIFIER` 为准。

### 2.2 Product IDs（业界通用命名规范）
> 规则：`<bundleId>.pro.<period>`

- **Monthly**：`com.nanwang.vibecap.pro.monthly`
- **Yearly**：`com.nanwang.vibecap.pro.yearly.v1`
- **Lifetime**：`com.nanwang.vibecap.pro.lifetime`

---

## 3. 权益刷新与状态机（指导实现）

### 3.1 刷新时机（最佳实践 + 你已确认）
- **App 启动**：刷新一次 entitlements
- **回到前台**：刷新一次 entitlements
- **购买/恢复/续费变更**：监听 `Transaction.updates`，收到更新立即刷新并更新 UI

### 3.2 离线策略（你已确认）
- **乐观离线**：刷新失败时 **沿用上次已知状态**（不强制回 Free）

### 3.3 Pro 判定（实现规则）
当满足任一条件，即为 **Pro**：
- 存在有效的 **Auto-Renewable Subscription**（月/年）交易（当前 entitlements 中仍有效）
- 或存在 **Non-Consumable Lifetime** 交易

买断优先显示/生效：
- 如果同时存在订阅与买断：**以买断为 Pro 的长期来源**（订阅状态不影响可用性）

---

## 4. 数据模型与持久化（卡点强依赖）

> 说明：这里定义“应存在的逻辑数据”，用于指导后续在 `SettingsStore`/持久化层落地。  
> **降级不丢数据（隐藏）** 与 **Free 专属 1 个自定义 App** 的规则都依赖这里。

### 4.1 自定义 App 列表拆分（SSOT）
- **Pro 自定义列表**：`proUserWhitelistApps[]`
  - 用户在 Pro 状态下添加的自定义 App（可增删）
  - 降级到 Free：**隐藏/禁用，不删除**
- **Free 专属自定义 App**：`freePinnedCustomApp`
  - Free 状态允许新增 **1 个**（只允许从 `/Applications` 选择 `.app`）
  - Free 状态：**不可移除/不可替换**
  - 升级回 Pro：**自动合并进 Pro 列表（去重）**，并变为可管理

### 4.2 “名额不消耗”规则（已定）
- 若用户选择的 `.app` 的 `bundleId` 已属于 **系统内置白名单**：提示“无需占用名额”，并 **不写入** `freePinnedCustomApp`。

### 4.3 降级/升级触发的数据规则（必须严格一致）
- **Pro → Free（订阅到期且无买断）**
  - `proUserWhitelistApps`：保留不变，但 **在 Free UI 隐藏/禁用**
  - `freePinnedCustomApp`：允许写入（若为空）
- **Free → Pro（购买/恢复/订阅有效）**
  - `proUserWhitelistApps`：恢复可见/可用
  - `freePinnedCustomApp`：若存在则 **合并**到 `proUserWhitelistApps`（去重），并允许用户管理（增删）

---

## 5. Capability Keys（用于开发 & 文档长期维护）

> 原则：功能是否可用不直接写“if Pro”，而是以 capability 判定；  
> 这样未来新增功能/卡点只需要加 capability 并在表格里映射即可。

### 5.1 基础约定
- **Key 命名**：`cap.<domain>.<feature>`
- **默认策略**：文档未明确标注的能力，默认为 **TBD**（必须做决策）

### 5.2 当前能力列表（已实现功能 + 已定卡点）

| Capability Key | 功能描述 | Free | Pro | 触发点（UI/行为） |
|---|---|---:|---:|---|
| `cap.capture.area` | 区域截图（Overlay 框选） | ✅ | ✅ | 全局快捷键 / 菜单栏 Capture |
| `cap.capture.save` | 保存 PNG（手动保存） | ✅ | ✅ | Modal `Save Image` / ⌘S |
| `cap.capture.autosave` | 发送后自动保存 | ✅ | ✅ | `ScreenshotSaveService.saveIfEnabled` |
| `cap.send.systemWhitelist` | Send 到系统内置白名单应用（含浏览器） | ✅ | ✅ | Modal 主按钮 `Send to …` |
| `cap.send.customApp.freePinnedOne` | Free：新增 1 个自定义 App（从 /Applications 选） | ✅ | ✅ | Settings/Modal “Add to Send List…” |
| `cap.send.customApp.manage` | 自定义 App 可移除/可添加多个 | ❌ | ✅ | Settings Added Apps 的移除/多次添加 |
| `cap.annotations.arrow` | 标注：箭头（默认颜色，允许编辑/删除/清空） | ✅ | ✅ | Modal 标注工具栏 |
| `cap.annotations.shapes` | 标注：圆/矩形 | ❌ | ✅ | 工具栏按钮（带锁/Pro 标签，点击弹 paywall） |
| `cap.annotations.numbering` | 标注：数字序号/编号箭头 | ❌ | ✅ | 工具栏按钮（带锁/Pro 标签，点击弹 paywall） |
| `cap.annotations.colors` | 标注：更换颜色（含箭头颜色） | ❌ | ✅ | 工具栏颜色按钮（点击弹 paywall） |

> 注意：`cap.send.customApp.freePinnedOne` 在 Pro 也为 ✅，因为 Pro 同样允许新增（且无限制时由 `cap.send.customApp.manage` 覆盖管理能力）。

---

## 6. 功能清单（层级结构，长期维护用）

> 规则：新增功能必须挂到此树，并在第 5 章表格新增 capability（或明确复用已有 capability）。

### 6.1 入口与基础
- 菜单栏应用形态
- 菜单栏菜单：Capture / Settings / Quit
- 全局快捷键：启动截图（默认 ⌘⇧C，可配置）

### 6.2 截图采集
- 权限：Screen Recording
- Overlay 框选（多显示器）
- 最小选区阈值
- 图像生成（Retina 处理）

### 6.3 预览与编辑（Modal）
- 预览窗口（置顶、可拖动、居中）
- Prompt 文本输入（可选）
- 快捷键：ESC/⌘↩︎/⌘S
- 标注
  - Free：箭头（默认色，不可换色；可移动/删除/清空）
  - Pro：圆/矩形/数字序号/编号箭头/换颜色

### 6.4 发送到目标应用（AutoPaste）
- 目标应用识别：默认使用“截图前前台应用”
- 下拉选择：运行中的支持应用
- 系统内置白名单（含浏览器）
- 自定义 App（Send List）
  - Free：仅允许新增 1 个自定义 App（确认后锁死；升级 Pro 后可管理）
  - Pro：可添加/移除任意数量

### 6.5 保存与预览面板
- 保存 PNG（手动/自动）
- 目录权限（security-scoped bookmark）
- 保存后预览面板（倒计时、Show in Finder、拖拽）

### 6.6 设置
- 快捷键设置（冲突提示/回滚）
- 自动保存开关 + 选择目录
- Launch at Login
- Send List 管理（与 IAP 强耦合）

### 6.7 未来功能（占位，必须决策 Free/Pro）
- **TBD**：下载图片管理
- **TBD**：发送队列管理

---

## 7. 付费卡点清单（“在哪卡”与“怎么卡”）

### 7.1 卡点原则（已定）
- **触发即弹 Paywall**：点击被锁功能时弹出 Paywall
- **按钮可见 + 锁/Pro 标识**（你已选 A）：避免用户认为是 bug

### 7.2 标注卡点（Modal → AnnotationToolbar）
- 被锁功能：
  - 圆 / 矩形 / 数字序号（工具按钮）
  - 颜色选择（颜色按钮）
- Free 行为：
  - 按钮可见、带锁/Pro 标识
  - 点击 → 弹 Paywall
  - 取消购买 → 留在当前 Modal，不改变现有箭头标注能力

### 7.3 自定义 App 管理卡点（Settings / Modal “Add to Send List…”）
- Free 行为：
  - 允许新增 1 个自定义 App（仅 `/Applications` 选择）
  - 新增前弹确认（见 i18n keys）
  - 添加后在 Free 下不可移除
  - 若所选 app 属于系统白名单：不消耗名额，并给出提示
  - 若 Free 已有 `freePinnedCustomApp`：再次尝试添加 → 弹 Paywall（或提示需 Pro）
- Pro 行为：
  - 可无限添加/移除
  - 从 Free 升级到 Pro：自动合并 `freePinnedCustomApp` → `proUserWhitelistApps`

---

## 8. Paywall/Settings 入口（审核友好 + 降工单）

> 你已确认：Settings + 菜单栏 + 触发锁功能都要有入口。

### 8.1 必备入口清单
- **Settings**
  - Upgrade to Pro（购买）
  - Restore Purchases
  - Manage Subscription（跳系统订阅管理页）
  - 当前状态展示（Free/Pro、来源、刷新时间）
- **菜单栏菜单**
  - Upgrade…
- **功能触发点**
  - 点击锁功能 → 弹 Paywall

---

## 9. i18n（20 语言）规范（SSOT）

> 你已确认：首发覆盖 20 语言；规格只维护 **英文文案 + key**，翻译从 `feature/language` 分支接入。

### 9.1 Key 命名规范
- `paywall.*`：付费墙
- `iap.*`：购买/恢复/错误提示
- `gating.*`：功能被锁时的提示/确认弹窗

### 9.2 必须覆盖的 key（第一期）
- `paywall.title`
- `paywall.subtitle`
- `paywall.option.monthly`
- `paywall.option.yearly`
- `paywall.option.lifetime`
- `paywall.cta.purchase`
- `paywall.cta.restore`
- `paywall.cta.manageSubscription`
- `paywall.error.generic`
- `settings.proStatus.free`
- `settings.proStatus.pro`
- `settings.proStatus.lastRefreshed`

#### Free 添加 1 个自定义 App 的确认弹窗
- `gating.customApp.confirm.title` = "Add Custom App (Free Limit)"
- `gating.customApp.confirm.message` = "Free users can add only one custom app. You won't be able to remove it on Free. Add this app now?"
- `gating.customApp.confirm.primary` = "Add"
- `gating.customApp.confirm.secondary` = "Cancel"

#### 不占名额提示
- `gating.customApp.notCounted.title` = "No Slot Needed"
- `gating.customApp.notCounted.message` = "This app is already supported. It won't use your Free custom-app slot."

---

## 10. 测试矩阵（必须通过，避免上架后翻车）

### 10.1 购买与恢复
- Monthly：购买成功 → 立即 Pro → 解锁全部 Pro 能力
- Yearly：同上
- Lifetime：购买成功 → 永久 Pro
- Restore：未购买/已购买/网络失败/未登录 App Store

### 10.2 权益叠加与优先级
- 先订阅后买断：买断优先，订阅到期后仍 Pro
- 先买断后订阅：仍 Pro（可显示订阅存在但不影响）
- 月↔年切换：系统行为符合预期（不崩、不丢 Pro）

### 10.3 Free 卡点
- Free 点击圆/矩形/数字/颜色 → 弹 Paywall
- Free 添加自定义 App：
  - 从 `/Applications` 选一个非白名单 app → 弹确认 → 添加成功 → Free 下不可移除
  - 再次尝试添加第二个 → 弹 Paywall
  - 选中系统白名单 app → 不消耗名额 → 给提示

### 10.4 降级/升级数据规则
- Pro 添加多个自定义 app → 订阅到期 → 降级 Free → 列表隐藏
- Free 新增 1 个 pinned → 购买 Pro → 自动恢复 Pro 列表 + 合并 pinned（去重）

---

## 11. 维护规范（长期维护的“怎么改”）

### 11.1 新增功能时必须做的 3 件事
1) 在 **第 6 章功能树**增加节点  
2) 在 **第 5 章能力表**新增 capability 或复用现有 capability，并明确 Free/Pro  
3) 在 **第 7 章卡点清单**补充“触发点/降级行为/i18n key/测试点”

### 11.2 新增卡点或调整策略时必须做的 2 件事
1) 更新第 5/7 章对应条目（避免实现与文档不一致）  
2) 追加 Change Log

---

## Change Log

### 2026-01-22
- 初始化版本：定义 Free/Pro、SKU（Monthly/Yearly/Lifetime）、标注与自定义 App 卡点、降级/合并规则、i18n key 与测试矩阵。

---

## 12. 代码落点映射（开发实施指南）

> 本章用于把“capability/卡点”落到你当前代码结构中，避免实现时找不到入口。

### 12.1 发送目标（Send List / 自定义 App）

#### 12.1.1 相关文件（现状）
- `VibeCapture/Settings/SettingsStore.swift`
  - 当前只有 `userWhitelistApps`（单一列表）
- `VibeCapture/UI/SettingsViewController.swift`
  - Settings 页 “Added Apps” 列表展示/移除按钮
- `VibeCapture/UI/AddAppPanelController.swift`
  - Add to Send List 面板：既支持“运行中应用一键添加”，也支持 “Choose from Applications…”
- `VibeCapture/UI/CaptureModalViewController.swift`
  - 下拉菜单包含 “Add to Send List...”，会弹出 `AddAppPanelController`
- `VibeCapture/Services/AppDetectionService.swift`
  - `getRunningWhitelistedApps()` / `isWhitelisted()` / `userWhitelistApps` 参与白名单判断

#### 12.1.2 需要实现的目标行为（按本规格）
- **Free**
  - 允许从 **`/Applications` 选择 `.app`** 新增 **1 个**自定义 App（确认后锁死）
  - Settings/Modal 两处入口都允许添加，但都必须遵循同一规则
  - Free 下 **不可移除** `freePinnedCustomApp`
  - 若所选 app 已在系统白名单：提示且 **不占名额**（不写入 pinned）
- **Pro**
  - `proUserWhitelistApps` 可无限增删
  - 恢复 Pro 时：自动恢复 Pro 列表，并将 `freePinnedCustomApp` 合并进 Pro 列表（去重）

#### 12.1.3 与现状代码的关键差异（必须改动点）
- `AddAppPanelController` 当前的“运行中应用点击即添加”与本规格 **不一致**：
  - 本规格要求：**Free 的自定义名额只允许从 `/Applications` 选择 `.app` 产生**；
  - 因此实现时需决定：
    - 要么移除“运行中应用点击即添加”的入口；
    - 要么保留列表但点击时走权限判断（Free 触发 paywall 或引导使用 “Choose from Applications…”）。

### 12.2 标注工具（Annotation）

#### 12.2.1 相关文件（现状）
- `VibeCapture/UI/CaptureModalViewController.swift`
  - 创建并持有 `AnnotationToolbarView` 与 `AnnotationCanvasView`
- `VibeCapture/UI/AnnotationToolbarView.swift`
  - 工具按钮：arrow/circle/rectangle/number
  - 颜色按钮：`colorButton`
- `VibeCapture/UI/AnnotationCanvasView.swift`
  - 实际绘制与交互（拖拽/删除/清空/编号重排）

#### 12.2.2 需要实现的目标行为（按本规格）
- **Free**
  - 仅允许 `Arrow Tool`
  - 颜色：固定默认色（不可更换）
  - 允许移动/删除/清空
- **Pro**
  - 解锁 Circle/Rectangle/Number/Color

#### 12.2.3 卡点触发点（必须弹 Paywall）
- 点击 `circleButton` / `rectangleButton` / `numberButton`（Free）→ 弹 Paywall
- 点击 `colorButton`（Free）→ 弹 Paywall

> UI 规则（你已选）：按钮可见，带锁/Pro 标识；点击触发 Paywall。

### 12.3 Paywall 入口与权益刷新

#### 12.3.1 入口清单（已定）
- Settings：Upgrade / Restore / Manage Subscription / 状态展示
- 菜单栏：Upgrade…
- 锁功能点击：弹 Paywall

#### 12.3.2 刷新落点建议（实现参考）
- App 启动：`AppDelegate.applicationDidFinishLaunching`
- 回到前台：监听 `NSApplication.didBecomeActiveNotification`
- 交易更新：StoreKit 2 `Transaction.updates`

---

## 13. 迁移策略（从当前 `userWhitelistApps` 过渡到 Pro/Free 拆分）

> 背景：当前工程中只有 `SettingsStore.userWhitelistApps`，既用于发送目标，也用于白名单判断。  
> IAP 引入后需要拆分为：
> - `proUserWhitelistApps[]`
> - `freePinnedCustomApp`

### 13.1 一次性迁移（首次引入 IAP 版本时）
建议规则（避免老用户升级后“丢 Send List”）：
- 若检测到旧字段 `userWhitelistApps` 非空，且新字段为空：
  - 将旧 `userWhitelistApps` 迁移到 `proUserWhitelistApps`
  - 清空或停止使用旧字段（但建议保留一段兼容读取期，见 13.2）

### 13.2 兼容读取期（建议至少 1-2 个版本）
- 读取 `proUserWhitelistApps` 为空时，可回退读取旧 `userWhitelistApps`（只读）
- 所有写入都写新字段，不再写旧字段

### 13.3 与 Pro/Free 状态结合的显示规则
- Free 下 Send List UI：
  - 只展示系统白名单 + `freePinnedCustomApp`（如有）
  - `proUserWhitelistApps` 不展示（隐藏）
- Pro 下 Send List UI：
  - 展示 `proUserWhitelistApps`（含合并后的 pinned）


