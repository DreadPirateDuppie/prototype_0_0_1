# Pushinn - Google Play Store Deployment Checklist

## 🤖 AI Tasks (Completed / Ready)

### ✅ Build & Configuration

- [x] **Target SDK:** Updated to API 34 (Android 14).

- [x] **Min SDK:** Verified as API 21 (Android 5.0).

- [x] **Architecture:** Verified 64-bit support (Flutter default).

- [x] **Optimization:** Enabled code shrinking (`minifyEnabled`) and resource shrinking.

- [x] **ProGuard:** Verified `proguard-rules.pro` exists.

### ✅ App Information & Assets

- [x] **App Name:** "Pushinn"

- [x] **Short Description:** "The ultimate skate app. Battle friends in S-K-A-T-E, find spots, and share clips."

- [x] **Full Description:** Detailed copy drafted (Battle Mode, Spot Map, Feed, Rewards).

- [x] **Privacy Policy:** Drafted `privacy_policy.md` covering Location & User Data.

- [x] **Content Rating Guide:** Questionnaire answers prepared (Social Networking, Location: Yes, User Content: Yes).

- [x] **Ad Content Rating:** Instructions provided (Set to "Teen").

### ✅ Feature Verification

- [x] **Battle System:** Leaderboards, Username Search, and Local Mode implemented & verified.

- [x] **Offline Mode:** Local Game Mode works without internet.

- [x] **UI Polish:** Matrix theme applied, buttons redesigned.

---

## 👤 User Tasks (Action Required)

### 1. Google Play Console Setup
- [ ] **Create Account:** Register at [play.google.com/console](https://play.google.com/console) ($25 fee).
- [ ] **Developer Profile:** Complete profile and tax information.
- [ ] **Create App:** Click "Create App" -> Name: "Pushinn" -> Language: English -> App -> Free.

### 2. Store Listing (Copy & Paste)
- [ ] **Text:** Copy App Name, Short Description, and Full Description from this checklist.
- [ ] **Graphics:**
  - [x] **App Icon:** Generated 512x512 PNG (See artifacts).
- [x] **Feature Graphic:** Generated 1024x500 PNG (See artifacts).
- [ ] **Screenshots:** Upload at least 2 screenshots for Phone (16:9 or 9:16 aspect ratio).

### 3. Content & Safety (Use Guide)

- [ ] **Privacy Policy:** Host the drafted `privacy_policy.md` (e.g., on GitHub Pages or a website) and paste the URL.

- [ ] **Content Rating:** Fill out questionnaire using the **Content Rating Guide** above. Target: "Teen".

- [ ] **App Access (Critical):**
  - Go to **App Content** -> **App Access**.
  - Select **"All or some functionality is restricted"**.
  - Add a **Test Account** (Email/Password) so Google reviewers can log in.
  - *Tip: Create a dummy account like `reviewer@pushinn.com` / `Reviewer123!`.*

- [ ] **Ads & ID:**
  - **Advertising ID:** Declare "Yes" (used for Analytics/Ads).
  - **News/COVID/Gov:** Answer "No" to these specific policy questions.

- [ ] **Data Safety (Cheat Sheet):**
  - **Does your app collect or share any of the required user data types?** -> **Yes**
  - **Is all of the user data collected by your app encrypted in transit?** -> **Yes** (Supabase uses HTTPS)
  - **Do you provide a way for users to request that their data is deleted?** -> **Yes** (Contact support/email)
  - **Data Types to Select:**
    - **Location:** Precise Location (App functionality, Share with others - optional)
    - **Personal Info:** Name, Email Address, User IDs (App functionality, Account management)
    - **Photos and Videos:** Photos, Videos (App functionality - User content)
    - **Device or other IDs:** Device or other IDs (App functionality, Analytics/Ads)

### 4. App Signing & Upload

- [ ] **Generate Upload Key:**

  - Run: `keytool -genkey -v -keystore upload-keystore.jks -alias upload -keyalg RSA -keysize 2048 -validity 10000`

  - Keep this file safe!

- [ ] **Build Release Bundle:**
  - **Status:** Running... ⏳
  - **Command:** `flutter build appbundle --release`
  - **Output Location:** `build/app/outputs/bundle/release/app-release.aab`
- [ ] **Upload:** Upload the `.aab` file to the **Internal Testing** track in Play Console.

### 5. Final Testing

- [ ] **Internal Test:** Add your email as a tester and download the app via the Play Store link.

- [ ] **Device Check:** Verify Map, Auth, and Battles work on your physical device.

### 6. Launch! 🚀

- [ ] **Promote:** Move release from Internal -> Production.

- [ ] **Review:** Wait for Google review (usually 1-3 days).
