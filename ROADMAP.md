# Wardrobe — Status & Roadmap

_Last updated: 2026-06-17_

This doc answers: **where are we, what's left, and what's ahead.** See [README.md](README.md) for
setup and usage.

---

## 1. Where we are

All five build phases are **code-complete** and on `main` (https://github.com/vatsalp2008/Wardrobe),
**26 unit tests passing**, building clean for the iOS 17 simulator. The app runs fully on mock
services with zero keys; live providers activate automatically when their keys are present.

### Feature status

| Feature | State | Notes |
|---|---|---|
| **Closet Scanner** | ✅ Live | Vision background removal + on-device color extraction + **Gemini** auto-tagging; Core Data persistence |
| **Outfit Generator** | ✅ Live | **Gemini**-generated, weather-aware, recent-wear avoidance, daily reminder |
| **Gap Finder** | ✅ Live (AI) / mock shopping | Combinatorial matrix + Gemini ranking work; shopping cards are mock until SerpAPI key |
| **Photo Try-On** | 🟡 Mock render | Encrypted photo, pose validation, caching, daily limit all done; **mock composite** until live Replicate (F7/F12) |
| **Profile** | ✅ Live | Photo mgmt, wear stats, budget + notification settings, privacy |
| **Cloud (Supabase)** | ✅ Live | Anonymous auth, image hosting, and cross-device row sync all verified end-to-end |

### AI provider
Active provider is **Google Gemini** (`gemini-2.5-flash`), selected because a Gemini key was
available. Precedence in `AppContainer`: **Gemini key → Claude key → deterministic mock.** Switching
providers is a config change, no code edits. (Claude client `LiveClaudeService` remains fully wired.)

### What's verified working
- ✅ Build + 26 tests (CLI + Xcode)
- ✅ App runs on Simulator (all 5 tabs)
- ✅ Supabase: anonymous auth, image upload, public URL, and `wardrobe_items` row insert/read/delete (tested against the live project)
- ✅ Gemini: `gemini-2.5-flash` `generateContent` returns 200 against the live key

---

## 2. What's left (to be fully live / shippable)

### 2a. Free — can do now
| Task | Effort | Notes |
|---|---|---|
| **Rotate the Gemini key** | 2 min | Regenerate in AI Studio, replace in `Wardrobe/Config.plist`. |
| **Persist outfits / try-on / gap to Core Data** | ~half day | Currently in-memory — they reset on relaunch. Add entities to `Wardrobe.xcdatamodeld`. |

### 2b. Paid / account-gated
| Task | Cost | Unlocks |
|---|---|---|
| **Apple Developer Program** | $99/yr | Device testing, camera on device (F3), WeatherKit (F4), Push on device, **TestFlight + App Store** (F11) |
| **Live Replicate try-on render** | ~$0.01/run | Real IDM-VTON output (F7/F12): needs `REPLICATE_API_TOKEN`, a pinned model version hash, and uploading the person photo to the private `tryon-results` bucket |
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
- **Onboarding flow** — the 3-slide intro + permission priming (spec §7.3) is a stub.

---

## 4. Path to the App Store (deploy checklist)

1. Enroll in the Apple Developer Program.
2. Set a real bundle ID (e.g. `com.vatsalp2008.wardrobe`) + `DEVELOPMENT_TEAM` in `project.yml`.
3. Add an app icon + launch assets to `Assets.xcassets`.
4. Enable capabilities: WeatherKit, Push Notifications (Signing & Capabilities).
5. Device-test the camera, WeatherKit, and notifications.
6. Confirm the App Store **Privacy Nutrition Label** (in-app privacy screen already done).
7. Set up **Xcode Cloud** CI/CD → TestFlight beta.
8. Submit for review.

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
| F7 | Live IDM-VTON render | 🟡 Client done; needs version hash + hosted images |
| F8 | Live SerpAPI shopping | 🟡 Client done; needs `SERPAPI_KEY` |
| F9 | Supabase auth + image hosting + row sync | ✅ Done — verified live (auth, upload, row sync) |
| F10 | Encrypted user photo | ✅ Done (Phase 3) |
| F11 | Apple Developer enrollment | 🟡 Needed for device/TestFlight/App Store |
| F12 | Host person photo for live try-on | 🟡 Pairs with F7 |
