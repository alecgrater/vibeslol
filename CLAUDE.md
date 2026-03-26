# Vibeslol Project Context

## What This Is
Vibeslol is a 6-second vertical video platform (TikTok competitor) for iOS.
- Native iOS app built with SwiftUI
- Python FastAPI backend
- SQLite database (local dev)
- Custom recommendation engine in Python

## Tech Stack
- **iOS:** Swift, SwiftUI, AVFoundation, Core Haptics, Combine
- **Backend:** Python 3, FastAPI, SQLAlchemy, Alembic, aiosqlite
- **Database:** SQLite (local dev), PostgreSQL (production)
- **Video:** Cloudflare Stream API (future), bundled mp4s (current)
- **Package Management:** UV (NEVER use pip or python directly)

## Project Structure
```
vibeslol/
├── ios/Vibeslol/              # Xcode project (SwiftUI)
│   ├── App/VibeslolApp.swift  # Entry point, dark mode forced
│   ├── Views/
│   │   ├── ContentView.swift      # Tab navigation
│   │   ├── FeedView.swift         # Vertical snap-scroll video feed
│   │   ├── TabBarView.swift       # Translucent bottom tab bar
│   │   ├── VideoPlayerView.swift  # AVPlayerLayer UIViewRepresentable
│   │   ├── CameraView.swift       # Camera recording screen (record, countdown, preview)
│   │   ├── CameraPreviewView.swift # AVCaptureVideoPreviewLayer UIViewRepresentable
│   │   └── VideoTrimmerView.swift # Trim-to-6s scrubber UI with thumbnail strip
│   ├── ViewModels/
│   │   ├── FeedViewModel.swift    # Feed data + analytics stubs
│   │   ├── CameraViewModel.swift  # AVCaptureSession, recording, timer logic
│   │   └── VideoTrimmerViewModel.swift # Thumbnail generation, trim export logic
│   ├── Models/
│   │   ├── Video.swift            # Video model (resolvedURL for bundle/remote)
│   │   └── User.swift             # User model with anonymous support
│   ├── Services/
│   │   ├── APIClient.swift        # API client stub
│   │   ├── HapticsService.swift   # Like, tap, scroll snap, success haptics
│   │   ├── VideoPlayerManager.swift # AVQueuePlayer + AVPlayerLooper
│   │   └── VideoPreloader.swift   # Preloads 2 videos ahead, evicts old ones
│   ├── Utils/Colors.swift         # vibePurple (#9449FF)
│   └── Resources/Videos/          # 5 bundled 6s seed videos (generated)
├── backend/
│   ├── app/
│   │   ├── main.py               # FastAPI app with /health endpoint
│   │   ├── core/config.py        # DB config, Cloudflare keys, app settings
│   │   ├── core/database.py      # Async SQLAlchemy session
│   │   ├── api/                  # Route handlers (empty)
│   │   ├── models/               # DB models (empty)
│   │   ├── services/             # Business logic (empty)
│   │   └── recommendations/      # Algorithm (empty)
│   └── pyproject.toml
├── scripts/generate_videos.py     # Python video generator (opencv)
├── PRD.md                         # Full product requirements
├── SETUP_GUIDE.md                 # Dev environment guide
└── CLAUDE.md                      # This file
```

