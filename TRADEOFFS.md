# Wardrobe — Tradeoffs & Deferred Work

A living log of deliberate shortcuts we've taken, *why*, and what has to happen later to
"pay them back." Update this whenever we choose speed/simplicity now over completeness.
Each entry has a **trigger** — the event that means it's time to revisit.

Legend: 🟢 low-risk / intentional · 🟡 needs follow-up before a real release · 🔴 blocks a feature until done

---

## Current tradeoffs (active shortcuts)

### 1. 🟢 Mock-first external services
**Decision:** Every external API (Claude, Replicate, SerpAPI, Supabase, Remove.bg, WeatherKit)
is a Swift protocol with a `Mock`/`Stub` conformer; the app runs fully offline with no keys.
**Why:** Build and demo features without paid accounts or per-call cost; keeps feature work
unblocked by account setup.
**Cost:** Mocks return canned data — no real intelligence/results until live adapters land.
**Trigger to revisit:** Each feature phase wires its own live adapter (see backlog). Live wiring
points are marked `// Phase N:` in `Wardrobe/App/AppContainer.swift`.

### 2. 🟡 In-memory repositories for outfits / try-on / gap
**Decision:** The **wardrobe** is now Core Data-backed (`CoreDataWardrobeRepository`, persists
across launches). Outfits, try-on, and gap still use `InMemory*Repository`.
**Why:** Each is persisted in the phase that owns it; no need for their tables yet.
**Cost:** Generated outfits / try-on cache / gap results reset on restart until their phases.
**Trigger to revisit:** Phase 2 (outfits), Phase 3 (try-on cache), Phase 4 (gap cache) —
add their entities to `Wardrobe.xcdatamodeld`.

### 6. 🟡 Garment images stored as local thumbnail only
**Decision:** On save we keep a ~600px thumbnail in Core Data (`thumbnailData`) and set
`imageURL` to a mock Supabase URL. The full-resolution background-removed PNG is not persisted.
**Why:** Supabase upload is mocked until Phase 5; the thumbnail is enough to render the closet.
**Cost:** No full-res original; `imageURL` isn't loadable yet (cards fall back to the thumbnail).
**Trigger to revisit:** Phase 5 — real Supabase upload returns a usable `imageURL`.

### 8. 🟡 Simplified trend pipeline + occasion regeneration
**Decision:** Trend score is assigned by Claude during generation using `SerpService.trendingKeywords()`
(mocked). There's no separate weekly trend-keyword cache. Occasion filter chips **regenerate** the
feed for the selected occasion rather than producing one mixed-occasion batch.
**Why:** Keeps Phase 2 to one Claude call per refresh; the weekly-cache + multi-occasion feed is more
than the MVP needs.
**Cost:** Trend keywords aren't real until SerpAPI is wired (F8); switching occasion costs a regenerate.
**Trigger to revisit:** Phase 4 (real SerpAPI), or a polish pass for a mixed-occasion feed + 7-day trend cache.

### 7. 🟢 Manual camera capture (no auto-capture)
**Decision:** `CameraCaptureView` uses a manual shutter button + framing guide.
**Why:** Auto-capture-when-frame-filled (spec §7.3) is polish, not core.
**Cost:** User taps to capture instead of it firing automatically.
**Trigger to revisit:** Phase 5 polish, if desired.

### 3. 🟢 XcodeGen project (`.xcodeproj` is gitignored)
**Decision:** `project.yml` is the source of truth; `Wardrobe.xcodeproj` is regenerated and not
committed.
**Why:** Avoids constant pbxproj merge conflicts; one declarative file to review.
**Cost:** Must run `xcodegen generate` after adding/removing files or editing `project.yml`;
adding files via Xcode's UI alone won't stick.
**Trigger to revisit:** Only if we ever need committed project settings XcodeGen can't express.

### 4. 🟡 Placeholder signing (`com.yourname.wardrobe`, no team)
**Decision:** Bundle ID is a placeholder and no development team is set; runs on Simulator only.
**Why:** Simulator needs no signing; we haven't enrolled in the Apple Developer Program yet.
**Cost:** Can't run on a physical iPhone (so no real camera / WeatherKit testing).
**Trigger to revisit:** Before first device test — set a real bundle ID (e.g.
`com.vatsalp2008.wardrobe`) and `DEVELOPMENT_TEAM` in `project.yml`, add Apple ID account.

### 5. 🟢 SPM packages linked but unused
**Decision:** `Supabase` and `swift-collections` are declared/linked though no code imports them yet.
**Why:** Validates package resolution early; they're needed in Phase 5 / for wardrobe indexing.
**Cost:** Slightly larger first build; no functional impact.
**Trigger to revisit:** Phase 5 (Supabase), and whenever wardrobe indexing needs `OrderedDictionary`.

---

## Future work backlog (not yet started)

