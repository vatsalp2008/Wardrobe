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

### 2. 🟡 In-memory repositories instead of Core Data
**Decision:** `InMemory*Repository` types back the app in Phase 0; data does not persist across
app launches.
**Why:** Avoids shipping a Core Data model before we need one; keeps Phase 0 buildable with zero
persistence code.
**Cost:** Nothing is saved — restart wipes state.
**Trigger to revisit:** **Phase 1** — introduce `Wardrobe.xcdatamodeld` + Core-Data-backed
`WardrobeRepository`. `CoreDataStack.swift` is the placeholder marking where it goes.

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
| F1 | 🔴 **Train `ClothingClassifier.mlmodel`** (CreateML / MobileNetV3 on DeepFashion) for auto-tagging category/pattern/formality | Needs a labeled DeepFashion dataset sourced + training time | Real auto-tagging in Phase 1 (manual-tag review path works meanwhile) | **Vatsal: source dataset** |
| F2 | 🔴 Real on-device **Vision segmentation** pipeline (`VNGenerateForegroundInstanceMaskRequest` + iOS-16 fallback + Remove.bg) | Phase 1 scope | Background-removed garment images | Phase 1 |
| F3 | 🟡 **Camera capture** (AVFoundation) with framing overlay | Camera only works on a physical device + needs signing (see tradeoff #4) | Capturing items without the Photos picker | Phase 1 (device) |
| F4 | 🟡 **WeatherKit** live weather | Requires Apple Developer Program ($99/yr) entitlement; seasonal fallback used until then | Accurate weather-aware outfits (degrades gracefully) | Phase 2 |
| F5 | 🟡 **Claude API** live outfit/gap generation | Needs `ANTHROPIC_API_KEY`; rule-based mock is the offline fallback | On-trend, reasoned suggestions | Phase 2 / 4 |
| F6 | 🟡 **CLIP embeddings** for visual similarity search | Embedding vector is stubbed on `ClothingItem` for now | "Find similar items" / smarter pairing | Later enhancement |
| F7 | 🟡 **Replicate IDM-VTON** try-on + result caching + daily cost limit | Needs `REPLICATE_API_TOKEN`; ~\$0.01/run | Virtual try-on | Phase 3 |
| F8 | 🟡 **SerpAPI** live shopping + weekly trend keywords | Needs `SERPAPI_KEY` ($50/mo plan) | Real shopping results in Gap Finder | Phase 4 |
| F9 | 🟡 **Supabase** auth + cloud sync + storage buckets w/ RLS | Phase 5 scope; local-only until then | Cross-device sync, image hosting | Phase 5 |
| F10 | 🟡 **CryptoKit** encryption of the user's try-on photo | Phase 3 scope | Privacy guarantee for the body photo | Phase 3 |
| F11 | 🟢 **Apple Developer Program enrollment** ($99/yr) | Not needed for Simulator work | Gates F3 (device), F4 (WeatherKit), TestFlight | When ready for device/beta |

---

## How to use this doc
- When we take a new shortcut, add a row to **Current tradeoffs** with its trigger.
- When a backlog item is done, move it out of the table and (if it created a tradeoff) close the
  matching tradeoff entry.
- Cross-reference the phase plan for full context.
