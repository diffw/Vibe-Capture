# IAP 测试用例（完整版）

> **测试环境**：Xcode StoreKit Testing + `.storekit` 配置文件  
> **适用版本**：VibeCap 1.0.0+  
> **最后更新**：2026-01-23

---

## 目录

1. [测试前准备](#1-测试前准备)
2. [购买流程测试](#2-购买流程测试)
3. [恢复购买测试](#3-恢复购买测试)
4. [权益刷新测试](#4-权益刷新测试)
5. [权益叠加与优先级测试](#5-权益叠加与优先级测试)
6. [标注功能卡点测试](#6-标注功能卡点测试)
7. [自定义 App 卡点测试](#7-自定义-app-卡点测试)
8. [降级/升级数据规则测试](#8-降级升级数据规则测试)
9. [Paywall UI 测试](#9-paywall-ui-测试)
10. [数据迁移测试](#10-数据迁移测试)
11. [异常与边界测试](#11-异常与边界测试)
12. [本地化测试](#12-本地化测试)

---

## 1. 测试前准备

### 1.1 环境配置检查

| 编号 | 检查项 | 预期结果 | 通过 |
|------|--------|----------|:----:|
| P-001 | `.storekit` 文件已添加到 Xcode Scheme | Scheme → Run → Options → StoreKit Configuration 指向 `VibeCap.storekit` | ☐ |
| P-002 | Product ID 与代码一致 | `com.luke.vibecapture.pro.monthly/yearly/lifetime` | ☐ |
| P-003 | 清空 StoreKit 交易 | Xcode → Debug → StoreKit → Manage Transactions → 删除所有 | ☐ |
| P-004 | 清空 UserDefaults 缓存 | 删除 `IAPCachedProStatus`、`proUserWhitelistApps`、`freePinnedCustomApp` | ☐ |

### 1.2 初始状态验证

| 编号 | 测试步骤 | 预期结果 | 通过 |
|------|----------|----------|:----:|
| P-005 | 启动 App，检查 `EntitlementsService.shared.status` | `tier == .free`, `source == .none` | ☐ |
| P-006 | 检查 `CapabilityService.shared.canUse(.annotationsShapes)` | 返回 `false` | ☐ |
| P-007 | 检查 `CapabilityService.shared.canUse(.annotationsArrow)` | 返回 `true` | ☐ |

---

## 2. 购买流程测试

### 2.1 Monthly 订阅购买

| 编号 | 测试步骤 | 预期结果 | 通过 |
|------|----------|----------|:----:|
| BUY-001 | 打开 Paywall → 选择 Monthly → 点击购买 | 弹出 StoreKit 购买确认 | ☐ |
| BUY-002 | 确认购买 | 购买成功，状态更新 | ☐ |
| BUY-003 | 检查 `EntitlementsService.shared.status.tier` | `== .pro` | ☐ |
| BUY-004 | 检查 `EntitlementsService.shared.status.source` | `== .monthly` | ☐ |
| BUY-005 | 检查 `lastRefreshedAt` | 非空，时间为当前时间附近 | ☐ |
| BUY-006 | 检查 UserDefaults 缓存 | `IAPCachedProStatus` 已更新 | ☐ |
| BUY-007 | 检查 Paywall CTA 按钮 | 显示 "Already Pro"，按钮禁用 | ☐ |
| BUY-008 | 检查标注工具栏 Circle 按钮 | 无锁图标，点击可切换到 Circle 工具 | ☐ |

### 2.2 Yearly 订阅购买

| 编号 | 测试步骤 | 预期结果 | 通过 |
|------|----------|----------|:----:|
| BUY-009 | 清空交易 → 打开 Paywall → 选择 Yearly → 购买 | 购买成功 | ☐ |
| BUY-010 | 检查 `status.source` | `== .yearly` | ☐ |
| BUY-011 | 检查 Paywall "Yearly" 卡片的折扣计算 | 显示正确的节省百分比（对比 Monthly×12） | ☐ |

### 2.3 Lifetime 买断购买

| 编号 | 测试步骤 | 预期结果 | 通过 |
|------|----------|----------|:----:|
| BUY-012 | 清空交易 → 打开 Paywall → 选择 Lifetime → 购买 | 购买成功 | ☐ |
| BUY-013 | 检查 `status.source` | `== .lifetime` | ☐ |
| BUY-014 | 在 Transaction Manager 中验证交易类型 | Non-Consumable | ☐ |

### 2.4 用户取消购买

| 编号 | 测试步骤 | 预期结果 | 通过 |
|------|----------|----------|:----:|
| BUY-015 | 打开 Paywall → 选择任意商品 → 点击购买 → 取消 | 返回 Paywall，状态不变 | ☐ |
| BUY-016 | 检查 `status.tier` | 仍为 `.free` | ☐ |
| BUY-017 | 检查 Paywall statusLabel | 为空或显示空字符串 | ☐ |
| BUY-018 | 检查 App 不崩溃 | 无 crash | ☐ |

### 2.5 购买时网络/系统错误

| 编号 | 测试步骤 | 预期结果 | 通过 |
|------|----------|----------|:----:|
| BUY-019 | 在 `.storekit` 中启用 `_failTransactionsEnabled: true` | 配置生效 | ☐ |
| BUY-020 | 尝试购买 → 触发失败 | 显示 `paywall.error.generic` 错误提示 | ☐ |
| BUY-021 | 检查 `status.tier` | 仍为 `.free` | ☐ |
| BUY-022 | 恢复 `_failTransactionsEnabled: false` | 后续测试正常 | ☐ |

---

## 3. 恢复购买测试

### 3.1 有购买记录时恢复

| 编号 | 测试步骤 | 预期结果 | 通过 |
|------|----------|----------|:----:|
| RST-001 | 先完成一次 Lifetime 购买 | 购买成功 | ☐ |
| RST-002 | 清空 UserDefaults 中的 `IAPCachedProStatus` | 缓存清空 | ☐ |
| RST-003 | 重启 App | 状态应从 StoreKit 恢复为 Pro | ☐ |
| RST-004 | 或：点击 Paywall "Restore" 按钮 | 触发 `AppStore.sync()` | ☐ |
| RST-005 | 检查 `status` | `tier == .pro`, `source == .lifetime` | ☐ |

### 3.2 无购买记录时恢复

| 编号 | 测试步骤 | 预期结果 | 通过 |
|------|----------|----------|:----:|
| RST-006 | 清空所有 StoreKit 交易 | Transaction Manager 为空 | ☐ |
| RST-007 | 清空 UserDefaults 缓存 | 缓存清空 | ☐ |
| RST-008 | 点击 "Restore" 按钮 | 执行完成，无购买可恢复 | ☐ |
| RST-009 | 检查 `status.tier` | 仍为 `.free` | ☐ |
| RST-010 | 检查无错误提示（预期行为） | 无 alert 或显示"无购买记录" | ☐ |

### 3.3 恢复时网络失败

| 编号 | 测试步骤 | 预期结果 | 通过 |
|------|----------|----------|:----:|
| RST-011 | 断开网络（或模拟网络错误） | 网络不可用 | ☐ |
| RST-012 | 点击 "Restore" 按钮 | 显示错误提示 `paywall.error.generic` | ☐ |
| RST-013 | 检查 `status` | 保持上次已知状态（乐观离线） | ☐ |

---

## 4. 权益刷新测试

### 4.1 App 启动时刷新

| 编号 | 测试步骤 | 预期结果 | 通过 |
|------|----------|----------|:----:|
| REF-001 | 存在有效购买 → 启动 App | `EntitlementsService.start()` 被调用 | ☐ |
| REF-002 | 检查 `status` | 正确反映 StoreKit 中的交易状态 | ☐ |
| REF-003 | 检查 `lastRefreshedAt` | 更新为启动时间 | ☐ |

### 4.2 App 回到前台时刷新

| 编号 | 测试步骤 | 预期结果 | 通过 |
|------|----------|----------|:----:|
| REF-004 | App 进入后台 → 在 Transaction Manager 中添加交易 | 交易添加成功 | ☐ |
| REF-005 | App 回到前台 | 触发 `refreshEntitlements()` | ☐ |
| REF-006 | 检查 `status` | 反映新添加的交易 | ☐ |

### 4.3 Transaction.updates 实时更新

| 编号 | 测试步骤 | 预期结果 | 通过 |
|------|----------|----------|:----:|
| REF-007 | App 运行中 → 在 Transaction Manager 添加 Lifetime 交易 | 添加成功 | ☐ |
| REF-008 | 观察 `Transaction.updates` 是否触发 | `refreshEntitlements()` 被调用 | ☐ |
| REF-009 | 检查 UI 是否实时更新 | Paywall/标注工具栏等 UI 更新 | ☐ |

### 4.4 乐观离线策略

| 编号 | 测试步骤 | 预期结果 | 通过 |
|------|----------|----------|:----:|
| REF-010 | Pro 状态下 → 断开网络 → 重启 App | App 正常启动 | ☐ |
| REF-011 | 检查 `status` | 从缓存恢复，仍为 Pro | ☐ |
| REF-012 | 检查 Pro 功能是否可用 | 可用 | ☐ |
| REF-013 | `lastRefreshedAt` 可能更新（即使刷新失败） | 时间戳更新 | ☐ |

---

## 5. 权益叠加与优先级测试

### 5.1 买断优先级

| 编号 | 测试步骤 | 预期结果 | 通过 |
|------|----------|----------|:----:|
| PRI-001 | 先购买 Monthly 订阅 | `source == .monthly` | ☐ |
| PRI-002 | 再购买 Lifetime 买断 | `source == .lifetime` | ☐ |
| PRI-003 | 验证 Lifetime 优先 | `source == .lifetime`（非 `.monthly`） | ☐ |

### 5.2 订阅到期后买断仍有效

| 编号 | 测试步骤 | 预期结果 | 通过 |
|------|----------|----------|:----:|
| PRI-004 | 存在 Lifetime 买断 + Monthly 订阅 | 初始状态 Pro | ☐ |
| PRI-005 | 在 Transaction Manager 中删除/过期 Monthly 交易 | 订阅交易移除 | ☐ |
| PRI-006 | 触发 `refreshEntitlements()` | 刷新完成 | ☐ |
| PRI-007 | 检查 `status` | 仍为 `tier == .pro`, `source == .lifetime` | ☐ |

### 5.3 仅订阅时到期降级

| 编号 | 测试步骤 | 预期结果 | 通过 |
|------|----------|----------|:----:|
| PRI-008 | 仅有 Monthly 订阅（无 Lifetime） | `tier == .pro`, `source == .monthly` | ☐ |
| PRI-009 | 在 Transaction Manager 中删除订阅交易 | 交易移除 | ☐ |
| PRI-010 | 触发刷新 | 刷新完成 | ☐ |
| PRI-011 | 检查 `status` | `tier == .free`, `source == .none` | ☐ |

### 5.4 Yearly 优先于 Monthly

| 编号 | 测试步骤 | 预期结果 | 通过 |
|------|----------|----------|:----:|
| PRI-012 | 同时存在 Monthly 和 Yearly 订阅 | 两个交易都在 | ☐ |
| PRI-013 | 检查 `status.source` | `== .yearly`（Yearly 优先） | ☐ |

### 5.5 撤销（Revoke）交易

| 编号 | 测试步骤 | 预期结果 | 通过 |
|------|----------|----------|:----:|
| PRI-014 | 存在 Lifetime 购买 | Pro 状态 | ☐ |
| PRI-015 | 在 Transaction Manager 中 Refund 该交易 | 交易被撤销 | ☐ |
| PRI-016 | 触发刷新 | 刷新完成 | ☐ |
| PRI-017 | 检查 `status` | `tier == .free`（撤销后不再有效） | ☐ |

---

## 6. 标注功能卡点测试

### 6.1 Free 状态下标注工具

| 编号 | 测试步骤 | 预期结果 | 通过 |
|------|----------|----------|:----:|
| ANN-001 | Free 状态 → 打开截图 Modal | 工具栏显示 | ☐ |
| ANN-002 | 检查 Arrow 按钮 | 无锁图标，可点击，可绘制箭头 | ☐ |
| ANN-003 | 检查 Circle 按钮 | 显示小锁图标 | ☐ |
| ANN-004 | 点击 Circle 按钮 | 弹出 Paywall | ☐ |
| ANN-005 | 取消 Paywall → 检查状态 | 留在 Modal，Arrow 仍可用，无状态变化 | ☐ |
| ANN-006 | 检查 Rectangle 按钮 | 显示小锁图标 | ☐ |
| ANN-007 | 点击 Rectangle 按钮 | 弹出 Paywall | ☐ |
| ANN-008 | 检查 Number 按钮 | 显示小锁图标 | ☐ |
| ANN-009 | 点击 Number 按钮 | 弹出 Paywall | ☐ |
| ANN-010 | 检查颜色按钮 | 显示小锁图标 | ☐ |
| ANN-011 | 点击颜色按钮 | 弹出 Paywall | ☐ |
| ANN-012 | Free 状态下绘制箭头 | 默认红色，可绘制/移动/删除 | ☐ |
| ANN-013 | 点击 Clear All | 清空所有标注 | ☐ |

### 6.2 Pro 状态下标注工具

| 编号 | 测试步骤 | 预期结果 | 通过 |
|------|----------|----------|:----:|
| ANN-014 | Pro 状态 → 打开截图 Modal | 工具栏显示 | ☐ |
| ANN-015 | 检查 Circle 按钮 | 无锁图标 | ☐ |
| ANN-016 | 点击 Circle 按钮 | 切换到 Circle 工具，可绘制圆形 | ☐ |
| ANN-017 | 检查 Rectangle 按钮 | 无锁图标，可绘制矩形 | ☐ |
| ANN-018 | 检查 Number 按钮 | 无锁图标，可绘制编号 | ☐ |
| ANN-019 | 检查颜色按钮 | 无锁图标 | ☐ |
| ANN-020 | 点击颜色按钮 → 选择其他颜色 | 颜色切换成功，新标注使用新颜色 | ☐ |

### 6.3 降级时标注状态回退

| 编号 | 测试步骤 | 预期结果 | 通过 |
|------|----------|----------|:----:|
| ANN-021 | Pro 状态 → 选中 Circle 工具 | Circle 工具激活 | ☐ |
| ANN-022 | 选择非红色颜色（如蓝色） | 颜色为蓝色 | ☐ |
| ANN-023 | 模拟降级（删除交易 + 触发 `proStatusDidChange`） | 降级完成 | ☐ |
| ANN-024 | 检查当前工具 | 自动切换到 Arrow | ☐ |
| ANN-025 | 检查当前颜色 | 自动切换到 Red | ☐ |
| ANN-026 | 检查 Circle/Rectangle/Number/Color 按钮 | 显示锁图标 | ☐ |

---

## 7. 自定义 App 卡点测试

### 7.1 Free 状态下添加自定义 App

| 编号 | 测试步骤 | 预期结果 | 通过 |
|------|----------|----------|:----:|
| APP-001 | Free 状态 → 打开 AddAppPanel | 面板显示 | ☐ |
| APP-002 | 点击 "Choose from Applications..." | 打开 `/Applications` 文件选择器 | ☐ |
| APP-003 | 选择一个非白名单 App（如 "Notes.app"） | 弹出确认对话框 | ☐ |
| APP-004 | 确认对话框显示正确文案 | 显示 `gating.customApp.confirm.title/message` | ☐ |
| APP-005 | 点击 "Cancel" | 不添加，返回面板 | ☐ |
| APP-006 | 再次选择 → 点击 "Add" | 添加成功 | ☐ |
| APP-007 | 检查 `SettingsStore.shared.freePinnedCustomApp` | 非空，bundleID 正确 | ☐ |
| APP-008 | 检查 `proUserWhitelistApps` | 为空（Free 不写入 Pro 列表） | ☐ |
| APP-009 | 刷新 AddAppPanel 列表 | 新增 App 显示绿色勾选 | ☐ |

### 7.2 Free 状态下尝试添加第二个自定义 App

| 编号 | 测试步骤 | 预期结果 | 通过 |
|------|----------|----------|:----:|
| APP-010 | Free 状态 + 已有 `freePinnedCustomApp` | 已有一个自定义 App | ☐ |
| APP-011 | 再次点击 "Choose from Applications..." | 选择另一个 App | ☐ |
| APP-012 | 选择非白名单 App → 确认 | 弹出 Paywall（非确认对话框） | ☐ |
| APP-013 | 取消 Paywall | 返回面板，`freePinnedCustomApp` 不变 | ☐ |

### 7.3 Free 状态下选择官方白名单 App

| 编号 | 测试步骤 | 预期结果 | 通过 |
|------|----------|----------|:----:|
| APP-014 | Free 状态 → 选择官方白名单 App（如 "Cursor.app"） | 选择成功 | ☐ |
| APP-015 | 检查提示 | 显示 `gating.customApp.notCounted.title/message` | ☐ |
| APP-016 | 检查 `freePinnedCustomApp` | 未被占用（仍为 nil 或之前的值） | ☐ |

### 7.4 Free 状态下选择黑名单 App

| 编号 | 测试步骤 | 预期结果 | 通过 |
|------|----------|----------|:----:|
| APP-017 | Free 状态 → 选择 "Finder.app" | 选择成功 | ☐ |
| APP-018 | 检查提示 | 显示 `error.cannot_add_app` + `error.app_no_paste_support` | ☐ |
| APP-019 | 检查 `freePinnedCustomApp` | 未变化 | ☐ |

### 7.5 Free 状态下无法移除已添加的自定义 App

| 编号 | 测试步骤 | 预期结果 | 通过 |
|------|----------|----------|:----:|
| APP-020 | Free 状态 + 存在 `freePinnedCustomApp` | 已有自定义 App | ☐ |
| APP-021 | 在运行中 App 列表点击该 App 行 | 无反应（不触发移除） | ☐ |
| APP-022 | 检查 `freePinnedCustomApp` | 仍存在 | ☐ |

### 7.6 Pro 状态下添加/移除自定义 App

| 编号 | 测试步骤 | 预期结果 | 通过 |
|------|----------|----------|:----:|
| APP-023 | Pro 状态 → 打开 AddAppPanel | 面板显示 | ☐ |
| APP-024 | 选择非白名单 App | 直接添加（无确认对话框） | ☐ |
| APP-025 | 检查 `proUserWhitelistApps` | 包含新增 App | ☐ |
| APP-026 | 再添加另一个 App | 继续添加成功（无限制） | ☐ |
| APP-027 | 在列表中点击已添加的 App | 切换状态（取消添加/移除） | ☐ |
| APP-028 | 检查 `proUserWhitelistApps` | 该 App 已移除 | ☐ |

### 7.7 从运行中 App 列表添加

| 编号 | 测试步骤 | 预期结果 | 通过 |
|------|----------|----------|:----:|
| APP-029 | Free 状态 → AddAppPanel → 点击运行中的非白名单 App | 弹出确认 → 添加成功 | ☐ |
| APP-030 | Pro 状态 → AddAppPanel → 点击运行中的非白名单 App | 直接添加 | ☐ |
| APP-031 | 点击官方白名单 App | 提示不占名额 | ☐ |
| APP-032 | 点击黑名单 App | 提示不支持 | ☐ |

---

## 8. 降级/升级数据规则测试

### 8.1 Pro → Free 降级

| 编号 | 测试步骤 | 预期结果 | 通过 |
|------|----------|----------|:----:|
| MIG-001 | Pro 状态 → 添加 3 个自定义 App 到 `proUserWhitelistApps` | 添加成功 | ☐ |
| MIG-002 | 模拟降级（删除订阅交易，无 Lifetime） | 降级完成 | ☐ |
| MIG-003 | 检查 `proUserWhitelistApps` | 数据保留（未删除） | ☐ |
| MIG-004 | 检查 `userWhitelistApps(isPro: false)` | 返回空或仅 `freePinnedCustomApp` | ☐ |
| MIG-005 | 检查 `getRunningWhitelistedApps()` | 不包含 Pro 列表中的 App | ☐ |
| MIG-006 | 检查 Send List UI | Pro 列表 App 不显示 | ☐ |

### 8.2 Free → Pro 升级（合并 freePinnedCustomApp）

| 编号 | 测试步骤 | 预期结果 | 通过 |
|------|----------|----------|:----:|
| MIG-007 | Free 状态 → 添加 `freePinnedCustomApp`（如 "Notes"） | 添加成功 | ☐ |
| MIG-008 | 购买 Pro | 升级成功 | ☐ |
| MIG-009 | 检查 `userWhitelistApps(isPro: true)` | 包含之前的 pinned App | ☐ |
| MIG-010 | 检查 Send List UI | pinned App 可见 | ☐ |
| MIG-011 | 检查该 App 是否可移除 | Pro 下可移除（调用 `removeProUserWhitelistApp`） | ☐ |

### 8.3 合并去重

| 编号 | 测试步骤 | 预期结果 | 通过 |
|------|----------|----------|:----:|
| MIG-012 | Pro 状态 → 添加 "Notes" 到 `proUserWhitelistApps` | 添加成功 | ☐ |
| MIG-013 | 降级到 Free → 添加 "Notes" 为 `freePinnedCustomApp` | 添加成功 | ☐ |
| MIG-014 | 升级回 Pro | 升级成功 | ☐ |
| MIG-015 | 检查 `userWhitelistApps(isPro: true)` | "Notes" 只出现一次（去重） | ☐ |

---

## 9. Paywall UI 测试

### 9.1 Paywall 显示与布局

| 编号 | 测试步骤 | 预期结果 | 通过 |
|------|----------|----------|:----:|
| PAY-001 | 点击菜单栏 "Upgrade..." | Paywall 窗口显示 | ☐ |
| PAY-002 | 检查窗口标题 | 显示 `paywall.window_title` | ☐ |
| PAY-003 | 检查标题/副标题 | 显示 `paywall.title` / `paywall.subtitle` | ☐ |
| PAY-004 | 检查比较表格 | Free vs Pro 功能对比正确 | ☐ |
| PAY-005 | 检查 Monthly/Yearly/Lifetime 卡片 | 三个卡片都显示 | ☐ |
| PAY-006 | Yearly 卡片显示 "Recommended" 徽章 | 徽章可见 | ☐ |
| PAY-007 | 检查价格加载 | 显示从 StoreKit 加载的真实价格 | ☐ |

### 9.2 Paywall 交互

| 编号 | 测试步骤 | 预期结果 | 通过 |
|------|----------|----------|:----:|
| PAY-008 | 默认选中 Yearly 卡片 | Yearly 卡片高亮 | ☐ |
| PAY-009 | 点击 Monthly 卡片 | Monthly 卡片高亮，Yearly 取消高亮 | ☐ |
| PAY-010 | 点击 Lifetime 卡片 | Lifetime 卡片高亮 | ☐ |
| PAY-011 | CTA 按钮文案随选择变化 | 显示对应商品信息 | ☐ |
| PAY-012 | 点击 "Restore" | 触发 `AppStore.sync()` | ☐ |
| PAY-013 | 点击 "Manage Subscriptions" | 打开 Apple 订阅管理页面 | ☐ |
| PAY-014 | 点击 "Close" | 关闭 Paywall 窗口 | ☐ |
| PAY-015 | 点击 "Terms" | 打开条款 URL | ☐ |
| PAY-016 | 点击 "Privacy" | 打开隐私政策 URL | ☐ |

### 9.3 Pro 状态下 Paywall

| 编号 | 测试步骤 | 预期结果 | 通过 |
|------|----------|----------|:----:|
| PAY-017 | Pro 状态 → 打开 Paywall | 窗口显示 | ☐ |
| PAY-018 | CTA 按钮文案 | 显示 "Already Pro" | ☐ |
| PAY-019 | CTA 按钮状态 | 禁用（不可点击） | ☐ |
| PAY-020 | statusLabel | 显示 `paywall.status.already_pro` | ☐ |

### 9.4 Paywall 层级

| 编号 | 测试步骤 | 预期结果 | 通过 |
|------|----------|----------|:----:|
| PAY-021 | 从截图 Modal 中触发 Paywall | Paywall 显示在 Modal 上方 | ☐ |
| PAY-022 | Paywall 窗口可拖动 | 可移动位置 | ☐ |
| PAY-023 | Paywall 保持最前 | 点击其他窗口后 Paywall 仍在前 | ☐ |

---

## 10. 数据迁移测试

### 10.1 从旧版本迁移

| 编号 | 测试步骤 | 预期结果 | 通过 |
|------|----------|----------|:----:|
| LEG-001 | 模拟旧版本数据：写入 `userWhitelistApps` (legacy key) | 数据写入成功 | ☐ |
| LEG-002 | 确保 `proUserWhitelistApps` 和 `didMigrateUserWhitelistAppsToPro` 为空 | 新字段为空 | ☐ |
| LEG-003 | 初始化 `SettingsStore.shared`（触发迁移） | `migrateLegacyWhitelistIfNeeded()` 执行 | ☐ |
| LEG-004 | 检查 `proUserWhitelistApps` | 包含旧 `userWhitelistApps` 的数据 | ☐ |
| LEG-005 | 检查 `didMigrateUserWhitelistAppsToPro` | 为 `true` | ☐ |
| LEG-006 | 再次初始化 SettingsStore | 不重复迁移 | ☐ |

### 10.2 迁移不覆盖已有数据

| 编号 | 测试步骤 | 预期结果 | 通过 |
|------|----------|----------|:----:|
| LEG-007 | `proUserWhitelistApps` 已有数据 + `userWhitelistApps` (legacy) 有不同数据 | 两者数据不同 | ☐ |
| LEG-008 | 确保 `didMigrateUserWhitelistAppsToPro` 为 `false` | 未迁移 | ☐ |
| LEG-009 | 触发迁移 | 迁移执行 | ☐ |
| LEG-010 | 检查 `proUserWhitelistApps` | 保持原数据（未被覆盖） | ☐ |

---

## 11. 异常与边界测试

### 11.1 产品加载失败

| 编号 | 测试步骤 | 预期结果 | 通过 |
|------|----------|----------|:----:|
| ERR-001 | 在 `.storekit` 中删除所有产品 | 产品为空 | ☐ |
| ERR-002 | 打开 Paywall | 显示 "Loading..." 或错误提示 | ☐ |
| ERR-003 | 检查 App 不崩溃 | 无 crash | ☐ |
| ERR-004 | 恢复 `.storekit` 产品配置 | 后续测试正常 | ☐ |

### 11.2 Product ID 不匹配

| 编号 | 测试步骤 | 预期结果 | 通过 |
|------|----------|----------|:----:|
| ERR-005 | 在代码中临时修改 Product ID（与 `.storekit` 不一致） | ID 不匹配 | ☐ |
| ERR-006 | 尝试加载产品 | `Product.products(for:)` 返回空 | ☐ |
| ERR-007 | Paywall 显示 "Loading..." | 无崩溃 | ☐ |

### 11.3 交易验证失败

| 编号 | 测试步骤 | 预期结果 | 通过 |
|------|----------|----------|:----:|
| ERR-008 | 模拟 `VerificationResult.unverified` | 验证失败 | ☐ |
| ERR-009 | 检查交易被拒绝 | 不更新 Pro 状态 | ☐ |
| ERR-010 | 检查错误处理 | 无崩溃，可能显示错误提示 | ☐ |

### 11.4 并发刷新

| 编号 | 测试步骤 | 预期结果 | 通过 |
|------|----------|----------|:----:|
| ERR-011 | 同时触发多次 `refreshEntitlements()` | 并发执行 | ☐ |
| ERR-012 | 检查最终状态一致性 | 状态正确，无数据竞争 | ☐ |
| ERR-013 | 检查无崩溃 | 无 crash | ☐ |

### 11.5 App 被强制退出后重启

| 编号 | 测试步骤 | 预期结果 | 通过 |
|------|----------|----------|:----:|
| ERR-014 | Pro 状态 → 强制退出 App（`kill -9`） | App 终止 | ☐ |
| ERR-015 | 重启 App | 正常启动 | ☐ |
| ERR-016 | 检查 `status` | 从缓存恢复，然后刷新确认 | ☐ |

---

## 12. 本地化测试

### 12.1 Paywall 本地化

| 编号 | 测试步骤 | 预期结果 | 通过 |
|------|----------|----------|:----:|
| L10N-001 | 切换系统语言为英文 → 打开 Paywall | 所有文案为英文 | ☐ |
| L10N-002 | 切换系统语言为简体中文 → 打开 Paywall | 所有文案为简体中文 | ☐ |
| L10N-003 | 检查 `paywall.title` | 正确翻译 | ☐ |
| L10N-004 | 检查 `paywall.subtitle` | 正确翻译 | ☐ |
| L10N-005 | 检查商品价格格式 | 符合当地货币格式 | ☐ |

### 12.2 卡点提示本地化

| 编号 | 测试步骤 | 预期结果 | 通过 |
|------|----------|----------|:----:|
| L10N-006 | Free 状态 → 添加自定义 App → 检查确认对话框 | 文案正确翻译 | ☐ |
| L10N-007 | 选择官方白名单 App → 检查提示 | `gating.customApp.notCounted.*` 正确翻译 | ☐ |
| L10N-008 | 选择黑名单 App → 检查提示 | `error.cannot_add_app` 正确翻译 | ☐ |

### 12.3 StoreKit 产品本地化

| 编号 | 测试步骤 | 预期结果 | 通过 |
|------|----------|----------|:----:|
| L10N-009 | 检查 `.storekit` 中 `zh_Hans` 本地化 | 存在中文产品名和描述 | ☐ |
| L10N-010 | 切换系统语言为简体中文 → 检查 Paywall 商品名 | 显示中文商品名 | ☐ |

---

## 测试通过标准

### 必须全部通过（阻塞提交）

- [ ] 所有 `BUY-*` 测试用例
- [ ] 所有 `RST-*` 测试用例
- [ ] 所有 `REF-*` 测试用例
- [ ] 所有 `PRI-*` 测试用例
- [ ] 所有 `ANN-*` 测试用例
- [ ] 所有 `APP-*` 测试用例
- [ ] 所有 `MIG-*` 测试用例
- [ ] 所有 `PAY-*` 测试用例

### 建议通过（不阻塞提交但强烈建议）

- [ ] 所有 `LEG-*` 测试用例（数据迁移）
- [ ] 所有 `ERR-*` 测试用例（异常处理）
- [ ] 所有 `L10N-*` 测试用例（本地化）

---

## 附录：StoreKit Transaction Manager 操作指南

### 打开 Transaction Manager

```
Xcode → Debug → StoreKit → Manage Transactions
```

### 常用操作

| 操作 | 用途 |
|------|------|
| Delete Transaction | 模拟订阅到期/删除购买 |
| Refund Transaction | 模拟退款（触发 `revocationDate`） |
| Add Transaction | 手动添加测试交易 |
| Enable/Disable Subscription | 模拟续费/取消续费 |

### 快速重置测试环境

```bash
# 清空 App 的 UserDefaults（需要 App 的 Bundle ID）
defaults delete com.luke.vibecapture
```

---

## Change Log

### 2026-01-23
- 初始版本：完整 IAP 测试用例（12 章、~150 个测试点）
