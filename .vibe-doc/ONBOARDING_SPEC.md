# VibeCap Onboarding 01–05 — Product & UX Spec (v0)

> 基于 2026-01-31 对齐结果整理。目标：60 秒内完成首张截图；优先级：权限同意率 > 试用启动 > 付费转化。  
> 语气：专业工具。所有文案需支持多语言（Localizable.strings）。

---

## 0. 关键决策（已拍板）

- **流程顺序**：01 价值主张 → 02 屏幕录制权限 → 03 辅助功能权限 → 04 Preferences → 05 试用/付费
- **首要目标**：完成首张截图（<= 60s）
- **02/03**：
  - 都提供 **Skip**（避免用户点“拒绝”）
  - 点击 **Allow access**：打开对应系统设置的“最终授权页面”（用户只需勾开关）
  - 页面展示 **权限状态**；检测到已授权后 **自动进入下一步**
  - 02/03 页面提供 **Restart VibeCap** 按钮（用户点击触发一键重启）
- **后续提醒**：
  - 若用户未开 Screen Recording，之后每次触发截图（快捷键/菜单）都弹 **同款 onboarding 大 Modal** 引导去开权限
  - 若用户未开 Accessibility，不阻断截图；在 Copy Image / Copy Prompt 等相关动作上做引导（后续设计细化）
  - 引导弹窗中已有 Cancel（= 稍后再说）；无需额外 Skip
- **04**：即使 02/03 Skip，也仍展示 04；按钮文案为 Continue，并增加“可稍后在 Settings 修改”的提示
- **05**：先强展示（不提供明确 Not now），但用户理论上可忽略/关闭 onboarding 窗口后仍能从菜单栏/快捷键开始截图
- **onboarding 窗口红点关闭语义**：视为 onboarding 结束（以后不主动弹，仅在触发功能时再引导）
- **状态刷新策略**：从系统设置返回后自动刷新（轮询/监听），无需“我已开启”按钮
- **默认快捷键**：先用 `⌘⇧C`；若注册失败（冲突），按 F=b：提示并引导去 04 修改（不自动更换）
- **Preferences 默认保存路径**：`~/Desktop/VibeCap`；在第一次保存图片时自动创建
- **权限中心**：放在 Settings，仅包含 Screen Recording + Accessibility（Login Items 维持现状位置）

---

## 1. 术语与状态机（核心）

### 1.1 OnboardingStep

建议枚举：

- `welcome` (01)
- `screenRecording` (02)
- `accessibility` (03)
- `preferences` (04)
- `paywall` (05)
- `done`

### 1.2 持久化字段（必须）

用于恢复流程、实现 Restart：

- `onboarding.step`：当前 step（字符串/整型）
- `onboarding.completed`：是否完成（Bool）
- `onboarding.dismissedAt`：用户关闭时间（可选，用于调试/将来策略）

> 规则：用户点击红点关闭 onboarding → `completed = true`（不再主动弹完整 onboarding）。

### 1.3 自动推进（Auto-advance）

- 02/03 页面进入时立即检测权限状态；
- 若已授权：展示 Granted ✓（可短暂 200–400ms 作为确认动画），然后自动跳下一步。
- 从系统设置返回后：自动刷新权限状态，满足即自动跳下一步。

---

## 2. 屏幕规范（01–05）

> 说明：文案内容可后续迭代，但信息结构与 CTA 行为按此实现。

### 2.1 01 — Welcome

- **目的**：建立心智模型（Capture → Prompt → Copy & Paste），降低接下来权限请求的心理阻力
- **组件**：
  - 品牌/标题/副标题
  - 小动效/示例图（你已要求补充，非交互 demo）
  - 主 CTA：Get Started
- **行为**：
  - 点击 Get Started → 进入 02

### 2.2 02 — Enable Screen Recording（可 Skip）

- **目的**：拿到硬门槛权限，支持完成首张截图
- **组件**：
  - 标题 + 简短说明（需专业、明确、非恐吓）
  - 系统设置截图示意
  - **权限状态行**：Not granted / Granted ✓（实时）
  - 主 CTA：Allow access（打开系统设置 Screen Recording 页面）
  - 次 CTA：Skip
  - 辅助 CTA：Restart VibeCap
- **行为**：
  - Allow access：
    - 打开 `x-apple.systempreferences:...Privacy_ScreenCapture`
    - 前置 System Settings；本窗口让路（必要时降级窗口 level，避免挡住系统设置）
    - 启动自动检测循环（例如每 500ms–1s 检测一次，最多 60s；或应用激活时检测）
  - 检测到 Granted ✓：自动进入 03
  - Skip：直接进入 03（并记录“用户跳过”状态，供后续每次截图弹窗）
  - Restart VibeCap：执行“一键重启”并在重启后回到此步（或已授权则自动进 03）

### 2.3 03 — Enable Accessibility（可 Skip）

- **目的**：提升核心体验（Copy image & prompt 的自动粘贴链路），但非硬门槛
- **组件**：
  - 标题 + 价值说明（更快粘贴、更少步骤、一次复制得到图片+prompt）
  - 透明说明（降低隐私顾虑）：明确“仅用于在你触发粘贴时模拟 ⌘V / 完成自动粘贴”，并避免不一致表述（不写“detect active windows”）
  - **权限状态行**：Not granted / Granted ✓（实时）
  - 主 CTA：Allow access（打开系统设置 Accessibility 页面）
  - 次 CTA：Skip
  - 辅助 CTA：Restart VibeCap
