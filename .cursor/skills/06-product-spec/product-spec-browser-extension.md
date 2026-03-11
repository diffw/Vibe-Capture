# [产品名称] Browser Extension Product Spec

> **文档版本 (Version)**: 1.0  
> **最后更新 (Last Updated)**: YYYY-MM-DD  
> **作者 (Author)**: [你的名字]  
> **状态 (Status)**: Draft / In Review / Approved  
> **平台 (Platform)**: Browser Extension (Chrome / Edge / Firefox / Safari)

---

## 文档说明

本文档是交给AI实现的完整指南。AI应能仅凭此文档完成开发，无需查阅其他资料。

**前置文档**（已整合关键信息至本文档）：
- PRD: [链接]
- 技术架构文档: [链接]
- IA & User Flow: [链接]
- 设计稿: [Figma链接]

---

## 1. 技术栈 (Tech Stack)

### 1.1 扩展框架

| 类别 | 选型 | 版本 | 备注 |
|------|------|------|------|
| 框架 | Plasmo | latest | 或 WXT / 原生 Manifest V3 |
| 语言 | TypeScript | 5.x | 严格模式 |
| 样式 | Tailwind CSS | 3.x | - |
| UI组件库 | shadcn/ui | latest | 按需引入 |
| 状态管理 | Zustand | 4.x | 配合 chrome.storage |
| 打包 | Plasmo内置 | - | 自动处理多浏览器 |

### 1.2 Extension API

| API | 用途 | 权限 |
|-----|------|------|
| chrome.storage.local | 本地数据存储 | storage |
| chrome.storage.sync | 跨设备同步数据 | storage |
| chrome.tabs | 标签页操作 | tabs |
| chrome.runtime | 消息通信 | - |
| chrome.alarms | 定时任务 | alarms |
| chrome.notifications | 系统通知 | notifications |
| chrome.contextMenus | 右键菜单 | contextMenus |
| chrome.sidePanel | 侧边栏(Chrome 114+) | sidePanel |

### 1.3 后端服务（可选）

| 类别 | 选型 | 备注 |
|------|------|------|
| BaaS | Supabase | 用户数据同步 |
| 认证 | Supabase Auth | OAuth |

### 1.4 发布平台

| 平台 | 商店 | 审核周期 |
|------|------|----------|
| Chrome | Chrome Web Store | 1-3天 |
| Edge | Microsoft Edge Add-ons | 1-3天 |
| Firefox | Firefox Add-ons | 1-5天 |
| Safari | App Store | 1-7天（需包装为macOS/iOS App） |

---

## 2. Extension架构 (Extension Architecture)

### 2.1 Manifest V3 结构

```
extension/
├── manifest.json           # 扩展配置
├── background/
│   └── index.ts           # Service Worker (后台脚本)
├── popup/
│   ├── index.html         # Popup HTML
│   └── index.tsx          # Popup React入口
├── sidepanel/             # 侧边栏 (可选)
│   ├── index.html
│   └── index.tsx
├── options/               # 选项页面
│   ├── index.html
│   └── index.tsx
├── contents/              # Content Scripts
│   └── main.tsx           # 注入页面的脚本
├── components/            # 共享组件
├── lib/                   # 工具函数
├── storage/               # 存储逻辑
└── assets/                # 图标等资源
    ├── icon-16.png
    ├── icon-32.png
    ├── icon-48.png
    └── icon-128.png
```

### 2.2 Manifest.json 配置

