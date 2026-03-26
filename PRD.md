# Vibeslol — Product Requirements Document

> "this app is dumb" — and that's the point.

## Overview

Vibeslol is a **6-second vertical video platform** for ages 13+. It's positioned as the unfiltered, chaotic, irony-pilled alternative to TikTok. The name is intentionally absurd. The product is intentionally exceptional.

**The core bet:** A strict 6-second format forces creativity, makes the feed impossibly fast, and creates a genuinely different experience from anything else on the market. The contrast between the chaotic brand and the futuristic, buttery-smooth UI is the hook.

---

## Brand Identity

### Voice & Tone
- Self-aware, slightly chaotic, never corporate
- Ironic but not mean
- Treats the user like they're in on the joke

### Tagline Options
- "this app is dumb"
- "scroll at your own risk"
- "we warned you"
- "6 seconds. no excuses."

### Visual Identity
- **Dark-first design** (dark mode only at launch)
- **Near-transparent UI** — chrome fades away, content IS the experience
- **Subtle purple glow** on interactive elements — barely there, but enough to see
- **Minimal color palette** — blacks, dark grays, one accent (purple glow)
- **Logo:** Design from scratch — should feel chaotic-meets-futuristic

---

## Target Audience

- **Age:** 13+ (App Store rating, COPPA-compliant by targeting teens+)
- **Psychographic:** Kids and teens who find TikTok too try-hard, Instagram too polished, and want something that feels more raw and real
- **Early adopters:** Meme culture, shitposters, short-form comedy creators who thrive under constraints

---

## Core Features (MVP)

### 1. The Feed
- **Full-screen vertical video feed** (portrait only)
- **Swipe up/down** to navigate between videos
- **All videos are exactly 6 seconds** — no more, no less
- Videos auto-play with sound on
- Loop seamlessly (6s loops hit different)
- **Scroll physics matter** — smooth inertia, satisfying snap-to-video feel
- UI overlays are near-transparent, fade in on tap, fade out after 2s of inactivity

### 2. Video Creation
- **In-app camera** with basic recording
- **Timer/countdown** for hands-free recording
- **Trimming tool** to cut down to exactly 6 seconds
- **Upload from camera roll** (auto-trim to 6s or let user select 6s window)
- No music library, no filters, no effects at launch — raw content only
- Post flow: Record/upload → Trim to 6s → Add caption (optional) → Post

### 3. Interactions
- **Like** (with satisfying haptic feedback)
- **Comment** (only for users with accounts — anonymous users can only watch)
- **Share** (native iOS share sheet + copy link)
- Haptic feedback on all primary interactions (like, post, scroll snap)

### 4. Accounts & Auth
- **Zero-friction start:** App auto-generates an anonymous account on first launch
- Anonymous users can: browse feed, like, follow, share
- Anonymous users CANNOT: post videos, comment
- **Optional account creation:** Apple Sign-In, email/password, phone number
- Account creation unlocks: posting, commenting, profile customization
- Profile: username, avatar, bio, video grid

### 5. Following System
- Follow/unfollow users
- "Following" tab in feed (in addition to "For You" tab)
- Following count and follower count on profiles
- No DMs, no friend lists, no stories — just follow

### 6. Discovery & Algorithm

#### For You Feed (Recommendation Engine)
Build a recommendation engine inspired by TikTok's approach:

**Signals to track:**
- Watch time (did they watch the full 6s? How many loops?)
- Loop count (key metric — how many times did they rewatch?)
- Like, comment, share actions
- Skip speed (how fast did they swipe away?)
- Follow-after-watch events
- Content category/tags
- Time of day

**Algorithm approach (iterative):**
- **V1 (launch):** Weighted random — mix of popular videos (by likes/loops) with random discovery. Simple collaborative filtering (users who liked X also liked Y).
- **V2:** Add content-based signals (video embeddings, caption NLP)
- **V3:** Full hybrid recommendation with real-time personalization

**Cold start strategy:**
- New users see a mix of top-performing videos across categories
- First 20-30 interactions rapidly tune the feed
- Track skip speed heavily early on — it's the fastest negative signal

