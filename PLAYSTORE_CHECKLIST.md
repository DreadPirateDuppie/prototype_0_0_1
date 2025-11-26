# Pushinn - Google Play Store Deployment Checklist

## Google Play Console Setup
- [ ] Create Google Play Console account ($25 one-time registration fee)
- [ ] Set up developer profile with tax information
- [ ] Create new app in Play Console
- [ ] Choose app name: "Pushinn"
- [ ] Select default language: English (United States)
- [ ] Choose app or game: App
- [ ] Select free or paid: Free
- [ ] Confirm app content declaration

## App Signing and Security
- [ ] Generate app signing key using Play Console (recommended) OR
- [ ] Set up local keystore for signing (update android/key.properties)
- [ ] Generate upload key certificate for signing
- [ ] Keep keystore files secure and backed up
- [ ] Create key.properties file with correct paths and passwords

## App Bundle and Build Configuration
- [ ] Update app version in pubspec.yaml (version: 1.0.0+1 → 1.0.1+2 for release)
- [ ] Update app icon if not already done
- [ ] Add privacy policy URL (required for location-based apps)
- [ ] Create 512x512 app icon
- [ ] Create feature graphic (1024x500)
- [ ] Update targetSdkVersion to API level 33+ (Android 13)
- [ ] Update compileSdkVersion to API level 34

## Release Build Configuration
- [ ] Enable code shrinking (minifyEnabled: true)
- [ ] Enable resource shrinking (shrinkResources: true)
- [ ] Update ProGuard rules if needed
- [ ] Test release build: `flutter build appbundle --release`
- [ ] Verify app bundle: `build/app/outputs/bundle/release/app-release.aab`

## Play Console App Details

### App Information
- [ ] App name: Pushinn
- [ ] Short description (80 chars): Ultimate skateboarding and trick-sharing community app
- [ ] Full description (4000 chars): Detailed feature description
- [ ] App category: Sports
- [ ] Tags: skateboarding, tricks, community, sports, location

### Store Listing
- [ ] Upload feature graphic (1024x500)
- [ ] Upload screenshots for phone (at least 2, max 8)
- [ ] Upload screenshots for tablet (optional)
- [ ] Upload 512x512 app icon
- [ ] Upload 1024x500 TV banner (optional)

### Content Rating
- [ ] Complete content rating questionnaire
- [ ] Select "Teen" rating (13+) due to location features
- [ ] Ensure content complies with rating

### App Content and Pricing
- [ ] Add privacy policy URL (required for location-based apps)
- [ ] Set up in-app purchases if any (currently none)
- [ ] Add contact details (email, website, phone)
- [ ] Confirm content guidelines compliance

## Technical Requirements
- [ ] Target Android API level 33+ (Android 13)
- [ ] Support 64-bit architecture (arm64-v8a, armeabi-v7a)
- [ ] Support Android 7.0 (API level 24) minimum
- [ ] Test on multiple device sizes and Android versions
- [ ] Ensure app passes Google's security checks
- [ ] Verify no sensitive data in logs or crash reports

## Testing and Quality Assurance
- [ ] Test app thoroughly on multiple devices
- [ ] Test on Android 7.0, 10, 13, and 14
- [ ] Test permissions handling (location, internet, etc.)
- [ ] Test offline functionality
- [ ] Test map functionality and location services
- [ ] Test user authentication flows
- [ ] Test post creation and interaction
- [ ] Test battle system
- [ ] Verify no crashes or ANRs
- [ ] Performance testing (startup time, memory usage)

## Google Mobile Ads Compliance
- [ ] Update AdMob app ID to production (currently using test ID)
- [ ] Ensure ads comply with Google Play policies
- [ ] Add ad content rating
- [ ] Implement COPPA compliance if needed
- [ ] Add privacy policy mentioning ads

## Release Process
- [ ] Internal testing: Upload to internal testing track first
- [ ] Alpha testing: Limited external testers
- [ ] Beta testing: Broader testing group
- [ ] Production: Full public release
- [ ] Monitor crashes and ANRs after release
- [ ] Respond to user reviews promptly

## Post-Launch Checklist
- [ ] Monitor app performance in Play Console
- [ ] Track crash reports and fix issues
- [ ] Update app based on user feedback
- [ ] Maintain regular updates for security and features
- [ ] Monitor app store ranking and reviews

## Important Notes
- Location-based apps require privacy policy
- Review Google Play's developer policies regularly
- Keep keystore files secure - losing them means you can't update the app
- Test thoroughly before each release
- Consider staged rollout for major updates
- Monitor app performance and user feedback continuously
