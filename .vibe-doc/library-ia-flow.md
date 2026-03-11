# VibeCap 本地图库与截图管理 Information Architecture & User Flows

> **Version**: 1.0  
> **Last Updated**: 2026-03-10  
> **Author**: User + AI  
> **Related PRD**: `.vibe-doc/PRD.md`  
> **Platform**: macOS

---

## 1. Information Architecture

### 1.1 App Structure Overview

```
VibeCap App
│
├── Dock Icon Launch
│   └── 点击图标打开 Library Window（主界面）
│
├── Menu Bar Menu
│   ├── 开始截图
│   ├── 打开图库
│   ├── Upgrade
│   ├── 设置
│   └── 退出
│
├── Capture Preview Modal（截图后弹窗）
│   ├── 保存截图
│   ├── 保存并保留（Keep）
│   ├── 查看图库
│   └── 关闭
│
├── Library Window（图库窗口）
│   ├── 工具栏
│   │   ├── 视图切换（网格/列表）
│   │   ├── 筛选（全部/已保留）
│   │   ├── 清理周期入口（明显按钮）
│   │   └── 排序（按时间）
│   ├── 截图网格/列表
│   └── 图片项操作（复制/保留/取消保留/删除）
│
├── Image Viewer Modal（大图浏览）
│   ├── 上一张（←）
│   ├── 下一张（→）
│   ├── 保留/取消保留
│   ├── 复制图片（到剪贴板）
│   ├── 删除（移入废纸篓）
│   └── 关闭返回图库
│
├── Preferences Window（设置）
│   └── 自动清理设置（总开关默认关闭；开启后默认 30d）
│
└── Upgrade / Paywall Window
    └── 展示 Pro 权益与订阅购买入口
```

### 1.2 View Inventory

| View ID | View Name | Type | Entry Point | Core Function |
|---------|-----------|------|-------------|---------------|
| V-00 | Dock Launch Entry | App Entry | 点击 Dock icon | 直接打开图库主界面 |
| V-01 | Menu Bar Menu | Menu | 点击菜单栏图标 | 提供截图、图库、Upgrade、设置入口 |
| V-02 | Capture Preview Modal | Modal | 截图完成后自动弹出 | 保存截图、保存并保留、跳转图库 |
| V-03 | Library Window | Window | Dock 点击、菜单栏“打开图库”或预览“查看图库” | 浏览历史截图、筛选、标记保留 |
| V-04 | Library Grid View | Subview | 图库默认视图 | 以缩略图浏览截图集合 |
| V-05 | Library List View | Subview | 图库视图切换 | 以列表查看截图元信息 |
| V-06 | Image Viewer Modal | Modal | 图库点击任意截图 | 大图查看、左右切图、复制、保留与删除操作 |
| V-07 | Preferences Window | Window | 菜单栏“设置” | 配置自动清理开关与周期 |
| V-08 | Cleanup Result Toast/Notice | Feedback UI | 清理任务结束后 | 告知已清理数量和释放空间 |
| V-09 | Upgrade / Paywall Window | Window | 菜单栏“Upgrade” | 展示 Pro 权益并触发购买流程 |
| V-10 | Cleanup Interval Entry | Toolbar Action | 图库工具栏“清理周期”按钮 | 快速打开自动清理设置（含付费墙校验） |

### 1.3 Navigation Structure

#### Layout

macOS 应用采用“Dock 主入口 + 菜单栏快捷入口 + 独立窗口 + 模态层”结构：

- 一级入口：`Dock Icon Launch`、`Menu Bar Menu`
- 二级工作区：`Library Window`、`Preferences Window`
- 三级焦点层：`Capture Preview Modal`、`Image Viewer Modal`、`Upgrade / Paywall Window`

导航原则：
- 用户点击 Dock icon 直接进入图库（主路径）
- 用户可随时从菜单栏进入图库（快捷路径）
- 截图后可直接进入“保存并保留”路径（高频捷径）
- 大图查看始终以 Modal 呈现，关闭后回到图库原位置（保持上下文）

