# VibeCap — 本地图库与截图管理 PRD

> **Version**: 1.0  
> **Last Updated**: 2026-03-10  
> **Author**: User + AI  
> **Status**: Draft  
> **Type**: Feature Addition (existing product: VibeCap macOS menu bar app)

---

## 1. Product Overview

### 1.1 One-Liner

> VibeCap 本地图库 — 让用户将截图保存到指定本地目录，可在 App 内或 Finder 中浏览/打开历史截图，支持按时间自动清理，并可"保留"(Keep) 重要截图使其不受清理影响。

### 1.2 Background & Motivation

**Current Problems**:
- 大部分截图软件（尤其是 macOS 系统截图）随着时间推移会产生大量截图文件，堆积成用户的清理负担
- 用户往往需要花大量时间逐一 review 哪些截图要保留、哪些不需要，这是额外的时间负担
- 现有 VibeCap 保存功能是"存完就忘"模式，缺乏回看和管理入口

**Opportunity**:
- 提供定期自动清理功能，从根本上解决截图堆积问题
- 让用户主动标记需要长期保留的截图，将"被动清理"变为"主动选择"
- 在现有保存功能基础上扩展，打造完整的截图生命周期管理
- **市场空白**：目前没有任何主流 Mac 截图工具提供"本地自动定期清理 + 保留标记"的组合功能

### 1.3 Product Vision

> 让截图管理从负担变成零成本 — 用户只需关注值得保留的内容，其余由 VibeCap 自动处理。

### 1.4 Platforms

| Platform | Priority | Notes |
|----------|----------|-------|
| macOS | P0 | 现有平台，功能扩展 |

### 1.5 Multi-language Support

| Supported | Languages |
|-----------|-----------|
| Yes | 沿用现有 20 个语言（en, zh-Hans, zh-Hant, ja, ko, de, fr, es, it 等） |

### 1.6 Feature Relationship

- **类型**: 扩展现有保存功能（VibeCap 内的功能模块，非独立 App）
- 现有保存目录即为图库目录，所有已保存的截图自动出现在图库中
- 不引入新的独立目录，复用 `ScreenshotSaveService` 的 security-scoped bookmark 机制

---

## 2. Target Users

### 2.1 Primary Persona

**Persona A — 现有 VibeCap 用户**

| Attribute | Description |
|-----------|-------------|
| **Role** | 开发者、设计师 — 使用 VibeCap 截图并粘贴到 AI 工具/设计工具 |
| **Technical Level** | 中高级 |
| **Core Pain Point** | 频繁截图导致文件堆积，手动清理耗时耗力，难以快速找到之前保存的截图 |
| **Usage Scenario** | 日常工作中频繁截图，事后需要回顾和管理 |

**Persona B — 通用 macOS 截图用户**

| Attribute | Description |
|-----------|-------------|
| **Role** | 任何在 macOS 上频繁截图的用户（产品经理、运营、教师等） |
| **Technical Level** | 初中级 |
| **Core Pain Point** | 截图文件长期堆积在桌面或截图文件夹，手动逐张清理是一项负担 |
| **Usage Scenario** | 日常截图后不管不顾，直到文件夹臃肿才被迫花时间手动清理 |

### 2.2 User Stories

| ID | User Story | Priority | Source |
|----|------------|----------|--------|
| US-01 | 作为设计师，我希望保留我想要的截图并自动清理其余内容，使文件目录保持整洁清爽 | P0 | User |
| US-02 | 作为频繁截图的用户，我希望打开 VibeCap 就能浏览所有历史截图，而不用去 Finder 里翻找 | P0 | AI Suggested |
| US-03 | 作为用户，我希望对重要截图点"保留"，这样自动清理时不会误删我需要的内容 | P0 | AI Suggested |
| US-04 | 作为用户，我希望设定一个清理周期（比如 30 天），之后截图自动消失，不需要我手动干预 | P0 | AI Suggested |
| US-05 | 作为用户，我希望在 VibeCap 中点击一张截图就能放大查看细节 | P1 | AI Suggested |
| US-06 | 作为用户，我希望 VibeCap 首次使用时能清晰引导我设定截图保存目录 | P1 | AI Suggested |

---

## 3. Product Scope

### 3.1 Feature List

