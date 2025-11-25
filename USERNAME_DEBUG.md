# Username Display Debug Guide

## Quick Fix - Hot Restart Required

The username display changes require a **hot restart** (not just hot reload) because we modified service layer code.

### Steps to Apply Changes:

1. **In your terminal where `flutter run` is running**, press:
   ```
   R
   ```
   (Capital R for hot restart)

2. **Or stop and restart**:
   ```
   q  (to quit)
   flutter run -d emulator --no-pub
   ```

### What Changed:

1. **UI Updates** (work with hot reload):
   - Post cards now show username instead of email
   - Background is now pure black
   - Avatar shows first letter of username

2. **Service Updates** (need hot restart):
   - `saveUserUsername()` now updates all posts
   - `createMapPost()` fetches username from user_profiles
   - `getAllMapPostsWithVotes()` fetches fresh usernames

### After Restart:

1. **Check existing posts** - Should show username or "User"
2. **Change your username** - All posts should update
3. **Create new post** - Should show username immediately

### If Still Not Working:

Check if you have a username set:
1. Go to Profile/Settings
2. Check if username is set
3. If not, set one
4. All your posts should update automatically

### Debug Info:

The username display logic in `post_card.dart` (line 186-189):
```dart
Text(
  currentPost.userName?.isNotEmpty == true
    ? currentPost.userName!
    : 'User',
  ...
)
```

This checks:
- If `userName` exists and is not empty → show username
- Otherwise → show "User"

**Note**: We never show email anymore for privacy.
