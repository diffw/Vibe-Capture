# VibeCap 产品规格文档（反向工程版）

> **文档版本**：基于代码库 commit fe48b62 反向工程  
> **生成日期**：2026-01-17  
> **文档性质**：事实级别规格，仅描述已实现行为

---

## 1. 功能系统概览

### 1.1 产品定位

VibeCap 是一个 macOS 菜单栏应用，核心功能是**截取屏幕区域并自动粘贴到 AI 代码编辑器或聊天应用**。

### 1.2 系统架构

```
┌─────────────────────────────────────────────────────────────┐
│                      AppDelegate                            │
│  - 菜单栏图标管理                                             │
│  - 全局快捷键绑定                                             │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│                    CaptureManager                           │
│  - 截图流程编排                                               │
│  - Modal 生命周期管理                                         │
└──────────────────────┬──────────────────────────────────────┘
                       │
         ┌─────────────┼─────────────┐
         ▼             ▼             ▼
┌─────────────┐ ┌─────────────┐ ┌─────────────────────┐
│ScreenCapture│ │AppDetection │ │CaptureModalWindow   │
│Service      │ │Service      │ │Controller           │
└─────────────┘ └─────────────┘ └──────────┬──────────┘
                                           │
                              ┌────────────┼────────────┐
                              ▼            ▼            ▼
                       ┌──────────┐ ┌──────────┐ ┌──────────┐
                       │AutoPaste │ │Screenshot│ │Clipboard │
                       │Service   │ │SaveService│ │Service   │
                       └──────────┘ └──────────┘ └──────────┘
```

### 1.3 核心能力清单

| 能力 | 状态 | 说明 |
|------|------|------|
| 区域截图 | ✅ 已实现 | 用户拖拽选择屏幕区域 |
| 自动粘贴到目标应用 | ✅ 已实现 | 自动激活目标应用并模拟粘贴 |
| 附加文字指令 | ✅ 已实现 | 可选的 prompt 文本 |
| 自动保存截图 | ✅ 已实现 | 可配置的自动保存 |
| 全局快捷键 | ✅ 已实现 | 可自定义 |
| 开机自启动 | ✅ 已实现 | 通过 SMAppService |

---

## 2. 用户操作模型

### 2.1 主要操作流程

```
用户按下快捷键 (默认 ⌘⇧C)
         │
         ▼
记录当前前台应用 → 显示截图覆盖层
         │
         ▼
用户拖拽选择区域 ─── ESC取消 ──→ 流程终止
         │
         ▼
截取屏幕内容 → 显示 Modal 预览窗口
         │
         ├── 点击 "Send to [App]" 或 ⌘↩︎
         │         │
         │         ▼
         │    关闭 Modal → 激活目标应用 → 粘贴图片 → 粘贴文字(如有)
         │         │
         │         ▼
         │    (如开启自动保存) → 保存到指定文件夹
         │
         ├── 点击下拉菜单选择其他应用
         │         │
         │         ▼
         │    直接发送到选中应用
         │
         ├── 点击 "Save Image"
         │         │
         │         ▼
         │    保存截图到指定文件夹
         │
         └── 点击 "Close" 或 ESC
                   │
                   ▼
              关闭 Modal，不执行任何操作
```

### 2.2 快捷键清单

| 快捷键 | 触发位置 | 行为 |
|--------|----------|------|
| ⌘⇧C (默认，可配置) | 全局 | 启动截图流程 |
| ESC | 截图覆盖层 | 取消截图 |
| ESC | Modal 窗口 | 关闭 Modal |
| ⌘↩︎ | Modal 窗口 | 发送到当前选中应用 |
| ⌘A/C/V/X | Modal 输入框 | 标准编辑快捷键 |

---

## 3. 交互状态机

### 3.1 截图流程状态机

```
                    ┌─────────┐
                    │  IDLE   │
                    └────┬────┘
                         │ 触发快捷键/菜单
                         ▼
                    ┌─────────┐
                    │SELECTING│ ←── 用户拖拽中
                    └────┬────┘
                         │
            ┌────────────┼────────────┐
            │ ESC        │ 松开鼠标   │ 选区 < 5x5px
            ▼            ▼            ▼
       ┌────────┐  ┌──────────┐  ┌────────┐
       │CANCELLED│  │CAPTURED  │  │CANCELLED│
       └────────┘  └────┬─────┘  └────────┘
                        │
                        ▼
                   ┌─────────┐
                   │ MODAL   │ ←── Modal 显示中
                   │ SHOWING │
                   └────┬────┘
                        │
      ┌─────────────────┼─────────────────┐
      │ 关闭/ESC        │ 发送            │ 保存
      ▼                 ▼                 ▼
 ┌─────────┐      ┌─────────┐       ┌─────────┐
 │CANCELLED│      │ PASTING │       │ SAVED   │
 └─────────┘      └────┬────┘       └─────────┘
                       │
                       ▼
                  ┌─────────┐
                  │ DONE    │
                  └─────────┘
```

