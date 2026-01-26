# Mac App Store 上架指南

## 需要的文件格式

对于 Mac App Store 上架，你需要提供 **`.xcarchive`** 格式的文件。这是通过 Xcode 的 Archive 功能创建的归档文件。

## 上架步骤

### 1. 准备工作

#### 1.1 确保 App Store 配置正确

在 Xcode 中检查以下设置：

- **Signing & Capabilities**:
  - 选择 "Mac App Store" 作为分发方式
  - 使用 **App Store 证书**（不是 Developer ID）
  - 确保 Bundle Identifier 正确：`com.nanwang.vibecap`
  - 确保 Team 已设置

- **Entitlements**:
  - 当前 `VibeCapture.entitlements` 已包含 App Sandbox
  - 确保所有需要的权限都已添加

#### 1.2 更新 Info.plist

确保以下信息完整：
- `CFBundleShortVersionString`: 版本号（如 1.0）
- `CFBundleVersion`: 构建号（如 1）
- `LSMinimumSystemVersion`: 最低系统版本（当前为 13.0）

### 2. 创建 Archive

#### 方法一：使用 Xcode（推荐）

1. 在 Xcode 中选择 **Product > Archive**
2. 等待构建完成
3. Xcode Organizer 会自动打开，显示你的 archive

#### 方法二：使用命令行

```bash
# 清理之前的构建
xcodebuild clean -project VibeCapture.xcodeproj -scheme "Vibe Capture"

# 创建 Archive
xcodebuild archive \
  -project VibeCapture.xcodeproj \
  -scheme "Vibe Capture" \
  -configuration Release \
  -archivePath "./build/VibeCapture.xcarchive" \
  CODE_SIGN_IDENTITY="Apple Distribution" \
  CODE_SIGN_STYLE="Manual" \
  PROVISIONING_PROFILE_SPECIFIER="你的 App Store Provisioning Profile"
```

### 3. 上传到 App Store Connect

#### 方法一：通过 Xcode Organizer（最简单）

1. 在 Xcode Organizer 中选择你的 archive
2. 点击 **Distribute App**
3. 选择 **App Store Connect**
4. 选择 **Upload**
5. 按照向导完成上传

#### 方法二：使用命令行工具

```bash
# 使用 altool（已弃用，但可用）
xcrun altool --upload-app \
  --type macos \
  --file "./build/VibeCapture.pkg" \
  --apiKey "你的 API Key" \
  --apiIssuer "你的 Issuer ID"

# 或使用 notarytool（推荐）
xcrun notarytool submit \
  --apple-id "your@email.com" \
  --team-id "YOUR_TEAM_ID" \
  --password "app-specific-password" \
  "./build/VibeCapture.pkg"
```

### 4. 在 App Store Connect 中完成

1. 登录 [App Store Connect](https://appstoreconnect.apple.com)
2. 创建新应用（如果还没有）
3. 填写应用信息：
   - 应用名称
   - 描述
   - 截图
   - 关键词
   - 隐私政策 URL
   - 分类等
4. 等待构建处理完成
5. 提交审核

## 重要注意事项

### App Sandbox 要求

Mac App Store 应用必须启用 App Sandbox。你的 `VibeCapture.entitlements` 已包含：
- `com.apple.security.app-sandbox = true`
- `com.apple.security.files.user-selected.read-write = true`

### 权限说明

如果应用需要以下权限，需要在 Info.plist 中添加说明：
- 屏幕录制权限
- 辅助功能权限
- 文件访问权限

### 证书和配置文件

- **App Store 证书**：用于签名 App Store 分发的应用
- **Provisioning Profile**：包含应用 ID、证书和设备的配置文件
- 确保在 Xcode 的 Signing & Capabilities 中选择正确的配置

### 版本号管理

每次上传新版本时：
- `CFBundleShortVersionString` 可以保持不变（如果只是修复）
- `CFBundleVersion` 必须递增（每次构建都要增加）

## 常见问题

### Q: 可以直接上传 .app 文件吗？
A: 不可以。必须使用 `.xcarchive` 格式，然后通过 Xcode Organizer 上传。

### Q: 可以导出为 .pkg 文件吗？
A: 可以，但通常直接上传 archive 更方便。如果导出 .pkg，需要确保使用 App Store 证书签名。

### Q: 需要 notarization（公证）吗？
A: App Store 应用不需要单独公证，上传到 App Store Connect 时会自动处理。

### Q: 当前 build.sh 脚本可以用于 App Store 吗？
A: 不可以。`build.sh` 脚本是为本地分发设计的，使用 Developer ID 证书。App Store 上架必须使用 Xcode Archive 和 App Store 证书。

## 推荐工作流程

1. **开发阶段**：使用 `build.sh` 进行本地测试
2. **准备发布**：使用 Xcode Archive 创建 archive
3. **上传**：通过 Xcode Organizer 上传到 App Store Connect
4. **提交审核**：在 App Store Connect 中完成应用信息并提交

## 相关资源

- [App Store Connect 帮助文档](https://help.apple.com/app-store-connect/)
- [Mac App Store 审核指南](https://developer.apple.com/app-store/review/guidelines/)
- [App Sandbox 设计指南](https://developer.apple.com/library/archive/documentation/Security/Conceptual/AppSandboxDesignGuide/)