| Module | Feature Description | Priority | Notes |
|--------|---------------------|----------|-------|
| 图库入口 | 点击 Dock icon 直接打开图库主界面（Library Window） | P0 | 主入口 |
| 图库入口 | 菜单栏下拉菜单增加"图库"入口，点击打开独立浏览窗口 | P0 | 快捷入口 |
| Upgrade 入口 | 菜单栏下拉菜单增加"Upgrade"入口，点击打开付费升级窗口 | P1 | 付费转化入口 |
| 图库入口 | 截图完成后的预览弹窗中增加"查看图库"按钮 | P1 | 辅助入口 |
| 图库浏览 | 网格缩略图 + 列表视图，可切换 | P0 | 类似 macOS 照片 App 的双模式 |
| 图片查看 | 在 VibeCap 窗口中点击截图可放大查看 | P0 | |
| 图片查看 | 用户也可通过 Finder 直接在本地目录浏览截图 | P0 | 天然支持，无需额外开发 |
| 复制图片 | 用户选中图片后可执行“复制图片”到系统剪贴板 | P0 | 支持右键菜单与快捷键，便于粘贴到其他应用 |
| 手动删除 | 用户可在图库或大图页手动删除单张截图 | P0 | 删除动作需二次确认，文件移入系统废纸篓（可恢复） |
| 自动清理 | 用户可开启自动清理并设定清理周期，超期截图自动删除 | P0 | 含总开关（默认关闭）；首次开启后默认周期为 30d；固定档位：24h / 7d / 15d / 30d / 60d |
| 清理周期入口 | 自动清理周期支持双入口：全局设置 + 图库内明显入口 | P0 | 图库入口建议放在工具栏显著位置（如“清理周期”按钮） |
| 自动清理付费墙 | 非付费用户点击自动清理开关或周期设置时触发 Upgrade / Paywall | P0 | 仅付费用户可使用自动清理相关设置 |
| 保留 (Keep) | 用户可标记重要截图为"保留"，被保留的截图不受自动清理影响 | P0 | 图标：📌 Pin；语义："留着这个，别清理" |
| 图库筛选 | 图库支持"全部" / "已保留"筛选 Tab | P1 | 方便用户快速找到已保留截图 |
| 目录设定引导 | 首次使用时引导用户设定/确认截图保存目录 | P0 | 复用现有 security-scoped bookmark |

### 3.2 Out of Scope

- ❌ 云端同步/备份截图
- ❌ 截图搜索（文字识别/OCR）
- ❌ 截图分类/标签/文件夹组织
- ❌ 截图编辑（裁剪、标注 — 已有独立功能）
- ❌ 批量导出/分享
- ❌ 独立 App — 本功能是 VibeCap 内的功能模块
- ❌ 新的系统权限申请 — 复用已有权限

---

## 4. Product Characteristics

### 4.1 Data & Content

| Attribute | Value |
|-----------|-------|
| **Content Types** | 截图图片文件（PNG/JPEG），存储于用户指定的本地目录 |
| **Data Ownership** | 完全私有，纯本地存储 |
| **Data Sensitivity** | 个人内容（截图可能包含敏感信息），不上传不联网 |
| **自动清理计时起点** | 截图的创建时间（截图那一刻开始计时） |
| **自动清理通知** | 清理后汇报（如"已帮你清理 23 张过期截图，节省了 156MB 空间~"），此行为后续可能调整 |
| **自动清理默认状态** | 总开关默认关闭；用户首次开启后，自动将周期设为 30 天 |
| **自动清理权限策略** | 自动清理相关设置受付费墙保护，仅 Pro 用户可开启与修改 |
| **保留 (Keep) 机制** | 留在原目录，通过元数据/扩展属性标记，清理时跳过 |

### 4.2 Collaboration Model

| Attribute | Value |
|-----------|-------|
| **Model** | 个人工具（单用户），沿用主产品 |
| **Sharing Capability** | 无 |

### 4.3 Connectivity & Sync

| Attribute | Value |
|-----------|-------|
| **Offline Requirement** | 完全不需要联网，纯本地功能 |
| **Cross-device Sync** | 不需要 |
| **Time Sensitivity** | 非实时，用户按需访问 |

### 4.4 Usage Patterns

| Attribute | Value |
|-----------|-------|
| **Usage Frequency** | 沿用主产品（每日多次截图，图库浏览频率预计每日至每周） |
| **Session Duration** | 图库浏览预计 1-5 分钟（快速扫一眼或标记几张） |
| **User Acquisition** | 沿用主产品（ASO + 口碑） |
| **Migration Source** | 从手动清理截图的习惯迁移到自动管理 |

### 4.5 Notifications

