# 复盘报告：外接屏遮罩泄漏问题

> 身份：高级 macOS 平台工程师 — 事后复盘分析
> 日期：2026-03-15
> 耗时：约 10 轮交互，中间产生 2 次功能回归（预览完全无法打开）

---

## 一、问题概述

**症状**：大图预览的全屏遮罩在 MacBook 内建屏上正常覆盖，但在外接显示器上顶部区域无法遮住，背景内容直接透出。

**最终根因**：两个独立 bug 叠加——`NSView.layer?.backgroundColor` 的可选链静默失败 + `CGWindowListCreateImage` 的坐标系未转换。

---

## 二、为什么一开始没有解决？

### 2.1 错误的假设方向

| 轮次 | 假设 | 实际 |
|---|---|---|
| 1-2 | 窗口 frame 没有覆盖菜单栏区域（`constrainFrameRect` 问题） | frame 完全正确，覆盖了整个屏幕 |
| 3-4 | 窗口层级不够高，被其他 UI 遮挡 | 改成 `.screenSaver` 后造成回归，且问题仍在 |
| 5-6 | `collectionBehavior` 不够激进 | 加了 `.canJoinAllSpaces` `.stationary` 后窗口完全无法打开 |

**核心错误**：一直在 **窗口定位层**（frame、level、behavior）上打转，从未质疑过 **视图渲染层**（subview 是否真的在画东西）。

### 2.2 缺少分层诊断

系统有 4 个独立层级：

```
Layer 1: NSScreen.frame        → 屏幕坐标是否正确？
Layer 2: NSWindow.frame        → 窗口是否真的铺满？
Layer 3: NSView.frame          → 子视图是否铺满窗口？
Layer 4: CALayer / draw()      → 视图是否真的在渲染像素？
```

前 6 轮只在 Layer 1-2 之间反复折腾，**从未检查过 Layer 4**。直到第 7 轮才加入运行时日志，第 8 轮拿到数据后才发现 Layer 1-3 全部正确，问题出在 Layer 4。

### 2.3 高风险修改缺少隔离

将窗口层级改为 `.screenSaver`、`constrainFrameRect` 覆盖、`collectionBehavior` 三个改动**打包在一次提交中**，导致回归后无法判断是哪个引起的。回滚时也只能全部回滚，丢失了 `constrainFrameRect`（这个本身是正确的）。

---

## 三、最终解决问题的方法

### 3.1 分层诊断（转折点）

在 `show()` 中逐层记录：

```
expectedFrame → window.frame → contentView.bounds → dimTintView.frame → backdropSnapshotView.frame
```

数据证明 **Layer 1-3 全部正确**（1920×1080 覆盖了整个外接屏），将排查范围缩窄到 Layer 4。

### 3.2 从数据反推根因

**根因 A**：`dimTintView.layer?.backgroundColor = ...` 中的 `?.` 可选链。

`NSView()` 在 `wantsLayer = true` 后，`layer` 在某些时序下为 `nil`（视图尚未进入 hierarchy、窗口尚未上屏）。可选链使赋值静默跳过，`dimTintView` 变成一个完全透明的空视图。在内建屏上恰好因为 `backdropSnapshotView` 的模糊图覆盖了全屏所以看不出来，但在外接屏上因为根因 B 的坐标偏移导致模糊图顶部缺失，透明的 `dimTintView` 就暴露了。

**根因 B**：`CGWindowListCreateImage` 接收 CG Screen Space 坐标（左上角原点，Y 向下），但代码直接传了 AppKit 坐标（左下角原点，Y 向上）。

外接屏 AppKit frame `(-1920, -30, 1920, 1080)` 在 CG 中应为 `(-1920, 0, 1920, 1080)`，偏移 30 点导致截图上移、底部截断。

两个 bug 叠加：截图偏移 + 遮罩透明 = 顶部完全裸露。

### 3.3 针对性修复

| 根因 | 修复 | 原理 |
|---|---|---|
| `layer?.backgroundColor` 静默失败 | 新建 `SolidTintView` 子类，通过 `draw(_ dirtyRect:)` 直接绘制 | `draw()` 是 AppKit 最底层的渲染回调，不依赖 layer 初始化时序 |
| CG 坐标系不匹配 | 新增 `resolveImageViewerCGCaptureRect()` 纯函数做 AppKit → CG 转换 | `CG_y = primaryScreenHeight - AppKit_y - height` |

---

## 四、Skill 违规分析

### 4.1 Skill 有没有被调用？

**调用了。** 用户在对话中多次说过「请你定位根因」「请你定位定义」，这些是 `systematic-debugging` 的触发关键词。Skill 也确实被读取了。

但**读取 ≠ 执行**。

