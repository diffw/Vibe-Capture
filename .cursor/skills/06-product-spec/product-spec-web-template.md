# [产品名称] Web App Product Spec

> **文档版本 (Version)**: 1.0  
> **最后更新 (Last Updated)**: YYYY-MM-DD  
> **状态 (Status)**: Draft / In Review / Approved  
> **平台 (Platform)**: Web App（响应式：桌面端 + 移动端）

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

### 1.1 前端

| 类别 | 选型 | 版本 | 备注 |
|------|------|------|------|
| 框架 | Next.js | 14.x | App Router |
| 语言 | TypeScript | 5.x | 严格模式 |
| 样式 | Tailwind CSS | 3.x | - |
| UI组件库 | shadcn/ui | latest | 按需引入 |
| 状态管理 | Zustand | 4.x | 轻量级 |
| 表单 | React Hook Form + Zod | - | 校验 |
| HTTP请求 | fetch / SWR | - | 数据获取 |

### 1.2 后端

| 类别 | 选型 | 备注 |
|------|------|------|
| BaaS | Supabase | 或 Firebase |
| 数据库 | PostgreSQL | Supabase托管 |
| 认证 | Supabase Auth | 邮箱+OAuth |
| 存储 | Supabase Storage | 文件上传 |
| 边缘函数 | Supabase Edge Functions | 服务端逻辑 |

### 1.3 部署

| 类别 | 选型 | 备注 |
|------|------|------|
| 托管 | Vercel | 自动部署 |
| 域名 | [你的域名] | - |
| 环境 | Development / Staging / Production | 三套环境 |

### 1.4 第三方服务

| 服务 | 提供商 | 用途 |
|------|--------|------|
| 邮件 | Resend | 验证邮件、通知 |
| 分析 | PostHog | 用户行为分析 |
| 错误监控 | Sentry | 异常捕获 |
| 支付 | Stripe | 如需付费功能 |

---

## 2. 数据模型 (Data Model)

### 2.1 ER关系图

```
┌──────────────┐       ┌──────────────┐       ┌──────────────┐
│    users     │       │   projects   │       │    tasks     │
├──────────────┤       ├──────────────┤       ├──────────────┤
│ id (PK)      │──┐    │ id (PK)      │──┐    │ id (PK)      │
│ email        │  │    │ user_id (FK) │←─┘    │ project_id(FK)│←─┘
│ name         │  │    │ name         │       │ title        │
│ avatar_url   │  │    │ description  │       │ description  │
│ created_at   │  │    │ created_at   │       │ status       │
│ updated_at   │  └───→│ updated_at   │       │ priority     │
└──────────────┘       └──────────────┘       │ due_date     │
                                              │ created_at   │
                                              │ updated_at   │
                                              └──────────────┘
```

### 2.2 数据表详情

#### users 表

| 字段 | 类型 | 约束 | 说明 |
|------|------|------|------|
| id | uuid | PK, default gen_random_uuid() | 主键 |
| email | varchar(255) | UNIQUE, NOT NULL | 邮箱 |
| name | varchar(100) | NOT NULL | 显示名称 |
| avatar_url | text | NULL | 头像URL |
| created_at | timestamptz | default now() | 创建时间 |
| updated_at | timestamptz | default now() | 更新时间 |

#### projects 表

| 字段 | 类型 | 约束 | 说明 |
|------|------|------|------|
| id | uuid | PK | 主键 |
| user_id | uuid | FK → users.id, ON DELETE CASCADE | 所属用户 |
| name | varchar(200) | NOT NULL | 项目名称 |
| description | text | NULL | 项目描述 |
| color | varchar(7) | default '#6366f1' | 项目颜色(HEX) |
| is_archived | boolean | default false | 是否归档 |
| created_at | timestamptz | default now() | 创建时间 |
| updated_at | timestamptz | default now() | 更新时间 |

#### tasks 表

