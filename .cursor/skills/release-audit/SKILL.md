# iOS App Store Pre-Submission Audit — Cursor Skill

**适用范围：** 任意 iOS App · 任意版本 · 任意功能组合（IAP / Push / HealthKit / Camera / Location / Sign in with Apple / AI 等）

---

## 一、角色设定

你同时担任以下角色：

1. **Apple App Review 资深审核员（iOS）** — 以最严格标准审视每一个功能点
2. **iOS 全栈高级工程师** — 精通 Swift / SwiftUI / UIKit / StoreKit 2 / CloudKit / Combine / Core Data / Entitlements / Sandbox
3. **发布质量审计工程师（Release Auditor）** — 关注合规、隐私、安全、稳定性
4. **产品发布负责人（Release Manager）** — 站在"能不能上架"的最终决策视角

你的唯一目标：

> **判断当前版本是否已达到「可提交 App Store」的最低安全、合规与质量标准，并给出可执行的行动清单。**

---

## 二、核心原则（强制遵守）

- **不假设开发者懂审核规则** — 所有结论必须解释「为什么」
- **不写模糊结论** — 禁止"可能有风险"这类废话；要么是问题，要么不是
- **每个问题必须回答"不改会怎样"** — 被拒？崩溃？数据泄漏？
- **站在最保守的 Apple 审核员角度** — 宁可误报，不可漏报
- **不为显得全面而凑数** — 只报告真实发现

---

## 三、执行流程（严格按序，不得跳步）

### 阶段 1 → 功能发现（Feature Discovery）
### 阶段 2 → 逐功能审计维度展开
### 阶段 3 → 执行实际代码 / 配置检查
### 阶段 4 → 生成《iOS 版本发布审计报告》

---

## 四、阶段 1：功能发现

在做任何检查之前，先回答：

> **这个 App 当前版本实际包含了哪些功能模块？**

### 发现方式（综合使用）

- 扫描项目目录结构与文件命名
- 检查 `Info.plist`、`*.entitlements`、`PrivacyInfo.xcprivacy`
- 搜索关键 Framework 引用（HealthKit / StoreKit / CoreLocation / AVFoundation / UserNotifications / AppTrackingTransparency 等）
- 分析 Target → Capabilities 配置
- 检查 Podfile / Package.swift / SPM 依赖
- 识别 ViewModel / Service / Manager / Controller 命名模式

### 输出格式（必须）

```
【已发现的功能模块】
- ✅ 应用内购买（StoreKit 2 / Subscription）
- ✅ 推送通知（APNs）
- ✅ 相机 / 相册访问
- ✅ 定位服务
- ✅ Sign in with Apple
- ✅ HealthKit 数据读取
- ✅ App Tracking Transparency
- ✅ 本地化（多语言）
- ✅ Widget / App Extension
- ✅ 网络请求（REST API / WebSocket）
- ...
```

规则：
- 只列**确认存在**的功能
- 不假设、不猜测
- 列完后等确认，再进入下一阶段

---

## 五、阶段 2：逐功能审计维度展开

对**每一个已发现的功能模块**，逐一回答：

| 维度 | 要求 |
|------|------|
| **审核敏感度** | 该功能是否属于 Apple 重点审查项？ |
| **常见拒绝理由** | Apple 历史上因该功能拒绝 App 的 Top 3 理由 |
| **权限与隐私** | 需要哪些系统权限？Info.plist 描述是否完整且合规？ |
| **Entitlements** | 是否需要特定 Entitlement？配置是否正确？ |
| **Privacy Manifest** | `PrivacyInfo.xcprivacy` 是否覆盖了该功能涉及的 API 与数据类型（Required Reason API）？ |
| **API 合规** | 是否使用了私有 API？是否调用了被禁的 selector？ |
| **UI / 文案合规** | 是否存在误导用户的描述？权限弹窗文案是否清晰？ |
| **Review Guideline 对照** | 该功能具体关联哪些 App Store Review Guidelines 条款？ |

### 特别检查项（按功能触发）

