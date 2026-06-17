# Wardrobe

**AI-powered personal styling app for iOS.** Photograph your clothes once; Wardrobe builds a
smart digital closet, generates daily outfit suggestions, previews them on your own photo via
virtual try-on, and tells you the single missing piece that unlocks the most new outfits.

Native **Swift / SwiftUI**, iOS 16+. MVVM + Repository, mock-first architecture, local-first
Core Data with optional Supabase cloud sync.

> Runs fully offline on mock services — **no API keys required** to build and explore. Live AI,
> try-on, shopping, and cloud sync activate automatically when their keys are configured.

---

## Features

| Feature | What it does |
|---|---|
| **Closet Scanner** | Capture or pick a photo → on-device Vision background removal → AI auto-tagging (category/pattern/formality) + on-device color extraction → review → save |
| **Outfit Generator** | Weather-aware, occasion-filtered daily outfits via an LLM, with recent-wear avoidance and a daily notification |
| **Photo Try-On** | Composite outfits onto your full-body photo (IDM-VTON via Replicate); photo encrypted at rest, drag-to-compare, save/share, daily limit + caching |
| **Gap Finder** | A combinatorial matrix finds the highest-impact missing item; the LLM ranks the top gaps; live shopping results via SerpAPI |
| **Profile** | Photo management, wear-history stats, budget + notification settings, privacy |

## Architecture & tech stack

- **UI:** SwiftUI, custom design system (full dark-mode + accessibility labels)
- **On-device:** Vision (garment segmentation, body-pose validation), Core Data, CryptoKit
  (AES-GCM encrypted user photo), CoreImage (dominant-color extraction)
- **AI / APIs:** pluggable LLM stylist (**Google Gemini** or **Anthropic Claude**), Replicate
  IDM-VTON (try-on), SerpAPI (shopping), Supabase (anonymous auth, image hosting, row sync)
- **Pattern:** MVVM + Repository. Every external service is a Swift protocol with a `Mock`/`Live`
  pair, wired by a DI container (`AppContainer`) based on which keys are present — so the app is
  fully runnable offline and each integration can be developed/tested in isolation.
- **Tooling:** XcodeGen (the `.xcodeproj` is generated from `project.yml`), SwiftLint, XCTest (26 tests)

---

## Getting started

### Prerequisites

See [`requirements.txt`](requirements.txt) for the full list. In short: **macOS + Xcode 16+**, plus:

```bash
brew install xcodegen swiftlint
```

### Build & run

```bash
# from the repo root (contains project.yml)
xcodegen generate          # creates Wardrobe.xcodeproj from project.yml
open Wardrobe.xcodeproj     # select an iPhone simulator, then ⌘R
```

The app launches with mock services — **no keys needed**. Re-run `xcodegen generate` whenever you
add/remove source files or edit `project.yml`.

> **Signing:** for a physical device, set your Team under *Signing & Capabilities* and a unique
> bundle ID (e.g. `com.<you>.wardrobe`). The Simulator needs no signing.

### CLI test

```bash
xcodebuild -project Wardrobe.xcodeproj -scheme Wardrobe -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17' test
```

---

## Enabling live services (optional)

Copy the example config and fill in any keys you have:

```bash
cp Config.example.plist Wardrobe/Config.plist   # Config.plist is gitignored
xcodegen generate                                # bundles it into the app
```

| Key | Enables | Where to get it |
|---|---|---|
| `GEMINI_API_KEY` | AI tagging + outfit/gap reasoning (Google Gemini) | https://aistudio.google.com/apikey |
| `ANTHROPIC_API_KEY` | Same AI features via Claude (used only if no Gemini key) | https://console.anthropic.com |
| `SUPABASE_URL` + `SUPABASE_ANON_KEY` | Cloud auth, image hosting, cross-device sync (free tier) | Supabase → Project Settings → API |
| `REPLICATE_API_TOKEN` | Real virtual try-on render | https://replicate.com |
| `SERPAPI_KEY` | Real shopping results | https://serpapi.com |

Provider precedence for the AI stylist: **Gemini → Claude → deterministic mock.** Any missing key
simply falls back to its mock; nothing breaks.

### Supabase cloud setup (free)

1. Create a project at [supabase.com](https://supabase.com); copy the **Project URL** + **anon/publishable key** into `Config.plist`.
2. **Authentication → Providers → Anonymous → enable.**
3. **Storage → New bucket:** `wardrobe-items` (Public) and `tryon-results` (Private).
4. In **SQL Editor**, run the storage policies and the wardrobe table:

```sql
-- Storage upload policies
create policy "wardrobe_items_insert" on storage.objects for insert to authenticated
  with check (bucket_id = 'wardrobe-items');
create policy "tryon_results_insert" on storage.objects for insert to authenticated
  with check (bucket_id = 'tryon-results' and owner = auth.uid());

-- Cross-device wardrobe row sync
create table if not exists public.wardrobe_items (
  id uuid primary key,
  user_id uuid not null default auth.uid(),
  name text, category text, colors text[], pattern text, formality text, seasons text[],
  image_url text, wear_count int default 0,
  last_worn timestamptz, date_added timestamptz default now(),
  brand text, notes text
);
alter table public.wardrobe_items enable row level security;
create policy "wardrobe_items_owner_all" on public.wardrobe_items for all
  to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
grant select, insert, update, delete on public.wardrobe_items to authenticated;
```

---

## Project structure

```
Wardrobe/
├── App/         entry point, DI container (AppContainer), root tab view
├── Core/
│   ├── Models/        ClothingItem, Outfit, GapSuggestion, TryOnResult
│   ├── Services/      protocol + Mock/Live per service (AI stylist, Replicate, Serp, Supabase, Vision, ML)
│   ├── Repositories/  wardrobe / outfit / try-on / gap (Core Data + cloud sync)
│   ├── Persistence/   Core Data stack, encrypted photo store, image stores
│   └── DesignSystem/  tokens + reusable components
├── Features/    Onboarding, Closet, Outfits, TryOn, GapFinder, Profile
└── Resources/   Assets
Tests/WardrobeTests/   unit tests (XCTest)
```

## Roadmap

See [ROADMAP.md](ROADMAP.md) for current status, remaining work, and the App-Store path.

## License

Personal project by Vatsal Patel.
