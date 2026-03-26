# Running Vibeslol on Your iPhone

## What You Need

- Mac with Xcode installed
- iPhone running iOS 17+
- USB / USB-C cable (for first-time setup)
- Apple Developer account (free or paid)

---

## Step 1: Open the Project in Xcode

```bash
open ios/Vibeslol.xcodeproj
```

---

## Step 2: Configure Signing

1. In the left sidebar, click the **Vibeslol** project (blue icon at the top)
2. Select the **Vibeslol** target under TARGETS
3. Click the **Signing & Capabilities** tab
4. Make sure **Automatically manage signing** is checked
5. Click the **Team** dropdown and select your Apple Developer team
   - If your team doesn't appear, go to **Xcode → Settings → Accounts** and sign in with your Apple ID first
6. The bundle identifier is `com.vibeslol.app` — if Xcode shows a provisioning error, change it to something unique like `com.yourusername.vibeslol`

---

## Step 3: Connect Your iPhone

1. Plug your iPhone into your Mac via USB/USB-C
2. Unlock your iPhone
3. If prompted, tap **Trust** on the phone and enter your passcode
4. If prompted on your Mac, click **Trust** as well

### Enable Developer Mode (iOS 16+)

If you haven't used your phone for development before:

1. On your iPhone go to **Settings → Privacy & Security → Developer Mode**
2. Toggle **Developer Mode** on
3. Your phone will restart — confirm when prompted after restart

---

## Step 4: Select Your iPhone as the Build Target

1. In the Xcode toolbar at the top, click the device/simulator dropdown (it probably says "iPhone 17 Pro")
2. Under **iOS Devices**, select your physical iPhone
3. If your phone doesn't appear, try:
   - Unplugging and re-plugging the cable
   - Restarting Xcode
   - Check **Window → Devices and Simulators** to see if Xcode recognizes it

---

## Step 5: Choose Debug or Release Build

### Option A: Debug Build (connects to local backend)

- Uses `http://localhost:8000` — your phone **cannot reach localhost**
- To test with your local backend, you need to change the URL to your Mac's local IP:

1. Find your Mac's IP: **System Settings → Wi-Fi → Details → IP Address** (e.g., `192.168.1.42`)
2. Make sure your phone is on the **same Wi-Fi network**
3. Start the backend on your Mac:
   ```bash
   cd backend && uv run uvicorn app.main:app --reload --host 0.0.0.0
   ```
   (The `--host 0.0.0.0` flag is important — it makes the server accessible from other devices)
4. In `ios/Vibeslol/Services/APIClient.swift`, temporarily change the debug URL:
   ```swift
   #if DEBUG
   self.baseURL = "http://192.168.1.42:8000"  // your Mac's IP
   #else
   ```

### Option B: Release Build (connects to Railway production)

- Uses `https://vibeslol-production.up.railway.app`
- No local backend needed — uses the deployed production server
- To build in Release mode: **Product → Scheme → Edit Scheme → Run → Build Configuration → Release**

---

## Step 6: Build and Run

1. Press **Cmd + R** (or click the Play ▶ button in the toolbar)
2. Xcode will:
   - Compile the app
   - Install it on your iPhone
   - Launch it automatically
3. First build takes longer (1-2 minutes). Subsequent builds are faster.

---

## Step 7: Trust the App (First Time Only)

If the app won't launch and you see an "Untrusted Developer" alert:

1. On your iPhone: **Settings → General → VPN & Device Management**
2. Tap your Apple ID / developer certificate under "Developer App"
3. Tap **Trust "[your Apple ID]"**
4. Confirm by tapping **Trust**
5. Go back and launch Vibeslol

---

## Troubleshooting

### "Unable to install — device is locked"
Unlock your iPhone and try again.

### "Could not launch — process launch failed: Security"
You need to trust the developer profile (see Step 7).

### Provisioning profile errors
- Make sure **Automatically manage signing** is checked
- Try changing the bundle identifier to something unique
- Go to **Xcode → Settings → Accounts → your team → Manage Certificates** and make sure you have an Apple Development certificate

### App installs but can't reach backend
- Debug builds point to `localhost` which your phone can't reach
- Either switch to Release build (uses Railway) or update the debug URL to your Mac's local IP
- Make sure your Mac's firewall isn't blocking port 8000

### "This app cannot be installed because its integrity could not be verified"
- Clean the build: **Product → Clean Build Folder** (Cmd + Shift + K)
- Delete the app from your phone
- Rebuild

### Xcode doesn't see your iPhone
- Try a different cable
- Restart Xcode
- Restart your iPhone
- Check **Window → Devices and Simulators** for error messages

---

## Wireless Debugging (Optional)

After the first USB connection, you can deploy wirelessly:

1. Connect via USB
2. In Xcode: **Window → Devices and Simulators**
3. Select your iPhone and check **Connect via network**
4. Wait for a globe icon to appear next to your device name
5. Unplug the cable — your device should still appear in the target dropdown

Note: Wireless builds are slower than USB.

---

## Quick Reference

| Build Mode | Backend URL | Use When |
|-----------|------------|----------|
| Debug | `http://localhost:8000` | Testing with local backend on simulator |
| Debug (modified) | `http://<your-mac-ip>:8000` | Testing with local backend on physical device |
| Release | `https://vibeslol-production.up.railway.app` | Testing against production server |
