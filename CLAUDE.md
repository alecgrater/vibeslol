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
│   │   ├── VideoTrimmerView.swift # Trim-to-6s scrubber UI with thumbnail strip
│   │   ├── CommentSheetView.swift # Comment bottom sheet with posting
│   │   └── UserProfileView.swift  # Other user's profile with video grid + follow button
│   ├── ViewModels/
│   │   ├── FeedViewModel.swift    # Feed data + analytics stubs
│   │   ├── CameraViewModel.swift  # AVCaptureSession, recording, timer logic
│   │   └── VideoTrimmerViewModel.swift # Thumbnail generation, trim export logic
│   │   └── CommentViewModel.swift # Comment fetching, posting logic
│   │   └── UserProfileViewModel.swift # Other user profile + follow logic
│   ├── Models/
│   │   ├── Video.swift            # Video model (resolvedURL for bundle/remote)
│   │   ├── User.swift             # User model with anonymous support
│   │   └── Comment.swift          # Comment model with timeAgo
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
│   │   ├── api/routes.py         # /api/users, /api/videos endpoints
│   │   ├── models/               # User, Video, Like, Follow, VideoView DB models
│   │   ├── schemas.py            # Pydantic request/response schemas
│   │   ├── services/             # Business logic (empty)
│   │   └── recommendations/      # V1 recommendation engine
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
- [x] **Feature C: Backend API — Users + Videos** — SQLAlchemy models for User/Video/Like/Follow. API endpoints: POST /users/anonymous, GET /videos/feed, POST /videos/{id}/like, POST /videos (upload). Wire up APIClient.swift.
- [x] **Feature D: Auto-Account Generation** — On first app launch, auto-create anonymous account via POST /api/users/anonymous (pass device_token). Store user ID + device token in Keychain. Wire up APIClient.likeVideo with stored userId. Show username in Profile tab. — On first app launch, auto-create anonymous account via POST /api/users/anonymous (pass device_token). Store user ID + device token in Keychain. Wire up APIClient.likeVideo with stored userId. Show username in Profile tab.
- [x] **Feature E: Like/Comment/Share Wired Up** — Connect like button to API. Add comment bottom sheet with real comment posting. Share via native iOS share sheet.
- [x] **Feature F: User Profiles + Follow System** — Profile screen showing user's videos in a grid. Follow/unfollow button. Follower/following counts. Following tab in feed.
- [x] **Feature G: Algorithm V1** — Track watch time, loops, skips. Build simple recommendation engine (popularity + collaborative filtering). Replace mock feed with algorithm-served feed.
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

**Feature C (Backend API — Users + Videos):**
- New files: models/base.py (DeclarativeBase), models/user.py (User), models/video.py (Video), models/like.py (Like), models/follow.py (Follow), schemas.py (Pydantic schemas), api/routes.py (all API endpoints)
- Modified: models/__init__.py (exports all models), main.py (lifespan for table creation, router include, static file mount for uploads), APIClient.swift (full HTTP client with real endpoints), Video.swift (added CodingKeys for snake_case API), User.swift (added CodingKeys for snake_case API), FeedViewModel.swift (async API calls with bundled fallback, pagination support)
- API endpoints: POST /api/users/anonymous, GET /api/users/{id}, GET /api/videos/feed (paginated, reverse-chrono), POST /api/videos (multipart upload), POST /api/videos/{id}/like (toggle like/unlike)
- Database tables auto-created via metadata.create_all in lifespan (dev only — use alembic for prod)
- Video uploads saved to backend/uploads/ and served via FastAPI StaticFiles mount
- APIClient.swift includes multipart form-data upload helper (Data extensions), UploadResponse/LikeResponse/APIError types
- FeedViewModel now calls API with graceful fallback to Video.mockFeed when backend is unreachable
- Like endpoint is a toggle (like/unlike) and returns new count + liked status
- Python 3.8 constraint: all models use typing.Optional instead of str | None
- Gotcha for Feature D: APIClient.likeVideo requires userId param — Feature D needs to store the user ID from createAnonymousUser and pass it through. FeedViewModel.likeVideo has a TODO to wire this up once auth exists.
- Gotcha for Feature D: The createAnonymousUser endpoint accepts optional device_token in the body. Feature D should generate and store a device UUID in Keychain, then pass it here.