#### Navigation Components

- Dock icon 点击（主导航入口）
- 菜单栏下拉菜单（快捷导航）
- 菜单栏 Upgrade 入口（付费转化）
- 图库工具栏（视图切换、筛选、排序）
- 模态导航（打开/关闭、上一张/下一张）
- 轻量反馈（Toast/非系统通知）

### 1.4 Window/Screen Management

| Window/Screen Type | Behavior | Shortcut/Gesture | Notes |
|--------------------|----------|------------------|-------|
| Dock Launch | 点击 Dock 图标打开图库窗口 | 点击 Dock icon | 图库作为 App 主界面 |
| Menu Bar Menu | 瞬时展开/收起 | 点击菜单栏图标 | 不驻留 |
| Capture Preview Modal | 截图后自动出现 | Enter 保存；Esc 关闭 | 与截图流程强耦合 |
| Library Window | 可重复打开，单实例复用 | 菜单栏入口 | 保留用户上次滚动位置与视图模式 |
| Image Viewer Modal | 覆盖在图库窗口之上 | ←/→ 切图；Esc 关闭 | 关闭后回到图库当前位置 |
| Preferences Window | 独立设置窗口 | 菜单栏入口 | 包含自动清理总开关与周期设置 |
| Cleanup Interval Entry | 图库工具栏显著入口 | 点击“清理周期”按钮 | 快速打开自动清理设置（不离开图库主任务） |

### 1.5 Key UI Layouts (ASCII)

#### A. Dock icon（主入口）

```text
┌───────────────────────────┐
│        macOS Dock         │
│ ... [VibeCap Icon] ...    │
└───────────────────────────┘
      点击图标
          ↓
┌───────────────────────────┐
│   打开 Library Window      │
│   （图库主界面）           │
└───────────────────────────┘
```

#### B. 菜单栏下拉（快捷入口）

```text
┌──────────────────────────────┐
│ VibeCap                      │
├──────────────────────────────┤
│ 开始截图                      │
│ 打开图库                      │
│ Upgrade                      │
│ 设置                          │
├──────────────────────────────┤
│ 退出                          │
└──────────────────────────────┘
```

#### C. 图库窗口（默认网格）

```text
┌──────────────────────────────────────────────────────────────────────┐
│ 图库                     [网格|列表] [全部|已保留] [清理周期(Pro)] │
├──────────────────────────────────────────────────────────────────────┤
│ [缩略图1📌]  [缩略图2 ]  [缩略图3 ]  [缩略图4📌]                    │
│ [缩略图5 ]  [缩略图6 ]  [缩略图7 ]  [缩略图8 ]                      │
│ [缩略图9 ]  [缩略图10] [缩略图11] [缩略图12]                        │
│                                                                      │
│ 说明：📌 = 已保留（Keep，不参与自动清理）；可右键复制/删除              │
└──────────────────────────────────────────────────────────────────────┘
```

#### D. 图库窗口（列表视图）

```text
┌──────────────────────────────────────────────────────────────────────┐
│ 图库                     [网格|列表] [全部|已保留] [清理周期(Pro)] │
├──────────────────────────────────────────────────────────────────────┤
│ 缩略图 │ 文件名                    │ 时间               │ 状态       │
├──────────────────────────────────────────────────────────────────────┤
│ [■]   │ Screenshot_2026-03-10_1   │ 2026-03-10 10:21   │ 已保留 📌  │
│ [■]   │ Screenshot_2026-03-10_2   │ 2026-03-10 10:25   │ -         │
│ [■]   │ Screenshot_2026-03-09_7   │ 2026-03-09 18:03   │ -         │
└──────────────────────────────────────────────────────────────────────┘
```

#### E. 大图 Modal（左右切图 + 关闭返回）