```json
{
  "manifest_version": 3,
  "name": "[产品名称]",
  "version": "1.0.0",
  "description": "[产品描述，最多132字符]",
  "icons": {
    "16": "assets/icon-16.png",
    "32": "assets/icon-32.png",
    "48": "assets/icon-48.png",
    "128": "assets/icon-128.png"
  },
  "action": {
    "default_popup": "popup/index.html",
    "default_icon": {
      "16": "assets/icon-16.png",
      "32": "assets/icon-32.png"
    },
    "default_title": "[产品名称]"
  },
  "background": {
    "service_worker": "background/index.ts",
    "type": "module"
  },
  "permissions": [
    "storage",
    "tabs",
    "alarms",
    "notifications",
    "contextMenus"
  ],
  "optional_permissions": [
    "history",
    "bookmarks"
  ],
  "host_permissions": [
    "https://*.example.com/*"
  ],
  "content_scripts": [
    {
      "matches": ["https://*.example.com/*"],
      "js": ["contents/main.tsx"],
      "css": ["contents/style.css"]
    }
  ],
  "options_ui": {
    "page": "options/index.html",
    "open_in_tab": true
  },
  "side_panel": {
    "default_path": "sidepanel/index.html"
  }
}
```

### 2.3 组件通信架构

```
┌─────────────────────────────────────────────────────────────────┐
│                         Browser                                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────┐     chrome.runtime      ┌──────────────────┐  │
│  │    Popup     │◄──────────────────────►│  Service Worker  │  │
│  │   (React)    │      .sendMessage       │   (Background)   │  │
│  └──────────────┘                         └────────┬─────────┘  │
│                                                    │             │
│  ┌──────────────┐     chrome.runtime              │             │
│  │  Side Panel  │◄────────────────────────────────┤             │
│  │   (React)    │      .sendMessage               │             │
│  └──────────────┘                                 │             │
│                                                    │             │
│  ┌──────────────┐                                 │             │
│  │   Options    │◄────────────────────────────────┤             │
│  │    Page      │      chrome.storage             │             │
│  └──────────────┘         .onChanged              │             │
│                                                    │             │
│  ┌───────────────────────────────────────────────┐│             │
│  │                  Web Page                      ││             │
│  │  ┌──────────────┐                             ││             │
│  │  │Content Script│◄────────────────────────────┘│             │
│  │  │  (Injected)  │      chrome.runtime          │             │
│  │  └──────────────┘       .sendMessage           │             │
│  └───────────────────────────────────────────────┘│             │
│                                                    │             │
│              ┌──────────────────────┐              │             │
│              │   chrome.storage     │◄─────────────┘             │
│              │  (local / sync)      │                            │
│              └──────────────────────┘                            │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 3. 数据存储 (Data Storage)

### 3.1 存储方案选择

| 存储类型 | 容量限制 | 同步 | 使用场景 |
|----------|----------|------|----------|
| chrome.storage.local | 10MB | 否 | 大量本地数据 |
| chrome.storage.sync | 100KB | 跨设备 | 用户设置、小量数据 |
| IndexedDB | 无限制 | 否 | 大量结构化数据 |
| 后端API | 无限制 | 是 | 需要服务端功能 |

### 3.2 本地数据结构

```typescript
// storage/types.ts

interface StorageSchema {
  // 用户设置 (sync)
  settings: UserSettings;
  
  // 任务数据 (local)
  projects: Project[];
  tasks: Task[];
  
  // 缓存数据 (local)
  cache: {
    lastSync: number;
    version: string;
  };
}

interface UserSettings {
  theme: 'light' | 'dark' | 'system';
  showBadge: boolean;
  notifications: boolean;
  defaultProject: string | null;
  shortcuts: {
    openPopup: string;
    quickAdd: string;
  };
}

interface Project {
  id: string;
  name: string;
  color: string;
  createdAt: number;
  updatedAt: number;
}

interface Task {
  id: string;
  projectId: string;
  title: string;
  description: string;
  status: 'todo' | 'in_progress' | 'done';
  priority: 'low' | 'medium' | 'high' | 'urgent';
  dueDate: number | null;
  completedAt: number | null;
  position: number;
  createdAt: number;
  updatedAt: number;
  // 扩展特有字段
  sourceUrl?: string;      // 添加任务时的网页URL
  sourceTitle?: string;    // 添加任务时的网页标题
}
```

### 3.3 存储操作封装

```typescript
// storage/index.ts

// 读取数据
async function getStorage<K extends keyof StorageSchema>(
  key: K,
  area: 'local' | 'sync' = 'local'
): Promise<StorageSchema[K] | null>

