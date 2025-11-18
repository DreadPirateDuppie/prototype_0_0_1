# VS Tab - User Interface Flow

## Visual UI Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        HOME SCREEN                               │
│  ┌─────┬─────┬─────┬─────┬─────┬─────┐                         │
│  │Feed │Prof.│Map  │ VS  │Rwrds│Stngs│  ← Bottom Navigation    │
│  └─────┴─────┴─────┴──▲──┴─────┴─────┘                         │
└────────────────────────│──────────────────────────────────────┘
                         │
                         │ Tap VS Tab
                         │
┌────────────────────────▼──────────────────────────────────────┐
│                    VS TAB                                       │
│  ┌─────────────────────────────────────┐  [Verification Icon] │
│  │  Active Battles                     │                       │
│  │                                     │                       │
│  │  ┌────────────────────────────┐    │                       │
│  │  │ [Turn] SKATE vs Opponent   │───────┐                    │
│  │  │ You: S / SKATE             │    │  │                    │
│  │  │ Opp: SK / SKATE            │    │  │ Tap Battle         │
│  │  │ [Your turn]                │    │  │                    │
│  │  └────────────────────────────┘    │  │                    │
│  │                                     │  │                    │
│  │  ┌────────────────────────────┐    │  │                    │
│  │  │ [Pause] SK8 vs Player2     │    │  │                    │
│  │  │ You:  / SK8                │    │  │                    │
│  │  │ Opp: S / SK8               │    │  │                    │
│  │  │ [Opponent's turn]          │    │  │                    │
│  │  └────────────────────────────┘    │  │                    │
│  └─────────────────────────────────────┘  │                    │
│                                            │                    │
│  [+ New Battle] ◄─┐                        │                    │
└────────────────────┼────────────────────────┼──────────────────┘
                     │                        │
         Tap New     │                        │
                     │                        │
        ┌────────────▼──────────┐   ┌────────▼──────────────┐
        │ CREATE BATTLE DIALOG  │   │  BATTLE DETAIL SCREEN │
        │                       │   │                        │
        │ Game Mode:            │   │  ┌──────────────────┐ │
        │  [SKATE ▼]            │   │  │ You: S / SKATE   │ │
        │                       │   │  │ VS               │ │
        │ Opponent ID:          │   │  │ Opp: SK / SKATE  │ │
        │  [________]           │   │  └──────────────────┘ │
        │                       │   │                        │
        │ [Cancel] [Create]     │   │  [Your turn - Upload!] │
        └───────────────────────┘   │                        │
                                    │  ┌──────────────────┐ │
                                    │  │  SET TRICK       │ │
                                    │  │  [Video Player]  │ │
                                    │  │  [Play Button]   │ │
                                    │  └──────────────────┘ │
                                    │                        │
                                    │  [Upload Set Trick]───┐│
                                    │        or             ││
                                    │  [Upload Attempt]─────┼┤
                                    └────────────────────────┘│
                                                              ││
                              Video Upload                    ││
                              Processing...                   ││
                                        │                     ││
                              ┌─────────▼────────┐            ││
                              │ QUICK-FIRE VOTE  │◄───────────┘│
                              │                  │             │
                              │ Did player land? │             │
                              │                  │             │
                              │ [✓ Land]         │             │
                              │ [✗ No Land]      │             │
                              │ [↻ Rebate]       │             │
                              │                  │             │
                              │ Waiting for      │             │
                              │ other player...  │             │
                              └──────────────────┘             │
                                        │                      │
                     ┌──────────────────┼──────────────────┐   │
                     │                  │                  │   │
              Both Agree         Both Disagree      Rebate    │
                     │                  │              │       │
                     ▼                  ▼              ▼       │
              Apply Result    Community Verify    Retry       │
              (Land/No Land)          │            Again      │
                     │                 │              │       │
                     │        ┌────────▼────────┐    │       │
                     │        │  COMMUNITY      │    │       │
                     │        │  VERIFICATION   │◄───┼───────┘
                     │        │                 │    │
                     │        │ ┌─────────────┐ │    │
                     │        │ │ Attempt #1  │ │    │
                     │        │ │ [Video]     │ │    │
                     │        │ │             │ │    │
                     │        │ │ Vote:       │ │    │
                     │        │ │ [Land]      │ │    │
                     │        │ │ [No Land]   │ │    │
                     │        │ │ [Rebate]    │ │    │
                     │        │ │             │ │    │
                     │        │ │ Influence:  │ │    │
                     │        │ │ 72.3%       │ │    │
                     │        │ └─────────────┘ │    │
                     │        │                 │    │
                     │        │ ┌─────────────┐ │    │
                     │        │ │ Attempt #2  │ │    │
                     │        │ │ [Video]     │ │    │
                     │        │ └─────────────┘ │    │
                     │        └─────────────────┘    │
                     │                 │             │
                     │      Weighted Calculation     │
                     │                 │             │
                     └─────────────────┼─────────────┘
                                       │
                                       ▼
                              ┌────────────────┐
                              │ RESULT APPLIED │
                              │                │
                              │ Land?          │
                              │  → Next turn   │
                              │                │
                              │ No Land?       │
                              │  → Assign      │
                              │    letter      │
                              │                │
                              │ Game Over?     │
                              │  → Update      │
                              │    scores      │
                              └────────────────┘
```

## Screen-by-Screen Breakdown

### 1. VS Tab (Main Screen)

**Elements:**
- App bar with "VS Battles" title
- Verification icon button (top right)
- List of active battles
- Each battle card shows:
  - Turn indicator (play/pause icon)
  - Game mode
  - Your letters vs Opponent's letters
  - Turn status ("Your turn" / "Opponent's turn")
- Floating action button: "+ New Battle"
- Pull-to-refresh

**Actions:**
- Tap battle → Battle Detail Screen
- Tap verification icon → Community Verification Screen
- Tap "+ New Battle" → Create Battle Dialog

### 2. Create Battle Dialog

**Elements:**
- Game mode dropdown (SKATE / SK8 / Custom)
- Custom letters input (if Custom selected)
- Opponent User ID input field
- Cancel button
- Create button

**Validation:**
- Opponent ID required
- Custom letters: 2-10 characters, letters only
- Form validation on submit

**Actions:**
- Cancel → Close dialog
- Create → Create battle, close dialog, refresh list

### 3. Battle Detail Screen

**Elements:**
- App bar with game mode title
- Score display section:
  - Your letters / Target
  - "VS"
  - Opponent letters / Target
- Turn indicator banner (green=your turn, orange=opponent's)
- Set trick video display (if uploaded)
- Quick-Fire voting card (if in voting status)
- Action buttons:
  - "Upload Set Trick" (if your turn, no set trick)
  - "Upload Attempt" (if opponent's turn, has set trick)

**Actions:**
- Upload Set Trick → Pick video → Upload → Update battle
- Upload Attempt → Pick video → Upload → Create verification → Show voting
- Submit vote → Update Quick-Fire → Process result

### 4. Quick-Fire Voting Interface

**Elements:**
- "Quick-Fire Voting" header
- Question: "Did the player land the trick?"
- Three vote buttons:
  - [✓] Land (green)
  - [✗] No Land (red)
  - [↻] Rebate (orange)
- Status text (waiting for other player)

**Logic:**
- Show buttons if haven't voted
- Show waiting text if voted
- Both voted → Process:
  - Both agree → Apply result
  - Either rebate → Retry
  - Disagree → Community verification

### 5. Community Verification Screen

**Elements:**
- App bar with "Community Verification" title
- List of verification attempts
- Each attempt card shows:
  - Video player (placeholder)
  - Battle ID preview
  - Time submitted
  - Question: "Did the player land this trick?"
  - Three vote buttons (Land/No Land/Rebate)
  - Your vote influence percentage
- Pull-to-refresh

**Actions:**
- Tap vote button → Submit vote → Update Ranking Score
- Refresh → Reload queue

### 6. Profile Tab (Enhanced)

**Elements:**
- Existing profile info (username, email, user ID)
- **NEW: Battle Stats card:**
  - Map Score (0-1000) with progress bar (blue)
  - Player Score (0-1000) with progress bar (green)
  - Ranking Score (0-1000) with progress bar (orange)
  - Final Score (average) with progress bar (purple)
  - Vote Influence percentage
- My Posts section (existing)

**Calculation:**
- Final Score = (Map + Player + Ranking) / 3
- Vote Influence = Final Score / 10 (as percentage)

## Color Scheme

**Turn Indicators:**
- Green: Your turn
- Orange: Opponent's turn
- Purple: App theme color

**Vote Buttons:**
- Green: Land (positive)
- Red: No Land (negative)
- Orange: Rebate (neutral/retry)

**Score Types:**
- Blue: Map Score
- Green: Player Score
- Orange: Ranking Score
- Purple: Final Score

## Navigation Flow

```
Home Screen
    └── VS Tab
        ├── Create Battle Dialog
        │   └── [Creates battle] → Back to VS Tab
        ├── Battle Detail Screen
        │   ├── Quick-Fire Voting
        │   │   └── [Result] → Back to Battle Detail
        │   └── [Battle complete] → Back to VS Tab
        └── Community Verification Screen
            └── [Back] → VS Tab
```

## User Feedback

**Loading States:**
- CircularProgressIndicator while fetching data
- Button disabled state during operations
- "Uploading..." indicators

**Success Messages:**
- "Battle created successfully!"
- "Set trick uploaded!"
- "Attempt uploaded! Waiting for votes..."
- "Vote recorded! Waiting for other player..."
- "Vote submitted successfully!"

**Error Messages:**
- "Error loading battles: [message]"
- "Error uploading video: [message]"
- "Error submitting vote: [message]"

## Empty States

**VS Tab:**
- Icon: sports_kabaddi (large, gray)
- Text: "No active battles"
- Subtext: "Start a new battle to compete!"

**Community Verification:**
- Icon: verified (large, gray)
- Text: "No attempts to verify"
- Subtext: "Check back later!"

## Responsive Behavior

- Pull-to-refresh on all list screens
- Auto-scroll on battle creation
- Progress indicators for all async operations
- Disabled buttons during loading
- Form validation on input
- Real-time vote weight calculation

---

This UI flow provides a complete, intuitive experience for SKATE battles with clear visual feedback at every step.
