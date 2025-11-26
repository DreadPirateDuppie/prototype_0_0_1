# Pushinn - Phone Testing Checklist

## Prerequisites Setup
- [ ] Install Android Studio with Flutter SDK
- [ ] Install Flutter SDK (latest version)
- [ ] Install Android SDK and build tools
- [ ] Enable USB debugging on your phone
- [ ] Connect phone to computer via USB

## Project Configuration
- [ ] Run `flutter doctor` to verify setup
- [ ] Run `flutter pub get` to install dependencies
- [ ] Check `.env` file has all required environment variables
- [ ] Verify Supabase configuration is correct
- [ ] Test Firebase integration (if needed for testing features)

## Build and Install Options

### Option 1: Direct Installation (Fastest for Testing)
- [ ] Run `flutter run` from project directory
- [ ] Select your connected device when prompted
- [ ] App will automatically install and run on your phone

### Option 2: Generate APK for Manual Installation
- [ ] Run `flutter build apk --debug`
- [ ] Find APK at: `build/app/outputs/flutter-apk/app-debug.apk`
- [ ] Transfer APK to your phone
- [ ] Enable "Install unknown apps" for your file manager/browser
- [ ] Install APK on your phone

### Option 3: Release APK (Closer to Play Store Experience)
- [ ] Ensure `android/key.properties` file exists for signing
- [ ] Run `flutter build apk --release`
- [ ] Find APK at: `build/app/outputs/flutter-apk/app-release.apk`
- [ ] Install on your phone

## Testing Verification
- [ ] App launches successfully
- [ ] Location permissions work correctly
- [ ] All tabs load without crashes (Feed, Map, Profile, VS, Rewards)
- [ ] User authentication works (sign in/up)
- [ ] Supabase connection is functional
- [ ] Map functionality works
- [ ] Post creation and interaction works
- [ ] Battle system functions properly
- [ ] Google Mobile Ads display correctly
- [ ] No critical crashes or performance issues

## Troubleshooting Tips
- If installation fails: Check "Install unknown apps" permissions
- If app crashes: Check logs with `flutter logs`
- If features don't work: Verify `.env` and Supabase settings
- If location issues: Enable location services on phone