// 写入数据
async function setStorage<K extends keyof StorageSchema>(
  key: K,
  value: StorageSchema[K],
  area: 'local' | 'sync' = 'local'
): Promise<void>

// 监听变化
function onStorageChange(
  callback: (changes: StorageChanges) => void
): void
```

---

## 4. 消息通信 (Message Passing)

### 4.1 消息类型定义

```typescript
// lib/messages.ts

type MessageType =
  | { type: 'GET_TASKS'; payload: { projectId?: string } }
  | { type: 'ADD_TASK'; payload: { task: Omit<Task, 'id' | 'createdAt' | 'updatedAt'> } }
  | { type: 'UPDATE_TASK'; payload: { id: string; updates: Partial<Task> } }
  | { type: 'DELETE_TASK'; payload: { id: string } }
  | { type: 'GET_CURRENT_TAB'; payload: null }
  | { type: 'SHOW_NOTIFICATION'; payload: { title: string; message: string } }
  | { type: 'OPEN_SIDE_PANEL'; payload: null }
  | { type: 'SYNC_DATA'; payload: null };

type MessageResponse<T extends MessageType['type']> =
  T extends 'GET_TASKS' ? { tasks: Task[] } :
  T extends 'ADD_TASK' ? { task: Task } :
  T extends 'GET_CURRENT_TAB' ? { url: string; title: string } :
  { success: boolean };
```

### 4.2 消息发送/接收

```typescript
// 从Popup/Content Script发送消息
const response = await chrome.runtime.sendMessage({
  type: 'ADD_TASK',
  payload: { task: newTask }
});

// Service Worker接收消息
chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  handleMessage(message).then(sendResponse);
  return true; // 保持通道开放以支持异步响应
});
```

---

## 5. 功能模块详情 (Feature Specifications)

### 5.1 Popup (弹出窗口)

**功能描述**: 点击扩展图标弹出的主界面，用于快速查看和添加任务

**设计稿**: [Figma链接 - Popup]

**尺寸规范**:
| 属性 | 值 | 备注 |
|------|-----|------|
| 宽度 | 360px | 固定宽度 |
| 最小高度 | 400px | - |
| 最大高度 | 600px | 超出滚动 |

**UI结构**:

```
┌─────────────────────────────────┐ 360px
│ ┌─────────────────────────────┐ │
│ │ [项目下拉▼]     [⚙️] [📌]  │ │ ← Header
│ └─────────────────────────────┘ │
├─────────────────────────────────┤
│ ┌─────────────────────────────┐ │
│ │ ➕ 添加任务...               │ │ ← 快速添加
│ └─────────────────────────────┘ │
├─────────────────────────────────┤
│                                 │
│  □ 完成设计稿          🔴 今天  │ ← 任务列表
│  □ 写周报              🟡 明天  │
│  ☑ 发送邮件 (已完成)           │
│                                 │
│  ─────────────────────────────  │
│  已完成 (3)              [展开] │
│                                 │
├─────────────────────────────────┤
│ 📊 今日: 2/5 完成              │ ← Footer统计
└─────────────────────────────────┘
```

**UI组件**:

| 组件 | 类型 | 说明 |
|------|------|------|
| 项目选择器 | Select | 切换当前项目 |
| 设置按钮 | IconButton | 打开Options页面 |
| 固定按钮 | IconButton | 固定Popup为独立窗口 |
| 快速添加 | Input | Enter确认，支持快捷语法 |
| 任务列表 | List | 显示当前项目任务 |
| 任务项 | TaskItem | 勾选框+标题+标签 |
| 统计栏 | Stats | 今日完成情况 |

**交互规则**:

| 触发 | 行为 | 反馈 |
|------|------|------|
| 打开Popup | 加载当前项目任务 | 骨架屏 → 内容 |
| 输入任务+Enter | 创建任务 | 任务出现在列表顶部 |
| 点击任务勾选框 | 切换完成状态 | 勾选动画，移至已完成区 |
| 点击任务标题 | 展开任务详情 | 内联展开或Side Panel |
| 点击固定按钮 | 新窗口打开Popup | 固定窗口保持显示 |
| 点击设置 | 新Tab打开Options | - |

**快速添加语法**:

| 语法 | 效果 | 示例 |
|------|------|------|
| 普通文本 | 任务标题 | "完成设计稿" |
| `!1` `!2` `!3` `!4` | 优先级 | "完成设计稿 !1" → 紧急 |
| `#项目名` | 指定项目 | "完成设计稿 #工作" |
| `@today` `@tomorrow` | 截止日期 | "完成设计稿 @today" |
| `@2024-01-20` | 指定日期 | "完成设计稿 @2024-01-20" |

