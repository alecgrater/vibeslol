# Vibeslol Production Deployment Guide

## Overview

You need 4 services to run Vibeslol in production. All have generous free tiers.

| Service | Purpose | Free Tier | Cost After |
|---------|---------|-----------|------------|
| **Railway** | Host the FastAPI backend | $5 credit/month | ~$5-20/mo |
| **Neon** | PostgreSQL database | 0.5 GB storage, always free | $19/mo for 10GB |
| **Cloudflare R2** | Video file storage | 10 GB storage, 10M reads/mo | $0.015/GB/mo |
| **Upstash** | Redis caching | 10K commands/day | $0.20/100K commands |

Total cost at launch: **$0/month** (all free tiers).

---

## Step 1: Generate a JWT Secret Key

Before anything else, generate a secure secret key. Run this locally:

```bash
openssl rand -hex 32
```

Save the output — you'll use it as `SECRET_KEY` in every service.

---

## Step 2: Neon (PostgreSQL Database)

### Sign Up
1. Go to https://neon.tech
2. Sign up with GitHub
3. Click **"New Project"**
4. Name it `vibeslol`, pick the region closest to your users (e.g., `us-east-1`)
5. Click **Create Project**

### Get Connection String
1. On the project dashboard, find the **Connection Details** panel
2. Select **"Connection string"** tab
3. Copy the connection string — it looks like:
   ```
   postgresql://neondb_owner:abc123@ep-cool-name-12345.us-east-1.aws.neon.tech/neondb?sslmode=require
   ```
4. Modify it for async SQLAlchemy — change `postgresql://` to `postgresql+asyncpg://`:
   ```
   postgresql+asyncpg://neondb_owner:abc123@ep-cool-name-12345.us-east-1.aws.neon.tech/neondb?sslmode=require
   ```

### Run Initial Migration
From your local machine, temporarily set the DATABASE_URL and run Alembic:

```bash
cd backend
DATABASE_URL="postgresql+asyncpg://neondb_owner:abc123@ep-cool-name-12345.us-east-1.aws.neon.tech/neondb?sslmode=require" \
  uv run alembic upgrade head
```

You should see:
```
INFO  [alembic.runtime.migration] Running upgrade  -> 6891fab295f3, initial schema
```

### Env Var
```
DATABASE_URL=postgresql+asyncpg://neondb_owner:abc123@ep-cool-name-12345.us-east-1.aws.neon.tech/neondb?sslmode=require
```

---

## Step 3: Cloudflare R2 (Video Storage)

### Sign Up
1. Go to https://dash.cloudflare.com/sign-up
2. Create a Cloudflare account (free)
3. In the left sidebar, click **R2 Object Storage**
4. Click **Create bucket**
5. Name it `vibeslol-videos`, pick a region
6. Click **Create bucket**

### Enable Public Access
1. Open the `vibeslol-videos` bucket
2. Go to **Settings** tab
3. Under **Public access**, click **Allow Access**
4. You'll get a public URL like: `https://pub-abc123.r2.dev`
5. (Optional) Connect a custom domain like `cdn.vibeslol.com` under **Custom Domains**

### Create API Token
1. Go back to **R2 Object Storage** in the sidebar
2. Click **Manage R2 API Tokens** (top right)
3. Click **Create API token**
4. Permissions: **Object Read & Write**
5. Specify bucket: `vibeslol-videos`
6. Click **Create API Token**
7. Save the **Access Key ID** and **Secret Access Key** — you won't see the secret again

### Get Your Account ID
1. In the Cloudflare dashboard, click **Overview** in the left sidebar
2. Your **Account ID** is on the right side panel — copy it

### Env Vars
```
R2_ACCESS_KEY_ID=your-access-key-id
R2_SECRET_ACCESS_KEY=your-secret-access-key
R2_BUCKET_NAME=vibeslol-videos
R2_ENDPOINT_URL=https://<your-account-id>.r2.cloudflarestorage.com
R2_PUBLIC_URL=https://pub-abc123.r2.dev
```

Replace `<your-account-id>` with the Account ID from the dashboard, and `pub-abc123.r2.dev` with the public URL from step 2.

---

## Step 4: Upstash (Redis Cache)

### Sign Up
1. Go to https://console.upstash.com
2. Sign up with GitHub
3. Click **Create Database**
4. Name: `vibeslol-cache`
5. Type: **Regional**
6. Region: pick the same region as your Railway deploy (e.g., `us-east-1`)
7. Click **Create**

### Get Connection String
1. Open the database dashboard
2. Under **REST API**, find the section labeled **Connect to your database**
3. Click the **`redis://`** tab (not REST)
4. Copy the connection string — it looks like:
   ```
   rediss://default:AXxxYYY@usw1-abc-12345.upstash.io:6379
   ```