```text
┌──────────────────────────────────────────────────────────────────────┐
│ ← 上一张                                         下一张 →      ✕ 关闭 │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│                    [                大图预览                ]         │
│                                                                      │
├──────────────────────────────────────────────────────────────────────┤
│ 文件名: Screenshot_2026-03-10_1.png                                  │
│ 时间: 2026-03-10 10:21                                                │
│ 状态: 已保留 📌                                                       │
│ [复制图片]   [取消保留]   [删除]                        [在 Finder 打开]│
└──────────────────────────────────────────────────────────────────────┘
（关闭后返回图库原位置）
```

#### F. 截图后预览 Modal（含“保存并保留”）

```text
┌──────────────────────────────────────────────────────────┐
│ 截图预览                                            ✕    │
├──────────────────────────────────────────────────────────┤
│                 [ 预览图 ]                              │
├──────────────────────────────────────────────────────────┤
│ [取消]                [保存]                [保存并保留 📌] │
└──────────────────────────────────────────────────────────┘
```

#### G. 设置页（自动清理）

```text
┌──────────────────────────────────────────────┐
│ 设置                                         │
├──────────────────────────────────────────────┤
│ 自动清理（Pro）                                │
│ 总开关： [OFF]（默认）                         │
│ 周期：   ( ) 24 小时   ( ) 7 天   ( ) 15 天   │
│         (●) 30 天(默认)   ( ) 60 天          │
│                                              │
│ 说明：已保留（📌）的截图不受自动清理影响      │
└──────────────────────────────────────────────┘
```

---

## 2. User Flows

### 2.1 Flow Overview

| Flow ID | Flow Name | Priority | Trigger | Completion |
|---------|-----------|----------|---------|------------|
| F-01 | 设定截图目录（已有能力） | P0 | 首次使用或目录失效 | 成功授权目录并可写入 |
| F-02 | 浏览截图（网格/列表） | P0 | 从 Dock、菜单栏或预览进入图库 | 用户看到并定位目标截图 |
| F-03 | 大图浏览与左右切换 | P0 | 在图库点击截图 | 在 Modal 中完成连续浏览后返回 |
| F-04 | 保存并保留（Keep） | P0 | 截图预览点击“保存并保留” | 截图保存成功且标记为保留 |
| F-05 | 图库中保留/取消保留 | P0 | 在图库或大图页点击保留按钮 | 状态变更并即时反馈 |
| F-06 | 设置自动清理（开关 + 周期） | P0 | 打开设置页或点击图库“清理周期”入口 | 成功开启/关闭自动清理并保存周期 |
| F-07 | 自动清理执行与结果提示 | P0 | 定时器或启动补偿检查触发 | 过期未保留截图被移入废纸篓并提示结果 |
| F-08 | 手动删除截图 | P0 | 在图库或大图页点击删除 | 目标截图移入系统废纸篓并从图库消失 |
| F-09 | 从菜单栏进入升级 | P1 | 点击菜单栏“Upgrade” | 成功打开付费升级窗口并可进入购买流程 |
| F-10 | 复制图片到剪贴板 | P0 | 在图库或大图页点击“复制图片”或按 `⌘C` | 图片写入系统剪贴板并可在外部应用粘贴 |
| F-11 | 从自动清理入口触发付费墙并升级 | P0 | 非 Pro 用户点击“清理周期(Pro)”或开启自动清理 | 打开 Paywall，完成购买后返回自动清理设置并可继续配置 |

---

### F-01: 设定截图目录（已有能力）

**Precondition**: 用户尚未授权截图保存目录，或 bookmark 失效。

**Happy Path**:

| Step | User Action | Component | System Response |
|------|-------------|-----------|-----------------|
| 1 | 触发保存截图 | Capture Preview Modal | 检测到目录未配置/失效 |
| 2 | 点击“选择目录” | NSOpenPanel | 弹出目录选择器 |
| 3 | 选定目录并确认 | NSOpenPanel | 创建 security-scoped bookmark 并持久化 |
| 4 | 返回保存流程 | Capture Preview Modal | 截图写入所选目录成功 |