---

### 5.2 Side Panel (侧边栏)

**功能描述**: 浏览网页时在右侧显示的面板，提供更大的操作空间

**设计稿**: [Figma链接 - Side Panel]

**Chrome版本要求**: Chrome 114+

**尺寸规范**:
| 属性 | 值 |
|------|-----|
| 宽度 | 用户可调整，最小320px |
| 高度 | 视口高度 |

**UI结构**:

```
┌─────────────────────────────────────┐
│ [产品Logo]              [➕] [⚙️]  │ ← Header
├─────────────────────────────────────┤
│ 🔍 搜索任务...                      │ ← 搜索栏
├─────────────────────────────────────┤
│                                     │
│ 项目                                │
│ ├── 📁 工作项目 (5)                 │
│ ├── 📁 个人项目 (3)                 │
│ └── ➕ 新建项目                     │
│                                     │
├─────────────────────────────────────┤
│                                     │
│ 工作项目                    [视图▼] │
│                                     │
│ 待办 (3)                            │
│ ┌─────────────────────────────────┐ │
│ │ □ 任务1                    🔴   │ │
│ │ □ 任务2                    🟡   │ │
│ │ □ 任务3                         │ │
│ └─────────────────────────────────┘ │
│                                     │
│ 进行中 (1)                          │
│ ┌─────────────────────────────────┐ │
│ │ □ 任务4                    🔵   │ │
│ └─────────────────────────────────┘ │
│                                     │
└─────────────────────────────────────┘
```

**与Popup的功能差异**:

| 功能 | Popup | Side Panel |
|------|-------|------------|
| 项目列表 | 下拉选择 | 侧边树形列表 |
| 任务详情 | 简要展开 | 完整编辑 |
| 拖拽排序 | 不支持 | 支持 |
| 看板视图 | 不支持 | 支持 |
| 搜索 | 不支持 | 支持 |

---

### 5.3 Content Script (页面注入)

**功能描述**: 注入到网页中的脚本，提供页面内快捷操作

**设计稿**: [Figma链接 - Content Script UI]

**注入条件**:
```json
{
  "matches": ["<all_urls>"],
  "exclude_matches": [
    "https://chrome.google.com/*",
    "chrome://*",
    "chrome-extension://*"
  ]
}
```

#### 5.3.1 浮动操作按钮 (FAB)

**位置**: 页面右下角，距边缘20px

**UI**:
```
          ┌─────┐
          │  ➕ │  ← 主按钮 (40x40px)
          └─────┘
```

**交互**:

| 触发 | 行为 |
|------|------|
| 点击FAB | 展开快速添加面板 |
| 选中文本 + 点击FAB | 将选中文本作为任务标题 |
| 拖拽FAB | 调整位置（记住位置） |
| 长按FAB | 显示操作菜单 |

#### 5.3.2 快速添加面板

**位置**: FAB上方弹出

**UI**:
```
┌─────────────────────────────────┐
│ 添加任务到 [项目名▼]            │
├─────────────────────────────────┤
│ ┌─────────────────────────────┐ │
│ │ 任务标题                    │ │
│ └─────────────────────────────┘ │
│                                 │
│ 📎 当前页面: [页面标题...]      │ ← 自动关联
│                                 │
│ [取消]              [添加任务]  │
└─────────────────────────────────┘
```

**自动填充**:
- 如果有选中文本 → 填入任务标题
- 自动记录当前页面URL和标题

#### 5.3.3 右键菜单

**菜单项**:

| 菜单项 | 上下文 | 功能 |
|--------|--------|------|
| 添加为任务 | 选中文本 | 将选中文本创建为任务 |
| 将链接添加为任务 | 链接 | 将链接标题/URL创建为任务 |
| 将图片添加为任务 | 图片 | 保存图片URL到任务描述 |
| 打开任务面板 | 页面 | 打开Side Panel |

---

### 5.4 Options Page (选项页面)

**功能描述**: 扩展设置页面，在新标签页中打开

**设计稿**: [Figma链接 - Options]

**页面路径**: `chrome-extension://[id]/options.html`

**UI结构**:

```
┌─────────────────────────────────────────────────────────────┐
│ [Logo] [产品名] 设置                                         │
├───────────────┬─────────────────────────────────────────────┤
│               │                                             │
│ 通用设置      │  通用设置                                    │
│ 账户         │  ─────────────────────────────────────────  │
│ 快捷键       │                                             │
│ 数据管理     │  外观                                        │
│ 关于         │  ○ 浅色  ○ 深色  ● 跟随系统                  │
│               │                                             │
│               │  徽章显示                                    │
│               │  [✓] 在图标上显示待办数量                    │
│               │                                             │
│               │  通知                                        │
│               │  [✓] 任务到期提醒                            │
│               │  [✓] 每日摘要通知                            │
│               │      时间: [09:00 ▼]                        │
│               │                                             │
│               │  默认项目                                    │
│               │  [工作项目 ▼]                                │
│               │                                             │
└───────────────┴─────────────────────────────────────────────┘
```

**设置项**:

#### 通用设置

| 设置项 | 类型 | 默认值 | 存储位置 |
|--------|------|--------|----------|
| 外观主题 | Radio | system | sync |
| 徽章显示 | Toggle | true | sync |
| 任务到期提醒 | Toggle | true | sync |
| 每日摘要通知 | Toggle | false | sync |
| 摘要通知时间 | Time | 09:00 | sync |
| 默认项目 | Select | null | sync |

#### 快捷键设置

| 快捷键 | 默认值 | 说明 |
|--------|--------|------|
| 打开Popup | Alt+T | 全局快捷键 |
| 快速添加 | Alt+Shift+A | 全局快捷键 |

**Chrome快捷键设置**:
> 提示：全局快捷键需要在 chrome://extensions/shortcuts 中设置

#### 数据管理

| 操作 | 说明 | 确认 |
|------|------|------|
| 导出数据 | 导出为JSON文件 | 无需确认 |
| 导入数据 | 从JSON文件导入 | 确认覆盖 |
| 清空数据 | 删除所有本地数据 | 二次确认 |

#### 关于

- 版本号
- 更新日志链接
- 反馈链接
- 隐私政策链接

---

### 5.5 Service Worker (后台服务)

**功能描述**: 后台运行的服务脚本，处理事件和定时任务

**注意**: Manifest V3中Service Worker会在空闲时休眠，需要通过事件唤醒

#### 5.5.1 事件监听

```typescript
// background/index.ts

// 扩展安装/更新
chrome.runtime.onInstalled.addListener((details) => {
  if (details.reason === 'install') {
    // 首次安装：初始化数据，打开欢迎页
    initializeStorage();
    chrome.tabs.create({ url: 'welcome.html' });
  } else if (details.reason === 'update') {
    // 更新：数据迁移
    migrateData(details.previousVersion);
  }
});

// 消息处理
chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  handleMessage(message, sender).then(sendResponse);
  return true;
});

// 右键菜单点击
chrome.contextMenus.onClicked.addListener((info, tab) => {
  handleContextMenu(info, tab);
});

// 定时任务
chrome.alarms.onAlarm.addListener((alarm) => {
  handleAlarm(alarm);
});

// 通知点击
chrome.notifications.onClicked.addListener((notificationId) => {
  handleNotificationClick(notificationId);
});
```

