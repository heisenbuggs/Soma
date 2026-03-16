# Soma

A local-only iOS 17+ app that reads Apple Health data via HealthKit and computes four daily scores — **Recovery**, **Strain**, **Sleep**, and **Stress** — displayed on a modern SwiftUI dark-mode dashboard.

No backend. No accounts. No network calls. Everything runs on-device.

---

## Features

### Four Core Scores

| Score    | Range | What it measures |
|----------|-------|-----------------|
| Recovery | 0–100 | Readiness to perform: HRV, resting HR, sleep quality, and prior strain |
| Strain   | 0–100 | Cardiovascular load relative to personal capacity (heart-rate zone model) |
| Sleep    | 0–100 | 5-component quality score: duration, stages, sleeping HRV/HR, interruptions |
| Stress   | 0–100 | Autonomic stress estimated from daytime HRV and heart rate |

Each score has a 5-tier category system displayed consistently across charts and insight cards:

| Tier        | Recovery | Strain   | Sleep    | Stress   | Color      |
|-------------|----------|----------|----------|----------|------------|
| Excellent   | 85–100   | —        | 90–100   | 0–20     | Green      |
| Good        | 70–84    | 0–19     | 75–89    | 21–40    | Light Green|
| Fair/Light  | 50–69    | 20–39    | 60–74    | 41–60    | Yellow     |
| Low/Moderate| 30–49    | 40–59    | 40–59    | 61–80    | Orange     |
| Very Low    | 0–29     | 60–79    | 0–39     | 81–100   | Red        |

---

### Strain Score Formula

Strain is calculated using a cardiovascular zone-load model:

**Step 1 — HR Zone Classification** (MaxHR % thresholds):

| Zone | % of Max HR | Weight |
|------|-------------|--------|
| Z1   | < 60%       | 1.0    |
| Z2   | 60–70%      | 2.0    |
| Z3   | 70–80%      | 3.0    |
| Z4   | 80–90%      | 4.0    |
| Z5   | ≥ 90%       | 5.0    |

**Step 2 — StrainLoad** (raw zone-weighted minutes):
```
StrainLoad = Σ (minutes in zone × zone weight)
```

**Step 3 — Personal Capacity** (rolling 14-day average of StrainLoad):
- During the first 7 days: capacity defaults to 350 (estimated calibration value)
- After 7 days: `Capacity = average(last 14 days of StrainLoad)`

**Step 4 — StrainScore**:
```
StrainScore = min(100, StrainLoad / Capacity × 100)
```

**Workout-aware calculation**: The algorithm separates workout intervals from incidental activity and sums both. Heart rate samples during workout windows are weighted using the same zone model.

---

### Sleep Score Formula (5 components)

| Component      | Weight | Calculation |
|----------------|--------|-------------|
| Duration       | 30%    | `min(100, T/N × 100)` — T = total sleep, N = personalised sleep need |
| Stage mix      | 30%    | `0.40×deep + 0.40×REM + 0.20×core` vs optimal ratios (20% / 22% / 50%) |
| Sleeping HRV   | 15%    | Ratio vs 30-day HRV baseline; higher = better |
| Sleeping HR    | 15%    | Ratio vs baseline; lower = better |
| Interruptions  | 10%    | `max(0, 100 − awake_segments × 15)` |

**Sleep Need**: baseline sleep goal + sleep debt (3-day rolling, capped at 2 h/night) + strain factor (up to +1 h at max strain).

---

### Recovery Score Formula

```
Recovery = 0.40 × HRV_score + 0.25 × RHR_score + 0.25 × Sleep_score + 0.10 × Strain_recovery
```

---

## Architecture

### Data Flow

```
Apple Health (HealthKit)
  └── HealthKitManager  (HealthDataProviding protocol)
        └── DashboardViewModel
              ├── Calculators (pure functions, no state)
              │     ├── StrainCalculator    → StrainLoad + StrainScore
              │     ├── SleepCalculator     → SleepScore + SleepNeed
              │     ├── RecoveryCalculator  → RecoveryScore
              │     └── StressCalculator    → StressScore
              ├── MetricsStore             → UserDefaults (90-day window)
              └── InsightCache.invalidatePhysio()

CheckInStore (UserDefaults + Codable)
  ├── CheckInViewModel
  │     ├── CheckInStore.save()
  │     ├── HealthKitManager.writeBehavioralData()
  │     └── InsightCache.invalidateBehavior()
  ├── DashboardViewModel  → BehaviorEngine.coachingTips()
  └── InsightsViewModel   → BehaviorEngine.generateInsights()

InsightCache (UserDefaults + Codable)
  ├── InsightsViewModel.generateInsights(forceRefresh:)
  └── BackgroundTaskManager → BGTaskScheduler
```

