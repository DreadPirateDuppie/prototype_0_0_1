# VS Tab Implementation Guide

This guide explains how to set up and use the VS Tab feature for SKATE battles.

## Overview

The VS Tab feature enables users to compete in SKATE-style battles with the following capabilities:

- **Multiple Game Modes**: SKATE (S-K-A-T-E), SK8 (S-K-8), or Custom letters
- **Quick-Fire Voting**: Both players vote immediately after an attempt
- **Community Verification**: If players disagree, the community decides
- **Weighted Voting**: Vote influence based on user reputation (Final Score)
- **Comprehensive Scoring**: Three independent scores (Map, Player, Ranking)

## Setup Instructions

### 1. Database Setup

First, create all the required database tables in Supabase:

1. Log in to your Supabase dashboard
2. Go to the SQL Editor
3. Run all the SQL commands from `VS_TAB_DATABASE_SCHEMA.md`
4. This includes:
   - `user_scores` table
   - `battles` table
   - `verification_attempts` table
   - `quick_fire_votes` table
   - `community_votes` table
   - All indexes and RLS policies

### 2. Storage Setup

Create a storage bucket for battle videos:

1. Go to Storage in Supabase dashboard
2. Click "Create new bucket"
3. Name it `battle_videos`
4. Choose appropriate privacy settings (public or authenticated)
5. Set upload size limit (recommend at least 50MB for videos)

### 3. Initialize User Scores

When a new user signs up, they should get default scores. You can either:

**Option A: Automatic (Recommended)**
Create a database trigger to initialize scores on user creation:

```sql
CREATE OR REPLACE FUNCTION initialize_user_scores()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO user_scores (user_id, map_score, player_score, ranking_score)
  VALUES (NEW.id, 500.0, 500.0, 500.0);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION initialize_user_scores();
```

**Option B: Manual**
The app will automatically create default scores (500/500/500) when first accessing user scores.

## Feature Components

### 1. VS Tab (`lib/tabs/vs_tab.dart`)

Main interface for battles:
- Lists all active battles for the current user
- Shows current turn and letter count
- Button to create new battles
- Navigation to community verification

### 2. Battle Detail Screen (`lib/screens/battle_detail_screen.dart`)

Detailed battle interface:
- Displays current scores (letters earned)
- Shows who's turn it is
- Upload set trick video (player setting the trick)
- Upload attempt video (player attempting to match)
- Quick-Fire voting interface

### 3. Community Verification Screen (`lib/screens/community_verification_screen.dart`)

Community voting interface:
- Shows all attempts needing community verification
- Vote buttons (Land / No Land / Rebate)
- Displays your vote influence percentage
- Updates your Ranking Score based on voting accuracy

### 4. Profile Tab Updates

Enhanced profile display:
- Map Score (0-1000) - Trust from map posts
- Player Score (0-1000) - Battle performance
- Ranking Score (0-1000) - Voting accuracy
- Final Score - Average of all three
- Vote Influence - Percentage weight (Final Score / 10)

## User Flow

### Starting a Battle

1. Navigate to VS Tab
2. Click "New Battle" button
3. Select game mode (SKATE, SK8, or Custom)
4. Enter opponent's User ID
5. Battle is created with you as Player 1

### Playing a Battle

**Setting the Trick (Your Turn):**
1. Open the battle from VS Tab
2. Upload a video of the trick you're setting
3. Wait for opponent to attempt