### 3.2 Modal 窗口生命周期规则

| 规则 | 行为 |
|------|------|
| 单例约束 | 同时只能存在一个 Modal；新截图会自动关闭旧 Modal |
| 窗口层级 | `NSWindow.Level.floating`，始终浮于其他窗口之上 |
| 多显示器 | Modal 显示在鼠标所在屏幕的中央 |
| 可拖动 | 用户可拖动窗口背景移动 Modal |

---

## 4. UI / 交互细节规格

### 4.1 截图覆盖层

| 属性 | 值 |
|------|-----|
| 背景 | 半透明黑色 (45% opacity) |
| 选区边框 | 白色, 2px, 90% opacity |
| 尺寸标签 | 选区下方居中，黑色背景圆角标签 |
| 坐标标签 | 跟随鼠标，显示全局坐标 |
| 鼠标样式 | 十字准星 (crosshair) |

### 4.2 Modal 预览窗口

| 属性 | 值 |
|------|-----|
| 宽度范围 | 400px ~ 800px |
| 最大图片高度 | 400px |
| 窗口圆角 | 12px (macOS 系统风格) |
| 图片圆角 | 8px |
| 图片容器背景 | 灰色 (white: 0.95) |
| 图片容器圆角 | 仅顶部左上/右上 12px |
| 图片阴影 | 黑色, opacity 15%, offset (0, -2), radius 8 |
| 输入框高度 | 固定 140px |
| 输入框圆角 | 10px |

### 4.3 发送按钮样式规则