| 字段 | 类型 | 约束 | 说明 |
|------|------|------|------|
| id | uuid | PK | 主键 |
| project_id | uuid | FK → projects.id, ON DELETE CASCADE | 所属项目 |
| title | varchar(500) | NOT NULL | 任务标题 |
| description | text | NULL | 任务描述 |
| status | enum | default 'todo' | 状态: todo/in_progress/done |
| priority | enum | default 'medium' | 优先级: low/medium/high/urgent |
| due_date | date | NULL | 截止日期 |
| completed_at | timestamptz | NULL | 完成时间 |
| position | integer | NOT NULL | 排序位置 |
| created_at | timestamptz | default now() | 创建时间 |
| updated_at | timestamptz | default now() | 更新时间 |

### 2.3 枚举类型

```sql
-- 任务状态
CREATE TYPE task_status AS ENUM ('todo', 'in_progress', 'done');

-- 任务优先级
CREATE TYPE task_priority AS ENUM ('low', 'medium', 'high', 'urgent');
```

### 2.4 索引

```sql
-- 常用查询索引
CREATE INDEX idx_projects_user_id ON projects(user_id);
CREATE INDEX idx_tasks_project_id ON tasks(project_id);
CREATE INDEX idx_tasks_status ON tasks(status);
CREATE INDEX idx_tasks_due_date ON tasks(due_date);
```

---

## 3. API设计 (API Specification)

### 3.1 认证相关

#### POST /auth/register
注册新用户

**Request Body**:
```json
{
  "email": "user@example.com",
  "password": "SecurePass123!",
  "name": "张三"
}
```

**校验规则**:
| 字段 | 规则 |
|------|------|
| email | 有效邮箱格式，最长255字符 |
| password | 最少8位，包含大写、小写、数字 |
| name | 1-100字符，不能纯空格 |

**Response 201**:
```json
{
  "user": {
    "id": "uuid",
    "email": "user@example.com",
    "name": "张三"
  },
  "message": "验证邮件已发送"
}
```

**Error Responses**:
| 状态码 | code | message | 触发条件 |
|--------|------|---------|----------|
| 400 | INVALID_EMAIL | 邮箱格式不正确 | 邮箱格式校验失败 |
| 400 | WEAK_PASSWORD | 密码强度不足 | 密码不符合规则 |
| 409 | EMAIL_EXISTS | 该邮箱已注册 | 邮箱已存在 |
| 429 | RATE_LIMITED | 请求过于频繁 | 超过频率限制 |
| 500 | SERVER_ERROR | 服务器错误 | 内部错误 |

---

#### POST /auth/login
用户登录

**Request Body**:
```json
{
  "email": "user@example.com",
  "password": "SecurePass123!"
}
```

**Response 200**:
```json
{
  "user": {
    "id": "uuid",
    "email": "user@example.com",
    "name": "张三",
    "avatar_url": null
  },
  "access_token": "eyJhbG...",
  "refresh_token": "eyJhbG...",
  "expires_in": 3600
}
```

**Error Responses**:
| 状态码 | code | message | 触发条件 |
|--------|------|---------|----------|
| 401 | INVALID_CREDENTIALS | 邮箱或密码错误 | 认证失败 |
| 401 | EMAIL_NOT_VERIFIED | 请先验证邮箱 | 邮箱未验证 |
| 423 | ACCOUNT_LOCKED | 账户已锁定，请15分钟后重试 | 连续失败5次 |

---

#### POST /auth/logout
退出登录

**Headers**:
```
Authorization: Bearer {access_token}
```

**Response 200**:
```json
{
  "message": "已退出登录"
}
```

---

#### POST /auth/forgot-password
发送密码重置邮件

**Request Body**:
```json
{
  "email": "user@example.com"
}
```

**Response 200**:
```json
{
  "message": "如果该邮箱已注册，重置链接已发送"
}
```

> 注意：无论邮箱是否存在，都返回相同响应，避免信息泄露

---

#### POST /auth/reset-password
重置密码

**Request Body**:
```json
{
  "token": "reset_token_from_email",
  "password": "NewSecurePass123!"
}
```

**Response 200**:
```json
{
  "message": "密码已重置，请重新登录"
}
```

**Error Responses**:
| 状态码 | code | message | 触发条件 |
|--------|------|---------|----------|
| 400 | INVALID_TOKEN | 链接无效或已过期 | token错误或过期 |
| 400 | WEAK_PASSWORD | 密码强度不足 | 密码不符合规则 |