**Attempting the Trick (Opponent's Turn):**
1. Watch the set trick video
2. Upload your attempt video
3. Quick-Fire voting begins

### Quick-Fire Voting

When an attempt is uploaded:
1. Both players see voting interface
2. Each votes: Land / No Land / Rebate
3. **If both agree**: Result applied immediately
4. **If either selects Rebate**: Automatic retry
5. **If they disagree**: Escalates to community

### Community Verification

When players disagree:
1. Attempt appears in community verification feed
2. Any user can vote (Land / No Land / Rebate)
3. Votes are weighted by Final Score
4. System calculates weighted totals
5. Highest total wins
6. Voters' Ranking Scores adjusted based on accuracy

### Scoring System

**Letter Assignment:**
- Failed attempt = Next letter assigned
- Letters follow game mode order (S→K→A→T→E or S→K→8)
- First player to reach all letters loses

**Score Updates:**

*Player Score:*
- Winner: +10 points
- Loser: -5 to -15 points (based on letters earned)

*Ranking Score:*
- Vote with majority: +1 point
- Vote against majority: -1 point
- Rebate votes: No change
- Repeat trolling (5+ wrong): -3 points

*Map Score:*
- Updated based on map post quality
- Managed by existing map post system

## Vote Weighting Formula

```
Final Score = (Map Score + Player Score + Ranking Score) / 3
Vote Weight = Final Score / 1000
```

**Example:**
- User has scores: Map=600, Player=800, Ranking=700
- Final Score = (600 + 800 + 700) / 3 = 700
- Vote Weight = 700 / 1000 = 0.7
- Vote Influence = 70%

## API Methods

### Battle Service (`lib/services/battle_service.dart`)

- `createBattle()` - Create a new battle
- `getUserBattles()` - Get all battles for a user
- `getActiveBattles()` - Get ongoing battles
- `uploadTrickVideo()` - Upload video to storage
- `uploadSetTrick()` - Set the trick video
- `uploadAttempt()` - Upload attempt video
- `assignLetter()` - Assign letter to player
- `completeBattle()` - Mark battle as complete
- `getUserScores()` - Get user's scores
- `updatePlayerScore()` - Update player score
- `updateRankingScore()` - Update ranking score
- `updateMapScore()` - Update map score

### Verification Service (`lib/services/verification_service.dart`)

- `createVerificationAttempt()` - Create verification attempt
- `createQuickFireVote()` - Initialize Quick-Fire voting
- `submitQuickFireVote()` - Submit player vote
- `submitCommunityVote()` - Submit community vote
- `getVotesForAttempt()` - Get all votes for an attempt
- `calculateWeightedResult()` - Calculate vote outcome
- `resolveAttempt()` - Apply verification result
- `updateRankingScores()` - Update voter scores
- `getCommunityVerificationQueue()` - Get attempts needing votes

## Testing Checklist

- [ ] Create a battle between two users
- [ ] Upload a set trick video
- [ ] Upload an attempt video
- [ ] Both players vote (agreement)
- [ ] Both players vote (disagreement)
- [ ] Community verification appears in feed
- [ ] Submit community votes
- [ ] Verify weighted vote calculation
- [ ] Check letter assignment on failed attempt
- [ ] Check turn switching on successful attempt
- [ ] Complete a full battle
- [ ] Verify Player Score updates
- [ ] Verify Ranking Score updates
- [ ] Check vote influence display
- [ ] Test rebate functionality

## Known Limitations

1. **Video Player**: Current implementation shows a placeholder. You'll need to integrate a video player package like `video_player` or `chewie` to actually play videos.

2. **User Search**: Currently requires knowing opponent's User ID. Future enhancement: add username search.

3. **Real-time Updates**: Battles don't update in real-time. Users must refresh manually.

4. **Video Upload**: Uses `image_picker` which may have limited video support on some platforms.

5. **Notification System**: No push notifications when it's your turn or when voting is needed.

## Future Enhancements

- [ ] Add video player integration
- [ ] Implement username-based opponent search
- [ ] Add real-time updates using Supabase subscriptions
- [ ] Add push notifications for turn changes
- [ ] Add battle history and statistics
- [ ] Implement leaderboards
- [ ] Add battle replays
- [ ] Support for team battles (2v2, etc.)
- [ ] Add chat/trash talk feature
- [ ] Implement seasonal rankings
- [ ] Add achievements and badges

## Troubleshooting

**Videos won't upload:**
- Check storage bucket permissions
- Verify file size limits
- Ensure video format is supported (MP4 recommended)

**Scores not updating:**
- Check RLS policies on `user_scores` table
- Verify user authentication

**Community verification not showing:**
- Check RLS policies on `verification_attempts`
- Ensure status is set to 'communityVerification'

**Vote weight showing 50%:**
- This is default if user scores don't exist
- Check if `user_scores` record exists for user

## Support

For issues or questions:
1. Check database RLS policies
2. Review Supabase logs for errors
3. Check Flutter console for error messages
4. Verify all tables and indexes exist
5. Ensure storage bucket is properly configured

## Credits

Implemented by GitHub Copilot based on requirements for SKATE battle functionality including Quick-Fire voting, community verification, and weighted vote scoring system.