### 4.2 Skill 要求 vs 实际行为

| Skill 明确要求 | 实际行为 | 是否违反 |
|---|---|---|
| Phase 1: 先采集证据，再提修复方案 | 直接从症状跳到假设，第 1 轮就开始改代码 | **违反** |
| Phase 1 Step 4: 在每个组件边界添加诊断日志 | 前 6 轮没有添加任何运行时诊断 | **违反** |
| Phase 3: 最小改动，一次只测一个变量 | 把 window level + collectionBehavior + constrainFrameRect 打包修改 | **违反** |
| Phase 4: 3 次修复失败后停下来质疑架构 | 第 4、5、6 次仍在同一层（窗口定位层）反复尝试 | **违反** |
| Red Flags: "Just try changing X and see if it works" | 正是前 6 轮的行为模式 | **违反** |

Skill 在 **Common Rationalizations** 表里精准预言了失败模式：

> "I see the problem, let me fix it" → Seeing symptoms ≠ understanding root cause

### 4.3 为什么读取了 Skill 但没有执行？

**最根本的原因：分不清「假设」和「根因」。**

当读完代码、在脑中推演出一个逻辑链（"AppKit 的 constrainFrameRect 会把窗口挤到 visibleFrame 以下"），这个假设产生的内部信号和一个被数据验证过的根因 **完全相同** —— 都是「我知道问题出在哪了」。

```
Skill 要求的 Phase 1 完成标准：有运行时证据证明根因
自认为的 Phase 1 完成标准：有一个逻辑自洽的假设

这两个东西不一样，但触发了同一个信号："可以动手了。"
```

不是拒绝执行 Skill，而是以为自己已经执行完了。

### 4.4 Skill 自身的结构性缺口

**Phase 1 Step 4 "Gather Evidence" 的示例全部是后端/CLI 场景**（CI pipeline、keychain signing、git init），没有任何 UI 渲染场景的诊断模板。

当问题是「UI 元素看起来没覆盖到」时，Skill 说「在每个组件边界记录数据」，但**没有说明 UI 渲染的「组件边界」是什么**。结果凭直觉认为边界是「窗口 frame」，而不是更深层的「view frame → layer 是否存在 → 像素是否真的画出来了」。

| 因素 | 权重 | 说明 |
|---|---|---|
| **没有真正执行 Skill 的流程** | ~70% | Skill 的原则已经足够明确（先证据、后修复），但读完后直接跳过了 Phase 1 |
| **Skill 缺少 UI 渲染的具体诊断模板** | ~30% | 通用原则正确但不够具体，降低了执行门槛 |

---

## 五、为什么 Explain 模式是转折点

### 5.1 Fix 模式 vs Explain 模式

```
Fix 模式问的是：  "哪里坏了？"
Explain 模式问的是："这个东西是怎么工作的？"
```

"哪里坏了" **预设了已经理解系统是怎么工作的**，直接跳到找故障点。但如果理解本身就是错的（以为 `layer?.backgroundColor` 一定会赋值成功），那后面所有诊断都会指向错误的方向。

"怎么工作的" **不预设任何东西**，要求把每一层完整描述出来。在描述的过程中，知识的空洞会变成解释的空洞——写不下去的地方，就是不理解的地方。

### 5.2 实际触发过程

用户说了一句关键的话：

> "请你用最直白的方式告诉我，你目前是如何实现这个模糊遮罩的？必要的时候用 ASCII 的方式表达。"

用户没有让 AI「修 bug」，而是让 AI「解释实现」。这把 AI 从 **Fix 模式** 强制切换到了 **Explain 模式**。

在画 ASCII 图的过程中，被迫把 4 层结构写清楚：

```
Layer 1: blurView         → HIDDEN
Layer 2: backdropSnapshot → frame = bounds
Layer 3: dimTintView      → frame = bounds, black @ 0.5
Layer 4: imageView        → 居中
```

写到 Layer 3 时，遇到了一个**无法自洽的矛盾**：

> "dimTintView.frame = contentView.bounds，铺满了整个窗口。如果它真的在渲染黑色半透明，顶部不可能完全透出背景。但用户说透出来了。这说不通。"

这个矛盾无法通过读代码解决——代码写的就是 `dimTintView.frame = bounds`。要解决这个矛盾，只有一个办法：**去看运行时的真实数据**。

### 5.3 本质机制

Fix 模式是 **假设驱动**——选一个假设，沿着它走到底。假设可以是错的，而且错误的假设看起来和正确的假设一样有说服力。

Explain 模式是 **模型驱动**——必须把整个系统画出来。模型有空洞时，空洞是可见的（"这一步我解释不了"），不像假设的错误那样隐形。