---

### Insight Engine Architecture

Insights are computed once and cached. They are never recomputed on every app launch.

**Cache-first loading (InsightsViewModel)**:
1. Check staleness for physio cache and behavior cache independently
2. If fresh: load cached `[Insight]` / `[BehaviorInsight]` from UserDefaults — instant, zero compute
3. If stale: recompute, save to cache, update UI

**Staleness rules**:

| Cache      | Stale when |
|------------|-----------|
| Physio     | No cache exists, OR cache is from a previous calendar day, OR new metrics were saved after the cache was built |
| Behavior   | No cache exists, OR a new check-in was submitted after the cache was built |

**Cache invalidation triggers**:
- `DashboardViewModel.fetchAllMetrics()` → `InsightCache.shared.invalidatePhysio()` after saving metrics
- `CheckInViewModel.save()` → `InsightCache.shared.invalidateBehavior()` after saving check-in
- `SettingsView` Reset Baselines → `InsightCache.shared.invalidateAll()`

**UserDefaults keys** (versioned with `_v2` suffix to prevent reading stale formats):
- `cachedPhysioInsights_v2` — encoded `[Insight]`
- `cachedBehaviorInsights_v2` — encoded `[BehaviorInsight]`
- `physioInsightsCachedAt_v2` — build timestamp (`Date`)
- `behaviorInsightsCachedAt_v2` — build timestamp (`Date`)

---

### Local Data Persistence

All persistence uses **UserDefaults + Codable**. No CoreData, SQLite, or network storage.

| Store            | Key prefix          | Retention    | Contents |
|------------------|---------------------|--------------|----------|
| `MetricsStore`   | `dailyMetrics_`     | 90 days      | `DailyMetrics` snapshots |
| `CheckInStore`   | `checkIn_`          | Indefinite   | `DailyCheckIn` records |
| `NotificationStore` | `notifications` | 14 days      | `NotificationRecord` history |
| `InsightCache`   | `cached*_v2`        | Until stale  | `[Insight]`, `[BehaviorInsight]` |

Each day's metrics are keyed by a normalized date string (`yyyy-MM-dd`). The stores prune old entries automatically on write to stay within their retention windows.

**Raw HealthKit data is never stored locally.** Only computed scores and metadata are persisted.

---

### Background Task Scheduling

`BackgroundTaskManager` wraps `BGTaskScheduler` to refresh the insight cache while the app is in the background.

**Task identifier**: `com.soma.insight-refresh`
**Minimum interval**: 1 hour
**Registration**: `BackgroundTaskManager.shared.registerTasks()` — called in `SomaApp.init()` before the first runloop tick.
**Scheduling**: `BackgroundTaskManager.shared.scheduleInsightRefresh()` — called when the main tab view appears and after onboarding completes. Rescheduled automatically after each background run.

**Background execution flow**:
1. System wakes the app in the background
2. `handleInsightRefresh(task:)` fires
3. Immediately reschedules the next background window
4. Instantiates `InsightsViewModel` with live stores and calls `generateInsights(forceRefresh: true)`
5. Marks task complete (or failed if the expiration handler fires first)

---

### Dashboard

