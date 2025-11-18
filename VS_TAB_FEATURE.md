# VS Tab Feature - SKATE Battles

## Overview

The VS Tab feature adds competitive SKATE-style battles to the app, where players challenge each other by setting tricks and attempting to match them. Failed attempts earn letters (S-K-A-T-E), and the first player to spell the complete word loses.

## Key Features

### 🎮 Game Modes
- **SKATE**: Traditional S-K-A-T-E format
- **SK8**: Shorter S-K-8 format
- **Custom**: Choose your own letters

### ⚡ Quick-Fire Voting
- Both players vote immediately after each attempt
- Options: Land, No Land, or Rebate (retry)
- Instant resolution when players agree
- Automatic retry on Rebate
- Escalates to community if players disagree

### 👥 Community Verification
- Disagreements resolved by community voting
- All users can participate in verification
- Votes weighted by user reputation (Final Score)
- Accurate voting improves your Ranking Score

### 📊 Comprehensive Scoring System

**Three Independent Scores (0-1000 each):**

1. **Map Score**: Reputation from map post contributions
2. **Player Score**: Performance in SKATE battles
3. **Ranking Score**: Accuracy in community verification

**Final Score**: Average of the three scores
**Vote Weight**: Final Score ÷ 1000 (determines voting influence)

### 🏆 Letter System
- Failed attempts earn the next letter
- Game ends when a player completes the word
- Winner gains +10 Player Score
- Loser loses 5-15 points (fewer letters = better performance)

## UI Components

### VS Tab
- View all active battles
- Current turn indicators
- Letter progress display
- Create new battles
- Access community verification

### Battle Detail Screen
- Score display (You vs Opponent)
- Turn indicator
- Video upload for tricks and attempts
- Quick-Fire voting interface
- Real-time battle status

### Community Verification Feed
- Queue of attempts needing votes
- Video player for each attempt
- Vote buttons (Land/No Land/Rebate)
- Your vote influence percentage

### Enhanced Profile
- Display all three scores with progress bars
- Final Score calculation
- Vote influence percentage
- Battle statistics

## Architecture

### Data Models
- `UserScores`: Three independent scores and Final Score calculation
- `Battle`: Battle state, players, letters, current turn
- `VerificationAttempt`: Video attempts needing verification
- `QuickFireVote`: Voting sessions between battle players
- `Vote`: Community votes with weighted scoring

### Services
- `BattleService`: Battle creation, management, scoring, letter assignment
- `VerificationService`: Quick-Fire and community voting, weighted calculation

### Database Tables
- `user_scores`: User scoring metrics
- `battles`: Battle state and progress
- `verification_attempts`: Attempts needing verification
- `quick_fire_votes`: Player voting sessions
- `community_votes`: Community verification votes

## Quick Start

1. **Set up database**: Run SQL from `VS_TAB_DATABASE_SCHEMA.md`
2. **Create storage**: Add `battle_videos` bucket in Supabase
3. **Navigate to VS Tab**: Tap the VS icon in bottom navigation
4. **Create a battle**: Tap "New Battle" button
5. **Play**: Upload tricks, attempt, and vote!

## Files Added

### Models
- `lib/models/user_scores.dart`
- `lib/models/battle.dart`
- `lib/models/verification.dart`

### Services
- `lib/services/battle_service.dart`
- `lib/services/verification_service.dart`

### Screens & Tabs
- `lib/tabs/vs_tab.dart`
- `lib/screens/battle_detail_screen.dart`
- `lib/screens/create_battle_dialog.dart`
- `lib/screens/community_verification_screen.dart`

### Updated Files
- `lib/screens/home_screen.dart` (added VS tab)
- `lib/tabs/profile_tab.dart` (added score display)

### Documentation
- `VS_TAB_DATABASE_SCHEMA.md` (SQL schema and RLS policies)
- `VS_TAB_IMPLEMENTATION_GUIDE.md` (detailed setup guide)
- `VS_TAB_FEATURE.md` (this file)

## Vote Weighting Example

**User A:**
- Map Score: 600
- Player Score: 800  
- Ranking Score: 700
- Final Score: 700
- Vote Weight: 0.7 (70% influence)

**User B:**
- Map Score: 400
- Player Score: 300
- Ranking Score: 500
- Final Score: 400
- Vote Weight: 0.4 (40% influence)

In community verification, User A's vote counts more than User B's due to higher reputation.

## Next Steps

### Required Setup
1. Create database tables (see `VS_TAB_DATABASE_SCHEMA.md`)
2. Create storage bucket for videos
3. Test with two user accounts

### Optional Enhancements
- Add video player package (`video_player` or `chewie`)
- Implement real-time updates (Supabase subscriptions)
- Add username search for finding opponents
- Implement push notifications
- Add battle history and statistics
- Create leaderboards

## Dependencies

No new packages required! Uses existing dependencies:
- `supabase_flutter`: Database and storage
- `image_picker`: Video selection (already in project)
- `provider`: State management (already in project)

## Notes

- Default scores start at 500/1000 for new users
- All scores are constrained to 0-1000 range
- Vote weights are always between 0 and 1
- Videos are stored in Supabase storage
- RLS policies ensure proper access control

## Testing the Feature

1. Create two test user accounts
2. Find User IDs from profile screens
3. Create a battle from User A to User B
4. Upload set trick as User A
5. Upload attempt as User B
6. Vote as both users (try agreement and disagreement)
7. If disagree, check community verification feed
8. Vote from other accounts
9. Verify scores update correctly

---

**Status**: ✅ Feature Complete - Ready for Database Setup

**Implementation Date**: 2025-11-18

**Next Action**: Create database tables in Supabase before testing