---

### 3.2 项目相关

#### GET /projects
获取用户的项目列表

**Headers**:
```
Authorization: Bearer {access_token}
```

**Query Parameters**:
| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| include_archived | boolean | 否 | 是否包含已归档项目，默认false |

**Response 200**:
```json
{
  "projects": [
    {
      "id": "uuid",
      "name": "工作项目",
      "description": "日常工作任务",
      "color": "#6366f1",
      "is_archived": false,
      "task_count": 12,
      "completed_count": 5,
      "created_at": "2024-01-01T00:00:00Z",
      "updated_at": "2024-01-15T00:00:00Z"
    }
  ]
}
```

---

#### POST /projects
创建新项目

**Request Body**:
```json
{
  "name": "新项目",
  "description": "项目描述（可选）",
  "color": "#6366f1"
}
```

**校验规则**:
| 字段 | 规则 |
|------|------|
| name | 1-200字符，不能纯空格 |
| description | 最长5000字符 |
| color | 有效HEX颜色值 |

**Response 201**:
```json
{
  "project": {
    "id": "uuid",
    "name": "新项目",
    "description": "项目描述",
    "color": "#6366f1",
    "is_archived": false,
    "created_at": "2024-01-15T00:00:00Z",
    "updated_at": "2024-01-15T00:00:00Z"
  }
}
```

---

#### GET /projects/:id
获取单个项目详情

**Response 200**:
```json
{
  "project": {
    "id": "uuid",
    "name": "工作项目",
    "description": "日常工作任务",
    "color": "#6366f1",
    "is_archived": false,
    "created_at": "2024-01-01T00:00:00Z",
    "updated_at": "2024-01-15T00:00:00Z"
  }
}
```

**Error Responses**:
| 状态码 | code | message | 触发条件 |
|--------|------|---------|----------|
| 404 | NOT_FOUND | 项目不存在 | 项目不存在或无权访问 |

---

#### PATCH /projects/:id
更新项目

**Request Body** (所有字段可选):
```json
{
  "name": "更新后的名称",
  "description": "更新后的描述",
  "color": "#10b981",
  "is_archived": false
}
```

**Response 200**:
```json
{
  "project": { ... }
}
```

---

#### DELETE /projects/:id
删除项目

**Response 200**:
```json
{
  "message": "项目已删除"
}
```

> 注意：删除项目会同时删除所有关联任务（CASCADE）

---

### 3.3 任务相关

#### GET /projects/:project_id/tasks
获取项目下的任务列表

**Query Parameters**:
| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| status | string | 否 | 按状态筛选：todo/in_progress/done |
| priority | string | 否 | 按优先级筛选：low/medium/high/urgent |
| sort | string | 否 | 排序方式：position(默认)/due_date/created_at |

**Response 200**:
```json
{
  "tasks": [
    {
      "id": "uuid",
      "title": "完成设计稿",
      "description": "首页设计",
      "status": "in_progress",
      "priority": "high",
      "due_date": "2024-01-20",
      "position": 1,
      "created_at": "2024-01-10T00:00:00Z",
      "updated_at": "2024-01-15T00:00:00Z"
    }
  ]
}
```

---

#### POST /projects/:project_id/tasks
创建新任务

**Request Body**:
```json
{
  "title": "新任务",
  "description": "任务描述（可选）",
  "priority": "medium",
  "due_date": "2024-01-25"
}
```

**校验规则**:
| 字段 | 规则 |
|------|------|
| title | 1-500字符，不能纯空格 |
| description | 最长10000字符 |
| priority | 必须是有效枚举值 |
| due_date | 有效日期，可为null |

**Response 201**:
```json
{
  "task": {
    "id": "uuid",
    "title": "新任务",
    "status": "todo",
    "priority": "medium",
    "due_date": "2024-01-25",
    "position": 1,
    ...
  }
}
```

---

#### PATCH /tasks/:id
更新任务

