# VibeCap Library Acceptance Matrix

> Scope freeze for `full_prd` acceptance.
> Source of truth: `.vibe-doc/library-ia-flow.md` + `.vibe-doc/PRD-library.md`

## Acceptance Checklist (F-01 ~ F-11)

| Flow ID | Flow Name | Required Behavior | Implementation Status | Test Coverage | Notes |
|---|---|---|---|---|---|
| F-01 | 设定截图目录（已有能力） | Missing/stale folder path triggers folder picker and persists bookmark | Completed | Existing + regression | Reuse `ScreenshotSaveService` |
| F-02 | 浏览截图（网格/列表） | Open Library, switch grid/list, browse history | Completed | Unit + UI | `LibraryWindowController` + grid/list persisted |
| F-03 | 大图浏览与左右切换 | Click item -> modal viewer with prev/next/close | Completed | UI | `ImageViewerWindowController` + ←/→/Esc |
| F-04 | 保存并保留（Keep） | Capture preview supports save-and-keep path | Completed | Unit + UI | Capture modal + preview both support Keep path |
| F-05 | 图库中保留/取消保留 | Keep toggle in Library and viewer with immediate feedback | Completed | Unit + UI | Keep state syncs across list/viewer/filter |
| F-06 | 设置自动清理 | Toggle + interval (24h/7d/15d/30d/60d), persisted settings | Completed | Unit + UI | Pro-gated settings + interval persistence |
| F-07 | 自动清理执行与提示 | Timed/launch cleanup deletes expired unkept files to Trash and reports results | Completed | Unit + Integration | Scheduler + launch compensation + Keep exclusion |
| F-08 | 手动删除截图 | Delete confirmation -> move to system Trash | Completed | Unit + UI | Library + viewer both move to Trash |
| F-09 | 菜单栏 Upgrade 入口 | Upgrade entry opens paywall and purchase flow | Existing | Existing UI tests | Keep behavior unchanged |
| F-10 | 复制图片到剪贴板 | Copy action available in Library/viewer (+ keyboard support) | Completed | Unit + UI | Copy button + ⌘C in viewer |
| F-11 | 自动清理入口触发付费墙并升级 | Non-Pro cleanup entry shows paywall; purchase returns user to cleanup settings | Completed | Integration + UI | Pending navigation state + Pro status observer |

## Execution Gates

- Gate A: `F-02` + `F-03` usable from menu + Dock + preview entry.
- Gate B: `F-04` + `F-05` + `F-08` + `F-10` complete in Library/viewer.
- Gate C: `F-06` + `F-07` + `F-11` complete with Pro gate.
- Gate D: one-command local automation (`scripts/run-local-ci.sh`) configured and full pass verified (`Unit 84/84`, `Integration 2/2`, `UI 21/21`).

