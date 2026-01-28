# Rankd Design System

Design reference and improvement plan based on Lander Studio and competitor analysis.

---

## 🎨 Design Principles (from Lander Studio reference)

### 1. Breathe
- Generous whitespace between sections (24-32pt vertical)
- Content never touches screen edges (16-20pt horizontal padding)
- Cards have internal padding (16-20pt)

### 2. Depth
- Soft gradients, never flat solid backgrounds
- Cards with subtle shadows for layered feel
- Background tints that shift warm→cool or light→dark
- Glass/blur effects (`.ultraThinMaterial`) used sparingly

### 3. Personality
- Custom illustrations for empty states (not just SF Symbols)
- Personalized greetings ("Hey Ki" not generic)
- Micro-interactions and transitions
- Playful copywriting in CTAs

### 4. One Accent
- Single strong accent color per context (Rankd: orange)
- Supporting colors are muted/desaturated
- Accent only on primary actions and key data

### 5. Typography Hierarchy
- Large bold headlines (title/title2)
- Clearly smaller subheadings
- Body text in secondary color
- Caption/metadata nearly invisible until needed

### 6. Bottom-First
- Primary CTAs anchored at bottom (thumb reach)
- Tab bars minimal and clean
- Floating action buttons for key actions

---

## 🔄 Rankd Current State vs Target

### What We Have Now
- Functional but utilitarian
- System default components (basic List, standard Nav)
- Minimal empty states (just icon + text)
- No onboarding flow
- No personality or delight
- Flat color usage

### What We Need

#### Onboarding
- Welcome screen with app value prop
- Question-based flow: "What do you watch more? Movies or TV?"
- Tier explanation with visual examples
- First item add with guided comparison

#### Discover Tab (Current → Target)
- **Current:** Horizontal scroll sections with basic poster cards
- **Target:**
  - Hero banner with featured/trending item (full-width, gradient overlay)
  - "For You" section based on ranked items
  - Category chips with custom colors
  - Card hover states with subtle scale
  - Gradient section backgrounds (warm for movies, cool for TV)

#### Rankings Tab (Current → Target)
- **Current:** Basic segmented picker + flat list
- **Target:**
  - Custom tab bar (pill style, not system segmented)
  - Top 3 displayed as podium/showcase cards (larger, with poster)
  - Rest as clean list with rank medals
  - Tier grouping with colored section headers
  - Pull-down stats summary ("42 movies ranked, 15 TV shows")

#### Compare Tab (Current → Target)
- **Current:** Two poster cards side by side
- **Target:**
  - "VS" with dramatic split/animation
  - Swipe-based (Tinder-style) for faster comparison
  - Win/loss streak counter
  - Background color shifts based on choice

#### Detail View (Current → Target)
- **Current:** Backdrop + poster + info
- **Target:**
  - Parallax scrolling backdrop
  - Floating poster card with shadow
  - Animated rating display
  - Streaming availability section
  - "Friends who ranked this" (future social)

#### Empty States
- Custom illustrations per context:
  - Rankings empty: couch with popcorn "Start ranking!"
  - Watchlist empty: binoculars "Looking for something?"
  - Search empty: magnifying glass with sparkles
  - Compare empty: boxing gloves "Need more contenders"

---

## 🎯 Color System

```
Primary Accent:     Orange (#FF7A00) — rankings, CTAs, tier highlights
Secondary:          Blue (#007AFF) — watchlist, links
Success:            Green (#34C759) — ranked badge, winner
Warning:            Yellow (#FFD60A) — medium tier
Destructive:        Red (#FF3B30) — bad tier, delete
Background:         System background with subtle warm tint
Card:               Slightly elevated (.regularMaterial or white + shadow)
```

## 📐 Spacing Scale

```
4pt   — tight (icon-to-text)
8pt   — compact (within components)
12pt  — default (between related elements)
16pt  — comfortable (section padding)
20pt  — spacious (between sections)
24pt  — generous (major sections)
32pt  — dramatic (hero areas)
```

## 🔘 Component Standards

### Buttons
- Primary: Full-width, rounded (14pt radius), orange fill, white text, 50pt height
- Secondary: Full-width, rounded, orange/15% opacity fill, orange text
- Tertiary: Text-only, orange
- Destructive: Red tint

### Cards
- Corner radius: 12-16pt
- Shadow: color(.black.opacity(0.08)), radius: 8, y: 4
- Internal padding: 16pt

### Posters
- Aspect ratio: 2:3 (standard movie poster)
- Small: 50×75pt (list rows)
- Medium: 120×180pt (horizontal scroll)
- Large: 200×300pt (detail/hero)
- Corner radius: 8pt (small), 12pt (medium/large)

---

## 📱 Screen-by-Screen Improvement Plan

Priority order:
1. **Rankings** — this is the core; make it feel premium
2. **Detail View** — where users spend time; needs depth
3. **Discover** — first impression; needs wow factor
4. **Onboarding** — critical for retention
5. **Compare** — differentiator; make it fun
6. **Watchlist** — utility; clean is fine
7. **Search** — utility; clean is fine

---

*Reference: Lander Studio mobile portfolio (lander.studio/mobile-apps)*
*Last updated: 2026-01-28*