**Feature D (Auto-Account Generation):**
- New files: KeychainService.swift (Services), AuthManager.swift (Services), ProfileView.swift (Views)
- Modified: VibeslolApp.swift (added @StateObject AuthManager + .task bootstrap), ContentView.swift (replaced Profile placeholder with ProfileView), FeedViewModel.swift (wired likeVideo to AuthManager.shared.userId + API sync with server-confirmed count), project.pbxproj (3 new files)
- KeychainService wraps Security framework with kSecClassGenericPassword for userId, deviceToken, username storage. Uses kSecAttrAccessibleAfterFirstUnlock for persistence.
- AuthManager is a @MainActor ObservableObject singleton. bootstrap() checks Keychain for existing userId — if found, refreshes from API (falls back to cached Keychain data if API unreachable). If no userId, generates UUID device token, calls createAnonymousUser, stores credentials in Keychain. Handles offline first-launch gracefully with local-only User.anonymous fallback.
- ProfileView shows avatar circle with initial letter, @username, anonymous badge, follower/following/video stats, empty state for no videos. Uses vibePurple glow accents on OLED black.
- FeedViewModel.likeVideo now does optimistic update + async API call with AuthManager.shared.userId, updates to server-confirmed like count on success.
- Gotcha for Feature E: AuthManager.shared.userId is the source of truth for the current user's ID. Use it in any API call that needs user identity. AuthManager.shared.currentUser has the full User object. Like button in FeedView should track liked state per-video (not yet done — Feature E should add a Set<String> of liked video IDs).
- Gotcha for Feature E: ProfileView currently shows static 0 counts. Feature F will need to refresh user from API to get real counts.

**Feature E (Like/Comment/Share Wired Up):**
- New files: Comment.swift (Models), CommentSheetView.swift (Views), CommentViewModel.swift (ViewModels), comment.py (backend models)
- Modified: FeedView.swift (wired like button to viewModel.likeVideo, added comment bottom sheet via .sheet, added share sheet via UIActivityViewController), FeedViewModel.swift (added likedVideoIds Set<String> for like state tracking, toggle-aware likeVideo with optimistic update + server sync + revert on failure, updateCommentCount method), APIClient.swift (added fetchComments + postComment endpoints), routes.py (GET/POST /api/videos/{id}/comments), schemas.py (CommentOut + CommentCreateRequest), models/__init__.py (exports Comment), user.py (comments relationship), video.py (comments relationship), project.pbxproj (3 new files)
- Backend Comment model: id (autoincrement), user_id (FK), video_id (FK), text, created_at. Like model pattern replicated.
- CommentSheetView: bottom sheet with drag handle, comment list (avatar + username + timeAgo + text), text input with send button, empty state. Uses .presentationDetents([.medium, .large]).
- CommentViewModel: loads comments from API, posts new comments (inserts at top), requires AuthManager.shared.userId.
- FeedViewModel.likeVideo now properly toggles: tracks liked state in likedVideoIds Set, does optimistic count +/- 1, syncs with server, reverts on failure.
- ShareSheetView wraps UIActivityViewController with video caption text + video URL.
- VideoCell now takes viewModel as @ObservedObject to wire like/comment/share. isLiked is computed from viewModel.likedVideoIds.
- Comment.timeAgo computed property formats relative time (s/m/h/d).
- Gotcha for Feature F: ProfileView still shows static 0 counts. Feature F should fetch user from API to get real follower/following/video counts. Also, the comment sheet allows anonymous users to comment — PRD says only non-anonymous users should be able to comment. Feature F or a later polish pass should gate this.

