# Widget Extension Setup Instructions

The widget code has been created, but you need to add it to your Xcode project as a proper Widget Extension target.

## Step 1: Add Widget Extension Target

1. Open your Soma project in Xcode
2. Select your project file in the navigator (top-level "Soma")
3. Click the "+" button at the bottom of the targets list
4. Choose "Widget Extension" from the iOS section
5. Configure the extension:
   - **Product Name:** `SomaWidgets`
   - **Bundle Identifier:** `com.prasjain.Soma.SomaWidgets`
   - **Language:** Swift
   - **Include Configuration Intent:** No (we're using static widgets)
   - **Activate scheme:** Yes

## Step 2: Replace Generated Files

After creating the target, Xcode will generate template files. Replace them with our custom files:

1. **Delete** the generated files in the `SomaWidgets` folder:
   - `SomaWidgets.swift`
   - `SomaWidgetsBundle.swift`
   - `AppIntent.swift` (if present)

2. **Add** our custom widget files to the `SomaWidgets` target:
   - `SomaWidgets/SomaWidgetsBundle.swift`
   - `SomaWidgets/SomaWidgets.swift`
   - `SomaWidgets/AppIntent.swift`

## Step 3: Configure App Groups

1. **Main App Target:**
   - Select "Soma" target → "Signing & Capabilities"
   - Add "App Groups" capability
   - Add group: `group.com.prasjain.Soma`

2. **Widget Extension Target:**
   - Select "SomaWidgets" target → "Signing & Capabilities"
   - Add "App Groups" capability  
   - Add the same group: `group.com.prasjain.Soma`

## Step 4: Add Shared Code to Widget Target

The widget needs access to shared models and utilities:

1. **Select these files** and add them to the SomaWidgets target (check the target membership):
   - `Soma/Models/DailyMetrics.swift`
   - `Soma/Services/MetricsStore.swift`
   - `Soma/Views/Components/ColorState.swift`

**How to add to target:**
- Select the file in Project Navigator
- In File Inspector (right panel), check "SomaWidgets" under "Target Membership"

## Step 5: Build and Test

1. **Build the main app:** Cmd+B
2. **Build the widget extension:** Select "SomaWidgets" scheme → Cmd+B
3. **Install on device:** Run the main app on your iPhone
4. **Add widget:** Long press home screen → tap "+" → search "Soma"

## Step 6: Verify Widget Configuration

If widgets still don't appear, check:

1. **Bundle ID is correct:** `com.prasjain.Soma.SomaWidgets`
2. **Deployment target:** iOS 16.0+ (same as main app)
3. **Team/Signing:** Same team as main app
4. **App Groups configured** in Apple Developer portal

## Troubleshooting

**Widgets don't appear in widget gallery:**
- Make sure Widget Extension builds without errors
- Check that `SomaWidgetBundle.swift` is in the widget target
- Verify App Group ID matches between app and widget

**"Unable to load" widget error:**
- Check that shared files are added to widget target
- Verify App Group entitlements are correct
- Make sure `MetricsStore` can access UserDefaults with App Group

**Build errors:**
- Ensure all imported files are available to widget target
- Check that widget deployment target matches main app
- Verify no missing dependencies

## Expected Widgets

After setup, you should see these widgets:

- **Small (2x2):** Recovery score with other metrics summary
- **Medium (4x2):** All four scores in grid layout  
- **Large (4x4):** Full dashboard with title and all metrics
- **Lock Screen:** Circular recovery gauge, rectangular summary, inline text

The widgets will update when the main app refreshes health data and will show cached data from the App Group UserDefaults.