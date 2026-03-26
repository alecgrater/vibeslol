# Vibeslol Project Context

## What This Is
Vibeslol is a 6-second vertical video platform (TikTok competitor) for iOS.
- Native iOS app built with SwiftUI
- Python FastAPI backend
- PostgreSQL database
- Cloudflare Stream for video infrastructure
- Custom recommendation engine in Python

## Tech Stack
- **iOS:** Swift, SwiftUI, AVFoundation, Core Haptics, Combine
- **Backend:** Python 3, FastAPI, SQLAlchemy, Alembic, asyncpg
- **Database:** SQLite (local dev), PostgreSQL (production)
- **Video:** Cloudflare Stream API
- **Package Management:** UV (NEVER use pip or python directly)

## Project Structure
```
vibeslol/
├── ios/Vibeslol/          # Xcode project (SwiftUI)
│   ├── App/               # App entry point
│   ├── Views/             # SwiftUI views
│   ├── ViewModels/        # MVVM view models
│   ├── Models/            # Data models
│   ├── Services/          # API client, video player, haptics
│   └── Utils/             # Extensions, helpers
├── backend/
│   ├── app/
│   │   ├── api/           # FastAPI route handlers
│   │   ├── core/          # Config, security, dependencies
│   │   ├── models/        # SQLAlchemy models
│   │   ├── services/      # Business logic
│   │   └── recommendations/ # Recommendation engine
│   ├── alembic/           # Database migrations
│   └── tests/
├── PRD.md                 # Product requirements
├── SETUP_GUIDE.md         # Dev environment guide
└── CLAUDE.md              # This file
```

## Key Design Principles
- UI must be near-transparent with subtle purple glow accents
- Background is pure black (#000000) for OLED
- All videos are EXACTLY 6 seconds
- Haptic feedback on like, post, scroll snap
- Feed must feel infinite and instant (preload aggressively)
- Zero-friction onboarding (auto-generated anonymous account)

## Development Rules
- ALWAYS use UV for Python (uv run, uv pip install, uv add)
- iOS minimum deployment target: iOS 17
- Use SwiftUI (not UIKit) unless absolutely necessary
- Use MVVM architecture for iOS
- Use async/await throughout the backend
- All API endpoints must be documented with OpenAPI/Swagger
- Write tests for backend business logic
- Run the backend with: cd backend && uv run uvicorn app.main:app --reload
- Build iOS: cd ios && xcodebuild -project Vibeslol.xcodeproj -scheme Vibeslol -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
- Simulators available: iPhone 17, iPhone 17 Pro, iPhone 17 Pro Max, iPhone Air
