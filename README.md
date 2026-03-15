# Soma

A local-only iOS 17+ app that reads Apple Health data via HealthKit and computes four daily scores — **Recovery**, **Strain**, **Sleep**, and **Stress** — displayed on a modern SwiftUI dark-mode dashboard.

No backend. No accounts. No network calls. Everything runs on-device.

---

## Features

### Four Core Scores

| Score    | Range | What it measures |
|----------|-------|-----------------|
| Recovery | 0–100 | Readiness to perform: HRV, resting HR, sleep quality, and prior strain |
| Strain   | 0–21  | Cardiovascular load accumulated during the day (heart-rate zone model) |
| Sleep    | 0–100 | 5-component quality score: duration, stages, sleeping HRV/HR, interruptions |
| Stress   | 0–100 | Autonomic stress estimated from daytime HRV and heart rate |

#### Sleep Score Formula (5 components)

| Component      | Weight | Calculation |
|----------------|--------|-------------|
| Duration       | 30%    | `min(100, T/N × 100)` — T = total sleep, N = personalised sleep need |
| Stage mix      | 30%    | `0.40×deep + 0.40×REM + 0.20×core` vs optimal ratios (20% / 22% / 50%) |
| Sleeping HRV   | 15%    | Ratio vs 30-day HRV baseline; higher = better |
| Sleeping HR    | 15%    | Ratio vs baseline; lower = better |
| Interruptions  | 10%    | `max(0, 100 − awake_segments × 15)` |

Sleep need is personalised: baseline (default 8 h) + sleep debt (capped at 2 h/night over 7 days) + strain factor (up to +1 h at max strain 21).

#### Recovery Score Formula

```
Recovery = 0.40 × HRV_score + 0.25 × RHR_score + 0.25 × Sleep_score + 0.10 × Strain_recovery
```

#### Score Colour Thresholds

| Metric    | Green        | Yellow   | Red   |
|-----------|-------------|----------|-------|
| Recovery  | 67–100       | 34–66    | 0–33  |
| Sleep     | 75–100       | 60–74    | 0–59  |
| Stress    | 0–33         | 34–66    | 67–100|

---

### Dashboard