**Request Body** (所有字段可选):
```json
{
  "title": "更新后的标题",
  "description": "更新后的描述",
  "status": "done",
  "priority": "low",
  "due_date": "2024-01-30",
  "position": 2
}
```

**特殊逻辑**:
- 当 status 从非 done 改为 done 时，自动设置 completed_at 为当前时间
- 当 status 从 done 改为非 done 时，自动清空 completed_at

**Response 200**:
```json
{
  "task": { ... }
}
```

---

#### DELETE /tasks/:id
删除任务

**Response 200**:
```json
{
  "message": "任务已删除"
}
```

---

#### PATCH /tasks/reorder
批量更新任务排序

**Request Body**:
```json
{
  "tasks": [
    { "id": "uuid1", "position": 1 },
    { "id": "uuid2", "position": 2 },
    { "id": "uuid3", "position": 3 }
  ]
}
```

**Response 200**:
```json
{
  "message": "排序已更新"
}
```

---

## 4. 功能模块详情 (Feature Specifications)

### 4.1 用户注册

**功能描述**: 新用户通过邮箱注册账号

**设计稿**: [Figma链接 - 注册页面]

**页面路径**: `/register`

**前置条件**: 用户未登录

**UI组件**:
| 组件 | 类型 | 属性 |
|------|------|------|
| 邮箱输入框 | Input | type="email", placeholder="请输入邮箱", autofocus |
| 密码输入框 | Input | type="password", placeholder="请输入密码" |
| 密码可见切换 | IconButton | 点击切换密码显示/隐藏 |
| 密码强度指示器 | PasswordStrength | 实时显示强度：弱/中/强 |
| 注册按钮 | Button | 主要按钮，loading状态 |
| 登录链接 | Link | "已有账号？登录" |
| OAuth按钮组 | OAuthButtons | Google, GitHub |

**交互规则**:

| 触发 | 行为 | 反馈 |
|------|------|------|
| 邮箱输入框失焦 | 校验邮箱格式 | 错误时显示红色边框+提示文字 |
| 密码输入 | 实时计算密码强度 | 更新强度指示器 |
| 点击注册按钮 | 校验全部字段 → 调用API | 按钮显示loading，禁用表单 |
| 注册成功 | 显示成功提示，3秒后跳转 | Toast: "注册成功，请查收验证邮件" |
| 注册失败 | 显示错误信息 | 对应字段显示错误或Toast提示 |

**校验规则** (前端实时 + 后端兜底):

| 字段 | 规则 | 错误提示 |
|------|------|----------|
| 邮箱 | 必填，有效邮箱格式 | "请输入有效的邮箱地址" |
| 邮箱 | 最长255字符 | "邮箱长度不能超过255个字符" |
| 密码 | 必填，至少8位 | "密码至少需要8个字符" |
| 密码 | 包含大写字母 | "密码需要包含大写字母" |
| 密码 | 包含小写字母 | "密码需要包含小写字母" |
| 密码 | 包含数字 | "密码需要包含数字" |

**异常处理**:

| 异常情况 | 系统响应 | 用户体验 |
|----------|----------|----------|
| 邮箱已注册 | API返回409 | 提示"该邮箱已注册"，显示登录链接 |
| 网络错误 | fetch失败 | Toast: "网络连接失败，请重试" |
| 服务器错误 | API返回500 | Toast: "服务器繁忙，请稍后重试" |
| 请求超时 | 超过10秒 | Toast: "请求超时，请重试" |

**桌面端 vs 移动端**:

| 差异项 | 桌面端 | 移动端 |
|--------|--------|--------|
| 表单宽度 | 400px居中卡片 | 全宽，padding 16px |
| OAuth按钮 | 水平排列 | 垂直堆叠 |
| 键盘 | Enter提交表单 | 虚拟键盘"完成"提交 |

---

### 4.2 用户登录

**功能描述**: 已注册用户登录系统

**设计稿**: [Figma链接 - 登录页面]

**页面路径**: `/login`

**前置条件**: 用户未登录

