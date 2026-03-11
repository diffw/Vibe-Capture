---
name: 10-performance-test
description: Defines performance test methodology. Measures speed, memory usage, CPU usage, and other performance metrics to ensure the product is fast and resource-efficient. Triggered by "#测性能", "#test-perf", or related natural language like "这个会不会卡", "检查一下速度和内存". Must be used together with platform-specific toolchain in .cursor/skills/testing/toolchain/performance-[platform].md.
---

# Performance Test

 ⚠️ When executing this skill, you MUST also load the corresponding `.cursor/skills/testing/toolchain/performance-*.md` file for the current project's platform. If that file does not exist, prompt the user: "No performance test toolchain config found. Should I run the toolchain generator first?"

---

## What Is a Performance Test

A performance test measures how fast, efficient, and resource-friendly the application is. It answers: **"Is this fast enough? Does it use too much memory/CPU?"**

- ✅ Measure execution time of critical operations
- ✅ Measure memory usage and detect leaks
- ✅ Measure CPU usage during operations
- ✅ Establish baselines and detect regressions
- ❌ NOT testing correctness (that's unit/functional)
- ❌ NOT testing UI behavior (that's UI test)

---

## When to Run Performance Tests

Triggered by: **#测性能**, **#test-perf**, or natural language like "性能测试", "这个会不会卡", "检查一下速度和内存"

Run performance tests when:
1. Implementing operations that process large data (images, files)
2. Features that run frequently (hotkey triggers, event listeners)
3. Suspected performance issues reported by users
4. Before release to establish performance baselines
5. After optimization work to verify improvements

---

## What to Measure

### 1. Execution Time (required for critical operations)

Measure wall-clock time for:
- Core operations (screenshot capture, image crop, file save)
- UI operations (modal open, view render, animation)
- Data operations (load, transform, save)

### 2. Memory Usage (required)

- Peak memory during operation
- Memory after operation (should return near baseline)
- Memory leak detection (run operation 100x, memory should be stable)

### 3. CPU Usage (when applicable)

- CPU spike during operation
- Idle CPU usage (menu bar app should be near 0%)
- Background CPU usage

### 4. App Metrics (when applicable)

- App launch time (cold start, warm start)
- Time to interactive
- Frame rate during animations

---

## Baseline System

### Establishing Baselines

First time running performance tests:
```
Step 1 → Run each performance test 5 times
Step 2 → Calculate average and standard deviation
Step 3 → Set baseline = average
Step 4 → Set threshold = baseline + 2 standard deviations (or +20%, whichever is larger)
Step 5 → Store baselines in performance baseline file
```

### Comparing Against Baselines

Subsequent runs:
```
If result ≤ baseline → ✅ PASS (same or better)
If result ≤ threshold → ⚠️ WARNING (slightly degraded)
If result > threshold → ❌ FAIL (performance regression)
```

---

## Test Naming Convention

```
test_perf_[operation]_[metric]
```

Examples:
```
test_perf_screenshotCapture_executionTime
test_perf_imageCrop5KFullscreen_executionTime
test_perf_imageCrop5KFullscreen_peakMemory
test_perf_annotationRender100Arrows_frameRate
test_perf_appLaunch_coldStartTime
test_perf_idleMenuBar_cpuUsage
test_perf_captureFlow100Repeats_memoryLeak
```

---

## Performance Budgets

Define acceptable limits for critical operations:

```
| Operation | Metric | Budget | Rationale |
|-----------|--------|--------|-----------|
| Screen capture | Time | < 200ms | User-perceived instant |
| Image crop (5K) | Time | < 500ms | Acceptable wait |
| Modal open | Time | < 100ms | Feels instant |
| App launch | Time | < 1s | User expectation |
| Idle memory | Memory | < 50MB | Menu bar app, minimal footprint |
| Capture peak | Memory | < 200MB | 5K image processing |
```

Ask the user to confirm or adjust budgets:
```
⚡ Suggested performance budgets for [product]:
   [table above]
   Want me to use these, or adjust any thresholds?
```

---

## Anti-Patterns to Avoid

| ❌ Anti-Pattern | ✅ Correct Approach |
|----------------|-------------------|
| Run performance test once and trust the result | Run 5+ times, use average |
| No baselines | Establish baselines on first run |
| Test on debug build | Always test on release/optimized build |
| Ignore memory leaks | Run repeated operations and check stability |
| Hard-code expected values | Use baseline + threshold system |
| Mix performance and functional assertions | Separate performance tests from functional tests |

---

## Test Execution Workflow

When triggered by #测性能 or related keywords:

```
Step 1 → Identify operations to measure
Step 2 → Check if performance baselines exist
          - If NO → establish baselines (5 runs each)
          - If YES → run and compare against baselines
Step 3 → Run performance tests (5 iterations each)
Step 4 → Report results:

          ⚡ Performance Tests: [feature/operation]
          ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
          | Operation | Metric | Result | Baseline | Status |
          |-----------|--------|--------|----------|--------|
          | Capture | Time | 150ms | 160ms | ✅ |
          | Crop 5K | Time | 480ms | 450ms | ⚠️ |
          | Crop 5K | Memory | 250MB | 180MB | ❌ |
          ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
          ❌ Regressions: [list]
          💡 Suggestions: [optimization recommendations if any]

Step 5 → If any regression found → follow Test Failure Protocol
```

---

## File Organization

```
# Swift
PerformanceTests.swift
PerformanceBaselines.json        ← stored baselines

# TypeScript
performance.test.ts
performance-baselines.json       ← stored baselines
```