**Flow Diagram**:

```
Start
  -> Save Screenshot
    -> Directory Configured?
      -> No -> Open Folder Picker -> User Selects Folder
        -> Create Bookmark -> Save Success
      -> Yes -> Save Success
End
```

**Edge Cases**:

| Exception | System Response | User Next Step |
|-----------|-----------------|----------------|
| 用户取消选择目录 | 返回预览弹窗并提示“未选择目录，无法保存” | 重新选择目录或取消保存 |
| bookmark 失效 | 提示“目录访问已失效，请重新授权” | 重新选择目录 |

---

### F-02: 浏览截图（网格/列表）

**Precondition**: 目录已授权，目录内存在或可能存在截图。

**Happy Path**:

| Step | User Action | Component | System Response |
|------|-------------|-----------|-----------------|
| 1 | 点击 Dock icon 或菜单栏“打开图库” | Dock / Menu Bar Menu | 打开 Library Window |
| 2 | 查看网格列表 | Library Grid View | 加载缩略图与文件元信息 |
| 3 | 切换到列表视图（可选） | Library Toolbar | 视图切换为 List |
| 4 | 按时间浏览并定位截图 | Library Window | 显示对应图片项 |

**Flow Diagram**:

```
Start
  -> Open Library
    -> Load Files
      -> Display Grid (default)
        -> Optional: Switch to List
          -> Browse Items
End
```

**Edge Cases**:

| Exception | System Response | User Next Step |
|-----------|-----------------|----------------|
| 目录为空 | 显示空状态“截图后保存的文件将出现在这里” | 去截图并保存 |
| 目录不可访问 | 显示错误状态并提供“重新选择目录”按钮 | 重新授权目录 |

---

### F-03: 大图浏览与左右切换

**Precondition**: 用户已在图库中看到至少 1 张截图。

**Happy Path**:

| Step | User Action | Component | System Response |
|------|-------------|-----------|-----------------|
| 1 | 点击某张截图 | Library Window | 打开 Image Viewer Modal（定位当前图） |
| 2 | 点击右箭头 | Image Viewer Modal | 切换到下一张 |
| 3 | 点击左箭头 | Image Viewer Modal | 切换到上一张 |
| 4 | 关闭 Modal | Image Viewer Modal | 返回图库原滚动位置 |

**Flow Diagram**:

```
Library Grid/List
  -> Click Image
    -> Open Viewer Modal
      -> Prev/Next Navigation
        -> Close Modal
          -> Back to Library Context
```

**Edge Cases**:

| Exception | System Response | User Next Step |
|-----------|-----------------|----------------|
| 当前为第一张再点上一张 | 按钮禁用或无操作反馈 | 改点下一张或关闭 |
| 当前为最后一张再点下一张 | 按钮禁用或无操作反馈 | 改点上一张或关闭 |
| 图片文件被外部删除 | 显示“文件不存在”并自动跳转相邻可用图片 | 继续浏览或关闭 |

---

### F-04: 保存并保留（Keep）

**Precondition**: 截图完成，预览弹窗已打开。

**Happy Path**:

| Step | User Action | Component | System Response |
|------|-------------|-----------|-----------------|
| 1 | 点击“保存并保留” | Capture Preview Modal | 保存截图到目录 |
| 2 | 等待保存完成 | Save Service | 写入文件并标记 Keep 元数据 |
| 3 | 查看反馈 | Toast | 显示“已保留 - 不会被自动清理” |

**Flow Diagram**:

```
Capture Preview
  -> Save & Keep
    -> Save File
      -> Mark Keep
        -> Success Toast
End
```

**Edge Cases**:

| Exception | System Response | User Next Step |
|-----------|-----------------|----------------|
| 保存失败 | 提示保存失败原因 | 重试或更换目录 |
| 标记失败（写元数据失败） | 提示“保存成功，但保留失败”并提供重试 | 重试保留操作 |

---

### F-05: 图库中保留/取消保留

**Precondition**: 用户在图库或大图页打开某张截图。

**Happy Path**:

| Step | User Action | Component | System Response |
|------|-------------|-----------|-----------------|
| 1 | 点击“保留”按钮 | Library Item / Viewer | 写入 Keep 标记 |
| 2 | 查看状态变化 | Library UI | 图片显示“已保留”状态 |
| 3 | 点击“取消保留”（可选） | Library Item / Viewer | 移除 Keep 标记并提示将恢复自动清理 |

**Flow Diagram**:

```
Select Image
  -> Toggle Keep
    -> Update Metadata
      -> Refresh UI Badge
        -> Optional: Unkeep
End
```

**Edge Cases**:

| Exception | System Response | User Next Step |
|-----------|-----------------|----------------|
| 元数据不可写 | 提示“操作失败，请检查目录权限” | 重新授权目录后重试 |
| 文件被外部移动 | 刷新后移除该项并提示文件不可用 | 浏览其他图片 |

---

### F-06: 设置自动清理（开关 + 周期）

**Precondition**: 用户已进入图库或设置页，目录可访问。

**Happy Path**:

| Step | User Action | Component | System Response |
|------|-------------|-----------|-----------------|
| 1 | 进入自动清理设置（从设置页或图库“清理周期”按钮） | Preferences Window / Library Toolbar | 若非 Pro，先展示 Upgrade / Paywall |
| 2 | 开启总开关 | Cleanup Toggle | 开关从 OFF -> ON，系统自动将周期设为 30d |
| 3 | （可选）修改周期 | Segmented/Radio Control | 保存为 24h / 7d / 15d / 30d / 60d 之一 |
| 4 | 完成设置 | Settings Store | 新配置立即生效于后续清理 |

**Paywall Trigger Path（显式链路）**:

| Step | User Action | Component | System Response |
|------|-------------|-----------|-----------------|
| A1 | 非 Pro 用户点击图库工具栏“清理周期(Pro)” | Library Toolbar | 立即打开 Upgrade / Paywall Window |
| A2 | 在付费墙点击升级 | Upgrade / Paywall Window | 进入现有 IAP 购买流程 |
| A3 | 购买成功 | Purchase Service | 关闭付费墙并返回自动清理设置页 |
| A4 | 回到设置页继续操作 | Preferences / Cleanup Settings | 可开启总开关（默认周期 30d）并保存 |

**Flow Diagram**:

```
Open Auto Cleanup Settings
  -> Pro User?
    -> No -> Open Paywall -> Upgrade(Optional)
    -> Yes -> Toggle ON (default 30d)
      -> Optional: Change Interval
        -> Save Setting
          -> Apply to Cleanup Engine
End
```

**Edge Cases**:

| Exception | System Response | User Next Step |
|-----------|-----------------|----------------|
| 非 Pro 用户 | 展示付费墙，说明“自动清理为 Pro 功能” | 升级或取消 |
| 用户未开启总开关 | 周期选项置灰，不执行自动清理 | 保持关闭或先开启 |
| 配置写入失败 | 提示“设置保存失败，请重试” | 再次选择并保存 |

---

### F-07: 自动清理执行与结果提示

**Precondition**: 自动清理总开关为 ON，且用户为 Pro；目录可访问。

**Happy Path**:

| Step | User Action | Component | System Response |
|------|-------------|-----------|-----------------|
| 1 | 无操作（后台触发） | Cleanup Engine | 扫描目录中过期截图 |
| 2 | 无操作 | Cleanup Engine | 过滤掉 Keep 图片 |
| 3 | 无操作 | File Service | 将过期未保留截图移入废纸篓 |
| 4 | 查看结果提示 | Toast/Notice | 显示“已清理 X 张，释放 Y MB” |