**UI组件**:
| 组件 | 类型 | 属性 |
|------|------|------|
| 邮箱输入框 | Input | type="email", autofocus |
| 密码输入框 | Input | type="password" |
| 记住我 | Checkbox | 默认不勾选 |
| 登录按钮 | Button | 主要按钮 |
| 忘记密码 | Link | 跳转 /forgot-password |
| 注册链接 | Link | "还没有账号？注册" |
| OAuth按钮组 | OAuthButtons | Google, GitHub |

**交互规则**:

| 触发 | 行为 | 反馈 |
|------|------|------|
| 点击登录 | 校验 → 调用API | 按钮loading |
| 登录成功 | 存储token，跳转目标页 | 跳转到 /dashboard 或来源页 |
| 登录失败 | 显示错误 | 输入框抖动 + 错误提示 |
| 点击OAuth | 跳转第三方授权 | 新窗口或当前页跳转 |

**安全机制**:
- 连续失败5次：锁定15分钟
- Token有效期：Access Token 1小时，Refresh Token 7天
- 勾选"记住我"：Refresh Token 延长至30天

**异常处理**:

| 异常情况 | 错误码 | 用户体验 |
|----------|--------|----------|
| 邮箱或密码错误 | INVALID_CREDENTIALS | 提示"邮箱或密码错误" |
| 邮箱未验证 | EMAIL_NOT_VERIFIED | 提示"请先验证邮箱"，提供重发按钮 |
| 账户锁定 | ACCOUNT_LOCKED | 提示"账户已锁定，请15分钟后重试" |

---

### 4.3 项目管理

**功能描述**: 用户创建、编辑、删除、归档项目

**设计稿**: [Figma链接 - 项目列表/项目设置]

**页面路径**: `/dashboard`, `/projects/:id/settings`

#### 4.3.1 项目列表

**UI组件**:
- 侧边栏项目列表（桌面端）
- 项目选择下拉（移动端）
- 新建项目按钮
- 项目颜色标识

**列表项显示**:
- 项目颜色圆点
- 项目名称
- 任务统计（已完成/总数）
- 更多操作菜单（编辑、归档、删除）

**交互规则**:

| 触发 | 行为 |
|------|------|
| 点击项目 | 切换到该项目的任务列表 |
| 点击"新建项目" | 打开新建弹窗 |
| 点击更多 → 编辑 | 打开编辑弹窗 |
| 点击更多 → 归档 | 确认弹窗 → 归档 |
| 点击更多 → 删除 | 确认弹窗（警告会删除所有任务）→ 删除 |

#### 4.3.2 新建/编辑项目弹窗

**UI组件**:
| 组件 | 类型 | 属性 |
|------|------|------|
| 项目名称 | Input | maxLength=200, autofocus |
| 项目描述 | Textarea | maxLength=5000, 可选 |
| 颜色选择器 | ColorPicker | 预设色板 + 自定义 |
| 取消按钮 | Button | 次要按钮 |
| 保存按钮 | Button | 主要按钮 |

**校验规则**:

| 字段 | 规则 | 错误提示 |
|------|------|----------|
| 名称 | 必填，1-200字符 | "请输入项目名称" |
| 名称 | 不能纯空格 | "项目名称不能为空" |
| 颜色 | 有效HEX值 | "请选择有效颜色" |

#### 4.3.3 删除项目确认

**弹窗内容**:
```
标题：删除项目

确定要删除项目「{项目名}」吗？

⚠️ 此操作不可撤销，项目内的所有任务也将被删除。

[取消]  [删除]（红色危险按钮）
```

---

### 4.4 任务管理

**功能描述**: 用户在项目内创建、编辑、删除、排序任务

**设计稿**: [Figma链接 - 任务列表/任务详情]

**页面路径**: `/projects/:id`

#### 4.4.1 任务列表

**视图模式**:
- 列表视图（默认）
- 看板视图（按状态分列）

**列表项显示**:
| 元素 | 说明 |
|------|------|
| 完成勾选框 | 点击切换完成状态 |
| 优先级标识 | 颜色标识：🔴高 🟡中 🟢低 |
| 任务标题 | 截断显示，悬浮完整内容 |
| 截止日期 | 过期显示红色 |
| 拖拽把手 | 桌面端显示，用于排序 |

