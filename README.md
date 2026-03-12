# VibeCap — 本地图库与截图管理

可复用的 AI Agent 工作流与规则仓库。

## 目标平台

- 当前目标平台：`macOS`
- 说明：本仓库采用单平台优先策略，不默认同时覆盖四端。

## 项目结构

```text
.
├── AGENTS.md
├── README.md
├── .agents/skills/
├── .agents/rules/
├── .agents/references/
├── .agents/scripts/
├── .vibe-doc/
```

## Skills 分组

- `00-start/`：`00-start/generate-project-docs`, `00-start/sync-claude-skills`
- `01-design/`：`01-design/01-new-project-prd`, `01-design/02-ia-user-flow`, `01-design/03-design-token`, `01-design/04-design-system-guide`, `01-design/05-architecture`, `01-design/06-product-spec`, `01-design/frontend-design`, `01-design/interactive-prototype`
- `02-develop/`：`02-develop/Localization`, `02-develop/systematic-debugging`
- `03-testing/`：`03-testing/00-toolchain-generator`, `03-testing/01-unit-test`, `03-testing/02-integration-test`, `03-testing/03-api-test`, `03-testing/04-ui-test`, `03-testing/05-snapshot-test`, `03-testing/06-e2e-test`, `03-testing/07-functional-test` ...
- `fastlane-appstore/`：`fastlane-appstore/01-fastlane-base-metadata-builder`, `fastlane-appstore/02-fastlane-metadata-localization`, `fastlane-appstore/03-fastlane-keyword-refinement`, `fastlane-appstore/04-fastlane-preflight-check`, `fastlane-appstore/05-fastlane-deploy`
- `release-audit/`：`release-audit`
- `commit-code/`：`commit-code`
- `requirements-clarification/`：`requirements-clarification`

## Skills 清单（按项目阶段顺序）

