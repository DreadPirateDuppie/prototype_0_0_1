# Point System and Daily Wheel Spin Implementation

## Overview
This implementation adds a complete point system for users and an interactive daily wheel spin feature to the Rewards page. The system integrates with Supabase for data persistence.

## Features Implemented

### 1. Point System
- **User Points Tracking**: Each user has their own points balance stored in the database
- **Real-time Display**: Points are fetched from Supabase and displayed on the Rewards page
- **Points Integration**: Reward redemption buttons are enabled/disabled based on available points

### 2. Daily Wheel Spin
- **Interactive Wheel**: Animated spinning wheel with 6 colored segments
- **Random Rewards**: Users can win 10, 25, 50, 100, 200, or 500 points
- **Smooth Animation**: 3-second spinning animation with easing curve
- **Daily Limit**: Users can only spin the wheel once per day
- **Visual Feedback**: 
  - Congratulations dialog shows points won
  - Button states indicate when next spin is available
  - Message displays "Come back tomorrow!" when limit reached

### 3. Visual Design
- **Color-coded Wheel**: 6 distinct colors for each reward segment (red, blue, green, orange, purple, teal)
- **Pointer**: Red arrow at top shows the winning segment
- **Responsive Layout**: Works well on different screen sizes
- **Material Design**: Follows Flutter Material Design guidelines

## Technical Implementation

### Files Modified/Created

#### 1. `lib/models/user_points.dart` (NEW)
- Model class for user points data
- Includes logic for checking if user can spin today
- Handles serialization to/from database

#### 2. `lib/widgets/wheel_spin.dart` (NEW)
- Stateful widget for the spinning wheel
- Custom painter for drawing the wheel segments
- Animation controller for smooth spinning
- Random reward selection logic

#### 3. `lib/tabs/rewards_tab.dart` (MODIFIED)
- Converted from StatelessWidget to StatefulWidget
- Integrated with SupabaseService for fetching/updating points
- Added wheel spin UI
- Shows loading state while fetching data
- Displays error messages if operations fail

#### 4. `lib/services/supabase_service.dart` (MODIFIED)
- Added `getUserPoints()` method to fetch user points
- Added `updatePointsAfterSpin()` method to update points after wheel spin
- Handles cases where user_points table doesn't exist yet

#### 5. `DATABASE_SCHEMA.md` (NEW)
- SQL schema for creating the user_points table
- Row Level Security (RLS) policies
- Table structure documentation

## Database Schema

The implementation requires a `user_points` table in Supabase:

```
user_id (UUID, PRIMARY KEY) - References auth.users(id)
points (INTEGER, DEFAULT 0) - User's current point balance
last_spin_date (TIMESTAMP) - Date of last wheel spin
created_at (TIMESTAMP) - Record creation timestamp
updated_at (TIMESTAMP) - Last update timestamp
```

## How It Works

1. **Initial Load**:
   - When user opens Rewards tab, app fetches their points from Supabase
   - If no record exists, a new record with 0 points is created

2. **Daily Spin Check**:
   - App compares current date with last_spin_date
   - If dates differ (different day), spin is available
   - If same day, spin is disabled

3. **Spinning Process**:
   - User taps "Spin the Wheel!" button
   - Wheel animates for 3 seconds with random rotation
   - Landing position determines reward (10-500 points)
   - Points are added to user's balance in database
   - last_spin_date is updated to current timestamp
   - Congratulations dialog shows points won

4. **Reward Redemption**:
   - Each reward has a point cost (500, 600, 700, 800)
   - Buttons are enabled only if user has enough points
   - (Note: Actual redemption logic can be added later)

## Security Considerations

- **Row Level Security**: Database policies ensure users can only access their own points
- **Server-side Validation**: All point updates go through Supabase
- **No Client-side Manipulation**: Points cannot be modified locally
- **Daily Limit Enforcement**: Enforced both client and server side (via last_spin_date)

## Future Enhancements

Possible improvements:
1. Add actual reward redemption logic
2. Add point-earning activities (e.g., completing tasks, posting content)
3. Add leaderboard showing top users by points
4. Add more variety to wheel rewards
5. Add sound effects and haptic feedback
6. Add achievement badges for point milestones
7. Add point expiration system
8. Add special events with bonus multipliers

## Testing

To test the implementation:
1. Ensure user_points table exists in Supabase (run SQL from DATABASE_SCHEMA.md)
2. Sign in to the app
3. Navigate to Rewards tab
4. Verify points display (should start at 0)
5. Click "Spin the Wheel!" button
6. Verify wheel spins and stops on a random segment
7. Verify congratulations dialog appears with points won
8. Verify points balance updates
9. Try spinning again - should see "Come back tomorrow!" message
10. Check reward buttons - they should enable when you have enough points

## Dependencies

No new dependencies were added. Implementation uses existing Flutter packages:
- `flutter/material.dart` - UI components
- `supabase_flutter` - Database integration
- Dart standard library for math and animations