**筛选/排序**:
| 筛选项 | 选项 |
|--------|------|
| 状态 | 全部 / 待办 / 进行中 / 已完成 |
| 优先级 | 全部 / 紧急 / 高 / 中 / 低 |
| 排序 | 自定义排序 / 截止日期 / 创建时间 |

**交互规则**:

| 触发 | 行为 |
|------|------|
| 点击勾选框 | 切换完成状态，已完成任务移至底部 |
| 点击任务 | 打开任务详情面板/弹窗 |
| 拖拽任务 | 调整排序（调用批量排序API） |
| 点击"添加任务" | 显示快速添加输入框 |

#### 4.4.2 快速添加任务

**位置**: 任务列表底部或顶部

**组件**:
- 输入框：placeholder="添加新任务，按Enter确认"
- 快捷键：Enter确认，Esc取消

**默认值**:
- status: todo
- priority: medium
- position: 列表末尾

#### 4.4.3 任务详情

**打开方式**:
- 桌面端：右侧滑出面板
- 移动端：全屏弹窗

**UI组件**:
| 组件 | 类型 | 说明 |
|------|------|------|
| 标题 | EditableText | 点击编辑，失焦保存 |
| 状态选择 | Select | todo/in_progress/done |
| 优先级选择 | Select | low/medium/high/urgent |
| 截止日期 | DatePicker | 可清空 |
| 描述 | Textarea | Markdown支持（可选） |
| 删除按钮 | Button | 底部危险按钮 |
| 关闭按钮 | IconButton | 右上角 X |

**自动保存**:
- 任何字段变更后自动保存（debounce 500ms）
- 显示"保存中..."和"已保存"状态

---

## 5. 页面状态 (Page States)

### 5.1 全局状态

| 状态 | 触发条件 | UI表现 | 用户操作 |
|------|----------|--------|----------|
| 加载中 | 首次数据获取 | 骨架屏 | 等待 |
| 正常 | 数据加载完成 | 显示内容 | 正常操作 |
| 空状态 | 无数据 | 空状态插图+引导文案 | 根据引导操作 |
| 错误 | 请求失败 | 错误提示+重试按钮 | 点击重试 |
| 离线 | 网络断开 | 顶部Banner提示 | 恢复网络后自动重连 |

### 5.2 各页面空状态文案

| 页面 | 插图 | 标题 | 描述 | 操作按钮 |
|------|------|------|------|----------|
| 项目列表 | 📁 | 还没有项目 | 创建第一个项目开始使用 | [创建项目] |
| 任务列表 | ✅ | 还没有任务 | 添加第一个任务吧 | [添加任务] |
| 搜索结果 | 🔍 | 没有找到结果 | 试试其他关键词 | - |

---

## 6. 响应式设计 (Responsive Design)

### 6.1 断点定义

| 断点名称 | 宽度范围 | Tailwind类 |
|----------|----------|------------|
| Mobile | < 640px | 默认 |
| Tablet | 640px - 1024px | sm: / md: |
| Desktop | ≥ 1024px | lg: |

### 6.2 布局适配

| 组件 | Mobile | Tablet | Desktop |
|------|--------|--------|---------|
| 侧边栏 | 隐藏，汉堡菜单 | 可折叠 | 展开固定 |
| 任务详情 | 全屏弹窗 | 全屏弹窗 | 右侧滑出面板 |
| 项目选择 | 顶部下拉 | 顶部下拉 | 侧边栏列表 |
| 表单布局 | 单列 | 单列 | 可双列 |

---

## 7. 文案规范 (Copywriting)

### 7.1 语气

- 友好、简洁、专业
- 使用"你"而非"您"
- 避免技术术语

### 7.2 按钮文案

| 场景 | 推荐 | 避免 |
|------|------|------|
| 创建 | 创建项目 | 新建/添加/确定 |
| 保存 | 保存 | 确认/OK |
| 取消 | 取消 | 关闭/返回 |
| 删除 | 删除 | 移除/确认删除 |

### 7.3 错误提示

