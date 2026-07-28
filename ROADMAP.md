# Wardrobe — Status & Roadmap

_Last updated: 2026-07-27_

This doc answers: **where are we, what's left, and what's ahead.** See [README.md](README.md) for
setup and usage.

---

## 1. Where we are

All five build phases are **code-complete** and on `main` (https://github.com/vatsalp2008/Wardrobe),
**49 unit tests passing**, building clean under Xcode 26.5 on the iPhone 17 simulator. The app runs
fully on mock services with zero keys; live providers activate automatically when their keys are
present.

### Feature status

| Feature | State | Notes |
|---|---|---|
| **Closet Scanner** | ✅ Live | Vision background removal + on-device color extraction + **Gemini** auto-tagging; Core Data persistence |
| **Outfit Generator** | ✅ Live | **Gemini**-generated, weather-aware, recent-wear avoidance, daily reminder |
| **Gap Finder** | ✅ Live (AI) / mock shopping | Combinatorial matrix + Gemini ranking work; shopping cards are mock until SerpAPI key |
| **Photo Try-On** | 🟡 Mock render | Encrypted photo, pose validation, caching, daily limit, signed-URL photo hosting all done and unit-tested; **mock composite** until a Replicate token lands (F7/F12) |
| **Profile** | ✅ Live | Photo mgmt, wear stats, budget + notification settings, privacy |
| **Onboarding** | ✅ Live | 3-slide intro + camera/notification priming on first launch (spec §7.3) |
| **Local persistence** | ✅ Live | Closet, outfits, try-on cache, and gap results all survive relaunch |
| **Cloud (Supabase)** | ✅ Live | Anonymous auth, image hosting, and cross-device row sync all verified end-to-end |

### AI provider
Active provider is **Google Gemini** (`gemini-2.5-flash`), selected because a Gemini key was
available. Precedence in `AppContainer`: **Gemini key → Claude key → deterministic mock.** Switching
providers is a config change, no code edits. (Claude client `LiveClaudeService` remains fully wired.)

### What's verified working
- ✅ Build + 49 tests (CLI + Xcode), Xcode 26.5 / iPhone 17 simulator
- ✅ App runs on Simulator (all 5 tabs)
- ✅ Supabase: anonymous auth, image upload, public URL, and `wardrobe_items` row insert/read/delete (tested against the live project)
- ✅ Gemini: `gemini-2.5-flash` `generateContent` returns 200 against the live key

---

## 2. What's left (to be fully live / shippable)

### 2a. Free — can do now
| Task | Effort | Notes |
|---|---|---|
| **Rotate the Gemini key** | 2 min | Regenerate in AI Studio, replace in `Wardrobe/Config.plist`. Verified the key was **never committed** (`git log --all -- Wardrobe/Config.plist` is empty; `git log -p --all -S'AIza'` finds nothing) — hygiene, not an incident. |
| ~~Persist outfits / try-on / gap to Core Data~~ | — | ✅ Done. Model v2 adds `OutfitEntity`, `TryOnResultEntity`, `GapSuggestionEntity`; a refresh keeps favorited and worn outfits. |

### 2b. Paid / account-gated
| Task | Cost | Unlocks |
|---|---|---|
| **Apple Developer Program** | $99/yr | Device testing, camera on device (F3), WeatherKit (F4), Push on device, **TestFlight + App Store** (F11) |
| **Live Replicate try-on render** | ~$0.01/run | Real IDM-VTON output (F7/F12). All plumbing is done and tested offline — set `REPLICATE_API_TOKEN` + `REPLICATE_MODEL_VERSION` in `Config.plist` and it goes live with no code edits. |
| **Live shopping in Gap Finder** | SerpAPI $50/mo | Real buy links (F8) — or skip / swap for a cheaper shopping source |
| **Gemini usage** | pay-per-use (standard tier) | Already active; monitor at ai.dev/rate-limit |

---

## 3. What's ahead (enhancements / nice-to-haves)

Not required to ship — quality and depth improvements:

- **CLIP visual similarity (F6)** — "find similar items", smarter pairing; embedding field is stubbed today.
- **On-device ML classifier (F1, option 2)** — train a CreateML/MobileNetV3 model for offline tagging if you want to drop the network dependency Gemini introduces.
- **Auto-capture camera** — fire the shutter when the garment fills the frame.
- **Richer outfit feed** — mixed-occasion batch + a real 7-day trend-keyword cache instead of per-occasion regeneration.
- **Wardrobe indexing** — use `swift-collections` `OrderedDictionary` for large closets.
- **Cloud sync for outfits** — needs new `SupabaseServiceProtocol` methods and an `outfits` table; only the closet syncs today.

---

## 4. Path to the App Store (deploy checklist)

1. Enroll in the Apple Developer Program.
2. ✅ Bundle ID is `com.vatsalp2008.wardrobe`; still need `DEVELOPMENT_TEAM` in `project.yml` at enrolment.
3. Enable capabilities: WeatherKit, Push Notifications (Signing & Capabilities).
4. Device-test the camera, WeatherKit, and notifications.
5. Confirm the App Store **Privacy Nutrition Label** (in-app privacy screen already done).
6. Set up **Xcode Cloud** CI/CD → TestFlight beta.
7. Submit for review.

> Free workaround for step 4: Xcode's personal team issues 7-day provisioning profiles, enough to
> sideload onto your own iPhone and exercise the camera path (F3) without paying the $99.

---

## 5. Open backlog quick reference

| ID | Item | Status |
|---|---|---|
| F1 | Auto-tagging (category/pattern/formality) | ✅ Done — via Gemini vision (Claude also supported) |
| F2 | On-device Vision segmentation | ✅ Done (Phase 1) |
| F3 | Camera capture on device | 🟡 Code done; needs a physical device + signing |
| F4 | WeatherKit live weather | 🟡 Needs Apple Developer entitlement (seasonal fallback live) |
| F5 | Live AI outfit generation | ✅ Done — Gemini/Claude |
| F6 | CLIP embeddings / similarity | 🔜 Future enhancement |
| F7 | Live IDM-VTON render | 🟡 Client + hosting plumbing done and unit-tested; needs `REPLICATE_API_TOKEN` + `REPLICATE_MODEL_VERSION` |
| F8 | Live SerpAPI shopping | 🟡 Client done; needs `SERPAPI_KEY` |
| F9 | Supabase auth + image hosting + row sync | ✅ Done — verified live (auth, upload, row sync) |
| F10 | Encrypted user photo | ✅ Done (Phase 3) |
| F11 | Apple Developer enrollment | 🟡 Needed for device/TestFlight/App Store |
| F12 | Host person photo for live try-on | ✅ Done — uploaded to the private `tryon-results` bucket with a signed URL |
