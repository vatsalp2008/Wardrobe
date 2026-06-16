# Wardrobe

**AI-powered personal styling app for iOS.** Photograph your clothes once; Wardrobe builds a
smart digital closet, generates daily outfit suggestions, previews them on your own photo via
virtual try-on, and tells you the single missing piece that unlocks the most new outfits.

Native **Swift / SwiftUI**, iOS 16+. MVVM + Repository, mock-first architecture, local-first
Core Data with optional Supabase cloud sync.

> Status: all 5 build phases complete. Runs fully offline on mock services; live AI / try-on /
> shopping / cloud activate automatically when their keys are configured.

## Features

| Feature | What it does |
|---|---|
| **Closet Scanner** | Capture or pick a photo → on-device Vision background removal → Claude-vision auto-tagging (category/pattern/formality) + on-device color extraction → review → save |
| **Outfit Generator** | Weather-aware, occasion-filtered daily outfits via Claude, with recent-wear avoidance and a daily notification |
| **Photo Try-On** | Composite outfits onto your full-body photo (IDM-VTON via Replicate); photo encrypted at rest, drag-to-compare, save/share, daily limit + caching |
| **Gap Finder** | Combinatorial matrix finds the highest-impact missing item; Claude ranks the top gaps; live shopping results via SerpAPI |
| **Profile** | Photo management, wear-history stats, budget + notification settings, privacy |

## Tech stack

- **UI:** SwiftUI, custom design system (dark-mode + accessibility)
- **On-device:** Vision (segmentation, body-pose), Core Data, CryptoKit (encrypted photo), CoreImage
- **AI / APIs:** Claude API (outfits, gap analysis, garment tagging), Replicate IDM-VTON (try-on),
  SerpAPI (shopping), Supabase (anon auth, image hosting, row sync)
- **Architecture:** MVVM + Repository; every external service is a protocol with a `Mock`/`Live`
  pair, wired by a DI container (`AppContainer`) based on which keys are present
- **Tooling:** XcodeGen (project is generated from `project.yml`), SwiftLint, XCTest (26 tests)

## Getting started

Full instructions: **[SETUP.md](SETUP.md)**. Short version (macOS + Xcode 16+):

```bash
brew install xcodegen swiftlint
cd Wardrobe            # repo root (contains project.yml)
xcodegen generate
open Wardrobe.xcodeproj
```

Select an iPhone simulator and ⌘R. The app runs on mock services with **no keys required**.

### Optional: enable live services

Copy `Config.example.plist` → `Wardrobe/Config.plist` (gitignored) and fill in any of:

| Key | Enables |
|---|---|
| `ANTHROPIC_API_KEY` | Real outfit/gap reasoning + garment auto-tagging (Claude) |
| `GEMINI_API_KEY` | Same AI features via Google Gemini (used instead of Claude if set) |
| `REPLICATE_API_TOKEN` | Real virtual try-on render |
| `SERPAPI_KEY` | Real shopping results |
| `SUPABASE_URL` + `SUPABASE_ANON_KEY` | Cloud auth, image hosting, cross-device sync (see SETUP.md §4b) |

Each missing key simply falls back to its mock. Re-run `xcodegen generate` after adding `Config.plist`.

## Project structure

```
Wardrobe/
├── App/         entry point, DI container, root tab view
├── Core/
│   ├── Models/        ClothingItem, Outfit, GapSuggestion, TryOnResult
│   ├── Services/      protocol + Mock/Live per service (Claude, Replicate, Serp, Supabase, Vision, ML)
│   ├── Repositories/  wardrobe / outfit / try-on / gap (Core Data + cloud sync)
│   ├── Persistence/   Core Data stack, encrypted photo store, image stores
│   └── DesignSystem/  tokens + reusable components
├── Features/    Onboarding, Closet, Outfits, TryOn, GapFinder, Profile
└── Resources/   Assets
Tests/WardrobeTests/   unit tests
```

## Build & test (CLI)

```bash
xcodegen generate
xcodebuild -project Wardrobe.xcodeproj -scheme Wardrobe -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17' test
```

## Documentation

- **[SETUP.md](SETUP.md)** — toolchain, project generation, signing, API keys, Supabase setup
- **[TRADEOFFS.md](TRADEOFFS.md)** — deliberate shortcuts, remaining work, and decision log
- **Wardrobe_iOS_Project_Spec.docx** — original product/engineering spec