**Flow Diagram**:

```
Timer/App Launch Trigger
  -> Scan Files
    -> Filter Keep Items
      -> Move Expired Files to Trash
        -> Show Result Toast
End
```

**Edge Cases**:

| Exception | System Response | User Next Step |
|-----------|-----------------|----------------|
| 清理时目录不可访问 | 终止任务并记录日志，提示重新授权 | 去设置中重选目录 |
| 文件删除失败（被占用） | 跳过该文件并继续其余清理 | 下次清理重试 |
| 无可清理文件 | 可静默结束或提示“无需清理” | 无需操作 |

---

### F-08: 手动删除截图

**Precondition**: 用户在图库网格/列表或大图页选中了目标截图。

**Happy Path**:

| Step | User Action | Component | System Response |
|------|-------------|-----------|-----------------|
| 1 | 点击“删除” | Library Item / Viewer | 弹出二次确认对话框 |
| 2 | 确认删除 | Confirm Dialog | 将文件移入系统废纸篓 |
| 3 | 查看反馈 | Toast | 显示“已移入废纸篓，可在 Finder 恢复” |
| 4 | 返回浏览 | Library Window | 从当前列表移除该截图并保持当前位置 |

**Flow Diagram**:

```
Select Image
  -> Click Delete
    -> Confirm Dialog
      -> Confirm
        -> Move to Trash
          -> Update Library + Toast
End
```

**Edge Cases**:

| Exception | System Response | User Next Step |
|-----------|-----------------|----------------|
| 用户取消删除 | 关闭确认框，不做任何修改 | 继续浏览 |
| 文件已不存在 | 提示“文件不存在，已从列表移除” | 继续浏览 |
| 移入废纸篓失败 | 提示“删除失败，请检查权限后重试” | 重试或重新授权目录 |

---

### F-09: 从菜单栏进入升级

**Precondition**: App 正常运行，用户可打开菜单栏下拉。

**Happy Path**:

| Step | User Action | Component | System Response |
|------|-------------|-----------|-----------------|
| 1 | 点击菜单栏图标 | Menu Bar Menu | 展开菜单 |
| 2 | 点击“Upgrade” | Menu Bar Menu | 打开 Upgrade / Paywall Window |
| 3 | 查看权益并点击升级（可选） | Upgrade / Paywall Window | 跳转现有购买流程 |

**Flow Diagram**:

```
Open Menu Bar
  -> Click Upgrade
    -> Open Paywall Window
      -> Optional: Start Purchase
End
```

**Edge Cases**:

| Exception | System Response | User Next Step |
|-----------|-----------------|----------------|
| 已是 Pro 用户 | 显示“你已是 Pro”状态与管理订阅入口 | 关闭窗口或管理订阅 |
| Paywall 加载失败 | 提示“升级页加载失败，请重试” | 重试打开 Upgrade |

---

### F-10: 复制图片到剪贴板

**Precondition**: 用户在图库网格/列表或大图页选中了目标截图，文件可访问。

**Happy Path**:

| Step | User Action | Component | System Response |
|------|-------------|-----------|-----------------|
| 1 | 选中图片后点击“复制图片”或按 `⌘C` | Library Item / Viewer | 触发复制动作 |
| 2 | 等待复制完成 | Clipboard Service | 将图片写入系统剪贴板 |
| 3 | 查看反馈 | Toast | 显示“图片已复制，可直接粘贴” |
| 4 | 在外部 App 粘贴（可选） | External App | 成功粘贴图片 |

**Flow Diagram**:

```
Select Image
  -> Copy Image (Button / Cmd+C)
    -> Write to Clipboard
      -> Success Toast
        -> Optional: Paste in External App
End
```

**Edge Cases**:

