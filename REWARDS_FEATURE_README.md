# 🎁 Rewards Feature - Point System & Daily Wheel Spin

## Quick Start

This feature adds a gamified reward system to your Flutter app with a daily wheel spin mechanic.

## 📋 Prerequisites

1. **Flutter/Dart environment** (SDK 3.10.0+)
2. **Supabase project** with authentication enabled
3. **User authentication** working in the app

## 🚀 Setup Instructions

### Step 1: Create Database Table

Run this SQL in your Supabase SQL Editor:

```sql
CREATE TABLE user_points (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    points INTEGER NOT NULL DEFAULT 0,
    last_spin_date TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE user_points ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY "Users can view own points"
ON user_points FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own points"
ON user_points FOR INSERT
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own points"
ON user_points FOR UPDATE
USING (auth.uid() = user_id);
```

### Step 2: Build & Run

```bash
flutter pub get
flutter run
```

### Step 3: Test the Feature

1. Sign in to the app
2. Navigate to the "Rewards" tab
3. You should see:
   - Your current points (starts at 0)
   - A colorful spinning wheel
   - "Spin the Wheel!" button
4. Tap the button to spin
5. Win points (10-500)
6. Try spinning again - you should see "Come back tomorrow!"

## ✨ Features

### Point System
- ✅ User-specific point balances
- ✅ Persistent storage in Supabase
- ✅ Real-time updates
- ✅ Secure with Row Level Security

### Daily Wheel Spin
- ✅ Beautiful animated wheel with 6 colored segments
- ✅ Random rewards: 10, 25, 50, 100, 200, 500 points
- ✅ Smooth 3-second spinning animation
- ✅ One spin per day per user
- ✅ Congratulations dialog on winning
- ✅ Visual feedback for daily limit

### Reward System
- ✅ 4 sample rewards (500-800 points)
- ✅ Smart button states based on available points
- ✅ Ready for redemption logic implementation

## 🎨 User Experience

### Flow 1: First Spin
```
User opens Rewards → Sees 0 points → Taps "Spin!" 
→ Wheel spins → Lands on 100 points 
→ Dialog: "You won 100 points!" → Points update to 100
→ Button: "Come back tomorrow!"
```

### Flow 2: Next Day
```
User opens Rewards → Sees 100 points → Can spin again
→ Wins 50 more points → Total: 150 points
```

### Flow 3: Redeeming Rewards
```
User has 600 points → Reward 2 (600 pts) button enabled
→ Can tap "Redeem" (logic to be implemented)
```

## 📁 File Structure

```
lib/
├── models/
│   └── user_points.dart          # Point data model
├── widgets/
│   └── wheel_spin.dart            # Spinning wheel widget
├── services/
│   └── supabase_service.dart      # Database operations (updated)
└── tabs/
    └── rewards_tab.dart           # Main rewards UI (updated)
```

## 🔧 Code Architecture

### UserPoints Model
```dart
class UserPoints {
  final String userId;
  final int points;
  final DateTime? lastSpinDate;
  
  bool canSpinToday() { /* daily check logic */ }
}
```

### SupabaseService Methods
- `getUserPoints(userId)` - Fetch user's points
- `updatePointsAfterSpin(userId, points)` - Update after spin

### WheelSpin Widget
- Custom painter for wheel graphics
- Animation controller for spinning
- Random reward selection
- State management for spin availability

## 🎯 Customization

### Change Reward Values
Edit `lib/widgets/wheel_spin.dart`:
```dart
final List<int> _rewards = [10, 25, 50, 100, 200, 500]; // Modify these
```

### Change Wheel Colors
Edit `WheelPainter` in `lib/widgets/wheel_spin.dart`:
```dart
final colors = [
  Colors.red.shade400,    // Change these
  Colors.blue.shade400,
  // ... etc
];
```

### Change Spin Duration
Edit `lib/widgets/wheel_spin.dart`:
```dart
_controller = AnimationController(
  duration: const Duration(seconds: 3), // Change duration here
  vsync: this,
);
```

### Add More Rewards
Edit `lib/tabs/rewards_tab.dart`:
```dart
ListView.builder(
  itemCount: 4, // Change count
  itemBuilder: (context, index) {
    final pointCost = 500 + (index * 100); // Modify cost formula
    // ...
  },
)
```

## 🔐 Security

- ✅ Row Level Security (RLS) enabled
- ✅ Users can only access their own points
- ✅ All updates go through Supabase (server-side)
- ✅ Daily limit enforced by database timestamp
- ✅ No client-side point manipulation possible

## 🐛 Troubleshooting

### "Table 'user_points' doesn't exist"
**Solution:** Run the SQL from Step 1 in your Supabase project

### Points show as 0 after spinning
**Solution:** Check Supabase RLS policies are created correctly

### Wheel doesn't spin
**Solution:** Ensure user is authenticated and `canSpin` is true

### "Come back tomorrow" immediately
**Solution:** Check system time - may have already spun today

## 📚 Documentation Files

- `DATABASE_SCHEMA.md` - Complete database schema
- `IMPLEMENTATION_NOTES.md` - Technical details
- `UI_DESCRIPTION.md` - Visual layout guide
- `REWARDS_FEATURE_README.md` - This file

## 🎓 Learning Resources

- [Flutter Animations](https://docs.flutter.dev/development/ui/animations)
- [Supabase Flutter](https://supabase.com/docs/reference/dart/introduction)
- [Custom Painters](https://api.flutter.dev/flutter/rendering/CustomPainter-class.html)

## 🚀 Future Enhancements

Ideas for extending this feature:
1. Add sound effects and haptic feedback
2. Implement actual reward redemption
3. Add leaderboard
4. Add achievement badges
5. Add point-earning activities (posts, likes, etc.)
6. Add special event multipliers
7. Add streak bonuses for consecutive days
8. Add push notifications for available spins

## 💡 Tips

- Test with multiple users to verify RLS works correctly
- Consider adding analytics to track spin statistics
- Add error boundaries for network failures
- Consider caching points locally for better UX
- Add unit tests for point calculation logic

## 📝 License

This feature is part of the prototype_0_0_1 project.

---

**Questions?** Check the other documentation files or open an issue on GitHub.