| # | Item | Why deferred | Blocks | Owner |
|---|------|--------------|--------|-------|
| F1 | ✅ **DONE — Claude vision auto-tagging (option 3)** | `ClaudeService.tagGarment` sends the segmented image to Claude; activates with `ANTHROPIC_API_KEY`, falls back to manual tagging without one. Colors still extracted on-device | — | — |
| F2 | ✅ **DONE (Phase 1)** — Real on-device Vision segmentation (`VNGenerateForegroundInstanceMaskRequest` iOS17 + person-segmentation iOS16 fallback + Remove.bg hook) | — | — | — |
| F3 | 🟡 **Camera capture** (AVFoundation) with framing overlay | Camera only works on a physical device + needs signing (see tradeoff #4) | Capturing items without the Photos picker | Phase 1 (device) |
| F4 | 🟡 **WeatherKit** live weather | Requires Apple Developer Program ($99/yr) entitlement; seasonal fallback used until then | Accurate weather-aware outfits (degrades gracefully) | Phase 2 |
| F5 | ✅ **DONE (Phase 2)** — Live Claude client for outfit generation (`LiveClaudeService`, raw-HTTP `claude-sonnet-4-6`). Activates automatically when `ANTHROPIC_API_KEY` is set; deterministic mock is the offline fallback. *(Gap analysis still routes to the mock until Phase 4.)* | — | — | — |
| F6 | 🟡 **CLIP embeddings** for visual similarity search | Embedding vector is stubbed on `ClothingItem` for now | "Find similar items" / smarter pairing | Later enhancement |
| F7 | 🟡 **Live Replicate IDM-VTON render** | `LiveReplicateService` (POST-then-poll) is implemented + key-gated, but real runs also need a pinned IDM-VTON version hash and publicly hosted image URLs (Phase 5 Supabase). Caching, daily limit, pose validation, and encrypted photo are DONE (Phase 3); the **mock preview composite** works now | Photorealistic try-on render | Pin version hash + Phase 5 hosting |
| F8 | 🟡 **SerpAPI** live shopping | `LiveSerpService` (Google Shopping) implemented + key-gated; activates with `SERPAPI_KEY` ($50/mo). Gap analysis, the combination-matrix algorithm, Claude ranking, and 24h cache are DONE (Phase 4); mock returns sample shopping until the key is set. Trend keywords still use the mock set | Real shopping results + live trend keywords | Set `SERPAPI_KEY`; dedicated trend query |
| F9 | ✅ **DONE — Supabase auth + image hosting + wardrobe row sync** | `SyncingWardrobeRepository` mirrors Core Data writes to the `wardrobe_items` table and pulls on load; activates when Supabase is configured. Requires the `wardrobe_items` table (SQL in README/SETUP). Last-write-wins, push is best-effort (offline-safe) | — | — |
| F12 | 🟡 **Real try-on render also needs the person photo hosted** | IDM-VTON fetches images by URL; the encrypted local photo must be uploaded to the private `tryon-results` bucket for a live render (ties into F7 + F9) | Live (non-mock) try-on | After Supabase project + pinned version hash |
| F10 | ✅ **DONE (Phase 3)** — User try-on photo encrypted at rest with CryptoKit AES-GCM (`UserPhotoStore`); key in Keychain. Plaintext leaves the device only for the Replicate inference call | — | — | — |
| F11 | 🟢 **Apple Developer Program enrollment** ($99/yr) | Not needed for Simulator work | Gates F3 (device), F4 (WeatherKit), TestFlight | When ready for device/beta |

---

## Decision log — F1: auto-tagging category/pattern/formality

**Today:** colors are auto-detected on-device; **category / pattern / formality are tagged
manually** by the user in `ItemReviewView`. `OnDeviceMLService` returns those three at
confidence 0 to force the review prompt.

**Decision (current):** **Option 1 — keep manual tagging.** It's fully functional (a few taps
per item) and unblocks all later phases. No dataset, no training, no cost.

**Future paths (pick later — not started):**

- **Option 2 — Train a Core ML model (the spec's approach).** Obtain a labeled clothing dataset
  (DeepFashion — free but requires an access form + large download; or the easier-to-get Kaggle
  "Fashion Product Images" set), train an image classifier with **CreateML** (no-code, ~30–60 min)
  or fine-tune MobileNetV3, bundle `ClothingClassifier.mlmodel`, and wire it into
  `OnDeviceMLService`. *Pros:* on-device, free at inference, offline. *Cons:* dataset sourcing +
  training effort; **needs Vatsal to obtain the dataset.**
- **Option 3 — AI vision via Claude.** Send the segmented garment photo to Claude's vision API
  (already in the stack from Phase 2) and have it return category/pattern/formality as JSON.
  *Pros:* no dataset, no training, likely high accuracy, minimal code. *Cons:* network call + a
  small per-item cost; not on-device (departs from spec's on-device goal).

**Leaning:** Option 3 is likely the lower-effort long-term win since Claude is already integrated;
revisit once Phase 2 lands the Claude client.

## How to use this doc
- When we take a new shortcut, add a row to **Current tradeoffs** with its trigger.
- When a backlog item is done, move it out of the table and (if it created a tradeoff) close the
  matching tradeoff entry.
- Cross-reference the phase plan for full context.
