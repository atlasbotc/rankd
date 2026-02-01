# Rename Changelog: Rankd → Marqui

## Files Modified

### Swift Files (User-Facing Strings)

1. **Rankd/Services/ExportService.swift**
   - `"rankd_rankings.csv"` → `"marqui_rankings.csv"`
   - `"rankd_watchlist.csv"` → `"marqui_watchlist.csv"`
   - `"app": "Rankd"` → `"app": "Marqui"` (JSON export metadata)
   - `"rankd_export.json"` → `"marqui_export.json"`

2. **Rankd/Services/WidgetDataManager.swift**
   - App group: `"group.com.rankd.shared"` → `"group.app.marqui.shared"`

3. **Rankd/Views/LetterboxdImportView.swift**
   - `"into Rankd"` → `"into Marqui"` (onboarding text)
   - `"Already In Rankd"` → `"Already In Marqui"` (import summary badge)

4. **Rankd/Views/WhatsNewView.swift**
   - `"What's New in Rankd"` → `"What's New in Marqui"`

5. **Rankd/Views/ListShareSheet.swift**
   - `Text("rankd")` → `Text("marqui")` (branding watermark)

6. **Rankd/Views/ProfileView.swift**
   - `"About Rankd"` → `"About Marqui"` (alert title, 2 occurrences)

7. **Rankd/Views/DiscoverView.swift**
   - `"Welcome to Rankd"` → `"Welcome to Marqui"`

8. **Rankd/Views/SplashView.swift**
   - `Text("Rankd")` → `Text("Marqui")` (splash screen title)

9. **Rankd/Views/ShareCardView.swift**
   - `Text("rankd")` → `Text("marqui")` (branding watermark, 3 occurrences)

10. **Rankd/RankdApp.swift**
    - URL scheme: `"rankd"` → `"marqui"`

11. **RankdWidget/RankdWidget.swift**
    - App group: `"group.com.rankd.shared"` → `"group.app.marqui.shared"`
    - Widget URL: `"rankd://rankings"` → `"marqui://rankings"`

### Configuration Files

12. **RankdWidget/Info.plist**
    - CFBundleDisplayName: `"Rankd Widget"` → `"Marqui Widget"`

13. **Rankd.xcodeproj/project.pbxproj**
    - `INFOPLIST_KEY_CFBundleDisplayName = Rankd` → `Marqui` (2 configs: Debug & Release)
    - `INFOPLIST_KEY_CFBundleDisplayName = "Rankd Widget"` → `"Marqui Widget"` (2 configs)
    - `PRODUCT_BUNDLE_IDENTIFIER = com.rankd.app` → `app.marqui.Marqui` (2 configs)
    - `PRODUCT_BUNDLE_IDENTIFIER = com.rankd.app.widget` → `app.marqui.Marqui.widget` (2 configs)

## Intentionally Left Unchanged

The following references to "Rankd" were **intentionally preserved** as they are code identifiers, not user-facing strings:

### Design System (Rankd/Theme/DesignSystem.swift)
- `RankdColors`, `RankdTypography`, `RankdSpacing`, `RankdRadius`, `RankdMotion`, `RankdPoster`, `RankdShadow` — enum names
- `RankdPressStyle`, `RankdDynamicTypeModifier`, `RankdCardStyle`, `RankdSurfaceStyle` — struct names
- `.rankdDynamicTypeLimit()`, `.rankdCard()`, `.rankdSurface()` — extension method names

### App Entry Point (Rankd/RankdApp.swift)
- `struct RankdApp: App` — Swift struct name

### Widget (RankdWidget/)
- `RankdTimelineProvider`, `RankdWidgetEntry`, `RankdSmallView`, `RankdMediumView`, `RankdLargeView` — struct names
- `RankdWidgetEntryView`, `RankdWidget`, `RankdWidgetBundle` — struct names
- `let kind: String = "RankdWidget"` — internal widget identifier (not user-visible)

### Xcode Project (project.pbxproj)
- Target names: `Rankd`, `RankdWidgetExtension` — Xcode internal target identifiers
- Product names: `productName = Rankd` — Xcode build product name
- File references: `RankdApp.swift`, `RankdWidget.swift`, `RankdWidgetBundle.swift` — source file names
- Directory paths: `path = Rankd`, `path = RankdWidget` — folder names on disk
- `DEVELOPMENT_ASSET_PATHS` — references actual folder path

### Source File/Folder Names
- All `.swift` files and directories retain their original names (e.g., `RankdApp.swift`, `Rankd/`, `RankdWidget/`)
- Renaming these would require renaming actual files/folders and updating all Xcode project references

### Comment (RankdWidget/RankdWidget.swift:16)
- `// Verified against Rankd/Theme/DesignSystem.swift values:` — refers to file path