### 7. Analytics & Metrics Dashboard

**User-facing (eventually):** None at MVP — no creator tools yet.

**Internal dashboard (critical from day 1):**
- DAU/MAU, session length, sessions per day
- Average loops per video (THE key engagement metric)
- Skip rate by video
- Retention curves (D1, D7, D30)
- Feed position vs. engagement (does engagement drop after N videos?)
- Video upload rate
- Algorithm performance (CTR, engagement by recommendation source)

---

## Content Seeding Strategy

Since the app launches with no user-generated content, we need to seed the feed:

1. **Creative Commons / Public Domain video** — curate the best 6-second clips
2. **Pexels / Pixabay API integration** — pull free stock video, auto-trim to 6s
3. **Creator outreach** — find small creators willing to cross-post for early exposure
4. **Self-generated content** — record seed content that fits the brand voice
5. **Import flow** — make it trivially easy for creators to upload existing short clips

**Goal:** Have 500+ seed videos across diverse categories before any real user touches the app.

---

## UI/UX Design Principles

### Philosophy
The UI should feel like it doesn't exist. Content is the entire experience. Chrome appears only when needed, then dissolves.

### Specific Guidelines
- **Background:** Pure black (#000000) — OLED true black
- **Text overlays:** White with very subtle purple glow/shadow for readability
- **Interactive elements:** Near-transparent with faint purple glow on tap
- **Transitions:** Smooth, physics-based (spring animations)
- **Scroll behavior:** Snap-to-video with natural deceleration. This MUST feel premium.
- **Haptics:**
  - Like: Sharp, satisfying tap (UIImpactFeedbackGenerator, medium)
  - Post published: Success pattern (UINotificationFeedbackGenerator, success)
  - Scroll snap: Subtle tick (UIImpactFeedbackGenerator, light)
  - Long press: Soft ramp-up vibration
- **Loading:** No spinners. Preload next 2-3 videos aggressively. The feed should feel infinite and instant.
- **Typography:** System SF Pro (iOS native) — clean, doesn't compete with content
- **Icons:** Ultra-thin line icons, white, subtle glow on active state

### Key Screens
1. **Feed** (home — For You + Following tabs)
2. **Camera/Record** (center tab)
3. **Profile** (your videos, followers, following)
4. **Comments** (bottom sheet overlay)
5. **Search/Discover** (minimal — hashtags, trending)

### Navigation
- Bottom tab bar: Feed | Discover | [Record] | Notifications | Profile
- Tab bar is semi-transparent, blurs background content
- Record button is centered and slightly elevated (the main CTA)

---

## Technical Architecture

### Platform
- **iOS only** (native Swift/SwiftUI)
- Minimum iOS version: iOS 17

### Frontend (iOS App)
- **SwiftUI** for UI layer
- **AVFoundation** for video playback and recording
- **AVKit** for player controls
- **Core Haptics** for custom haptic patterns
- **Combine** for reactive data flow

### Backend
- **Python (FastAPI)** — API server
- **PostgreSQL** — primary database (users, videos, interactions, follows)
- **Redis** — caching, session management, real-time counters
- **Recommendation engine** — Python-based, runs as a separate service

### Video Infrastructure
- **Cloudflare Stream** — cheapest option for transcoding + CDN delivery + adaptive bitrate
- ~$1/1000 min stored, ~$1/1000 min delivered
- 6-second videos = extremely efficient storage
- Alternative fallback: **Cloudflare R2** (storage) + **FFmpeg** (self-transcode) for even cheaper

### Auth
- Auto-generated UUID-based accounts on first launch
- Store device token in Keychain
- Optional upgrade to full account (Apple Sign-In, email/pass, phone)

### Hosting (Budget-Conscious)
- **Railway** or **Fly.io** for backend API (~$5-20/mo to start)
- **Supabase** for PostgreSQL + auth helpers (free tier is generous)
- **Cloudflare Stream** for video ($0 minimum, pay-as-you-go)
- **Cloudflare R2** for any static assets (free tier: 10GB)

**Estimated monthly cost at launch:** $10-30/mo
**At 1,000 DAU:** ~$50-100/mo
**At 10,000 DAU:** ~$200-500/mo (this is when you need more investment)

---

## Content Moderation

- **Minimum viable moderation** for App Store compliance
- Apple requires you handle: CSAM reporting, user blocking, content reporting
- Implement: Report button on every video, block user option, basic profanity filter on comments
- Review reported content manually to start
- This is the bare minimum — plan to invest more here as you scale

---

## Go-to-Market Strategy

### Pre-Launch
- Build hype on TikTok (ironic, self-aware marketing)
- "We built a TikTok competitor and it's called Vibeslol"
- Seed content library (500+ videos)

### Launch
- **TestFlight beta** with friends and early believers
- **Product Hunt** launch
- **Reddit** posts in relevant communities (r/apps, r/ios, r/startups)
- **TikTok/Instagram Reels** marketing — use the platforms you're competing with

### Growth Loops
- Share-to-socials with Vibeslol watermark/branding
- "Found on Vibeslol" becomes the viral phrase
- 6-second constraint is inherently shareable — perfect for Twitter/X embeds
- Invite system with small perks (custom profile colors, etc.)

### Creator Acquisition
- DM small creators on TikTok: "Your content would kill on 6-second format"
- Early creator perks (verified badge, featured placement)
- Eventually: creator fund (when monetization exists)

---

## Monetization (Future — NOT at launch)

- No ads at launch. Period.
- Future options:
  - Native video ads (6-second ads fit the format perfectly)
  - Tipping / virtual gifts
  - Premium features (custom effects, analytics, profile themes)
  - Brand partnerships

---

## Success Metrics

### North Star Metric
**Average loops per video per session** — this tells you if the content is compelling AND the feed is working.

### Key Metrics
| Metric | Target (Month 1) |
|--------|------------------|
| D1 Retention | >40% |
| D7 Retention | >20% |
| Avg session length | >5 min |
| Avg loops per video | >1.5 |
| Videos posted/day | >10 |
| DAU | >100 (beta) |

---

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| No content at launch | Aggressive seeding strategy |
| Algorithm sucks early on | Start with simple popularity-based, iterate fast |
| Video costs spike | 6s format is inherently cheap; monitor closely |
| App Store rejection | Follow guidelines for 13+, add moderation, privacy policy |
| Nobody downloads it | The brand voice IS the marketing — lean into it hard |
| Legal issues with seeded content | Use only CC/public domain, Pexels/Pixabay licensed content |

---

## MVP Scope Summary

**In:**
- Full-screen 6-second video feed with snap scroll
- Basic recommendation algorithm (popularity + collaborative filtering)
- Video recording + upload + trim-to-6s
- Like, comment, share
- Auto-generated accounts + optional sign-up
- Follow system
- Near-transparent purple-glow UI
- Haptic feedback on key interactions
- Content seeding from free sources
- Internal analytics dashboard
- Basic moderation (report, block)

**Out (for now):**
- Music/audio library
- Video effects/filters
- DMs/messaging
- Creator tools/analytics
- Monetization/ads
- Android
- Landscape mode
- Duets/stitches/reactions

---

## Development Phases

### Phase 1: Foundation
- Project setup (Xcode, SwiftUI, backend scaffolding)
- Video playback engine (the most critical piece)
- Feed UI with snap scroll and physics
- Basic API (video list, user creation)

### Phase 2: Core Loop
- Video recording and upload flow
- Trim-to-6s tool
- Like/comment/share
- User profiles and follow system
- Auto-account generation

### Phase 3: Algorithm & Feed
- Interaction tracking (loops, skips, watch time)
- V1 recommendation engine
- For You + Following feed tabs
- Content seeding pipeline

### Phase 4: Polish & Launch
- Haptic feedback system
- UI refinement (transparency, glow effects, animations)
- Analytics dashboard (internal)
- Moderation tools (report, block)
- Content seeding (500+ videos)
- TestFlight beta → App Store submission
