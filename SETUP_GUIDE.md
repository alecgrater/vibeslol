# Vibeslol — Dev Environment & Claude Code Setup Guide

Everything you need to install, configure, and set up to build Vibeslol from scratch.

---

## Part 1: Dev Environment Setup

### Step 1: Install Core Tools

You need these installed on your Mac:

```bash
# 1. Xcode (from Mac App Store)
# Open App Store → search "Xcode" → Install
# This takes a while (10+ GB). Start this first.

# 2. After Xcode installs, open it once to accept the license:
sudo xcodebuild -license accept

# 3. Install Xcode command line tools (may already be installed)
xcode-select --install

# 4. Install Homebrew (if you don't have it)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 5. Install UV (Python package manager — required per your config)
brew install uv

# 6. Install Git (likely already installed, but make sure)
brew install git

# 7. Install PostgreSQL (for local development)
brew install postgresql@16
brew services start postgresql@16

# 8. Install Redis (for caching layer)
brew install redis
brew services start redis

# 9. Install FFmpeg (for local video processing/testing)
brew install ffmpeg

# 10. Install the GitHub CLI (for PRs, issues, etc.)
brew install gh
gh auth login
```

### Step 2: Set Up the iOS Project

```bash
# Navigate to your project directory
cd ~/git/vibeslol

# Create Xcode project
# Open Xcode → File → New → Project
# Choose: iOS → App
# Product Name: Vibeslol
# Team: Your Apple Developer account
# Organization Identifier: com.vibeslol (or your domain)
# Interface: SwiftUI
# Language: Swift
# Storage: None
# Check "Include Tests"
# Save to: ~/git/vibeslol/ios/
```

**Important:** You need an Apple Developer account ($99/year) to:
- Test on a physical device
- Submit to the App Store
- Use TestFlight

Sign up at https://developer.apple.com if you haven't.

### Step 3: Set Up the Backend

```bash
cd ~/git/vibeslol

# Create backend directory
mkdir -p backend

# Create Python virtual environment with UV
cd backend
uv venv
source .venv/bin/activate

# Initialize a pyproject.toml
uv init

# Install core dependencies
uv add fastapi uvicorn[standard] sqlalchemy asyncpg alembic redis pydantic python-jose[cryptography] passlib[bcrypt] httpx python-multipart

# Install dev dependencies
uv add --dev pytest pytest-asyncio httpx ruff

# Create project structure
mkdir -p app/{api,core,models,services,recommendations}
touch app/__init__.py
touch app/api/__init__.py
touch app/core/__init__.py
touch app/models/__init__.py
touch app/services/__init__.py
touch app/recommendations/__init__.py
touch app/main.py
```

### Step 4: Set Up the Database

```bash
# Create the database
createdb vibeslol

# You'll use Alembic for migrations (Claude will set this up)
cd ~/git/vibeslol/backend
uv run alembic init alembic
```

### Step 5: Set Up Cloudflare Stream

1. Create a Cloudflare account at https://cloudflare.com
2. Go to Dashboard → Stream
3. Get your **API Token** (create one with Stream permissions)
4. Get your **Account ID** (shown in the dashboard URL)
5. Save these — you'll need them for the backend config

### Step 6: Initialize Git

```bash
cd ~/git/vibeslol
git init

# Create .gitignore
cat > .gitignore << 'EOF'
# Python
__pycache__/
*.py[cod]
.venv/
*.egg-info/
dist/
build/

# Environment
.env
.env.local
*.pem

# iOS
*.xcuserstate
xcuserdata/
DerivedData/
*.ipa
*.dSYM.zip
*.dSYM

# IDE
.vscode/
.idea/
*.swp

# OS
.DS_Store
Thumbs.db

# Cloudflare
wrangler.toml
EOF

git add .
git commit -m "Initial project setup"
```

---

## Part 2: Claude Code Setup for Maximum Effectiveness

### Step 1: Install Claude Code

```bash
# Install Claude Code CLI
npm install -g @anthropic-ai/claude-code

# Or if you already have it, update:
npm update -g @anthropic-ai/claude-code

# Verify installation
claude --version
```

### Step 2: Create Project CLAUDE.md

This is the most important file for Claude Code. It gives Claude persistent context about your project.

Create `~/git/vibeslol/CLAUDE.md`:

```markdown
# Vibeslol Project Context

## What This Is
Vibeslol is a 6-second vertical video platform (TikTok competitor) for iOS.
- Native iOS app built with SwiftUI
- Python FastAPI backend
- PostgreSQL database, Redis cache
- Cloudflare Stream for video infrastructure
- Custom recommendation engine in Python

## Tech Stack
- **iOS:** Swift, SwiftUI, AVFoundation, Core Haptics, Combine
- **Backend:** Python 3.12+, FastAPI, SQLAlchemy, Alembic, asyncpg
- **Database:** PostgreSQL 16, Redis
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
├── SETUP_GUIDE.md         # This file
└── CLAUDE.md              # Claude Code context
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

## API Base
- Local: http://localhost:8000
- API docs: http://localhost:8000/docs
```