| 状态 | 样式 |
|------|------|
| 启用 (目标应用在白名单) | 品牌色背景 (#FF8D76), 白色文字 |
| 禁用 (目标应用不在白名单) | 默认灰色样式 |

### 4.4 下拉菜单内容

| 菜单项 | 条件 | 行为 |
|--------|------|------|
| "Send to [AppName]" | 每个运行中的白名单应用 | 直接发送 |
| "No supported apps running" | 无白名单应用运行时 | 禁用状态 |
| (分隔线) | - | - |
| "Save Image" | 始终显示 | 保存截图 |

---

## 5. 数据与状态模型

### 5.1 CaptureSession 数据结构

```swift
struct CaptureSession {
    let image: NSImage      // 截取的图像
    var prompt: String      // 用户输入的指令文本
    let createdAt: Date     // 创建时间
}
```

### 5.2 TargetApp 数据结构

```swift
struct TargetApp {
    let bundleIdentifier: String    // 应用 Bundle ID
    let displayName: String         // 显示名称
    let icon: NSImage?              // 应用图标
    let runningApp: NSRunningApplication?  // 运行实例引用
}
```

### 5.3 持久化设置 (UserDefaults)

| Key | 类型 | 默认值 | 说明 |
|-----|------|--------|------|
| `captureHotKey` | Data (JSON encoded) | ⌘⇧C | 截图快捷键 |
| `saveEnabled` | Bool | true | 自动保存开关 |
| `saveFolderBookmark` | Data | nil | 保存文件夹的安全书签 |
| `launchAtLogin` | Bool | false | 开机自启动 |
| `didShowLaunchHUD` | Bool | false | 首次启动提示标记 |

---

## 6. 业务规则与强约束

### 6.1 应用白名单

以下应用支持自动粘贴功能：

| 应用 | Bundle ID(s) | 焦点快捷键 |
|------|--------------|------------|
| Cursor | `com.todesktop.230313mzl4w4u92`, `com.cursor.Cursor` | ⌘L |
| VS Code | `com.microsoft.VSCode` | ⌘L |
| Windsurf | `com.exafunction.windsurf` | ⌘L |
| Antigravity | `com.google.antigravity` | ⌘L |
| Claude Desktop | `com.anthropic.claudefordesktop` | 空格+删除序列 |
| Figma | `com.figma.Desktop` | ⌘L |
| Telegram | `ru.keepcoder.Telegram`, `org.telegram.desktop` | 无 |
| Chrome | `com.google.Chrome` | 无 |
| Safari | `com.apple.Safari` | 无 |
| Edge | `com.microsoft.edgemac` | 无 |
| Arc | `company.thebrowser.Browser` | 无 |

### 6.2 自动粘贴流程规则

1. **发送前总是发送 ESC**（对于有焦点快捷键的应用）：关闭可能存在的搜索面板/弹窗
2. **焦点快捷键发送后**：等待 focusDelay 再粘贴
3. **图片粘贴后**：等待 textPasteDelay 再粘贴文字
4. **Claude 特殊处理**：使用空格+删除序列触发输入框焦点

### 6.3 截图保存规则

| 规则 | 说明 |
|------|------|
| 文件名格式 | `VC yyyyMMdd-HHmmss.png` |
| 文件名冲突 | 自动追加序号 `VC xxx 2.png`, `VC xxx 3.png` |
| 文件夹访问 | 使用 Security-Scoped Bookmarks 持久化权限 |
| 首次保存 | 如未配置文件夹，弹出选择对话框 |

### 6.4 权限要求

| 权限 | 用途 | 请求时机 |
|------|------|----------|
| Screen Recording | 截取屏幕内容 | 首次截图时 |
| Accessibility | 模拟键盘粘贴 | 首次发送时 |

---

## 7. 边界与异常处理

### 7.1 权限缺失处理

| 场景 | 行为 |
|------|------|
| Screen Recording 未授权 | 显示系统权限请求对话框 + 弹出提示 Alert |
| Accessibility 未授权 | 发送失败，显示 HUD 提示并引导到系统设置 |

### 7.2 错误状态 HUD 提示

| 错误类型 | 提示消息 |
|----------|----------|
| 截图失败 | "Unable to capture the selected area." |
| 目标应用未运行 | "Could not find [AppName]. Is it running?" |
| 保存失败 | "Failed to save screenshot: [具体错误]" |
| 快捷键冲突 | "Unable to register this shortcut... It may be used by another app..." |

### 7.3 选区最小尺寸约束

- 选区宽度或高度 < 5px 时，视为无效选区，取消截图流程

---

## 8. 当前实现的天然限制

### 8.1 架构限制

| 限制 | 说明 |
|------|------|
| 单 Modal 约束 | 新截图会关闭旧 Modal，不支持多截图并行编辑 |
| 内存中图像 | 截图存储在内存中，未实现磁盘缓存 |
| 同步粘贴流程 | 粘贴过程基于固定延时，非响应式确认 |

### 8.2 功能边界

| 限制 | 说明 |
|------|------|
| 仅支持区域截图 | 不支持窗口截图、全屏截图 |
| 白名单硬编码 | 支持的应用列表在代码中硬编码 |
| 无历史记录 | 截图不保留历史，关闭即丢失 |
| 无编辑功能 | 不支持标注、裁剪等图片编辑 |
| 浏览器无自动焦点 | 浏览器类应用需用户预先定位到输入框 |

### 8.3 已知的隐式行为（从代码推断）

| 行为 | 来源 |
|------|------|
| 图片始终以 PNG 格式保存 | `image.pngData()` 硬编码 |
| Modal 窗口大小根据图片宽高比动态计算 | `calculateWindowSize()` 逻辑 |
| 相同显示名的应用只显示第一个运行实例 | `getRunningWhitelistedApps()` 去重逻辑 |
| 输入框占位符在输入法组合状态也会隐藏 | `onTypingStarted` 回调 |

---

## 附录：文件与模块对照表

| 文件 | 职责 |
|------|------|
| `AppDelegate.swift` | 应用入口、菜单栏、全局快捷键绑定 |
| `CaptureManager.swift` | 截图流程编排 |
| `ScreenshotOverlayController.swift` | 截图选区 UI |
| `ScreenCaptureService.swift` | 屏幕截取 API 封装 |
| `CaptureModalViewController.swift` | Modal 内容视图 |
| `CaptureModalWindowController.swift` | Modal 窗口管理 |
| `AppDetectionService.swift` | 应用检测与白名单 |
| `AutoPasteService.swift` | 自动粘贴逻辑 |
| `ClipboardService.swift` | 剪贴板操作 |
| `ScreenshotSaveService.swift` | 截图保存 |
| `ShortcutManager.swift` | 全局快捷键注册 |
| `SettingsStore.swift` | 设置持久化 |
| `SettingsViewController.swift` | 设置界面 |

---

*文档结束*