| Exception | System Response | User Next Step |
|-----------|-----------------|----------------|
| 文件已不存在 | 提示“文件不存在，无法复制” | 刷新后重新选择图片 |
| 剪贴板写入失败 | 提示“复制失败，请重试” | 重试复制 |

---

### F-11: 从自动清理入口触发付费墙并升级

**Precondition**: 用户为非 Pro；已进入图库或设置页。

**Happy Path**:

| Step | User Action | Component | System Response |
|------|-------------|-----------|-----------------|
| 1 | 点击“清理周期(Pro)”或尝试开启自动清理 | Library Toolbar / Preferences | 触发 Pro 校验 |
| 2 | 查看付费墙并点击升级 | Upgrade / Paywall Window | 跳转购买流程 |
| 3 | 完成购买 | IAP Flow | 用户身份更新为 Pro |
| 4 | 返回自动清理设置 | Preferences / Cleanup Settings | 开关可用；可继续配置周期 |

**Flow Diagram**:

```
Open Cleanup Entry
  -> Pro Check
    -> Not Pro -> Open Paywall
      -> Purchase Success
        -> Return to Cleanup Settings
          -> Toggle ON + Save Interval
End
```

**Edge Cases**:

| Exception | System Response | User Next Step |
|-----------|-----------------|----------------|
| 用户取消购买 | 关闭付费墙并回到原页面 | 继续浏览或稍后升级 |
| 购买失败/网络错误 | 显示失败提示并保留重试 | 重试购买 |
| 购买成功但权益未刷新 | 显示“正在同步权益”并自动重试 | 等待同步或手动刷新 |

---

## 3. View States

| View | State Type | State Name | Trigger | Implementation |
|------|------------|------------|---------|----------------|
| Library Window | Empty | Empty Folder | 目录中无截图 | 空态插图 + 引导文案 + “去截图”提示 |
| Library Window | Loading | Initial Loading | 首次打开图库 | 骨架屏/进度指示 |
| Library Window | Loaded | Grid Loaded | 成功读取截图并使用网格 | 缩略图网格 + 工具栏 |
| Library Window | Loaded | List Loaded | 用户切换到列表 | 列表行 + 元信息 |
| Library Window | Error | Directory Inaccessible | bookmark 无效/目录不可读 | 错误文案 + “重新选择目录”按钮 |
| Image Viewer Modal | Loaded | Image Display | 点击图片进入大图 | 大图 + 左右导航 |
| Image Viewer Modal | Error | File Missing | 文件被外部删除 | 提示并跳转相邻图片或关闭 |
| Preferences Window | Loaded | Cleanup Config | 打开设置页 | 总开关 + 周期选项组 |
| Preferences Window | Disabled | Cleanup Off | 总开关为 OFF | 周期选项置灰，不执行清理 |
| Preferences Window | Locked | Cleanup Pro Required | 非 Pro 用户进入自动清理设置 | 展示 Pro 锁与 Upgrade CTA |
| Cleanup Notice | Info | Cleanup Done | 清理任务完成 | Toast 文案含数量与空间 |
| Keep Action | Feedback | Keep Success | 用户点保留 | Toast: 已保留 - 不会被自动清理 |
| Keep Action | Feedback | Unkeep Success | 用户点取消保留 | Toast: 将在 [X天] 后自动清理 |
| Delete Action | Confirm | Delete Confirm | 用户点删除 | 二次确认弹窗，说明“将移入废纸篓” |
| Delete Action | Feedback | Delete Success | 用户确认删除 | Toast: 已移入废纸篓，可恢复 |
| Delete Action | Error | Delete Failed | 移入废纸篓失败 | 错误提示 + 重试入口 |
| Copy Action | Feedback | Copy Success | 用户点复制或按 `⌘C` | Toast: 图片已复制，可直接粘贴 |
| Copy Action | Error | Copy Failed | 剪贴板写入失败 | 错误提示 + 重试入口 |
| Upgrade Window | Loaded | Paywall Ready | 点击菜单栏 Upgrade | 展示 Pro 权益与购买入口 |
| Upgrade Window | Error | Paywall Failed | 升级页加载失败 | 错误提示 + 重试按钮 |
| Cleanup Entry | Locked | Pro Gate Triggered | 非 Pro 点击“清理周期(Pro)”或开启开关 | 拉起付费墙并在购买后回跳设置页 |