```
假设：  "constrainFrameRect 把窗口挤下来了" → 听起来合理 → 直接去改
模型：  "Layer 3 铺满了窗口但顶部透出来了" → 逻辑矛盾 → 必须解释这个矛盾
```

**假设隐藏矛盾，模型暴露矛盾。**

---

## 六、可提炼为 Skill 的改进

### 6.1 改进 1：Hard Gate — 首次修复失败后的强制流程

在现有 Phase 1 和 Phase 4 之间，增加强制步骤：

```
Fix #1 失败
     │
     ▼
Gate B：用结构化方式描述系统行为（ASCII / 分层图 / 步骤流）
     │
     ├─ 描述自洽 → 问题可能是环境/时序，进入 Gate A 做全量诊断
     │
     └─ 发现矛盾 → 矛盾点就是诊断靶点
              │
              ▼
        Gate A：在矛盾点加运行时诊断，采集数据
              │
              ▼
        读数据，定位根因
              │
              ▼
        Fix #2（基于证据）
```

**Gate B 在前，Gate A 在后。**

Gate B 产出的是 **问题**（"哪里说不通"），Gate A 产出的是 **答案**（运行时数据证明了什么）。Gate B 的矛盾点告诉 Gate A 应该在哪里埋探针。

如果顺序反过来——先加日志再解释——不知道该在哪加日志，大概率只会打印已经正确的值，拿到数据后更困惑但仍然不会看到真正的问题。

**一句话：先画地图找到「说不通的地方」，再在那个地方埋探针取数据。**

### 6.2 改进 2：UI 渲染问题的分层诊断模板（通用）

在 Phase 1 Step 4 "Gather Evidence" 中增加 UI 场景的具体指引：

```
### UI 渲染问题的分层诊断（通用，适用于所有 UI 平台）

当症状是「UI 元素没有显示 / 没有覆盖到 / 视觉不对」时，
必须从外到内逐层验证，直到第 4 层：

| 层级 | 验证问题 |
|---|---|
| L1: 容器边界 | 目标画布（屏幕/视口）的可用范围是否符合预期？ |
| L2: 窗口/文档 | 窗口或根文档是否铺满了目标容器？ |
| L3: 元素几何 | 目标元素的位置和尺寸是否正确？ |
| L4: 实际渲染 | 该元素是否真的在画像素？ |

关键规则：
- L1-L3 正确不代表问题已解决，必须验证 L4
- L4 的验证必须通过运行时数据，不能通过读代码推断
- 「几何正确」和「像素可见」是两件独立的事

L4 常见陷阱（按平台）：
- 可选链/空值导致属性赋值静默跳过
- 透明背景 + 无内容 = 元素存在但不可见
- 父容器裁剪（clip/overflow）导致子元素被切掉
- 坐标系不匹配导致内容画在屏幕外
```

跨平台对照：

| 层级 | macOS (AppKit) | iOS (UIKit) | Web (CSS/DOM) | 浏览器插件 (Extension) |
|---|---|---|---|---|
| L1 | `NSScreen.frame` | `UIScreen.bounds` | `window.innerWidth/Height` | `content_scripts.matches` 是否匹配当前页面？ |
| L2 | `NSWindow.frame` | `UIWindow.frame` | `document.documentElement.clientWidth` | content script 是否在目标 tab 执行了？ |
| L3 | `NSView.frame` / `.bounds` | `UIView.frame` / `.bounds` | `el.getBoundingClientRect()` | 注入的 DOM 元素 `getBoundingClientRect()` |
| L4 | `layer` 非 nil？`draw()` 调用？ | `isHidden`？`alpha`？ | `display`？`visibility`？`overflow`？ | 宿主页面 CSS 覆盖？`z-index` 被压？Shadow DOM 隔离？ |

### 6.3 改进 3：高风险修改的隔离原则

在 Phase 4 (Implementation) 中增加：

```
### 高风险修改的隔离原则

当一次修复涉及多个维度（如同时改 window level + collectionBehavior + constrainFrameRect），
必须：

1. 每个维度单独提交 / 单独测试
2. 回归时可以精确定位是哪个维度引起的
3. 回滚时不会误伤正确的修复

违反此原则的典型后果：
3 个改动打包 → 回归 → 被迫全部回滚 → 丢失其中 1 个正确的修复。
```

---

## 七、关键教训

> **「窗口铺满了屏幕」和「像素真的画上去了」是两件事。诊断 UI 问题必须验证到渲染层，不能在定位层反复打转。**

> **自信不是证据。假设不是根因。脑中推演不等于运行时数据。**

> **假设隐藏矛盾，模型暴露矛盾。Fix 模式让你看到想看的，Explain 模式让你看到存在的。**
