# Wardrobe — Setup Guide

Native iOS app (Swift / SwiftUI, iOS 16+). See the full roadmap in the project plan.
This guide gets you from a fresh machine to a running app. **Phase 0 runs entirely on mock
services — no paid API keys are required to build and launch.**

## 1. Prerequisites

| Tool | Install |
| --- | --- |
| macOS Sonoma 14.0+ | required for Xcode 15 |
| Xcode 15.2+ | Mac App Store (this provides `xcodebuild`, simulators, SwiftUI previews) |
| Homebrew | https://brew.sh |
| XcodeGen | `brew install xcodegen` |
| SwiftLint | `brew install swiftlint` |
| Git | preinstalled; configure with your GitHub credentials |
| Proxyman *(optional)* | https://proxyman.io — API debugging, needed from Phase 2 on |

Apple Developer Program ($99/yr) is **not** needed yet. It's required later for WeatherKit
(Phase 2) and on-device testing. Until then the app degrades gracefully (seasonal weather default).

## 2. Generate and open the project

The `.xcodeproj` is **not** committed — it's generated from [`project.yml`](project.yml) by XcodeGen.

```bash
# Run from the repo root (the folder that contains project.yml), NOT the Wardrobe/ source subfolder.
xcodegen generate      # creates Wardrobe.xcodeproj
open Wardrobe.xcodeproj
```

Re-run `xcodegen generate` whenever you add/remove files or change `project.yml`.
The first build resolves the Swift Package dependencies (Supabase, swift-collections).

Then in Xcode: select the **Wardrobe** scheme + an iPhone simulator and press ⌘R.
You should see a 5-tab shell (Closet / Outfits / Try On / Gap Finder / Profile) with placeholders.

## 3. Signing

Signing & Capabilities → set **Team** to your personal Apple ID team and **Automatic** signing.
Leave capabilities off for now. Enable them as you reach the phase that needs them:

- **WeatherKit** — Phase 2 (requires Apple Developer Program enrollment)
- **Push Notifications** — Phase 2 (daily outfit reminders)
- **iCloud / CloudKit** — optional, Phase 5

## 4. Configuration & API keys

Copy the example config and fill in keys **only when you reach the phase that needs them**.
Empty keys ⇒ the app uses mock services automatically.

```bash
# From the repo root:
cp Config.example.plist Wardrobe/Config.plist   # Config.plist is gitignored
xcodegen generate                               # bundles it into the app target
```

| Key | Needed for | Where to get it |
| --- | --- | --- |
| `ANTHROPIC_API_KEY` | Phase 2/4 — outfit + gap AI | console.anthropic.com → API Keys |
| `REPLICATE_API_TOKEN` | Phase 3 — virtual try-on | replicate.com → Account → API Tokens |
| `SUPABASE_URL` / `SUPABASE_ANON_KEY` | Phase 5 — cloud sync | Supabase dashboard → Project Settings → API |
| `SERPAPI_KEY` | Phase 4 — shopping results | serpapi.com → Dashboard |
| `REMOVE_BG_KEY` | Phase 1 fallback — bg removal | remove.bg → Dashboard → API Keys |
| `OPENWEATHERMAP_KEY` | optional dev weather fallback | openweathermap.org |

Secrets can also be supplied as **Xcode scheme Environment Variables**
(Product → Scheme → Edit Scheme → Run → Arguments → Environment Variables);
`AppConfig` reads env vars first, then `Config.plist`.

## 5. Project layout

```
Wardrobe/
├── App/            entry point, DI container (AppContainer), AppConfig, root tab view
├── Core/
│   ├── Models/        ClothingItem, Outfit, GapSuggestion, TryOnResult, enums
│   ├── Services/      protocol + Mock per external service (Claude, Replicate, …)
│   ├── Repositories/  WardrobeRepository, OutfitRepository, …
│   ├── Persistence/   CoreDataStack, ImageStorageManager
│   ├── Extensions/    Color+Hex, Date+Formatting
│   └── DesignSystem/  colors, typography, spacing, reusable components
├── Features/       Onboarding, Closet, Outfits, TryOn, GapFinder, Profile
└── Resources/      Assets.xcassets
Tests/WardrobeTests/  unit tests
```

## 6. Mock-first architecture

Every external dependency is a Swift **protocol** with a `Mock…` and (later) `Live…` conformer.
[`AppContainer`](Wardrobe/App/AppContainer.swift) wires mocks when keys are absent and live
adapters when keys are present, so feature work is never blocked on accounts or cost.
