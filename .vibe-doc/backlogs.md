# Backlogs

> 规则：
> - 人工维护需求定义与优先级
> - AI 维护执行状态、执行日志、测试与结果
> - 本文件是 backlog 单一真实来源

## 执行规则
- 优先级顺序：P0 > P1 > P2 > P3
- 选择规则：优先 `status=todo` 且 `blocked=no`
- WIP：同一时间仅 1 个 `doing`

---

## T-001 增加 Keep 的标记
- owner: human
- priority: P1
- status: todo
- blocked: no
- type: feature
- area: LIBRARY 模块
- description: 当用户对一个图片标记为 Keep 时，在图片上显示一个 Icon 标记，便于用户（尤其在图库中）识别该图片已被 Keep。
- depends_on: []
- acceptance:
  - [ ] 添加 Keep 时标志显示
  - [ ] 取消 Keep 时标志消失
- context_files: []
- runbook: []
- updated_at: 2025-03-12
- assignee: ai

### AI Execution Log
- start:
- finish:
- plan:
- changes:
- tests:
- artifacts:
- outcome:
