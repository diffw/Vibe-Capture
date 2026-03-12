# AGENTS.md — VibeCap — 本地图库与截图管理 Agent Context Router

## 项目概要

VibeCap — 本地图库与截图管理：可复用的 AI Agent 工作流与规则仓库。

## 目标平台（单平台）

- 当前项目目标平台：`macOS`
- 仅对目标平台生成实现、测试与发布方案；非目标平台默认不展开。

## 模块总览

| 模块 | 路径 | 说明 |
|---|---|---|
| Skills | `.agents/skills/` | Agent workflow 能力定义 |
| Rules | `.agents/rules/` | 开发规范与测试规则 |
| References | `.agents/references/` | 技术与设计参考文档 |
| Scripts | `.agents/scripts/` | 自动化脚本与工具 |
| Product Docs | `.vibe-doc/` | 产品与设计过程文档 |

## 包含的 Skills（按实际扫描）

| Skill | 路径 | 用途 | 触发关键词 |
|---|---|---|---|
| `generate-project-docs` | `.agents/skills/00-start/generate-project-docs/SKILL.md` | 用于处理：生成 agents.md、生成 readme.md | 生成 agents.md、生成 readme.md |
| `sync-claude-skills` | `.agents/skills/00-start/sync-claude-skills/SKILL.md` | 用于处理：同步 Claude skills、更新 Claude skills、更新 .claude 中的 SKILLS | 同步 Claude skills、更新 Claude skills、更新 .claude 中的 SKILLS |
| `new-project-prd` | `.agents/skills/01-design/01-new-project-prd/SKILL.md` | 用于处理：#新功能、#新项目、#创建PRD、#PRD、skip | #新功能、#新项目、#创建PRD、#PRD、skip |
| `ia-user-flow` | `.agents/skills/01-design/02-ia-user-flow/SKILL.md` | 用于处理：#信息架构、#用户流程、#ia、#user-flow | #信息架构、#用户流程、#ia、#user-flow |
| `design-token-generator` | `.agents/skills/01-design/03-design-token/SKILL.md` | 用于处理：#创建design token、修改design token、#创建design、modify design token、修改 Design Token、调整颜色 | #创建design token、修改design token、#创建design、modify design token、修改 Design Token、调整颜色 |
| `design-system-guide` | `.agents/skills/01-design/04-design-system-guide/SKILL.md` | 用于处理：UI design、UX design、design optimization、interface design、interaction design、visual design | UI design、UX design、design optimization、interface design、interaction design、visual design |
| `architecture-design` | `.agents/skills/01-design/05-architecture/SKILL.md` | 用于处理：#architecture、#架构设计、continue architecture | #architecture、#架构设计、continue architecture |
| `product-spec` | `.agents/skills/01-design/06-product-spec/SKILL.md` | 用于处理：#product spec、#生成 Product Spec、continue product spec、#product、#生成 | #product spec、#生成 Product Spec、continue product spec、#product、#生成 |
| `frontend-design` | `.agents/skills/01-design/frontend-design/SKILL.md` | 用于执行 `frontend-design` 相关任务 | 见 SKILL.md |
| `interactive-prototype` | `.agents/skills/01-design/interactive-prototype/SKILL.md` | 用于处理：frontend-design | frontend-design |
| `localization-handler` | `.agents/skills/02-develop/Localization/SKILL.md` | 用于处理：#多语言补齐、#完善多语言、#新增多语言、补充多语言、完善多语言、新增多语言 | #多语言补齐、#完善多语言、#新增多语言、补充多语言、完善多语言、新增多语言 |
| `systematic-debugging` | `.agents/skills/02-develop/systematic-debugging/SKILL.md` | 用于处理：#定位根因、#根本原因 | #定位根因、#根本原因 |
| `00-toolchain-generator` | `.agents/skills/03-testing/00-toolchain-generator/SKILL.md` | 用于处理：generate test toolchain、initialize testing、set up tests | generate test toolchain、initialize testing、set up tests |
| `01-unit-test` | `.agents/skills/03-testing/01-unit-test/SKILL.md` | 用于执行 `01-unit-test` 相关任务 | 见 SKILL.md |
| `02-integration-test` | `.agents/skills/03-testing/02-integration-test/SKILL.md` | 用于处理：done、complete、finished、wire up、connect、integrate | done、complete、finished、wire up、connect、integrate |
| `03-api-test` | `.agents/skills/03-testing/03-api-test/SKILL.md` | 用于处理：api test | api test |
| `04-ui-test` | `.agents/skills/03-testing/04-ui-test/SKILL.md` | 用于处理：#测UI、#test-ui、检查一下 UI、UI 有没有问题 | #测UI、#test-ui、检查一下 UI、UI 有没有问题 |
| `05-snapshot-test` | `.agents/skills/03-testing/05-snapshot-test/SKILL.md` | 用于处理：#测UI | #测UI |
| `06-e2e-test` | `.agents/skills/03-testing/06-e2e-test/SKILL.md` | 用于处理：#测流程、#test-e2e、跑一下端到端测试、从头到尾走一遍 | #测流程、#test-e2e、跑一下端到端测试、从头到尾走一遍 |
| `07-functional-test` | `.agents/skills/03-testing/07-functional-test/SKILL.md` | 用于处理：#测流程、#test-e2e | #测流程、#test-e2e |
| `08-smoke-test` | `.agents/skills/03-testing/08-smoke-test/SKILL.md` | 用于处理：does it turn on without catching fire?、#准备发布、#pre-release、准备提审、最后检查一下、准备上架 | does it turn on without catching fire?、#准备发布、#pre-release、准备提审、最后检查一下、准备上架 |
| `09-acceptance-test` | `.agents/skills/03-testing/09-acceptance-test/SKILL.md` | 用于处理：#验收、#acceptance、对照 Spec 检查、check PRD、验收测试、complete | #验收、#acceptance、对照 Spec 检查、check PRD、验收测试、complete |
| `10-performance-test` | `.agents/skills/03-testing/10-performance-test/SKILL.md` | 用于处理：#测性能、#test-perf、这个会不会卡、检查一下速度和内存、性能测试 | #测性能、#test-perf、这个会不会卡、检查一下速度和内存、性能测试 |
| `11-accessibility-test` | `.agents/skills/03-testing/11-accessibility-test/SKILL.md` | 用于处理：#测无障碍、#test-a11y、VoiceOver 能用吗、accessibility 检查、无障碍测试 | #测无障碍、#test-a11y、VoiceOver 能用吗、accessibility 检查、无障碍测试 |
| `fastlane-base-metadata-builder` | `.agents/skills/fastlane-appstore/01-fastlane-base-metadata-builder/SKILL.md` | 用于执行 `fastlane-base-metadata-builder` 相关任务 | 见 SKILL.md |
| `fastlane-metadata-localization` | `.agents/skills/fastlane-appstore/02-fastlane-metadata-localization/SKILL.md` | 用于执行 `fastlane-metadata-localization` 相关任务 | 见 SKILL.md |
| `fastlane-keyword-refinement` | `.agents/skills/fastlane-appstore/03-fastlane-keyword-refinement/SKILL.md` | 用于执行 `fastlane-keyword-refinement` 相关任务 | 见 SKILL.md |
| `fastlane-preflight-check` | `.agents/skills/fastlane-appstore/04-fastlane-preflight-check/SKILL.md` | 用于执行 `fastlane-preflight-check` 相关任务 | 见 SKILL.md |
| `fastlane-deploy` | `.agents/skills/fastlane-appstore/05-fastlane-deploy/SKILL.md` | 用于执行 `fastlane-deploy` 相关任务 | 见 SKILL.md |
| `release-audit` | `.agents/skills/release-audit/SKILL.md` | 见 SKILL.md 定义 | 见 SKILL.md |
| `commit-code` | `.agents/skills/commit-code/SKILL.md` | 用于处理：feat、fix、refactor、docs、chore、perf | feat、fix、refactor、docs、chore、perf |
| `requirement-clarification` | `.agents/skills/requirements-clarification/SKILL.md` | 用于处理：#需求对齐、#需求澄清 | #需求对齐、#需求澄清 |

## 上下文加载规则（按需读取）

1. 先读任务相关 `.agents/rules/`，再读对应 `.agents/skills/**/SKILL.md`。
2. 仅在 Skill 明确引用时读取 `.agents/references/`。
3. 完成修改后必须执行相关测试/校验命令并报告结果。
4. Skill 路由以 `.agents/skills/**/SKILL.md` 为唯一准源，不在本文件维护重复映射。

## 完成标准（Definition of Done）

- 变更与需求一致，无未解释偏差。
- 相关测试已执行并给出真实结果。
- 路径引用有效，文档与实际结构一致。
- 不提交系统垃圾文件（如 `.DS_Store`）。

## 压缩恢复（Compaction Recovery）

1. 重新读取 `AGENTS.md`。
2. 重新读取当前任务计划（如有）。
3. 重新读取正在编辑的关键文件与相关规则/技能。
