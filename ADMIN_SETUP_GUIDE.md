# Admin Dashboard Security Fix

## Problem Identified

The admin dashboard was accessible to **all users** without any authorization checks. This security vulnerability allowed any logged-in user to:
- View all posts and analytics
- Access reported posts
- Delete posts
- View user information

## Solution Implemented

### 1. Added Admin Authorization Service Method
- Created `isCurrentUserAdmin()` method in `SupabaseService`
- Checks the `is_admin` flag in the `user_profiles` table
- Returns `false` by default if the column doesn't exist or any errors occur

### 2. Protected Settings Tab
- Admin Dashboard button now only shows for admin users
- Non-admin users will not see the "Administration" section in Settings

### 3. Protected Admin Dashboard
- Added authorization check when the dashboard loads
- Non-admin users are immediately redirected back with an error message
- Dashboard data only loads for authorized admins

## Database Setup Required

You need to add an `is_admin` column to your `user_profiles` table in Supabase.

### Step 1: Add the is_admin Column

Run this SQL in your Supabase SQL Editor:

```sql
-- Add is_admin column to user_profiles table
ALTER TABLE user_profiles 
ADD COLUMN IF NOT EXISTS is_admin BOOLEAN DEFAULT FALSE;

-- Add an index for performance
CREATE INDEX IF NOT EXISTS idx_user_profiles_is_admin 
ON user_profiles(is_admin) WHERE is_admin = TRUE;
```

### Step 2: Grant Admin Access to Specific Users

To make a user an admin, run this SQL (replace `'user-email@example.com'` with the actual admin email):

```sql
-- Option 1: Grant admin by email
UPDATE user_profiles 
SET is_admin = TRUE 
WHERE id = (
  SELECT id FROM auth.users 
  WHERE email = 'user-email@example.com'
);

-- Option 2: Grant admin by user ID (if you know the user's ID)
UPDATE user_profiles 
SET is_admin = TRUE 
WHERE id = 'user-uuid-here';
```

### Step 3: Verify Admin Status

Check which users are admins:

```sql
SELECT 
  up.id,
  au.email,
  up.display_name,
  up.is_admin
FROM user_profiles up
JOIN auth.users au ON up.id = au.id
WHERE up.is_admin = TRUE;
```

## Testing the Fix

### Test 1: Non-Admin User
1. Sign in as a regular user
2. Go to Settings tab
3. Verify that "Administration" section **does not appear**
4. If you try to navigate directly to the admin dashboard (e.g., via deep link), you should be immediately redirected with an "Access denied" message

### Test 2: Admin User
1. Grant admin privileges to your test user using the SQL above
2. Sign out and sign back in
3. Go to Settings tab
4. Verify that "Administration" section **appears**
5. Click "Admin Dashboard"
6. Verify you can access all admin features

## Security Notes

1. **Database-Level Security**: The authorization check happens on every admin dashboard load
2. **Fail-Safe**: If the `is_admin` column doesn't exist or there's any error, access is denied
3. **UI Protection**: Non-admin users don't see the admin button at all
4. **Runtime Protection**: Even if someone bypasses the UI, the dashboard checks authorization and redirects

## Future Enhancements

Consider these additional security measures:

1. **Row Level Security (RLS)**: Add Supabase RLS policies to enforce admin-only access at the database level:

```sql
-- Example RLS policy for post_reports table
CREATE POLICY "Only admins can view reports"
ON post_reports FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM user_profiles
    WHERE id = auth.uid()
    AND is_admin = TRUE
  )
);
```

2. **Audit Logging**: Log admin actions for accountability

3. **Admin Roles**: Implement different admin levels (super admin, moderator, etc.)

4. **Session Timeout**: Add shorter session timeouts for admin users

## Troubleshooting

### Issue: "Access denied" even for admin users

**Solution**: Verify the user has the `is_admin` flag set:
```sql
SELECT id, email, is_admin 
FROM user_profiles 
WHERE id = (SELECT id FROM auth.users WHERE email = 'your-email@example.com');
```

### Issue: Column doesn't exist error

**Solution**: Run the ALTER TABLE command from Step 1 above

### Issue: Admin button doesn't appear after granting admin

**Solution**: 
1. Sign out and sign back in (the admin status is checked on Settings tab load)
2. Or close and reopen the app to refresh the session