| Channel | Enabled | Use Cases |
|---------|---------|-----------|
| Email | No | N/A |
| Push | No | N/A |
| In-app | Yes | 自动清理完成后的汇报通知 |

### 4.6 Business Model

| Attribute | Value |
|-----------|-------|
| **Model** | 部分免费（Freemium） |
| **Free Tier** | 图库浏览 + 图片查看 + 手动删除（基础体验免费） |
| **Pro Features** | 自动清理（总开关 + 周期设置）+ 保留 (Keep) 标记 + 自定义清理周期（建议，详见竞品分析） |
| **Pricing Strategy** | 融入现有 VibeCap Pro 订阅，不单独定价 |

---

## 5. Design Principles

[Reference: `.cursor/references/design-principle.md` — 待后续补充]

---

## 6. UX Guidelines

### 6.1 Tone & Voice

| Attribute | Value |
|-----------|-------|
| **Overall Tone** | 专业简洁 — "图库：已保存 42 张截图" |
| **自动清理提示** | 友好型 — "已帮你清理 23 张过期截图，节省了 156MB 空间~" |
| **Address User As** | 沿用 VibeCap 现有风格 |

### 6.2 Content Guidelines

- 功能界面（图库浏览、设置）采用专业简洁风格，信息密度优先
- 涉及删除/清理的提示采用友好语气，降低用户对"文件被删"的焦虑感
- 称呼方式与 VibeCap 主产品保持一致

### 6.3 "保留" (Keep) 功能 UX 规范

#### 术语定义

| 元素 | 中文 | English | 说明 |
|------|------|---------|------|
| **动作名称** | 保留 | Keep | 语义："留着这个，别清理" |
| **图标** | 📌 Pin 图钉 | 📌 Pin | "钉住不动"的隐喻，天然传达"不会被移走" |
| **已保留状态** | 已保留 | Kept | 图库中显示的状态标识 |
| **取消动作** | 取消保留 | Unkeep | 恢复为自动清理对象 |
| **筛选 Tab** | 全部 / 已保留 | All / Kept | 图库顶部筛选 |

#### 交互反馈文案

| 场景 | 文案 |
|------|------|
| 点击保留 | Toast: "已保留 — 不会被自动清理" |
| 取消保留 | Toast: "已取消保留 — 将在 [X天] 后被自动清理" |
| 首次使用引导 | "截图将在 30 天后自动清理。想长期保留的截图，点 📌 即可。" |
| 设置页说明 | "自动清理默认关闭。开启后默认周期为 30 天。超过 [X天] 的截图将自动清理；标记为「保留」的截图不受影响。" |

#### 设计理由

> 调研结论：在"自动清理"的产品语境下，"保留"(Keep) 比"收藏"(Favorite) 更自然。
> - "收藏"的心智模型是"我喜欢" — 不自带"防删"含义，需要额外解释
> - "保留"的心智模型是"留着别扔" — 天然传达"不会被清理"的含义，用户无需二次理解
> - 行业参考：Lightroom/Darkroom 的 Flag 系统（Keep/Reject）、Google Photos 的 Archive 概念

---

## 7. Competitive Reference

> 📌 Role: Senior Market Research Expert

**核心发现：目前没有任何主流 Mac 截图工具提供"本地自动定期清理 + 保留标记"的组合功能。这是一个明确的市场空白。**

### 7.1 Reference Products

#### Competitor 1: CleanShot X