### Step 3: Set Up Memory Structure

Claude Code already has your memory directory. Organize it for a project this size:

The auto-memory in `~/.claude/projects/-Users-alecgc-git-vibeslol/memory/` will automatically track learnings. But you can also seed it with project context.

### Step 4: Install Useful MCP Servers

MCP servers give Claude extra capabilities. Here are the ones that matter for this project:

```bash
# 1. Context7 — pulls up-to-date library docs so Claude doesn't hallucinate APIs
# Useful for: SwiftUI, FastAPI, SQLAlchemy, Cloudflare Stream docs
claude mcp add context7 -- npx -y @upstash/context7-mcp

# 2. Sequential Thinking — helps Claude break down complex problems step by step
# Useful for: algorithm design, architecture decisions, debugging
claude mcp add sequential-thinking -- npx -y @anthropic/mcp-sequential-thinking

# 3. Filesystem MCP — enhanced file operations (already built into Claude Code, but the MCP version adds extras)
# Skip this one — Claude Code's built-in tools are sufficient

# 4. Postgres MCP — lets Claude query your database directly
# Useful for: debugging data issues, checking migrations, testing queries
claude mcp add postgres -- npx -y @anthropic/mcp-postgres postgresql://localhost:5432/vibeslol
```

### Step 5: Configure Claude Code Settings

Run these in your project directory:

```bash
cd ~/git/vibeslol

# Set up permission allowances for common operations so you don't have to approve every command
claude config set allowedTools '["Bash(uv *)", "Bash(cd *)", "Bash(git *)", "Bash(swift *)", "Bash(xcodebuild *)", "Bash(createdb *)", "Bash(psql *)", "Bash(curl *)", "Bash(ls *)", "Bash(mkdir *)", "Bash(cat *)", "Bash(touch *)"]'
```

### Step 6: GSD Workflow (You Already Have This)

You have the GSD skill installed which is excellent for a project this size. Use it:

```
/gsd:new-project          # Initialize project tracking
/gsd:plan-phase           # Plan each development phase
/gsd:execute-phase        # Execute with parallel agents
/gsd:progress             # Check where you are
/gsd:verify-work          # Validate features work
```

This keeps Claude organized across sessions and prevents context loss.

---

## Part 3: Workflow Tips for Solo Vibe Coding

### Session Management
- **Start each session with:** `/gsd:resume-work` or `/gsd:progress`
- **Before ending a session:** `/gsd:pause-work` to save context
- **This prevents Claude from losing track** of where you are

### When Claude Gets Confused
1. **"Read the PRD"** — tell Claude to re-read PRD.md for context
2. **"Read CLAUDE.md"** — forces re-grounding in project conventions
3. **Use `/gsd:check-todos`** — shows what's pending
4. **Be specific** — "implement the like button haptic in FeedView.swift" beats "add haptics"

### Maximize Claude's Effectiveness
- **One feature at a time.** Don't ask for "the whole feed AND the camera AND profiles." Break it up.
- **Show Claude errors.** Paste the full error, not a summary.
- **Let Claude run tests.** After writing code, say "run the tests" or "build the project."
- **Use plan mode for big features.** Say "plan how to build the recommendation engine" before "build it."

### Budget-Conscious Dev Tips
- **Use Cloudflare Stream's free tier** during development (first 1000 min free in trial)
- **Supabase free tier** gives you 500MB Postgres + auth
- **Railway free tier** or run the backend locally during development
- **Don't pay for hosting until you have beta users**

---

## Quick Reference: Common Commands

```bash
# Start backend
cd ~/git/vibeslol/backend && uv run uvicorn app.main:app --reload

# Run backend tests
cd ~/git/vibeslol/backend && uv run pytest

# Build iOS app (from command line)
cd ~/git/vibeslol/ios && xcodebuild -scheme Vibeslol -destination 'platform=iOS Simulator,name=iPhone 16'

# Database migrations
cd ~/git/vibeslol/backend && uv run alembic revision --autogenerate -m "description"
cd ~/git/vibeslol/backend && uv run alembic upgrade head

# Check Cloudflare Stream API
curl -H "Authorization: Bearer YOUR_TOKEN" https://api.cloudflare.com/client/v4/accounts/YOUR_ACCOUNT_ID/stream
```

---

## Checklist Before You Start Building

- [ ] Xcode installed and opened at least once
- [ ] Apple Developer account active ($99/year)
- [ ] Homebrew installed
- [ ] UV installed (`uv --version`)
- [ ] PostgreSQL running (`brew services list`)
- [ ] Redis running (`brew services list`)
- [ ] Git initialized in vibeslol/
- [ ] Claude Code installed and updated
- [ ] CLAUDE.md created in project root
- [ ] MCP servers installed (context7, sequential-thinking)
- [ ] Cloudflare account created
- [ ] Read through PRD.md completely
