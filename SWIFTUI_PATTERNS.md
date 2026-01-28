# SwiftUI Patterns & Gotchas

Living document of patterns, pitfalls, and best practices learned while building Rankd.

---

## 🚫 Known Gotchas

### 1. HStack in Segmented Picker
**Problem:** Using `HStack { Image(); Text() }` inside a `.pickerStyle(.segmented)` causes broken tab rendering on iOS.
**Fix:** Use plain `Text()` labels only for segmented pickers.
```swift
// ❌ Bad
Picker("Type", selection: $type) {
    HStack { Image(systemName: "film"); Text("Movies") }.tag(0)
}
.pickerStyle(.segmented)

// ✅ Good
Picker("Type", selection: $type) {
    Text("Movies").tag(0)
    Text("TV Shows").tag(1)
}
.pickerStyle(.segmented)
```

### 2. Type-Checker Timeout
**Problem:** Complex inline expressions with chained optionals, `.map`, `.compactMap`, and ternary operators cause "unable to type-check in reasonable time."
**Fix:** Extract into explicit helper functions with return types.
```swift
// ❌ Bad — inline complex expression
AdditionalInfoSection(
    items: [
        ("Budget", detail.budget.map { $0 > 0 ? "$\($0.formatted())" : nil } ?? nil),
    ].compactMap { $0.1 != nil ? ($0.0, $0.1!) : nil }
)

// ✅ Good — extracted helper
private func movieInfoItems(_ detail: TMDBMovieDetail) -> [(String, String)] {
    var items: [(String, String)] = []
    if let budget = detail.budget, budget > 0 {
        items.append(("Budget", "$\(budget.formatted())"))
    }
    return items
}
```

### 3. Dead Code Referencing Undefined Variables
**Problem:** Functions or code paths that reference `@State` variables that were never declared cause "cannot find in scope" errors.
**Fix:** Always search entire file for variable usage before defining functions that reference them. Delete unused code immediately.

### 4. fullScreenCover/Sheet onDisappear Timing
**Problem:** Using `.onDisappear` on content inside `.fullScreenCover` or `.sheet` to perform cleanup (like deleting items) can crash if the item is already gone or state has changed.
**Fix:** Use `.onChange(of: isPresented)` instead, and verify state before acting.
```swift
// ❌ Bad — timing issues
.fullScreenCover(isPresented: $showFlow) {
    SomeView()
        .onDisappear {
            modelContext.delete(item) // item might be nil
        }
}

// ✅ Good — explicit state check
.fullScreenCover(isPresented: $showFlow) {
    SomeView()
}
.onChange(of: showFlow) { _, isShowing in
    if !isShowing {
        if let item = itemToProcess,
           rankedItems.contains(where: { $0.tmdbId == item.tmdbId }) {
            modelContext.delete(item)
            try? modelContext.save()
        }
        itemToProcess = nil
    }
}
```

### 5. Computed Property from Optional State in Sheet
**Problem:** Using a computed property that depends on `@State` optional inside `.fullScreenCover` or `.sheet` can fail because the state may be nil when SwiftUI evaluates the view builder.
**Fix:** Assign the value to a separate `@State` before presenting the sheet.
```swift
// ❌ Bad — computed from optional
private var searchResult: TMDBSearchResult? {
    guard let item = itemToRank else { return nil }
    // ... convert
}
.fullScreenCover(isPresented: $showFlow) {
    if let result = searchResult { // may be nil
        FlowView(item: result)
    }
}

// ✅ Good — pre-built before presenting
@State private var searchResultToRank: TMDBSearchResult?

Button {
    searchResultToRank = buildSearchResult(from: item)
    showFlow = true
}
.fullScreenCover(isPresented: $showFlow) {
    if let result = searchResultToRank {
        FlowView(item: result)
    }
}
```

---

## ✅ Best Practices

### State Management
- Declare only the `@State` variables you actually use
- Prefer `@State` + explicit assignment over computed properties for sheet/cover content
- Clean up state in `onChange` not `onDisappear`

### View Composition
- Break views into small, focused components (< 50 lines per body)
- Use `private func someSection() -> some View` for large sections
- Keep `body` as a high-level layout coordinator

### Type Safety
- Add explicit return types to helper functions
- Avoid complex inline closures in view builders
- Break ternary chains into if/else

### Navigation
- Use `NavigationLink` for drill-down (push)
- Use `.sheet` for modal selection/input
- Use `.fullScreenCover` for flows (comparison, onboarding)
- Don't mix paradigms (don't show a sheet from a sheet)

### Lists & Performance
- Use `LazyVStack` / `LazyHStack` for scrollable content
- Always provide `id` in `ForEach`
- Avoid heavy computation in view bodies — move to `.task` or `.onAppear`

### SwiftData
- Always `try? modelContext.save()` after mutations
- Reorder items by updating the model, not the view
- Use `@Query` with sort descriptors for consistent ordering

---

## 📋 Pre-Push Checklist

Before every commit:

### Compilation
- [ ] All referenced types/structs exist in the project
- [ ] All `@State` / `@Binding` variables are declared
- [ ] No function calls to undefined methods
- [ ] No complex inline expressions that could timeout the type-checker
- [ ] Remove ALL dead code (unused functions, variables, imports)

### User Flows
- [ ] Trace each user flow start-to-finish mentally
- [ ] Verify button actions point to correct targets
- [ ] Check sheet/cover dismiss properly and clean up state
- [ ] Confirm navigation links resolve to existing views
- [ ] Test empty states (no data) path

### Edge Cases
- [ ] What happens with 0 items?
- [ ] What happens with 1 item?
- [ ] What if network fails?
- [ ] What if user cancels mid-flow?
- [ ] What if data is already added (duplicate check)?

### UX
- [ ] Buttons do what their labels say
- [ ] No redundant popups/confirmations
- [ ] Loading states for async operations
- [ ] Error states with retry option
- [ ] Disabled states for invalid actions

---

*Last updated: 2026-01-28*
