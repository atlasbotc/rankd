# Rename Changelog: Rankd → Marqui

## Files Modified

### Swift Files (User-Facing Strings)

1. **Marqui/Services/ExportService.swift**
   - `"rankd_rankings.csv"` → `"marqui_rankings.csv"`
   - `"rankd_watchlist.csv"` → `"marqui_watchlist.csv"`
   - `"app": "Rankd"` → `"app": "Marqui"` (JSON export metadata)
   - `"rankd_export.json"` → `"marqui_export.json"`

2. **Marqui/Services/WidgetDataManager.swift**
   - App group: `"group.com.rankd.shared"` → `"group.app.marqui.shared"`

3. **Marqui/Views/LetterboxdImportView.swift**
   - `"into Rankd"` → `"into Marqui"` (onboarding text)
   - `"Already In Rankd"` → `"Already In Marqui"` (import summary badge)

4. **Marqui/Views/WhatsNewView.swift**
   - `"What's New in Rankd"` → `"What's New in Marqui"`

5. **Marqui/Views/ListShareSheet.swift**
   - `Text("rankd")` → `Text("marqui")` (branding watermark)

6. **Marqui/Views/ProfileView.swift**
   - `"About Rankd"` → `"About Marqui"` (alert title, 2 occurrences)

7. **Marqui/Views/DiscoverView.swift**
   - `"Welcome to Rankd"` → `"Welcome to Marqui"`

8. **Marqui/Views/SplashView.swift**
   - `Text("Rankd")` → `Text("Marqui")` (splash screen title)

9. **Marqui/Views/ShareCardView.swift**
   - `Text("rankd")` → `Text("marqui")` (branding watermark, 3 occurrences)

10. **Marqui/MarquiApp.swift**
    - URL scheme: `"rankd"` → `"marqui"`

11. **MarquiWidget/MarquiWidget.swift**
    - App group: `"group.com.rankd.shared"` → `"group.app.marqui.shared"`
    - Widget URL: `"rankd://rankings"` → `"marqui://rankings"`

### Configuration Files

12. **MarquiWidget/Info.plist**
    - CFBundleDisplayName: `"Rankd Widget"` → `"Marqui Widget"`

13. **Rankd.xcodeproj/project.pbxproj**
    - `INFOPLIST_KEY_CFBundleDisplayName = Rankd` → `Marqui` (2 configs: Debug & Release)
    - `INFOPLIST_KEY_CFBundleDisplayName = "Rankd Widget"` → `"Marqui Widget"` (2 configs)
    - `PRODUCT_BUNDLE_IDENTIFIER = com.rankd.app` → `app.marqui.Marqui` (2 configs)
    - `PRODUCT_BUNDLE_IDENTIFIER = com.rankd.app.widget` → `app.marqui.Marqui.widget` (2 configs)

## Intentionally Left Unchanged

The following references to "Rankd" were **intentionally preserved** as they are code identifiers, not user-facing strings:

### Design System (Marqui/Theme/DesignSystem.swift)
- `MarquiColors`, `MarquiTypography`, `MarquiSpacing`, `MarquiRadius`, `MarquiMotion`, `MarquiPoster`, `MarquiShadow` — enum names
- `MarquiPressStyle`, `MarquiDynamicTypeModifier`, `MarquiCardStyle`, `MarquiSurfaceStyle` — struct names
- `.marquiDynamicTypeLimit()`, `.marquiCard()`, `.marquiSurface()` — extension method names

### App Entry Point (Marqui/MarquiApp.swift)
- `struct MarquiApp: App` — Swift struct name

### Widget (MarquiWidget/)
- `RankdTimelineProvider`, `MarquiWidgetEntry`, `RankdSmallView`, `RankdMediumView`, `RankdLargeView` — struct names
- `MarquiWidgetEntryView`, `MarquiWidget`, `MarquiWidgetBundle` — struct names
- `let kind: String = "MarquiWidget"` — internal widget identifier (not user-visible)

### Xcode Project (project.pbxproj)
- Target names: `Rankd`, `MarquiWidgetExtension` — Xcode internal target identifiers
- Product names: `productName = Rankd` — Xcode build product name
- File references: `MarquiApp.swift`, `MarquiWidget.swift`, `MarquiWidgetBundle.swift` — source file names
- Directory paths: `path = Rankd`, `path = MarquiWidget` — folder names on disk
- `DEVELOPMENT_ASSET_PATHS` — references actual folder path

### Source File/Folder Names
- All `.swift` files and directories retain their original names (e.g., `MarquiApp.swift`, `Marqui/`, `MarquiWidget/`)
- Renaming these would require renaming actual files/folders and updating all Xcode project references

### Comment (MarquiWidget/MarquiWidget.swift:16)
- `// Verified against Marqui/Theme/DesignSystem.swift values:` — refers to file path

---

## Phase 2: Full Codebase Rename (Feb 4, 2026)

All remaining code identifiers renamed from `Rankd*` to `Marqui*`:

### Design System Tokens (DesignSystem.swift + all consumers)
- `RankdColors` → `MarquiColors`
- `RankdTypography` → `MarquiTypography`
- `RankdSpacing` → `MarquiSpacing`
- `RankdRadius` → `MarquiRadius`
- `RankdMotion` → `MarquiMotion`
- `RankdPoster` → `MarquiPoster`
- `RankdShadow` → `MarquiShadow`
- `RankdPressStyle` → `MarquiPressStyle`
- `RankdDynamicTypeModifier` → `MarquiDynamicTypeModifier`
- `RankdCardStyle` → `MarquiCardStyle`
- `RankdSurfaceStyle` → `MarquiSurfaceStyle`
- `.rankdDynamicTypeLimit()` → `.marquiDynamicTypeLimit()`
- `.rankdCard()` → `.marquiCard()`
- `.rankdSurface()` → `.marquiSurface()`

### App & Widget
- `RankdApp` → `MarquiApp`
- `RankdWidget` → `MarquiWidget`
- `RankdWidgetBundle` → `MarquiWidgetBundle`
- `RankdTimelineProvider` → `MarquiTimelineProvider`
- `RankdSmallView` → `MarquiSmallView`
- `RankdMediumView` → `MarquiMediumView`
- `RankdLargeView` → `MarquiLargeView`

### Files & Directories
- `Rankd/` → `Marqui/`
- `RankdWidget/` → `MarquiWidget/`
- `Rankd.xcodeproj/` → `Marqui.xcodeproj/`
- `RankdApp.swift` → `MarquiApp.swift`
- `RankdWidget.swift` → `MarquiWidget.swift`
- `RankdWidgetBundle.swift` → `MarquiWidgetBundle.swift`
- `Rankd.xcscheme` → `Marqui.xcscheme`

### Build Config
- `codemagic.yaml` updated with new paths and scheme name
- All pbxproj references updated
- All xcscheme references updated

2130+ code references across 35+ files renamed.
