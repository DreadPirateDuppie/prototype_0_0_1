# Username Feature Implementation

## Backend Setup (Supabase)

You need to add a `username` column to your `user_profiles` table with a UNIQUE constraint:

```sql
-- Add username column to user_profiles table
ALTER TABLE user_profiles 
ADD COLUMN username TEXT UNIQUE;

-- Create an index for faster lookups
CREATE INDEX idx_user_profiles_username ON user_profiles(username);
```

If the `user_profiles` table doesn't exist yet, create it:

```sql
CREATE TABLE user_profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id),
  username TEXT UNIQUE,
  display_name TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);
```

## Features Implemented

### 1. Username Management
- Users can set a unique username on their profile
- Username requirements:
  - 3-20 characters
  - Letters, numbers, dashes, and underscores only
  - Case-insensitive storage (stored in lowercase)

### 2. Username Uniqueness
- The app checks username availability before saving
- Supabase enforces uniqueness with a UNIQUE constraint
- Error message if username is taken

### 3. Profile Display
- Profile tab shows the current username
- Edit button next to username for easy editing
- Shows "Not set" if no username has been set

### 4. Username Validation
- Real-time feedback on username validity
- Character count display
- Helper text with requirements

## Files Modified/Created

### New Files:
- `lib/screens/edit_username_dialog.dart` - Dialog for editing username

### Modified Files:
- `lib/services/supabase_service.dart` - Added username methods:
  - `getUserUsername(userId)` - Fetch user's username
  - `isUsernameAvailable(username)` - Check if username is taken
  - `saveUserUsername(userId, username)` - Save/update username

- `lib/tabs/profile_tab.dart` - Updated to:
  - Display username with edit button
  - Load username asynchronously
  - Open edit dialog when clicking edit button

## Testing Steps

1. Run the app
2. Go to Profile tab
3. You should see a "Username" field showing "Not set"
4. Click the edit button (pencil icon) next to Username
5. Enter a unique username (3-20 characters, alphanumeric + dash/underscore)
6. Click Save
7. Username should update and save to Supabase

## Next Steps (Optional)

- Display username on posts instead of just name
- Add username search/discovery feature
- Show username in post cards on feed
- Add username in comments (future feature)
