# Advanced Authentication Troubleshooting

## 🔍 STATUS: Issue Persists After Initial Fixes
Since basic network resets haven't resolved the "no address associated with host" error, we need to try more advanced solutions.

## 🚨 IMMEDIATE ACTIONS TO TRY

### 1. **Flutter Internet Permission Check**
Verify your AndroidManifest.xml has internet permissions:
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
```

### 2. **Emulator Internet Test**
Test if emulator can reach internet:
```bash
# Test basic connectivity
adb shell ping -c 3 8.8.8.8

# Test DNS resolution from emulator
adb shell nslookup google.com

# Test HTTPS connection
adb shell curl -v https://www.google.com
```

### 3. **Alternative Supabase URL Test**
Temporarily test with direct IP:
```dart
// In main.dart, try using direct IP instead of hostname
final supabaseUrl = 'https://104.18.38.10'; // One of the working IPs
```

### 4. **Android Network Security Config (CRITICAL)**
Create `android/app/src/main/res/xml/network_security_config.xml`:
```xml
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <domain-config cleartextTrafficPermitted="true">
        <domain includeSubdomains="true">fsogspnecjsoltcmwveg.supabase.co</domain>
        <domain includeSubdomains="true">104.18.38.10</domain>
        <domain includeSubdomains="true">172.64.149.246</domain>
    </domain-config>
    <base-config cleartextTrafficPermitted="true" />
</network-security-config>
```

### 5. **Emulator DNS Override**
Restart emulator with explicit DNS:
```bash
# Stop all emulators first
adb kill-server

# Start with custom DNS
emulator -avd YourAvdName -dns-server 8.8.8.8,8.8.4.4

# Or try different DNS servers
emulator -avd YourAvdName -dns-server 1.1.1.1,1.0.0.1
```

### 6. **Flutter Clean with Cache Clear**
```bash
flutter clean
flutter pub get
flutter pub cache clean
flutter pub cache repair
flutter run --verbose
```

### 7. **Create New Emulator**
Sometimes corrupt emulators cause DNS issues:
```bash
# List available AVDs
avdmanager list avd

# Create fresh emulator
avdmanager create avd -n TestEmulator -k "system-images;android-30;google_apis;x86_64"
```

### 8. **Test with Different Network**
- Try different WiFi network
- Use mobile hotspot from phone
- Test with VPN disabled entirely

### 9. **Debug Network Code**
Add to your sign-in screen for debugging:
```dart
// Test network connectivity first
Future<bool> testNetwork() async {
  try {
    final result = await InternetAddress.lookup('fsogspnecjsoltcmwveg.supabase.co');
    print('DNS lookup successful: ${result}');
    return true;
  } catch (e) {
    print('DNS lookup failed: $e');
    return false;
  }
}
```

### 10. **System DNS Check**
```bash
# Check system DNS configuration
scutil --dns | grep 'nameserver'

# Test system DNS resolution
nslookup fsogspnecjsoltcmwveg.supabase.co

# Try different DNS servers
nslookup fsogspnecjsoltcmwveg.supabase.co 8.8.8.8
