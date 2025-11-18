# VS Tab Feature - Setup Checklist

Use this checklist to set up and test the VS Tab feature.

## ☑️ Pre-Setup Verification

- [ ] Code changes have been pulled/merged to your local repository
- [ ] You have access to your Supabase dashboard
- [ ] You have at least one test user account (recommend 2-3 for testing)

## 📊 Database Setup (Required)

### Step 1: Create Tables

- [ ] Log into Supabase dashboard
- [ ] Navigate to SQL Editor
- [ ] Copy SQL from `VS_TAB_DATABASE_SCHEMA.md`
- [ ] Execute the following table creation scripts:
  - [ ] `user_scores` table
  - [ ] `battles` table
  - [ ] `verification_attempts` table
  - [ ] `quick_fire_votes` table
  - [ ] `community_votes` table
  - [ ] All indexes
  - [ ] Update trigger for `user_scores`

### Step 2: Apply Row Level Security

- [ ] Enable RLS on all tables
- [ ] Apply RLS policies for `user_scores`
- [ ] Apply RLS policies for `battles`
- [ ] Apply RLS policies for `verification_attempts`
- [ ] Apply RLS policies for `quick_fire_votes`
- [ ] Apply RLS policies for `community_votes`

### Step 3: Storage Setup

- [ ] Navigate to Storage in Supabase
- [ ] Create new bucket named `battle_videos`
- [ ] Set bucket to public or authenticated access
- [ ] Set upload size limit (recommend 50MB minimum)
- [ ] Configure allowed MIME types (video/mp4, video/quicktime)

### Step 4: Initialize User Scores (Optional but Recommended)

- [ ] Create trigger to auto-initialize user scores on signup
- [ ] OR: Let app create default scores on first access

## 🧪 Testing Setup

### Test User Accounts

- [ ] Create/have User Account 1 (Player 1)
- [ ] Create/have User Account 2 (Player 2)
- [ ] Create/have User Account 3 (Community Voter - optional)
- [ ] Note down all User IDs for testing

### Test Data Preparation

User 1 ID: `_____________________________`
User 2 ID: `_____________________________`
User 3 ID: `_____________________________`

## 🎮 Functional Testing

### Basic Battle Creation

- [ ] Log in as User 1
- [ ] Navigate to VS Tab
- [ ] Tap "New Battle"
- [ ] Select SKATE mode
- [ ] Enter User 2's ID
- [ ] Create battle successfully
- [ ] Battle appears in list

### Set Trick Upload

- [ ] As User 1 (Player 1), open the battle
- [ ] Verify turn indicator shows "Your turn"
- [ ] Tap "Upload Set Trick"
- [ ] Select a video file
- [ ] Video uploads successfully
- [ ] Set trick video appears in battle

### Attempt Upload

- [ ] Log in as User 2
- [ ] Navigate to VS Tab
- [ ] Open the battle
- [ ] Verify turn indicator shows "Your turn"
- [ ] Watch set trick video (or see placeholder)
- [ ] Tap "Upload Attempt"
- [ ] Select a video file
- [ ] Attempt uploads successfully
- [ ] Quick-Fire voting interface appears

### Quick-Fire Voting - Agreement

- [ ] As User 2, vote "Land" or "No Land"
- [ ] Verify "Waiting for other player" message
- [ ] Log in as User 1
- [ ] Open battle
- [ ] Vote the same as User 2
- [ ] Verify result applied immediately
- [ ] If "No Land": Check letter assigned
- [ ] If "Land": Check turn switched

### Quick-Fire Voting - Disagreement

- [ ] Create new battle or continue testing
- [ ] Upload set trick (User 1)
- [ ] Upload attempt (User 2)
- [ ] User 1 votes "Land"
- [ ] User 2 votes "No Land"
- [ ] Verify attempt sent to community verification

### Community Verification

- [ ] Navigate to VS Tab
- [ ] Tap verification icon (top right)
- [ ] Verify attempt appears in queue
- [ ] Check video player (should show placeholder)
- [ ] Verify vote influence percentage displays
- [ ] Submit a vote (Land/No Land/Rebate)
- [ ] Verify "Vote submitted" message
- [ ] Log in as User 3
- [ ] Navigate to community verification
- [ ] Submit a vote
- [ ] Check that weighted calculation happens

### Letter Assignment

- [ ] Complete a round with "No Land" result
- [ ] Verify letter assigned to attempting player
- [ ] Check letter display updates in battle card
- [ ] Check letter display updates in battle detail

