## Development workflow (VibeCapture)

这份文档用来解释：**什么时候用 Xcode build / 什么时候用 `build.sh`**，以及它们产物在哪里、用途是什么。

### 1) 两种 build 方式的区别

- **Xcode build / Run（Cmd+R / Cmd+B）**
  - **用途**：日常开发调试（断点、Console、权限/沙盒行为、更贴近 App Store 规则）。
  - **IAP**：可以在 Scheme 里启用 **StoreKit Configuration（`.storekit`）**，本地显示价格/购买流程（测试用）。
  - **产物位置**：Xcode 的 DerivedData（不是 `dist/`，也不是 `/Applications`）。
    - 在 Xcode 里直接用：**Product → Show Build Folder in Finder**
    - 常见路径形如：`~/Library/Developer/Xcode/DerivedData/.../Build/Products/Debug/Vibe Capture.app`

- **`build.sh`（Cursor/终端跑脚本，生成 `dist/` 并可安装到 `/Applications`）**
  - **用途**：快速生成一个可双击运行的 `.app`，用于本地试用/分发给别人测试（不依赖 Xcode）。
  - **IAP**：不会使用 Xcode Scheme 的 `.storekit` 配置；IAP 相关只能走真实 App Store Connect / Sandbox（或你自己实现的 mock）。
  - **产物位置**：
    - `dist/VibeCap.app`
    - （可选）脚本会复制安装到：`/Applications/VibeCap.app`

### 2) 最终发布到 App Store 的构建在哪里做？

**用 Xcode Archive**：

- Xcode：**Product → Archive**
- 然后在 Organizer 里上传到 App Store Connect / TestFlight

原因：签名/entitlements/打包结构/审核链路，App Store 以 Xcode Archive 为准。

### 3) 你应该什么时候用哪一种？

- **用 Xcode（推荐为主）**：
  - 做 IAP / Paywall / StoreKit（需要 `.storekit` 或 Sandbox）
  - 调试发送粘贴（Accessibility/Input Monitoring）、沙盒权限、签名等“系统级行为”
  - 准备发布（Archive / 上传）

- **用 `build.sh`**：
  - 需要快速打一个 `dist/` 包给自己/朋友试用
  - 验证你脚本化的打包/拷资源/签名流程
  - 注意：新增英文文案后，先运行 `./scripts/sync-localization.py` 再跑 `./scripts/check-localization.sh VibeCapture/Resources`

### 4) 重要原则：避免再次“跑错 app / 两个菜单栏图标”

- **同时存在两份 app**（例如 Xcode 跑的 Debug 版 + `/Applications` 安装版）会导致：
  - 菜单栏出现两个图标
  - 系统权限（Screen Recording/Accessibility）看起来“突然失效”（其实授权的是另一份 Bundle ID）

建议：
- 调试 IAP/发送粘贴时，先把旧安装版 **Quit**，只保留 Xcode 启动的一份。

### 5) 明早验收的一键命令（build + tests）

使用仓库内固定脚本：

```bash
./scripts/run-local-ci.sh
```

脚本会按顺序执行：

1. `./scripts/check-localization.sh VibeCapture/Resources`
2. `./build.sh`
3. Unit tests（`VibeCapTests`，跳过 `PurchaseFlowTests` 与 `LibraryFlowIntegrationTests`）
4. Integration tests（`LibraryFlowIntegrationTests`）
5. UI tests（`VibeCapUITests`）

如需额外回归购买链路，可单独执行：

```bash
xcodebuild -scheme VibeCap -destination 'platform=macOS' test -only-testing:VibeCapTests/PurchaseFlowTests
```

如果 UI 测试环境报 `Timed out while enabling automation mode`，通常是当前系统会话无法进入自动化模式（非代码问题），请在可用的本地 GUI 会话下重跑该脚本。

### 6) Bundle ID / Product ID / `.storekit` 的关系（最容易混乱的点）

- **Bundle ID**（例如 `art.nanwang.VibeCap` 或 `com.luke.vibecapture`）是在 Xcode Target 的 `PRODUCT_BUNDLE_IDENTIFIER` 里设置的。
- **Product ID**（例如 `*.pro.monthly/yearly/lifetime`）是你在 App Store Connect（或 `.storekit`）里创建的商品标识。
- **规则**：
  - 代码里请求的 Product ID 必须和 `.storekit`（或 App Store Connect）里的 Product ID **完全一致**，否则价格会一直 Loading。
  - 最佳实践：Product ID 前缀与 Bundle ID 保持一致（方便长期维护与排查）。

### 7) 自动 Clear + Run（替代手动 Shift+Cmd+K / Cmd+R）

新增脚本：

```bash
./scripts/run-dev.sh
```

默认行为：

1. 关闭当前运行中的 VibeCap 进程（避免双开冲突）
2. 清理本地开发用 DerivedData（等效 Clear）
3. 用 `xcodebuild` 重新构建 Debug app
4. 自动启动构建出的 app（等效 Run）
5. 失败时自动重试 1 次

常用参数：

```bash
# 只 Clear + Build，不自动启动 app
./scripts/run-dev.sh --no-open

# 调整失败重试次数
./scripts/run-dev.sh --retry 2
```

说明：

- 你仍然可以随时手动使用 Xcode 的 `Shift+Cmd+K` 和 `Cmd+R`，两种方式并行不冲突。
- 作为默认开发约定：当 AI 完成会影响 app 行为的改动后，应优先执行 `./scripts/run-dev.sh`，不再要求你手动点 Run。