| 类型 | 格式 | 示例 |
|------|------|------|
| 字段校验 | 描述问题 | "请输入有效的邮箱地址" |
| 操作失败 | 描述结果+建议 | "保存失败，请重试" |
| 网络错误 | 友好描述 | "网络连接失败，请检查网络" |

### 7.4 空状态

| 原则 | 说明 |
|------|------|
| 说明当前状态 | "还没有任务" |
| 提供下一步 | "添加第一个任务吧" |
| 给出操作按钮 | [添加任务] |

---

## 8. 边界情况与异常处理 (Edge Cases)

### 8.1 网络相关

| 场景 | 处理方式 |
|------|----------|
| 请求超时(10s) | 显示超时提示，提供重试按钮 |
| 网络断开 | 顶部显示离线Banner，禁用需要网络的操作 |
| 网络恢复 | 自动重试失败的请求，隐藏离线Banner |

### 8.2 认证相关

| 场景 | 处理方式 |
|------|----------|
| Token过期 | 自动使用Refresh Token刷新 |
| Refresh Token过期 | 弹窗提示"登录已过期"，跳转登录页 |
| 并发登录 | 允许多设备登录 |

### 8.3 数据冲突

| 场景 | 处理方式 |
|------|----------|
| 多标签页编辑同一数据 | 后保存的覆盖先保存的（最后写入优先） |
| 删除已删除的数据 | 静默处理，刷新列表 |

### 8.4 输入边界

| 场景 | 处理方式 |
|------|----------|
| 超长文本 | 前端限制maxLength，后端截断 |
| 特殊字符 | 允许，正确转义存储 |
| XSS攻击 | 后端过滤，前端使用textContent |

---

## 9. 安全要求 (Security)

| 要求 | 实现方式 |
|------|----------|
| HTTPS | 强制HTTPS，HSTS |
| 密码存储 | bcrypt加密，不可逆 |
| Token安全 | HttpOnly Cookie或安全存储 |
| CSRF防护 | SameSite Cookie + CSRF Token |
| XSS防护 | 内容转义，CSP头 |
| 输入校验 | 前后端双重校验 |
| 速率限制 | 注册/登录/API均有限制 |
| 敏感操作日志 | 记录登录、密码重置、删除操作 |

---

## 10. 性能要求 (Performance)

| 指标 | 目标 | 测量方式 |
|------|------|----------|
| 首屏加载(FCP) | < 1.5s | Lighthouse |
| 可交互时间(TTI) | < 3s | Lighthouse |
| API响应时间 | < 500ms | 后端监控 |
| 列表渲染 | 100条无卡顿 | 手动测试 |
| 图片加载 | 懒加载+压缩 | - |

---

## 11. 测试清单 (Test Checklist)

### 11.1 功能测试

- [ ] 注册：正常流程、重复邮箱、无效邮箱、弱密码
- [ ] 登录：正常流程、错误密码、账户锁定、OAuth
- [ ] 项目：创建、编辑、删除、归档
- [ ] 任务：创建、编辑、删除、排序、状态切换

### 11.2 兼容性测试

- [ ] Chrome (最新2个版本)
- [ ] Safari (最新2个版本)
- [ ] Firefox (最新2个版本)
- [ ] Edge (最新2个版本)
- [ ] iOS Safari
- [ ] Android Chrome

### 11.3 响应式测试

- [ ] 320px (iPhone SE)
- [ ] 375px (iPhone)
- [ ] 768px (iPad)
- [ ] 1024px (iPad横屏/小笔记本)
- [ ] 1440px (桌面)
- [ ] 1920px (大屏)

---

## 附录

### A. 环境变量

```env
# Supabase
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_ANON_KEY=
SUPABASE_SERVICE_ROLE_KEY=

# OAuth
GOOGLE_CLIENT_ID=
GOOGLE_CLIENT_SECRET=
GITHUB_CLIENT_ID=
GITHUB_CLIENT_SECRET=

# Email
RESEND_API_KEY=

# Monitoring
SENTRY_DSN=
POSTHOG_KEY=
```

### B. 版本历史

| 版本 | 日期 | 作者 | 变更说明 |
|------|------|------|----------|
| 1.0 | YYYY-MM-DD | [作者] | 初始版本 |