| Data Point | Details |
|------------|---------|
| **Product & Link** | [CleanShot X](https://cleanshot.com/) |
| **Industry Ranking** | Mac 截图工具品类第一梯队 |
| **User Base** | Data not public（广泛被开发者/设计师社区推荐） |
| **Update Frequency** | 约月更 |
| **Company** | 独立团队 |
| **Pricing Model** | 一次性购买 + 可选年费续更新 |
| **Pricing Tiers** | Basic: $29 一次性（含 1 年更新 + 1GB 云存储）；Pro: $8/人/月（团队版，无限云存储） |
| **Paywall Trigger** | 免费试用后付费 |
| **What to Learn** | 50+ 功能覆盖全面；Quick Access Overlay 浮窗体验好；Cloud 分享链接设计 |
| **What to Avoid** | 功能过于臃肿；没有本地截图管理/清理功能；定价偏高 |

#### Competitor 2: Shottr

| Data Point | Details |
|------------|---------|
| **Product & Link** | [Shottr](https://shottr.cc/) |
| **Industry Ranking** | 轻量级截图工具中口碑最好 |
| **User Base** | Data not public |
| **Company** | 独立开发者 Max K |
| **Pricing Model** | Freemium（免费可用，偶尔提示升级） |
| **Pricing Tiers** | Free（无限使用，30 天后偶尔提示）；Basic: $12 一次性；Friends Club: $30 一次性 |
| **What to Learn** | 极致轻量（2MB），截图速度 17ms；保存到专用文件夹减少桌面杂乱 |
| **What to Avoid** | 没有截图管理/浏览/清理功能；功能相对基础 |

#### Competitor 3: Pickle

| Data Point | Details |
|------------|---------|
| **Product & Link** | [Pickle](https://pickleformac.app/) |
| **Industry Ranking** | 新兴产品，专注隐私截图管理 |
| **Company** | 独立开发者 |
| **Pricing Model** | 完全免费 |
| **What to Learn** | **最接近的竞品** — 菜单栏 App + 按日期自动分组（Today / Yesterday / 星期）；一键脱敏；分享链接 7 天自动过期 |
| **What to Avoid** | 没有本地自动清理功能；没有保留标记；无 OCR、无滚动截图 |

#### Competitor 4: Screenshot Deleter

| Data Point | Details |
|------------|---------|
| **Product & Link** | [Screenshot Deleter](https://screenshotdeleter.com/) |
| **Industry Ranking** | 小众工具 |
| **Pricing Model** | Free + IAP |
| **What to Learn** | **唯一专注"删除截图"的产品** — 验证了"截图堆积是真实痛点"；批量删除；存储空间可视化 |
| **What to Avoid** | 仅批量删除，无自动定期清理；无浏览/管理功能；体验粗糙 |

#### Competitor 5: Xnapper

| Data Point | Details |
|------------|---------|
| **Product & Link** | [Xnapper](https://xnapper.com/) |
| **Industry Ranking** | "美化截图"品类领先 |
| **Pricing Model** | 一次性购买 |
| **Pricing Tiers** | Basic: $29.99（1 设备）；Personal: $54.99（2 设备）；Standard: $79.99（3 设备） |
| **What to Learn** | 有"截图历史"功能，证明用户需要回看能力；自动脱敏（邮箱、IP、API key） |
| **What to Avoid** | 截图历史功能简陋，无管理/清理能力 |

#### 行业参考: Apple Photos & Google Photos

| Product | Mechanism | Notes |
|---------|-----------|-------|
| Apple Photos | "收藏"(Favorite) ♡ + 删除后进入"最近删除"保留 30 天 | 行业标准的收藏交互，但无自动清理 |
| Google Photos | 截图超过 30 天自动归档（隐藏但不删除） | 30 天是行业最普遍的默认周期 |

### 7.2 Differentiation

> VibeCap 本地图库的独特价值：**市场上首个将"截图捕获 → 浏览管理 → 自动清理 → 保留标记"串联为完整生命周期的 macOS 截图工具**。现有竞品要么只做截图（CleanShot X、Shottr），要么只做删除（Screenshot Deleter），没有产品将两端打通。

---

## 8. Success Metrics

> 📌 Role: Growth Analytics Specialist

### 8.1 North Star Metric

> **图库活跃使用率** — 每周至少打开一次图库的用户占比

**Industry Benchmark**: 工具类 App 核心功能周活跃率 30-50%（Source: Mixpanel 2024 Product Benchmarks）

### 8.2 Key Metrics

| Category | Metric | MVP Target | V1 Target | Industry Benchmark |
|----------|--------|------------|-----------|-------------------|
| Activation | 设定保存目录并完成首次截图保存的用户占比 | 60% | 80% | 工具类首次关键操作 50-70% |
| Engagement | 每周打开图库浏览的用户占比 | 20% | 40% | 工具类功能周使用率 30-50% |
| Retention | 启用自动清理并保持 30 天的用户占比 | 30% | 50% | 工具类设置功能留存 25-40% |
| Feature Adoption | 使用"保留" (Keep) 标记的用户占比 | 15% | 30% | Apple Photos Favorite 使用率约 20% |
| Revenue | 因图库功能转化为 Pro 的用户占比 | 3% | 8% | Freemium 工具类转化率 2-5% |

---

## 9. Technical Constraints & Preferences

> 📌 Role: Solutions Architect

### 9.1 Tech Preferences

| Category | Preference | Reason |
|----------|------------|--------|
| UI 框架 | AppKit（沿用现有） | 与主产品保持一致，图库窗口可用 NSCollectionView |
| 保留标记存储 | macOS 扩展属性（xattr）或本地 SQLite/JSON | xattr 方案文件跟着走、Finder 可见；SQLite 方案查询快但与文件解耦 |
| 自动清理调度 | `Timer` + App 启动时检查 | 菜单栏 App 常驻，无需 Background Task；每次启动/定时检查过期文件 |
| 缩略图缓存 | `NSCache` + 磁盘缓存 | 避免每次打开图库都重新生成缩略图 |

### 9.2 Hard Constraints

- 沿用现有 security-scoped bookmark 机制访问用户目录（已实现）
- 沙盒环境下无法主动访问用户未授权的目录
- 删除文件需要用户已授权目录的写权限（security-scoped bookmark 已覆盖）
- 不需要 Full Disk Access — security-scoped bookmark 足够

### 9.3 Permission Summary

| 权限 | 是否需要 | 说明 |
|------|---------|------|
| 屏幕录制 | 已有 | 截图功能已申请 |
| 辅助功能 | 已有 | Auto-paste 已申请 |
| 文件访问 | 已有 | security-scoped bookmark 已实现，用户通过 NSOpenPanel 授权保存目录，涵盖读/写/删除 |
| Full Disk Access | **不需要** | bookmark 机制已足够 |
| 新增权限 | **无** | 本功能不需要任何新的系统权限授权 |

> **技术确认**：security-scoped bookmark 授权的是目录的完整读写权限，包括删除目录内的文件。操作时需调用 `startAccessingSecurityScopedResource()` / `stopAccessingSecurityScopedResource()` 对，这在现有 `ScreenshotSaveService` 中已有实现。自动清理功能复用相同机制即可，无需额外授权。

### 9.4 Third-Party Services

| Service Type | Candidates | Notes |
|--------------|------------|-------|
| 无 | N/A | 纯本地功能，不依赖任何第三方服务 |

---

## 10. Risks & Assumptions

> 📌 Role: Product Strategy Consultant

### 10.1 Core Assumptions

| Assumption | Validation Method |
|------------|-------------------|
| 用户会在截图时就启用保存到本地（而非仅复制到剪贴板） | 追踪保存 vs 仅复制的比例 |
| 用户愿意花时间标记"保留"而非任由自动清理 | 追踪保留功能使用率 |
| 自动清理不会让用户焦虑（怕误删） | 用户反馈 + 清理后通知的点击率 |
| 固定档位的清理周期能满足大部分用户 | 追踪各档位选择分布 |

### 10.2 Risk Identification

| Risk | Impact | Mitigation |
|------|--------|------------|
| 用户误删重要截图 | 高 — 信任危机 | 删除前移入系统废纸篓（可恢复）；清理后通知提供"撤销"入口 |
| 用户不理解"保留"的作用 | 中 — 导致重要文件被清理 | 首次使用 Onboarding 说明；保留时 Toast 提示"已保留 — 不会被自动清理" |
| 大量截图导致图库加载慢 | 中 — 体验差 | 渐进式加载 + 缩略图缓存 + 虚拟列表 |
| 用户保存目录被移动/删除/改名 | 中 — 图库空白 | security-scoped bookmark stale 检测 + 引导用户重新选择目录 |

---

## 11. Milestones

> 📌 Role: Technical Project Manager

| Milestone | Deliverable | Estimated Effort |
|-----------|-------------|-----------------|
| M1: 基础图库 | 图库窗口 + 网格/列表视图 + 图片查看（放大） | 1 周 |
| M2: 自动清理 | 清理周期设置 + 定时清理引擎 + 清理后通知 | 1 周 |
| M3: 保留 (Keep) 与手动删除 | 保留/取消保留 + 手动删除（移入废纸篓）+ 清理时跳过已保留 + 图库筛选"已保留" | 0.5 周 |
| M4: 入口集成 | Dock 主入口 + 菜单栏入口 + 截图预览弹窗入口 | 0.5 周 |
| M5: 付费墙集成 | 确定免费/Pro 分层 + Paywall 触发点 | 0.5 周 |
| M6: 本地化 | 20 语言翻译 + UI 适配 | 0.5 周 |
| M7: 测试与打磨 | 全功能测试 + 边界情况处理 + 性能优化 | 1 周 |

**总估时**: ~5 周

---

## 12. Glossary

| Term | Definition |
|------|------------|
| 图库 (Library) | VibeCap 内的截图浏览管理界面 |
| 保留 (Keep) | 用户标记截图为长期保留，使其不受自动清理影响 |
| 手动删除 (Manual Delete) | 用户主动删除单张截图，删除后文件移入系统废纸篓，可恢复 |
| 自动清理 (Auto Cleanup) | 根据用户设定的时间周期，自动删除过期且未被保留的截图 |
| Security-scoped bookmark | macOS 沙盒机制，允许 App 持久访问用户授权的目录 |

---

## 13. Open Items & Notes

### 13.1 User's Additional Notes

> 无额外补充。

### 13.2 Pending Decisions

| Item | Options | Decision | Date |
|------|---------|----------|------|
| 自动清理频率交互方式 | 固定档位 / 自定义输入 / 滑块 | ✅ 固定档位（24h / 7d / 15d / 30d / 60d），默认 30d | 2026-03-10 |
| 长期保留标记叫法 | 收藏 / 保留 / 标记 / 其他 | ✅ 保留 (Keep)，📌 Pin 图标 | 2026-03-10 |
| 付费分层细节 | 浏览免费 / 清理+保留 Pro | ✅ 确认：自动清理相关设置仅 Pro 可用（付费墙） | 2026-03-10 |
| 自动清理通知行为 | 清理后汇报 / 清理前提醒 / 静默 | 暂定清理后汇报，后续可能调整 | 2026-03-10 |
| 新增系统权限 | 需要 / 不需要 | ✅ 不需要任何新权限 | 2026-03-10 |

---

## AI Implementation Notes

### Core Intent

本功能的核心意图是将截图生命周期从"用户全程手动管理"转变为"系统自动清理 + 用户只标记例外"。设计上应让"不做任何操作"就是最省事的默认路径 — 截图自动过期、自动清理，用户只需在看到想留下的截图时点一下"保留"。

### User Mental Model

用户的心智模型应该是：
1. **截图会自动消失** — 这是默认行为，不需要任何操作
2. **想留下的就钉住** — 点 📌 = "这个别扔"
3. **图库是收件箱** — 定期看一眼，钉住想留的，其余不管

类比：邮件的"归档"机制 — 不处理的邮件自动过期，重要的标记保留。

### Edge Case Handling

| Scenario | Behavior |
|----------|----------|
| 保存目录不存在/已被移动 | 图库显示空状态 + 引导用户重新选择目录 |
| 保存目录为空 | 图库显示空状态 + 提示"截图后保存的文件将出现在这里" |
| 大量截图（1000+） | 渐进式加载 + 缩略图缓存 + 虚拟列表避免内存溢出 |
| 清理时 App 未运行 | 下次启动时执行补偿清理 |
| 用户在 Finder 中手动删除了截图 | 图库刷新时自动移除已不存在的条目 |
| 用户在 Finder 中手动添加了图片 | 图库刷新时自动发现新文件（需为截图格式） |
| 清理后用户后悔 | 文件移入系统废纸篓，可在 Finder 中恢复 |

### Tone & Copy Style

| Attribute | Value |
|-----------|-------|
| Tone | 功能界面专业简洁，清理相关提示友好亲切 |
| Error Style | 友好型："找不到截图目录了，请重新选择一个~" |
| Address User | 沿用 VibeCap 现有风格 |
| Button Labels | 动作导向："复制图片" / "保留" / "取消保留" / "删除" / "查看图库" / "设置清理周期" / "Upgrade" |

### Prohibited Actions

- ❌ 永远不在没有用户设定清理周期的情况下自动删除文件
- ❌ 永远不永久删除文件 — 自动清理必须移入系统废纸篓
- ❌ 永远不删除已标记为"保留"的文件
- ❌ 永远不在未获得 security-scoped bookmark 授权的目录中操作
- ❌ 永远不联网传输截图数据
- ❌ 永远不使用 alert() 弹窗打断用户

---

## Appendix: AI Roles

| Module | Role | Expertise |
|--------|------|-----------|
| 7. Competitive Reference | Senior Market Research Expert | 10+ years in market analysis, proficient in App Store analytics, competitive intelligence tools (Sensor Tower, App Annie), industry trend analysis |
| 8. Success Metrics | Growth Analytics Specialist | Expert in product metrics design, familiar with AARRR framework, benchmarking against industry standards |
| 9. Technical Constraints | Solutions Architect | 15+ years in system design, expertise in macOS sandboxing, security-scoped resource management |
| 10. Risks & Assumptions | Product Strategy Consultant | Strategic planning expert, skilled in risk assessment, market validation |
| 11. Milestones | Technical Project Manager | Experienced in agile delivery, sprint planning, realistic timeline estimation |