- **行为**：
  - Allow access：打开 `x-apple.systempreferences:...Privacy_Accessibility`，前置系统设置，自动检测
  - Granted ✓：自动进入 04
  - Skip：进入 04
  - Restart VibeCap：同 02

### 2.4 04 — Preferences（总可 Continue）

- **目的**：降低后续摩擦（保存路径、快捷键），并向用户强调“以快捷键为主”
- **组件**：
  - Save location：默认 `~/Desktop/VibeCap` + Browse…
  - Global shortcut：默认 `⌘⇧C`（可改）
  - 提示文案：可稍后在 Settings 修改
  - CTA：Continue（主）、Skip（可选：你说“可以全部跳过”；实现上可提供 Skip 或仅 Continue）
- **行为**：
  - Continue → 进入 05
  - 快捷键注册失败（冲突）：
    - 弹提示（不自动改），引导用户在此步调整（符合 F=b）

### 2.5 05 — Start Free / Paywall（先强展示）

- **目的**：试用启动（优先级 #2），并为后续转化铺垫
- **组件**：
  - 价值与权益（目前占位，后续替换）
  - 主 CTA：Start Your Free Trial
  - Restore（更显眼）
  - 关闭方式：窗口红点（隐式退出）
- **行为**：
  - CTA 成功 → onboarding 结束（`completed = true`）
  - 用户关闭窗口（红点）→ onboarding 结束（`completed = true`），但仍可使用截图功能（快捷键/菜单）
  - 未来可加 Not now（当前不实现）

---

## 3. 功能触发时的权限引导（After onboarding）

### 3.1 Screen Recording 未授权（强提醒：每次触发都弹大 Modal）

- 触发点：用户按快捷键或菜单点击开始截图
- 行为：
  - 弹 onboarding 同款大 Modal（02 的内容/结构复用）
  - 主按钮：Open System Settings（到 Screen Recording）
  - 次按钮：Cancel（= 稍后再说）
  - 显示权限状态；若用户回来后已授权，自动关闭并允许继续截图（建议：用户需要重新触发截图；或你也可以自动继续开始截图——后续可评估）

### 3.2 Accessibility 未授权（不阻断）

- 触发点（建议）：
  - 用户在截图 modal 中输入了 prompt 后点击 Copy / 按 ⌘C（想复制“图+prompt”）
  - 或点击 Copy Prompt / Copy Image 等扩展动作（你已提到）
- 行为：
  - 展示轻量引导（可复用 03 的大 Modal 或采用 modal 内 banner；此处后续出视觉方案）
  - 主按钮：Open System Settings（Accessibility）
  - Cancel：继续当前降级流程（仍可 copy image 或 copy prompt）

---

## 4. Restart VibeCap（产品与技术约束）

### 4.1 交互原则（业界做法）

- **不做静默自动重启**（避免“像崩溃”）
- 仅在用户点击 **Restart VibeCap** 后执行一键重启

### 4.2 行为定义

点击 Restart：

1. 立即持久化当前 `onboarding.step`
2. 触发 relaunch（启动一个新的 VibeCap 实例）
3. 当前进程退出
4. 新实例启动后：
   - 读取 step
   - 检测权限状态
   - 回到“最后完成的步骤位置”，并按 auto-advance 规则前进

---

## 5. Settings 内“权限中心”信息架构

位置：Settings → Permissions（或同级分组）

### 5.1 条目

- Screen Recording
  - 状态：Granted / Not granted
  - 操作：Open System Settings（Screen Recording）
  - 辅助说明：用于截图（必需）
- Accessibility
  - 状态：Granted / Not granted
  - 操作：Open System Settings（Accessibility）
  - 辅助说明：用于 Copy image & prompt 的自动粘贴（增强）

> Login Items 仍在现有位置，不放入权限中心（已拍板）。

---

## 6. 默认快捷键 `⌘⇧C` 的策略（v0）

### 6.1 结论

- v0 暂定 `⌘⇧C`（已拍板）
- 由于可能存在系统/第三方占用，必须实现：
  - 注册失败提示（错误弹窗/提示条）
  - 引导用户在 04 调整（不自动改，符合 F=b）

### 6.2 推荐的提示内容（结构）

- 标题：Shortcut unavailable
- 正文：`⌘⇧C` 已被其他应用占用。请在 Preferences 中更换快捷键。
- 按钮：OK（保留在 04 页面）

---

## 7. 多语言与文案键（建议）

> 仅给出 key 结构，英文/中文内容后续填充。

- `onboarding.01.title` / `onboarding.01.subtitle` / `onboarding.01.cta`
- `onboarding.02.title` / `onboarding.02.body` / `onboarding.02.status.granted` / `onboarding.02.status.notGranted` / `onboarding.02.cta.allow` / `onboarding.02.cta.skip` / `onboarding.02.cta.restart`
- `onboarding.03.*`（同上）
- `onboarding.04.title` / `onboarding.04.hint` / `onboarding.04.cta.continue` / `onboarding.04.cta.skip`
- `onboarding.05.title` / `onboarding.05.cta.trial` / `onboarding.05.restore`
- `permissions.center.title` / `permissions.center.screenRecording.*` / `permissions.center.accessibility.*`
- `error.shortcut_conflict`（你现有错误可复用/扩展）