### Battle Completion

- [ ] Continue battle until one player gets all letters
- [ ] Verify battle marked as complete
- [ ] Check winner determined correctly
- [ ] Verify Player Scores updated:
  - [ ] Winner gained points
  - [ ] Loser lost points

### Score Display

- [ ] Navigate to Profile Tab
- [ ] Verify Battle Stats card displays
- [ ] Check all four scores show:
  - [ ] Map Score
  - [ ] Player Score
  - [ ] Ranking Score
  - [ ] Final Score
- [ ] Verify progress bars display correctly
- [ ] Check Vote Influence percentage

### Rebate Testing

- [ ] Create new battle
- [ ] Upload set trick and attempt
- [ ] One player votes "Rebate"
- [ ] Verify automatic retry triggered
- [ ] Verify no letter assigned
- [ ] Verify turn remains the same

### Different Game Modes

- [ ] Test SK8 mode (shorter game)
- [ ] Test Custom mode with custom letters
- [ ] Verify custom letters validation
- [ ] Verify letters display correctly

## 🐛 Error Handling Testing

- [ ] Try creating battle with invalid User ID
- [ ] Try uploading very large video file
- [ ] Try voting twice on same attempt
- [ ] Try uploading without internet connection
- [ ] Verify appropriate error messages

## 📱 UI/UX Testing

- [ ] Test pull-to-refresh on VS Tab
- [ ] Test pull-to-refresh on Community Verification
- [ ] Verify loading indicators appear
- [ ] Test navigation between screens
- [ ] Verify back navigation works correctly
- [ ] Check empty states display properly
- [ ] Test on different screen sizes (if applicable)

## 🔒 Security Testing

- [ ] Verify users can only see their own battles
- [ ] Verify users cannot modify other users' scores
- [ ] Verify RLS policies prevent unauthorized access
- [ ] Test battle creation as different users
- [ ] Verify vote weight calculated correctly

## 📊 Data Integrity Testing

- [ ] Verify scores stay within 0-1000 range
- [ ] Verify vote weights stay within 0-1 range
- [ ] Verify letters assign in correct order
- [ ] Verify Final Score calculates correctly
- [ ] Test with default scores (500/500/500)
- [ ] Test with varying score values

## 🚀 Performance Testing

- [ ] Create multiple battles
- [ ] Test with multiple verification attempts
- [ ] Check query performance in database
- [ ] Verify indexes are being used
- [ ] Test video upload times

## 📝 Documentation Review

- [ ] Read through `VS_TAB_FEATURE.md`
- [ ] Review `VS_TAB_IMPLEMENTATION_GUIDE.md`
- [ ] Check `VS_TAB_DATABASE_SCHEMA.md`
- [ ] Review `VS_TAB_UI_FLOW.md`
- [ ] Understand `VS_TAB_SUMMARY.md`

## ✨ Optional Enhancements

Future improvements to consider:

- [ ] Add video player package (video_player or chewie)
- [ ] Implement real-time updates (Supabase subscriptions)
- [ ] Add username search for opponent selection
- [ ] Implement push notifications for turn changes
- [ ] Add battle history screen
- [ ] Create leaderboards
- [ ] Add achievement system
- [ ] Implement team battles
- [ ] Add chat feature

## 🎉 Launch Checklist

Before releasing to production:

- [ ] All functional tests passed
- [ ] Database tables created
- [ ] Storage bucket configured
- [ ] RLS policies applied and tested
- [ ] Error handling verified
- [ ] UI/UX acceptable
- [ ] Documentation complete
- [ ] Test with real users
- [ ] Monitor initial usage
- [ ] Have rollback plan ready

## 📞 Support

If you encounter issues:

1. Check Supabase logs for errors
2. Verify all database tables exist
3. Confirm RLS policies are correct
4. Check Flutter console for errors
5. Review storage bucket configuration
6. Ensure video file formats are supported
7. Verify network connectivity

## ✅ Completion

Date completed: _______________

Tested by: _______________

Issues found: _______________

Status: [ ] Ready for Production  [ ] Needs Work

Notes:
_________________________________________
_________________________________________
_________________________________________
_________________________________________

---

**Next Steps After Checklist:**
1. If all tests pass → Deploy to production
2. If issues found → Address and re-test
3. Monitor user feedback
4. Plan future enhancements

Good luck with your SKATE battles! 🛹🎮