#### 5.5.2 定时任务

| 任务名 | 周期 | 功能 |
|--------|------|------|
| daily-summary | 每天指定时间 | 发送每日摘要通知 |
| due-reminder | 每小时 | 检查到期任务 |
| badge-update | 每分钟 | 更新图标徽章 |

#### 5.5.3 徽章更新

```typescript
// 更新扩展图标徽章
async function updateBadge() {
  const settings = await getStorage('settings', 'sync');
  if (!settings?.showBadge) {
    chrome.action.setBadgeText({ text: '' });
    return;
  }
  
  const tasks = await getStorage('tasks', 'local');
  const todoCount = tasks?.filter(t => t.status === 'todo').length || 0;
  
  chrome.action.setBadgeText({ text: todoCount > 0 ? String(todoCount) : '' });
  chrome.action.setBadgeBackgroundColor({ color: '#6366f1' });
}
```

---

### 5.6 通知系统

**功能描述**: 系统级通知提醒

#### 5.6.1 通知类型

| 类型 | 触发条件 | 内容 |
|------|----------|------|
| 任务到期 | 任务截止日期到达 | "任务「{标题}」已到期" |
| 每日摘要 | 设定的时间 | "今日待办 {n} 项，已完成 {m} 项" |
| 同步完成 | 数据同步完成 | "数据已同步" |

#### 5.6.2 通知结构

```typescript
chrome.notifications.create('task-due-' + taskId, {
  type: 'basic',
  iconUrl: 'assets/icon-128.png',
  title: '任务到期提醒',
  message: '任务「完成设计稿」已到期',
  buttons: [
    { title: '标记完成' },
    { title: '延期1天' }
  ],
  priority: 2
});
```

---

## 6. 跨浏览器兼容 (Cross-Browser Compatibility)

### 6.1 API差异

| 功能 | Chrome | Firefox | Safari | Edge |
|------|--------|---------|--------|------|
| Manifest版本 | V3 | V2/V3 | V2(转换) | V3 |
| Service Worker | ✅ | ✅ | ❌(用Background Page) | ✅ |
| Side Panel | ✅ Chrome 114+ | ❌ | ❌ | ✅ |
| Promise API | ✅ | ✅ | ✅ | ✅ |

### 6.2 Firefox适配

```typescript
// 使用browser命名空间（Firefox）或chrome命名空间
const browserAPI = typeof browser !== 'undefined' ? browser : chrome;

// 或使用webextension-polyfill
import browser from 'webextension-polyfill';
```

### 6.3 Safari适配

- 需要使用Xcode将扩展转换为Safari Web Extension
- 需要包装为macOS App或iOS App发布到App Store
- 部分API不可用，需要功能降级

---

## 7. 页面状态 (Page States)

### 7.1 Popup状态

| 状态 | 触发条件 | UI表现 |
|------|----------|--------|
| 加载中 | 打开Popup，数据加载中 | 骨架屏 |
| 正常 | 数据加载完成 | 显示任务列表 |
| 空状态 | 无任务 | 空状态插图+引导 |
| 错误 | 数据加载失败 | 错误提示+重试 |
| 未登录 | 需要登录但未登录 | 登录引导 |

### 7.2 空状态文案

| 场景 | 标题 | 描述 | 操作 |
|------|------|------|------|
| 无任务 | 还没有任务 | 添加第一个任务开始使用 | [添加任务] |
| 无项目 | 还没有项目 | 创建项目来组织你的任务 | [创建项目] |
| 搜索无结果 | 没有找到任务 | 试试其他关键词 | - |

---

## 8. 存储限制与优化 (Storage Limits)

### 8.1 容量限制

| 存储类型 | 容量限制 | 单项限制 |
|----------|----------|----------|
| storage.local | 10MB | 8KB/项 |
| storage.sync | 100KB | 8KB/项，512项 |

### 8.2 优化策略