**Feature F (User Profiles + Follow System):**
- New files: UserProfileView.swift (Views), UserProfileViewModel.swift (ViewModels)
- Modified: ProfileView.swift (added video grid via LazyVGrid, loads user's videos from API on appear), FeedView.swift (added For You/Following tab switcher at top, wrapped in NavigationStack, tappable @username navigates to UserProfileView, added emptyFollowingState for no-follow-content), FeedViewModel.swift (added FeedMode enum + switchFeedMode + loadFollowingFeed support), APIClient.swift (added toggleFollow, checkIsFollowing, fetchUserVideos, fetchFollowingFeed endpoints + FollowResponse type), Video.swift (added authorId: String? field + updated all mock constructors), routes.py (POST /api/users/{id}/follow toggle, GET /api/users/{id}/videos, GET /api/videos/following-feed, GET /api/users/{id}/is-following), schemas.py (FollowOut schema, author_id added to VideoOut), project.pbxproj (2 new files)
- Backend follow toggle: POST /api/users/{user_id}/follow accepts follower_id via Form, checks for existing Follow row, creates or deletes it, returns FollowOut(following, follower_count). Self-follow blocked with 400.
- UserProfileView: shows other user's profile with avatar, @username, follow/unfollow button (vibePurple fill when not following, outline when following), stats row, video grid (3-column LazyVGrid with 9:16 aspect ratio cells). Wrapped in NavigationStack for back button.
- UserProfileViewModel: loads user + videos + follow status concurrently. toggleFollow uses optimistic update pattern (revert on API failure). Uses HapticsService.mediumTap() on follow.
- FeedView now has NavigationStack with .navigationDestination(for: String.self) routing authorId to UserProfileView. Feed mode tabs (For You / Following) float at the top with purple underline indicator.
- Video.authorId is Optional<String> to maintain backward compatibility with bundled mock videos (which have no author).
- VideoOut schema now includes author_id so iOS can navigate from feed → user profile.
- Gotcha for Feature G: The following-feed endpoint is reverse-chronological like the main feed. Algorithm V1 should improve both feeds with recommendation logic. The FeedMode enum and switchFeedMode pattern in FeedViewModel make it easy to add algorithm-served feeds later.
- Gotcha for Feature G: Comment sheet still allows anonymous users to comment — PRD says only non-anonymous users should be able to comment. Feature H polish pass should gate this.

**Feature G (Algorithm V1):**
- New files: models/video_view.py (VideoView model for watch event tracking), recommendations/engine.py (V1 recommendation engine)
- Modified: models/__init__.py (exports VideoView), schemas.py (WatchEventRequest + WatchEventOut), api/routes.py (POST /api/analytics/watch endpoint, GET /api/videos/feed now uses algorithm + accepts user_id param)
- Modified iOS: FeedViewModel.swift (onVideoAppear/onFeedDisappear/trackView for analytics, fetchFeed now passes userId for personalized recs), FeedView.swift (VideoCell.onChange tracks watch duration + loops on video switch, FeedView.onDisappear flushes analytics), APIClient.swift (trackWatchEvent endpoint, fetchFeed accepts userId param)
- VideoView model tracks: user_id, video_id, watch_duration_ms, loop_count, skipped (bool), watch_percentage, created_at
- Recommendation engine scoring: popularity (likes×1 + loops×2 + comments×1.5 + shares×3), collaborative filtering (users who liked same videos), recency boost (48h half-life exponential decay), anti-repetition (exclude watched videos)
- Feed composition: 70% algorithm-ranked picks, 30% random discovery (min 2 discovery slots per page)
- POST /api/analytics/watch also increments video.loop_count aggregate when loop_count > 0
- iOS tracks watch events on video transition (onChange of isActive): sends videoId, loopCount, watchDuration. Skipped = watched < 3s.
- Key decision: Kept following-feed as reverse-chronological (algorithm only powers For You tab). Following-feed is relationship-based, not ranked.
- Key decision: Used candidate pool approach (fetch 5× limit, score all, take top) rather than SQL-level scoring for flexibility.
- Gotcha for Feature H: Anonymous comment gating still needed. Also, the VideoView table should be indexed on (user_id, video_id) for production performance. The N+1 query issue in routes.py (fetching each author separately) persists — Feature H should add eager loading or a JOIN.

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