- 2×2 metric grid with colour-coded scores and 7-day sparklines
- Pull-to-refresh with 5-minute debounce
- "Building baseline" banner displayed until ≥ 14 days of HRV history exist
- **How to Improve Today** card — personalised coaching bullets derived from your behavioral patterns and today's physiology
- Daily check-in prompt (shown until today's check-in is complete)
- Quick Stats row: steps, active calories, sleep duration, VO2 max

### Trends

Switch between 7 / 30 / 90-day views with Swift Charts line charts for all four scores plus HRV and resting HR history. Each data point includes a tooltip showing: `Mar 15 · 60 — Fair`. An Ayurvedic Sleep score trend is included with its own detail screen.

### Insights

**Today** — physiological insight cards surfaced from today's data (low HRV, high strain, sleep debt, elevated stress, etc.), each showing the date it was generated.

**Your Patterns** — behavioral intelligence cards showing which of your logged behaviors are statistically correlated with better or worse next-day outcomes, with effect size in real units (ms, bpm, or points) and observation count.

### Notifications History

A dedicated tab showing the last 14 days of recovery notifications grouped by date, so you can review trends over time without leaving the app.

---

### Daily Behavior Check-In

A quick card-based flow (under 10 seconds) to log the previous day's behaviors:

| Category | What you log |
|----------|-------------|
| Alcohol | Consumed (yes/no) + units: none / 1–2 / 3–4 / 5+ |
| Stimulants | Caffeine after 5 PM |
| Nutrition timing | Late meal within 2 h of bed |
| Pre-sleep habits | Screen use 1 h before bed, workout within 2 h of bed |
| Stress | Subjective level 1–5 |
| Recovery practices | Meditation, stretching, cold exposure |

Check-in data is persisted locally via `CheckInStore` (UserDefaults + Codable). When HealthKit write permission is granted, alcohol (grams) and caffeine (mg) are also written to Apple Health.

---

### Behavior Intelligence Engine

`BehaviorEngine` correlates each behavior with five next-day physiological metrics:

- Sleep Score
- Recovery Score
- HRV (average)
- Sleeping HRV
- Sleeping HR

**Rules before a correlation is shown:**
- At least **5 observations** in both "with behavior" and "without behavior" groups
- Absolute mean difference ≥ **2.0** (points / ms / bpm)

Insights are sorted by effect magnitude. Both harmful behaviors (alcohol, late caffeine, screen time) and beneficial behaviors (meditation, stretching, cold exposure) are detected.

---

## How to Open in Xcode

1. Open `Soma.xcodeproj` in **Xcode 15+**.
2. Select your development team under **Signing & Capabilities → Team**.

## How to Enable HealthKit

1. Select the **Soma** target in the project navigator.
2. Go to **Signing & Capabilities → + Capability → HealthKit**.
3. Ensure "Clinical Health Records" is **unchecked** (not needed).

## How to Enable Background App Refresh

1. Select the **Soma** target in the project navigator.
2. Go to **Signing & Capabilities → + Capability → Background Modes**.
3. Check **Background fetch** and **Background processing**.

## How to Install on a Physical iPhone

1. Connect iPhone via USB or use wireless debugging.
2. Select the device in the Xcode toolbar.
3. Press **Cmd+R** to build and run.
4. Trust the developer certificate: **Settings → General → VPN & Device Management**.

## How to Grant Health Permissions

1. On first launch, tap **"Allow Health Access"** when prompted.
2. Enable **all data types** in the Health permissions sheet.
3. If previously denied: **Settings → Health → Data Access → Soma → enable all**.

---

## Project Structure

```
Soma/
├── SomaApp.swift                    # App entry point; registers BGTaskScheduler
├── Models/
│   ├── DailyMetrics.swift           # Core daily snapshot model (includes strainLoad)
│   ├── SleepData.swift              # Sleep stages + window + interruption count
│   ├── HeartRateZone.swift          # HR zone enum (1–5), MaxHR % thresholds
│   └── DailyCheckIn.swift           # Behavior check-in model (Codable)
├── Services/
│   ├── HealthKitManager.swift       # All HealthKit read/write + HealthDataProviding protocol
│   ├── MetricsStore.swift           # Daily metrics persistence (UserDefaults, 90 days)
│   ├── CheckInStore.swift           # Check-in persistence (UserDefaults + Codable)
│   ├── NotificationStore.swift      # Notification history persistence (14 days)
│   ├── NotificationScheduler.swift  # UNUserNotificationCenter + NotificationStore write
│   ├── InsightCache.swift           # Insight cache (UserDefaults, staleness logic)
│   └── BackgroundTaskManager.swift  # BGTaskScheduler registration and scheduling
├── Calculators/
│   ├── BaselineCalculator.swift     # Rolling 30-day baselines, normalise, clamp, extractHistory
│   ├── RecoveryCalculator.swift     # Recovery score 0–100 (40/25/25/10 weights)
│   ├── StrainCalculator.swift       # Zone-load model: StrainLoad, capacity, StrainScore 0–100
│   ├── SleepCalculator.swift        # Sleep score 0–100 (5 components) + sleep need
│   ├── StressCalculator.swift       # Stress 0–100 (daytime HRV + HR)
│   ├── AyurvedicSleepCalculator.swift # Dosha-aware sleep quality scoring
│   └── BehaviorEngine.swift         # Behavior–outcome correlations + coaching tips
├── ViewModels/
│   ├── DashboardViewModel.swift     # Today's metrics, sparklines, coaching tips, bedtime
│   ├── TrendsViewModel.swift        # Chart data for 7/30/90-day trends
│   ├── InsightsViewModel.swift      # Physiological + behavioral insight cards (cache-first)
│   ├── CheckInViewModel.swift       # Draft check-in + save + HealthKit write + cache invalidation
│   └── DayDetailViewModel.swift     # Day-level drill-down data formatting
└── Views/
    ├── MainTabView.swift            # TabView (Dashboard / Trends / Insights / Notifications)
    ├── DashboardView.swift          # 2×2 grid, check-in prompt, coaching card
    ├── TrendsView.swift             # Swift Charts line charts with date+category tooltips
    ├── InsightsView.swift           # Today + Your Patterns sections with date badges
    ├── NotificationsView.swift      # 14-day notification history grouped by date
    ├── OnboardingView.swift         # Welcome + HealthKit permission flow
    ├── SettingsView.swift           # Age, max HR, baseline sleep, clear data
    ├── CheckInView.swift            # Card-based check-in sheet
    ├── MetricDetailView.swift       # Per-metric trend chart + insights panel
    ├── AyurvedicSleepDetailView.swift # Ayurvedic sleep score breakdown + history chart
    └── Components/
        ├── MetricCardView.swift     # Score card with ring + sparkline (no "/100")
        ├── SparklineView.swift      # 7-day mini chart
        ├── RingView.swift           # Circular progress arc
        └── ColorState.swift         # 5-tier color/category system + Color(hex:)

SomaTests/
├── BaselineCalculatorTests.swift
├── RecoveryCalculatorTests.swift
├── StrainCalculatorTests.swift      # Zone load, score, capacity model
├── WorkoutStrainTests.swift         # Workout-aware strain calculation
├── SleepCalculatorTests.swift
├── StressCalculatorTests.swift
└── BehaviorEngineTests.swift
```

---

## Running Tests

In Xcode: **Product → Test** (`Cmd+U`)

| Test file | Coverage |
|-----------|----------|
| `SleepCalculatorTests` | 5-component score, sleeping HRV/HR sub-scores, interruption score, sleep need, sleep debt |
| `RecoveryCalculatorTests` | 40/25/25/10 weights, nil baseline fallback, green-range assertion, training recommendation strings |
| `StrainCalculatorTests` | Zone-time accumulation, HR zone classification, load/score/capacity model |
| `WorkoutStrainTests` | Workout-aware strain, incidental vs workout load split |
| `StressCalculatorTests` | Daytime HRV/HR stress model, boundary conditions |
| `BaselineCalculatorTests` | Rolling mean, normalisation, clamp, `extractHistory` key-path extraction |
| `BehaviorEngineTests` | Insight generation with synthetic data, delta filtering (< 2.0 suppressed), `impactDescription` text content, coaching tip fallback, max-3-tip limit |

---

## HealthKit Data Types

### Read
Heart rate samples, HRV (SDNN), resting heart rate, respiratory rate, VO2 max, active energy burned, step count, sleep analysis (stages + timing), sleep goal.

### Write (optional)
Dietary alcohol (grams, derived as 14 g/drink), dietary caffeine (mg, 200 mg per logged serving). Requires user consent. Written with source "Soma".

---

## Requirements

- Xcode 15+
- iOS 17.0+ deployment target
- Swift 5.9
- iPhone with Apple Watch for real HRV/sleep data — or use the `HealthDataProviding` protocol to inject mock data for development
- HealthKit capability enabled on the Soma target
- Background Modes capability (Background fetch + Background processing) for background insight refresh