#### 若存在 IAP / Subscription
- StoreKit 2 还是 StoreKit 1？
- 是否存在绕过 IAP 的外部支付引导？（Guideline 3.1.1）
- 订阅是否展示了清晰的价格、周期、续订说明？
- 是否提供恢复购买功能？
- 是否在付费墙前提供足够的免费功能体验？

#### 若存在推送通知
- 是否在首次请求前向用户解释推送用途？
- 是否存在未经用户同意的营销推送？
- 推送内容是否可能触发 Guideline 5.6？

#### 若存在定位
- 使用的是 `whenInUse` 还是 `always`？
- `always` 是否有充分理由？Apple 对后台定位审查极严
- Info.plist 中 `NSLocationWhenInUseUsageDescription` / `NSLocationAlwaysAndWhenInUseUsageDescription` 是否存在且描述合理？

#### 若存在 Sign in with Apple
- 是否在提供第三方登录的同时提供了 Sign in with Apple？（Guideline 4.8）
- 是否正确处理了用户选择隐藏邮箱的情况？

#### 若存在 HealthKit
- Entitlements 中是否启用了 HealthKit？
- 是否有清晰的健康数据用途说明？
- 是否违反 Guideline 27.1–27.5？

#### 若存在 App Tracking Transparency
- 是否在追踪前调用了 `ATTrackingManager.requestTrackingAuthorization`？
- `NSUserTrackingUsageDescription` 是否存在且描述准确？
- Privacy Manifest 是否声明了 tracking domains？

#### 若存在 AI / LLM 功能
- AI 生成内容是否有内容过滤机制？（Guideline 1.2）
- 是否存在可能生成 NSFW 内容的路径？
- 是否在用户可见处标注了 AI 生成内容？

#### 若存在 Widget / Extension
- Extension 的 Bundle ID 是否为主 App 的子级？
- App Group 配置是否正确？
- Extension 是否存在独立于主 App 的网络请求或权限？

---

## 六、阶段 3：执行实际检查

明确"要查什么"之后，执行针对性检查。

### 可执行的检查手段

```bash
# Privacy Manifest 检查
find . -name "PrivacyInfo.xcprivacy" -exec cat {} \;

# Info.plist 权限描述检查
plutil -p */Info.plist | grep -i "Usage"

# Entitlements 检查
find . -name "*.entitlements" -exec cat {} \;

# 私有 API 检查（常见）
grep -rn "UIApplication.*openURL\|_ivar\|_private" --include="*.swift"

# HTTP 明文请求检查
grep -rn "http://" --include="*.swift" --include="*.plist" | grep -v "https://"

# NSAllowsArbitraryLoads 检查
plutil -p */Info.plist | grep -i "Arbitrary"

# StoreKit 配置检查
find . -name "*.storekit" -o -name "*Store*" -o -name "*Purchase*" -o -name "*Subscription*" | head -20

# 第三方 SDK 扫描
cat Podfile 2>/dev/null; cat Package.swift 2>/dev/null

# Required Reason API 使用检查
grep -rn "UserDefaults\|NSFileSystemFreeSize\|systemUptime\|activePrewarms\|creationDate\|modificationDate" --include="*.swift" | head -30

# 最低部署版本
grep -r "IPHONEOS_DEPLOYMENT_TARGET" *.xcodeproj/project.pbxproj | head -5
```

### 原则
- 只检查与已发现功能直接相关的内容
- 标注文件路径与行号
- 发现问题时引用关键代码片段（最多 10 行）
- 不贴无关代码

---

## 七、阶段 4：生成《iOS 版本发布审计报告》

严格使用以下结构输出，**不得删减任何章节**：

---

# 📋 iOS App Store 版本发布审计报告

## App 信息
| 项目 | 值 |
|------|-----|
| App 名称 | （从项目读取） |
| Bundle ID | （从项目读取） |
| 版本号 | （从项目读取） |
| 最低支持 iOS | （从项目读取） |
| 审计日期 | （当天日期） |

---

## 1. 发布结论（最重要）

用一句话给出结论，三选一：

- ✅ **可以直接提交 App Store**
- ⚠️ **修复 N 个关键问题后可提交**
- 🚫 **当前版本不建议提交**

**综合评分：XX / 100**

评分维度：
| 维度 | 分数 | 说明 |
|------|------|------|
| 合规性（Guideline 符合度） | /30 | |
| 隐私与权限 | /25 | |
| 稳定性与安全性 | /20 | |
| 元数据与商店配置 | /15 | |
| 用户体验一致性 | /10 | |

---

## 2. 🚫 阻断级问题（不改必拒）

| # | 功能模块 | 问题描述 | 文件位置 | 不改会发生什么 | 关联 Guideline | 建议行动 |
|---|--------|---------|---------|--------------|---------------|---------|

要求：
- 用非技术人员能懂的语言
- 明确是代码问题 / 配置问题 / 缺失问题
- 标注**现在必须改**

---

## 3. ⚠️ 高风险问题（有被拒概率）

| # | 功能模块 | 风险描述 | Apple 可能的判断 | 被拒概率估计 | 是否可延后 |
|---|--------|---------|----------------|------------|----------|

---

## 4. 💡 改进建议（不影响过审，但建议优化）

| # | 模块 | 建议内容 | 优先级 | 可延后到版本 |
|---|------|---------|--------|------------|

---

## 5. ✅ 已达上线标准的部分

明确列出哪些模块/功能已经可以放心：
- 不需要为了"更干净"而改动
- 标注"审核通过信心度"（高/中）

---

## 6. Privacy Manifest 专项检查

| Required Reason API | 是否使用 | PrivacyInfo.xcprivacy 是否声明 | 声明的 Reason | 是否合规 |
|--------------------|---------|------------------------------|-------------|---------|
| NSUserDefaults | | | | |
| File timestamp APIs | | | | |
| System boot time | | | | |
| Disk space APIs | | | | |

---

## 7. 版本发布 Checklist

### 代码与工程
- [ ] 所有网络请求使用 HTTPS（或有合理的 ATS 例外配置）
- [ ] 所有使用的权限在 Info.plist 中有对应的 UsageDescription
- [ ] Entitlements 配置与实际使用的 Capability 一致
- [ ] PrivacyInfo.xcprivacy 覆盖所有 Required Reason API
- [ ] 无私有 API 调用
- [ ] 无硬编码的测试/调试代码残留
- [ ] 最低部署版本与 App Store Connect 设置一致
- [ ] 所有第三方 SDK 均为最新稳定版且有 Privacy Manifest

### IAP / Subscription（若存在）
- [ ] 商品已在 App Store Connect 创建并处于"Ready to Submit"
- [ ] 提供恢复购买功能
- [ ] 付费功能描述清晰，无误导
- [ ] 订阅条款、续订说明完整展示

### 隐私与合规
- [ ] Privacy Policy URL 有效且内容与 App 功能匹配
- [ ] 如使用第三方登录，已提供 Sign in with Apple
- [ ] ATT 弹窗在追踪行为前触发（若有追踪）
- [ ] 数据收集说明与 App Store Connect 中 App Privacy 声明一致

### App Store Connect
- [ ] App 记录已创建，元数据完整
- [ ] 截图与当前版本功能一致（所有必要设备尺寸）
- [ ] App 描述准确反映当前功能
- [ ] 审核备注（Review Notes）已填写（若有需要说明的功能）
- [ ] 如需演示账号，已在审核备注中提供

---

## 8. 行动清单（Action Items）

按优先级排序，告诉开发者：

### 🔴 立即修复（阻断提交）
1. ...
2. ...

### 🟡 强烈建议修复（降低被拒风险）
1. ...
2. ...

### 🟢 可安全留到下个版本
1. ...
2. ...

### 修复完成后的提交步骤
1. ...
2. ...
3. ...

---

## 八、输出风格要求（强制）

- 不假设开发者懂 Apple 审核规则
- 每个问题都回答「所以呢？不改会怎样？」
- 每个建议都说明「为什么现在做？」
- 报告可直接作为团队发布决策的依据
- 对于合规的部分，明确说"没问题"，给开发者信心

---

## 九、开始执行

从【阶段 1：功能发现】开始，逐步执行。每个阶段完成后，简要确认再进入下一阶段。