# Google Maps Setup Guide

## To Enable Google Maps in Your App

### Step 1: Create a Google Cloud Project
1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Create a new project
3. Enable **Maps SDK for Android** and **Maps SDK for iOS**
4. Create an API key (Credentials → Create Credentials → API Key)

### Step 2: Add API Key to Android

**File:** `android/app/src/main/AndroidManifest.xml`

Replace `YOUR_GOOGLE_MAPS_API_KEY_HERE` with your actual API key:

```xml
<meta-data
  android:name="com.google.android.geo.API_KEY"
  android:value="YOUR_API_KEY_HERE" />
```

### Step 3: Add API Key to iOS

**File:** `ios/Runner/Info.plist`

Add this entry:

```xml
<key>com.google.ios.maps.API_KEY</key>
<string>YOUR_API_KEY_HERE</string>
```

### Step 4: Set Up Android Release Signing

For production, you'll need your Android app's SHA-1 fingerprint.

Generate it with:
```bash
./gradlew signingReport
```

Add this fingerprint to your Google Cloud Console API key restrictions.

### Features Included

✅ Real-time location tracking with permission handling
✅ Multiple markers with different colors
✅ Info windows for markers
✅ Zoom and compass controls
✅ My Location button
✅ Sample markers (Downtown SF, Golden Gate Bridge, Ocean Beach)

### What Happens When You Use the Map Tab

1. **App asks for location permission** - "Allow" to see current location
2. **Map centers on your location** - Blue marker shows where you are
3. **Sample markers are displayed** - Red, orange, and green markers show interest points
4. **Tap any marker** - See the info window with details
5. **Use controls** - Zoom, pan, rotate the map freely

### Troubleshooting

**Map shows black/white screen:**
- Make sure API key is correctly set
- Check that Maps API is enabled in Google Cloud Console

**Location not showing:**
- Grant location permission when prompted
- Check that geolocator permission is allowed in system settings

**API Rate Limiting:**
- Your first 25,000 map loads per day are free
- After that, billing may apply

Enjoy! 🗺️