- 2×2 metric grid with colour-coded scores and 7-day sparklines
- Pull-to-refresh with 5-minute debounce
- "Building baseline" banner displayed until ≥ 14 days of HRV history exist
- **How to Improve Today** card — personalised coaching bullets derived from your behavioral patterns and today's physiology
- Daily check-in prompt (shown until today's check-in is complete)
- Quick Stats row: steps, active calories, sleep duration, VO2 max

### Trends

Switch between 7 / 30 / 90-day views with Swift Charts line charts for all four scores plus HRV and resting HR history.

### Insights

**Today** — physiological insights surfaced from today's data (low HRV, high strain, sleep debt, elevated stress, etc.).

**Your Patterns** — behavioral intelligence cards that show which of your logged behaviors are statistically correlated with better or worse next-day outcomes, with effect size in real units (ms, bpm, or points) and observation count.

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
├── SomaApp.swift
├── Models/
│   ├── DailyMetrics.swift       # Core daily snapshot model
│   ├── SleepData.swift          # Sleep stages + window + interruption count
│   ├── HeartRateZone.swift      # HR zone enum (1–5)
│   └── DailyCheckIn.swift       # Behavior check-in model (Codable)
├── Services/
│   ├── HealthKitManager.swift   # All HealthKit read/write + HealthDataProviding protocol
│   ├── MetricsStore.swift       # Daily metrics persistence (UserDefaults, 90 days)
│   └── CheckInStore.swift       # Check-in persistence (UserDefaults + Codable)
├── Calculators/
│   ├── BaselineCalculator.swift  # Rolling 30-day baselines, normalise, clamp, extractHistory
│   ├── RecoveryCalculator.swift  # Recovery score 0–100 (40/25/25/10 weights)
│   ├── StrainCalculator.swift    # Strain 0–21 (log scale, zone-minutes)
│   ├── SleepCalculator.swift     # Sleep score 0–100 (5 components) + sleep need
│   ├── StressCalculator.swift    # Stress 0–100 (daytime HRV + HR)
│   └── BehaviorEngine.swift      # Behavior–outcome correlations + coaching tips
├── ViewModels/
│   ├── DashboardViewModel.swift  # Today's metrics, sparklines, coaching tips
│   ├── TrendsViewModel.swift     # Chart data for 7/30/90-day trends
│   ├── InsightsViewModel.swift   # Physiological + behavioral insight cards
│   └── CheckInViewModel.swift    # Draft check-in + save to store + HealthKit write
└── Views/
    ├── MainTabView.swift         # TabView (Dashboard / Trends / Insights)
    ├── DashboardView.swift       # 2×2 grid, check-in prompt, coaching card
    ├── TrendsView.swift          # Swift Charts line charts
    ├── InsightsView.swift        # Today + Your Patterns sections
    ├── OnboardingView.swift      # Welcome + HealthKit permission flow
    ├── SettingsView.swift        # Age, max HR, baseline sleep, clear data
    ├── CheckInView.swift         # Card-based check-in sheet
    └── Components/
        ├── MetricCardView.swift  # Score card with ring + sparkline
        ├── SparklineView.swift   # 7-day mini chart
        ├── RingView.swift        # Circular progress arc
        └── ColorState.swift      # Green/Yellow/Red helpers + Color(hex:)

SomaTests/
├── BaselineCalculatorTests.swift
├── RecoveryCalculatorTests.swift
├── StrainCalculatorTests.swift
├── SleepCalculatorTests.swift
├── StressCalculatorTests.swift
└── BehaviorEngineTests.swift
```

---

## Architecture

```
HealthKit
  └── HealthKitManager  (HealthDataProviding protocol)
        ├── DashboardViewModel  ──► Calculators (pure functions)
        │                       └── MetricsStore (UserDefaults, 90 days)
        ├── TrendsViewModel
        └── InsightsViewModel

CheckInStore (UserDefaults + Codable)
  ├── CheckInViewModel  ──► CheckInStore.save() + HealthKitManager.writeBehavioralData()
  ├── DashboardViewModel  ──► BehaviorEngine.coachingTips()
  └── InsightsViewModel   ──► BehaviorEngine.generateInsights()
```

All HealthKit operations use `async/await`. The main thread is never blocked. Dashboard caches metrics on launch and refreshes in the background with a 5-minute debounce. Sleeping HR and HRV are fetched using the detected sleep window (start → end time) from that night's sleep analysis.

---

## Running Tests

In Xcode: **Product → Test** (`Cmd+U`)

| Test file | Coverage |
|-----------|----------|
| `SleepCalculatorTests` | 5-component score, sleeping HRV/HR sub-scores, interruption score, sleep need, sleep debt |
| `RecoveryCalculatorTests` | 40/25/25/10 weights, nil baseline fallback, green-range assertion, training recommendation strings |
| `StrainCalculatorTests` | Zone-time accumulation, HR zone classification, max HR estimation |
| `StressCalculatorTests` | Daytime HRV/HR stress model, boundary conditions |
| `BaselineCalculatorTests` | Rolling mean, normalisation, clamp, `extractHistory` key-path extraction |
| `BehaviorEngineTests` | Insight generation with synthetic data, delta filtering (< 2.0 suppressed), `impactDescription` text content, coaching tip fallback, max-3-tip limit |

---

## HealthKit Data Types

### Read
Heart rate samples, HRV (SDNN), resting heart rate, respiratory rate, VO2 max, active energy burned, step count, sleep analysis (stages + timing).

### Write (optional)
Dietary alcohol (grams, derived as 14 g/drink), dietary caffeine (mg, 200 mg per logged serving). Requires user consent. Written with source "Soma".

---

## Requirements

- Xcode 15+
- iOS 17.0+ deployment target
- Swift 5.9
- iPhone with Apple Watch for real HRV/sleep data — or use the `HealthDataProviding` protocol to inject mock data for development
- HealthKit capability enabled on the Soma target