## Key Design Principles
- UI must be near-transparent with subtle purple glow accents
- Background is pure black (#000000) for OLED
- All videos are EXACTLY 6 seconds
- Haptic feedback on like, post, scroll snap
- Feed must feel infinite and instant (preload aggressively)
- Zero-friction onboarding (auto-generated anonymous account)
- Portrait only

## Development Rules
- ALWAYS use UV for Python (uv run, uv pip install, uv add)
- iOS minimum deployment target: iOS 17
- Use SwiftUI (not UIKit) unless absolutely necessary
- Use MVVM architecture for iOS
- Use async/await throughout the backend
- Run the backend with: cd backend && uv run uvicorn app.main:app --reload
- Build iOS: cd ios && xcodebuild -project Vibeslol.xcodeproj -scheme Vibeslol -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
- Simulators available: iPhone 17, iPhone 17 Pro, iPhone 17 Pro Max, iPhone Air
- After adding new .swift files, update ios/Vibeslol.xcodeproj/project.pbxproj (PBXBuildFile, PBXFileReference, PBXGroup, PBXSourcesBuildPhase sections)
- After building: xcrun simctl install "iPhone 17 Pro" ~/Library/Developer/Xcode/DerivedData/Vibeslol-ercwfohezxnzvzbifovtowepeonj/Build/Products/Debug-iphonesimulator/Vibeslol.app && xcrun simctl launch "iPhone 17 Pro" com.vibeslol.app

## Build Progress

### COMPLETED
- [x] Phase 1: Foundation
  - Xcode project setup with SwiftUI
  - Video playback engine (AVQueuePlayer + AVPlayerLooper + seamless looping)
  - Vertical snap-scroll feed with iOS 17 ScrollView paging
  - Video preloading (2 ahead, eviction)
  - Near-transparent UI overlay with purple glow
  - Haptic feedback (like, scroll snap, tab tap)
  - Bottom tab bar (Feed/Discover/Record/Notifications/Profile)
  - FastAPI backend scaffold with /health endpoint
  - SQLite database setup with async SQLAlchemy
  - 5 bundled seed videos (Python-generated animations)

### BUILD QUEUE (do these in order, one per session)
- [x] **Feature A: Camera + Recording Screen** — In-app camera with countdown timer, record 6s video, preview before posting. Add CameraView.swift, CameraViewModel.swift. Wire up the Record tab.
- [x] **Feature B: Trim-to-6s Tool** — When uploading from camera roll, let user select a 6s window from a longer video. Scrubber UI with preview. Wire up the photo library button already in CameraView.swift.
- [ ] **Feature C: Backend API — Users + Videos** — SQLAlchemy models for User/Video/Like/Follow. API endpoints: POST /users/anonymous, GET /videos/feed, POST /videos/{id}/like, POST /videos (upload). Wire up APIClient.swift.
- [ ] **Feature D: Auto-Account Generation** — On first app launch, auto-create anonymous account via API. Store device token in Keychain. Show username in Profile tab.
- [ ] **Feature E: Like/Comment/Share Wired Up** — Connect like button to API. Add comment bottom sheet with real comment posting. Share via native iOS share sheet.
- [ ] **Feature F: User Profiles + Follow System** — Profile screen showing user's videos in a grid. Follow/unfollow button. Follower/following counts. Following tab in feed.
- [ ] **Feature G: Algorithm V1** — Track watch time, loops, skips. Build simple recommendation engine (popularity + collaborative filtering). Replace mock feed with algorithm-served feed.
- [ ] **Feature H: Polish + Launch Prep** — UI animations refinement, content moderation (report/block), analytics dashboard, App Store submission prep.

### COMPLETED FEATURE LOG
<!-- After each feature, append a brief entry here so future sessions know what exists -->
**Phase 1 (Foundation):**
- Files: VibeslolApp.swift, ContentView.swift, FeedView.swift, TabBarView.swift, VideoPlayerView.swift, FeedViewModel.swift, Video.swift, User.swift, HapticsService.swift, APIClient.swift, VideoPlayerManager.swift, VideoPreloader.swift, Colors.swift
- Backend: main.py (FastAPI /health), core/config.py (SQLite + CF keys), core/database.py (async session)
- Key decisions: iOS 17 ScrollView paging (not TabView rotation hack), AVPlayerLooper for seamless loops, bundled mp4s for dev (not streaming yet), vibePurple = #9449FF

**Feature A (Camera + Recording Screen):**
- New files: CameraView.swift, CameraPreviewView.swift (Views), CameraViewModel.swift (ViewModels)
- Modified: ContentView.swift (wired Record tab to CameraView), project.pbxproj (3 new files + camera/mic permission keys)
- CameraViewModel uses AVCaptureSession + AVCaptureMovieFileOutput, auto-stops at 6s via maxRecordedDuration
- Two recording modes: immediate tap (record button) or 3-2-1 countdown (timer button)
- Preview screen loops recorded video with Retake / Use Video buttons
- CameraPreviewView is a UIViewRepresentable wrapping AVCaptureVideoPreviewLayer
- Front/back camera flip supported, video mirroring for front camera
- NSCameraUsageDescription + NSMicrophoneUsageDescription added via INFOPLIST_KEY build settings
- Gotcha for Feature B: CameraView has a photo library button placeholder (photo.on.rectangle icon) that should be wired to the trim-to-6s picker

**Feature B (Trim-to-6s Tool):**
- New files: VideoTrimmerView.swift (Views), VideoTrimmerViewModel.swift (ViewModels)
- Modified: CameraView.swift (replaced photo library placeholder with PhotosPicker, added .trimming state rendering), CameraViewModel.swift (added .trimming state, pickedVideoURL, handlePickedVideo/handleTrimComplete/cancelTrim methods, MovieTransferable struct), project.pbxproj (2 new files + NSPhotoLibraryUsageDescription)
- PhotosPicker (PhotosUI) used for video selection — filters to .videos only
- MovieTransferable implements Transferable protocol to load video from PhotosPickerItem as a temp file URL
- Videos <= 6.5s go straight to preview; longer videos enter trimmer
- VideoTrimmerViewModel generates 20 thumbnail frames via AVAssetImageGenerator, manages scrub position (0-1 normalized), exports trimmed clip via AVAssetExportSession
- VideoTrimmerView shows: looping video preview of selected 6s window, thumbnail strip with bright selection window (dimmed outside), grab handles, purple glow border, time labels, Cancel/Use Clip buttons
- Player uses addPeriodicTimeObserver to loop within the 6s window (seeks back to startTime when reaching endTime)
- Drag gesture on scrubber tracks dragStartScrub to handle incremental translation correctly
- NSPhotoLibraryUsageDescription added to both Debug and Release build settings
- Gotcha for Feature C: MovieTransferable is defined in CameraViewModel.swift — if it needs to be reused elsewhere, consider moving to Models/

### INSTRUCTIONS FOR AUTONOMOUS BUILD
When starting a new session after /clear:
1. Read this file (CLAUDE.md) and PRD.md
2. Find the first unchecked item in BUILD QUEUE
3. Build it completely (create files, update xcodeproj, compile, test)
4. After building, update THIS FILE:
   a. Mark the feature [x] in BUILD QUEUE
   b. Append to COMPLETED FEATURE LOG: files created/modified, key decisions made, any gotchas the next session should know
   c. If the next feature's requirements changed based on what you built, update its description
5. Commit and push (include CLAUDE.md in the commit)
6. Stop and tell the user: "Feature X done. /clear and paste the prompt again for Feature Y."