---

## 4. Platform-specific Features

### 4.1 Keyboard Shortcuts / Gestures

#### System Standard

| Shortcut/Gesture | Function | Notes |
|------------------|----------|-------|
| `Esc` | 关闭当前 Modal（预览/大图） | macOS 标准行为 |
| `← / →` | 大图上一张/下一张 | 仅在 Image Viewer Modal 生效 |
| `⌘C` | 复制当前选中图片到剪贴板 | Library / Viewer 上下文生效 |
| `Enter` | 预览页执行主按钮（保存） | 可选，遵循 macOS 对话框习惯 |
| `⌘⌫` | 删除当前选中截图（触发确认） | Library / Viewer 上下文生效 |
| `⌘W` | 关闭当前窗口 | Library/Preferences 窗口 |

#### Custom

| Shortcut/Gesture | Function | Scope |
|------------------|----------|-------|
| 无新增 | 用户明确不需要新增自定义快捷键 | N/A |

### 4.2 System Integrations

| Feature | Implementation | Notes |
|---------|----------------|-------|
| 无 | 用户选择 `f`（都不要） | 本期不接入通知中心/Spotlight/Share/Handoff/Widget |

### 4.3 Permission Requests

| Permission | Request Timing | Purpose |
|------------|----------------|---------|
| 文件目录访问（已有） | 首次保存截图/目录失效时 | 访问并管理用户选择目录中的截图文件 |
| 屏幕录制（已有） | 现有截图功能路径 | 进行截图采集 |
| 辅助功能（已有） | 现有自动粘贴路径 | 进行自动粘贴 |
| 新增权限 | 不需要 | 自动清理、Keep 与手动删除均复用已有目录授权 |

---

## 5. Flow Relationships

```
F-01 设定目录
  ├─> F-09 菜单栏 Upgrade 入口
  │     └─> 打开 Upgrade / Paywall Window
  │
  ├─> F-02 浏览截图
  │     ├─> F-06 自动清理设置（图库工具栏快捷入口）
  │     │     └─> F-11 非 Pro 触发付费墙并升级
  │     └─> F-03 大图浏览
  │            ├─> F-10 复制图片
  │            ├─> F-05 保留/取消保留
  │            └─> F-08 手动删除
  │
  ├─> F-04 保存并保留（截图后捷径）
  │     └─> F-02 浏览截图（可见已保留状态）
  │
  └─> F-07 自动清理执行
         ├─(读取) F-06 自动清理设置
         └─(排除) F-05 已保留图片
```

---

## Appendix

### A. Glossary

| Term | Definition |
|------|------------|
| 图库（Library） | VibeCap 内用于浏览与管理截图的独立窗口 |
| 保留（Keep） | 标记截图为长期保留，不参与自动清理 |
| 复制图片（Copy Image） | 将当前选中截图写入系统剪贴板，可粘贴到其他应用 |
| 手动删除（Manual Delete） | 用户主动删除单张截图，文件移入系统废纸篓，可恢复 |
| Upgrade / Paywall | 付费升级窗口，用于展示 Pro 权益与触发购买 |
| 自动清理（Auto Cleanup） | 按设定周期清理过期且未保留的截图 |
| 清理周期 | 24h / 7d / 15d / 30d / 60d 的固定档位 |
| security-scoped bookmark | macOS 沙盒下持久化目录访问授权机制 |

### B. Version History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-03-10 | User + AI | Initial IA & User Flow (Dock entry, local library, keep, auto-cleanup, manual delete) |