| 阶段 | Skill | 作用 | 触发关键词 | 路径 |
|---|---|---|---|---|
| `00-start` | `generate-project-docs` | 用于处理：生成 agents.md、生成 readme.md | 生成 agents.md、生成 readme.md | `.agents/skills/00-start/generate-project-docs/SKILL.md` |
| `00-start` | `sync-claude-skills` | 用于处理：同步 Claude skills、更新 Claude skills、更新 .claude 中的 SKILLS | 同步 Claude skills、更新 Claude skills、更新 .claude 中的 SKILLS | `.agents/skills/00-start/sync-claude-skills/SKILL.md` |
| `01-design` | `new-project-prd` | 用于处理：#新功能、#新项目、#创建PRD、#PRD、skip | #新功能、#新项目、#创建PRD、#PRD、skip | `.agents/skills/01-design/01-new-project-prd/SKILL.md` |
| `01-design` | `ia-user-flow` | 用于处理：#信息架构、#用户流程、#ia、#user-flow | #信息架构、#用户流程、#ia、#user-flow | `.agents/skills/01-design/02-ia-user-flow/SKILL.md` |
| `01-design` | `design-token-generator` | 用于处理：#创建design token、修改design token、#创建design、modify design token、修改 Design Token、调整颜色 | #创建design token、修改design token、#创建design、modify design token、修改 Design Token、调整颜色 | `.agents/skills/01-design/03-design-token/SKILL.md` |
| `01-design` | `design-system-guide` | 用于处理：UI design、UX design、design optimization、interface design、interaction design、visual design | UI design、UX design、design optimization、interface design、interaction design、visual design | `.agents/skills/01-design/04-design-system-guide/SKILL.md` |
| `01-design` | `architecture-design` | 用于处理：#architecture、#架构设计、continue architecture | #architecture、#架构设计、continue architecture | `.agents/skills/01-design/05-architecture/SKILL.md` |
| `01-design` | `product-spec` | 用于处理：#product spec、#生成 Product Spec、continue product spec、#product、#生成 | #product spec、#生成 Product Spec、continue product spec、#product、#生成 | `.agents/skills/01-design/06-product-spec/SKILL.md` |
| `01-design` | `frontend-design` | 用于执行 `frontend-design` 相关任务 | 见 SKILL.md | `.agents/skills/01-design/frontend-design/SKILL.md` |
| `01-design` | `interactive-prototype` | 用于处理：frontend-design | frontend-design | `.agents/skills/01-design/interactive-prototype/SKILL.md` |
| `02-develop` | `localization-handler` | 用于处理：#多语言补齐、#完善多语言、#新增多语言、补充多语言、完善多语言、新增多语言 | #多语言补齐、#完善多语言、#新增多语言、补充多语言、完善多语言、新增多语言 | `.agents/skills/02-develop/Localization/SKILL.md` |
| `02-develop` | `systematic-debugging` | 用于处理：#定位根因、#根本原因 | #定位根因、#根本原因 | `.agents/skills/02-develop/systematic-debugging/SKILL.md` |
| `03-testing` | `00-toolchain-generator` | 用于处理：generate test toolchain、initialize testing、set up tests | generate test toolchain、initialize testing、set up tests | `.agents/skills/03-testing/00-toolchain-generator/SKILL.md` |
| `03-testing` | `01-unit-test` | 用于执行 `01-unit-test` 相关任务 | 见 SKILL.md | `.agents/skills/03-testing/01-unit-test/SKILL.md` |
| `03-testing` | `02-integration-test` | 用于处理：done、complete、finished、wire up、connect、integrate | done、complete、finished、wire up、connect、integrate | `.agents/skills/03-testing/02-integration-test/SKILL.md` |
| `03-testing` | `03-api-test` | 用于处理：api test | api test | `.agents/skills/03-testing/03-api-test/SKILL.md` |
| `03-testing` | `04-ui-test` | 用于处理：#测UI、#test-ui、检查一下 UI、UI 有没有问题 | #测UI、#test-ui、检查一下 UI、UI 有没有问题 | `.agents/skills/03-testing/04-ui-test/SKILL.md` |
| `03-testing` | `05-snapshot-test` | 用于处理：#测UI | #测UI | `.agents/skills/03-testing/05-snapshot-test/SKILL.md` |
| `03-testing` | `06-e2e-test` | 用于处理：#测流程、#test-e2e、跑一下端到端测试、从头到尾走一遍 | #测流程、#test-e2e、跑一下端到端测试、从头到尾走一遍 | `.agents/skills/03-testing/06-e2e-test/SKILL.md` |
| `03-testing` | `07-functional-test` | 用于处理：#测流程、#test-e2e | #测流程、#test-e2e | `.agents/skills/03-testing/07-functional-test/SKILL.md` |
| `03-testing` | `08-smoke-test` | 用于处理：does it turn on without catching fire?、#准备发布、#pre-release、准备提审、最后检查一下、准备上架 | does it turn on without catching fire?、#准备发布、#pre-release、准备提审、最后检查一下、准备上架 | `.agents/skills/03-testing/08-smoke-test/SKILL.md` |
| `03-testing` | `09-acceptance-test` | 用于处理：#验收、#acceptance、对照 Spec 检查、check PRD、验收测试、complete | #验收、#acceptance、对照 Spec 检查、check PRD、验收测试、complete | `.agents/skills/03-testing/09-acceptance-test/SKILL.md` |
| `03-testing` | `10-performance-test` | 用于处理：#测性能、#test-perf、这个会不会卡、检查一下速度和内存、性能测试 | #测性能、#test-perf、这个会不会卡、检查一下速度和内存、性能测试 | `.agents/skills/03-testing/10-performance-test/SKILL.md` |
| `03-testing` | `11-accessibility-test` | 用于处理：#测无障碍、#test-a11y、VoiceOver 能用吗、accessibility 检查、无障碍测试 | #测无障碍、#test-a11y、VoiceOver 能用吗、accessibility 检查、无障碍测试 | `.agents/skills/03-testing/11-accessibility-test/SKILL.md` |
| `fastlane-appstore` | `fastlane-base-metadata-builder` | 用于执行 `fastlane-base-metadata-builder` 相关任务 | 见 SKILL.md | `.agents/skills/fastlane-appstore/01-fastlane-base-metadata-builder/SKILL.md` |
| `fastlane-appstore` | `fastlane-metadata-localization` | 用于执行 `fastlane-metadata-localization` 相关任务 | 见 SKILL.md | `.agents/skills/fastlane-appstore/02-fastlane-metadata-localization/SKILL.md` |
| `fastlane-appstore` | `fastlane-keyword-refinement` | 用于执行 `fastlane-keyword-refinement` 相关任务 | 见 SKILL.md | `.agents/skills/fastlane-appstore/03-fastlane-keyword-refinement/SKILL.md` |
| `fastlane-appstore` | `fastlane-preflight-check` | 用于执行 `fastlane-preflight-check` 相关任务 | 见 SKILL.md | `.agents/skills/fastlane-appstore/04-fastlane-preflight-check/SKILL.md` |
| `fastlane-appstore` | `fastlane-deploy` | 用于执行 `fastlane-deploy` 相关任务 | 见 SKILL.md | `.agents/skills/fastlane-appstore/05-fastlane-deploy/SKILL.md` |
| `release-audit` | `release-audit` | 见 SKILL.md 定义 | 见 SKILL.md | `.agents/skills/release-audit/SKILL.md` |
| `commit-code` | `commit-code` | 用于处理：feat、fix、refactor、docs、chore、perf | feat、fix、refactor、docs、chore、perf | `.agents/skills/commit-code/SKILL.md` |
| `requirements-clarification` | `requirement-clarification` | 用于处理：#需求对齐、#需求澄清 | #需求对齐、#需求澄清 | `.agents/skills/requirements-clarification/SKILL.md` |

## Rules 与 References

- `.agents/rules/`：共 4 个文件
- `.agents/references/`：共 22 个文件
- `.agents/scripts/`：共 3 个文件

## 文档生成约定

当用户说“生成 agents.md”或“生成 readme.md”时：
- 同时全量更新根目录 `AGENTS.md` 与 `README.md`
- 基于当前仓库真实结构重新生成
- 输出语言为中文，结构简洁
