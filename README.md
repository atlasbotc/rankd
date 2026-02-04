# Marqui

*Beli for movies & TV*

A native iOS app for ranking movies and TV shows with minimal cognitive effort.

## Concept
1. **Add** a movie/show (search via TMDB)
2. **Tier it** — Good / Medium / Bad
3. **Compare** — A vs B within tiers
4. **View** your master ranked list

## Tech Stack
- SwiftUI (iOS 17+)
- SwiftData for local persistence
- TMDB API for metadata

## Features
- 🔍 Search movies and TV shows via TMDB
- 🏷️ Tier system (Good/Medium/Bad) for quick categorization
- ⚖️ A vs B comparisons to refine rankings
- 📊 Master ranked list view with filtering
- 💾 Local persistence with SwiftData

## Project Structure
```
Marqui/
├── MarquiApp.swift          # App entry point
├── ContentView.swift       # Main tab view
├── Config.swift            # TMDB API configuration
├── Models/
│   ├── RankedItem.swift    # SwiftData model
│   └── TMDBModels.swift    # TMDB API response models
├── Views/
│   ├── SearchView.swift    # Search and add movies
│   ├── RankedListView.swift # Master rankings list
│   └── CompareView.swift   # A vs B comparisons
├── ViewModels/
│   └── RankingViewModel.swift # Search and comparison logic
└── Services/
    └── TMDBService.swift   # TMDB API client
```

## Setup

### Prerequisites
- Xcode 15+
- iOS 17+ device or simulator
- TMDB API key (free at https://www.themoviedb.org/settings/api)

### Getting Started
1. Clone the repository
2. Copy `Config.swift.example` to `Config.swift`
3. Add your TMDB API key to `Config.swift`
4. Open `Marqui.xcodeproj` in Xcode
5. Build and run

```bash
cp Marqui/Config.swift.example Marqui/Config.swift
# Edit Config.swift and add your TMDB API key
```

## CI/CD
Builds are configured via Codemagic. See `codemagic.yaml` for details.

---
*Built by Atlas & Ki*