| 策略 | 说明 |
|------|------|
| 分页加载 | 任务列表分页，每次加载50条 |
| 数据压缩 | 存储前压缩JSON |
| 定期清理 | 清理30天前的已完成任务 |
| 懒加载详情 | 任务描述按需加载 |

---

## 9. 权限说明 (Permissions)

### 9.1 权限用途

| 权限 | 用途 | 用户提示 |
|------|------|----------|
| storage | 存储任务数据 | 无提示 |
| tabs | 获取当前标签页信息 | 无提示 |
| alarms | 定时提醒 | 无提示 |
| notifications | 系统通知 | 首次使用时提示 |
| contextMenus | 右键菜单 | 无提示 |
| activeTab | 获取当前页面信息 | 点击时授权 |

### 9.2 可选权限

| 权限 | 用途 | 请求时机 |
|------|------|----------|
| history | 根据浏览历史推荐任务 | 用户启用功能时 |
| bookmarks | 从书签创建任务 | 用户启用功能时 |

---

## 10. 安全要求 (Security)

| 要求 | 实现方式 |
|------|----------|
| CSP | 严格的Content Security Policy |
| 无远程代码 | 不执行远程加载的脚本 |
| 数据加密 | 敏感数据加密存储（可选） |
| 权限最小化 | 只请求必要权限 |
| 输入校验 | 所有用户输入严格校验 |

---

## 11. 商店发布要求 (Store Requirements)

### 11.1 Chrome Web Store

| 要求 | 说明 |
|------|------|
| 图标 | 128x128 PNG |
| 截图 | 1280x800 或 640x400，至少1张 |
| 描述 | 详细功能描述，最多132字符摘要 |
| 隐私政策 | 必须提供隐私政策URL |
| 单一用途 | 扩展只能有一个主要功能 |

### 11.2 提交清单

- [ ] 完整填写扩展描述
- [ ] 准备商店截图（至少3张）
- [ ] 编写隐私政策
- [ ] 准备宣传图片（可选）
- [ ] 测试所有功能
- [ ] 检查权限说明

---

## 12. 测试清单 (Test Checklist)

### 12.1 功能测试

- [ ] Popup：打开、添加任务、完成任务、切换项目
- [ ] Side Panel：完整任务管理流程
- [ ] Content Script：FAB显示、快速添加、右键菜单
- [ ] Options：所有设置项保存和生效
- [ ] 通知：到期提醒、每日摘要
- [ ] 快捷键：全局快捷键响应

### 12.2 兼容性测试

- [ ] Chrome (最新稳定版)
- [ ] Chrome (最新Beta版)
- [ ] Edge (最新版)
- [ ] Firefox (如适用)
- [ ] Safari (如适用)

### 12.3 边界测试

- [ ] 大量数据：1000+任务
- [ ] 存储接近上限
- [ ] Service Worker休眠后唤醒
- [ ] 网络离线状态

---

## 附录

### A. 目录结构

```
extension/
├── manifest.json
├── package.json
├── tsconfig.json
├── tailwind.config.js
├── src/
│   ├── background/
│   │   └── index.ts
│   ├── popup/
│   │   ├── index.html
│   │   ├── index.tsx
│   │   └── components/
│   ├── sidepanel/
│   │   ├── index.html
│   │   └── index.tsx
│   ├── options/
│   │   ├── index.html
│   │   └── index.tsx
│   ├── contents/
│   │   ├── main.tsx
│   │   └── style.css
│   ├── components/
│   │   └── ui/
│   ├── lib/
│   │   ├── messages.ts
│   │   └── utils.ts
│   ├── storage/
│   │   ├── index.ts
│   │   └── types.ts
│   └── hooks/
│       └── useStorage.ts
└── assets/
    ├── icon-16.png
    ├── icon-32.png
    ├── icon-48.png
    └── icon-128.png
```

### B. 版本历史

| 版本 | 日期 | 作者 | 变更说明 |
|------|------|------|----------|
| 1.0 | YYYY-MM-DD | [作者] | 初始版本 |