Note: It's `rediss://` (with double s) for TLS.

### Env Var
```
REDIS_URL=rediss://default:AXxxYYY@usw1-abc-12345.upstash.io:6379
```

---

## Step 5: Railway (Backend Hosting)

### Sign Up
1. Go to https://railway.app
2. Sign up with GitHub
3. Click **New Project** > **Deploy from GitHub repo**
4. Select your `vibeslol` repo
5. Railway will auto-detect the project. You need to configure it:

### Configure the Service
1. Click on the service that was created
2. Go to **Settings** tab:
   - **Root Directory**: `backend`
   - **Build Command**: `pip install uv && uv sync --frozen`
   - **Start Command**: `uv run alembic upgrade head && uv run uvicorn app.main:app --host 0.0.0.0 --port $PORT`
3. Go to **Variables** tab and add all env vars:

```
DATABASE_URL=postgresql+asyncpg://neondb_owner:abc123@ep-cool-name-12345.us-east-1.aws.neon.tech/neondb?sslmode=require
SECRET_KEY=<your-64-char-hex-from-step-1>
R2_ACCESS_KEY_ID=<from-step-3>
R2_SECRET_ACCESS_KEY=<from-step-3>
R2_BUCKET_NAME=vibeslol-videos
R2_ENDPOINT_URL=https://<account-id>.r2.cloudflarestorage.com
R2_PUBLIC_URL=https://pub-abc123.r2.dev
REDIS_URL=rediss://default:xxx@xxx.upstash.io:6379
ENVIRONMENT=production
CORS_ORIGINS=["*"]
```

4. Go to **Settings** > **Networking** > **Generate Domain**
   - You'll get a URL like `vibeslol-production.up.railway.app`
   - Or add a custom domain like `api.vibeslol.com`

### Verify Deployment
```bash
curl https://vibeslol-production.up.railway.app/health
```

Should return:
```json
{"status": "vibing", "version": "1.0.0"}
```

---

## Step 6: Point the iOS App at Production

Open `ios/Vibeslol/Services/APIClient.swift` and update the production URL:

```swift
private init() {
    #if DEBUG
    self.baseURL = "http://localhost:8000"
    #else
    self.baseURL = "https://vibeslol-production.up.railway.app"  // <-- your Railway URL
    #endif
    ...
}
```

Then build the Release scheme for the App Store — it will automatically use the production URL.

---

## Step 7: Verify Everything Works End-to-End

### Test auth:
```bash
export API=https://vibeslol-production.up.railway.app

# Create account
curl -s -X POST $API/api/auth/anonymous \
  -H "Content-Type: application/json" -d '{}' | python3 -m json.tool
```

### Test authenticated request:
```bash
TOKEN="<access_token from above>"

curl -s $API/api/videos/feed \
  -H "Authorization: Bearer $TOKEN" | python3 -m json.tool
```

### Test video upload:
```bash
# Create a tiny test video (or use any .mp4)
curl -s -X POST $API/api/videos \
  -H "Authorization: Bearer $TOKEN" \
  -F "file=@test.mp4" \
  -F "caption=first upload" | python3 -m json.tool
```

The `video_url` in the response should be an R2 URL like `https://pub-abc123.r2.dev/videos/xxx.mp4`.

---

## Quick Reference: All Env Vars

| Variable | Required | Example |
|----------|----------|---------|
| `DATABASE_URL` | Yes | `postgresql+asyncpg://...@neon.tech/vibeslol?sslmode=require` |
| `SECRET_KEY` | Yes | `a1b2c3...` (64 hex chars) |
| `ENVIRONMENT` | Yes | `production` |
| `R2_ACCESS_KEY_ID` | For R2 | `abc123...` |
| `R2_SECRET_ACCESS_KEY` | For R2 | `xyz789...` |
| `R2_BUCKET_NAME` | For R2 | `vibeslol-videos` |
| `R2_ENDPOINT_URL` | For R2 | `https://<id>.r2.cloudflarestorage.com` |
| `R2_PUBLIC_URL` | For R2 | `https://pub-abc123.r2.dev` |
| `REDIS_URL` | For caching | `rediss://default:xxx@xxx.upstash.io:6379` |
| `CORS_ORIGINS` | Optional | `["*"]` or `["https://vibeslol.com"]` |

---

## Ongoing: Running Migrations

Whenever you add new database tables or change models:

```bash
cd backend

# Generate migration
uv run alembic revision --autogenerate -m "describe the change"

# Apply locally
uv run alembic upgrade head

# Commit the migration file and push — Railway's start command
# runs `alembic upgrade head` automatically on each deploy
git add alembic/versions/
git commit -m "migration: describe the change"
git push
```
