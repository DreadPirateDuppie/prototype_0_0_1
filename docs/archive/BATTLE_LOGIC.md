# Battle Logic Documentation

## Overview
This document explains the S.K.A.T.E. battle system logic as implemented in the app. The game follows traditional skateboarding S.K.A.T.E. rules adapted for asynchronous online play.

## Game Modes
- **S.K.A.T.E.**: 5 letters (S-K-A-T-E)
- **S.K.8**: 3 letters (S-K-8)
- **Custom**: User-defined letters

## Core Roles
At any given time, there are two roles in a battle:
- **Setter**: Sets the trick that must be matched
- **Attempter**: Attempts to match the trick

## Game Flow

### 1. Battle Creation
- One player challenges another
- Game mode and optional wager/wager are specified
- Setter and Attempter roles are **randomly assigned** at start
- Timer starts for the Setter

### 2. Setting Phase
**Setter's Turn:**
- Setter uploads a trick video (with optional trick name)
- Turn automatically passes to Attempter
- New deadline set for Attempter

**Timeout Handling:**
- If Setter fails to upload within deadline:
  - ❌ **No letter assigned**
  - 🔄 **Roles swap**: Attempter becomes new Setter
  - ⏱️ New deadline set

### 3. Attempt Phase
**Attempter's Turn:**
- Attempter uploads attempt video
- System enters voting phase
- Both players vote: **LANDED** or **MISSED**

**Timeout Handling:**
- If Attempter fails to upload within deadline:
  - ❌ **Attempter receives a letter**
  - ✅ **Setter retains control**
  - 🔄 Return to Setting Phase
  - ⏱️ New deadline set

### 4. Voting Phase
Both Setter and Attempter vote on whether the attempt landed.

**Consensus Reached:**

**Case 1: Both vote LANDED**
- ✅ Attempter successfully matched the trick
- 🎯 **Setter KEEPS control** ("Make it, Keep it")
- 🔄 Return to Setting Phase
- Videos cleared, new deadline set

**Case 2: Both vote MISSED**
- ❌ Attempter failed to match
- ❌ **Attempter receives a letter**
- 🎯 **Setter KEEPS control**
- 🔄 Return to Setting Phase
- Videos cleared, new deadline set

**Disagreement:**
- If votes don't match, enter **Community Verification**
- Community members vote on the attempt
- (Feature pending implementation)

### 5. Game End
Game ends when:
- One player spells out all letters (loses)
- One player forfeits
- Timer expires during final letter

**Winner Determination:**
- Player with fewer letters wins
- Winner receives wager payout (if applicable)
- Scores updated

## State Machine

```
[Battle Created]
↓
[Setting Phase] ← ─ ─ ─ ─ ─ ─ ┐
↓                              │
Setter uploads trick           │
↓                              │
[Attempt Phase]                │
↓                              │
Attempter uploads attempt      │
↓                              │
[Voting Phase]                 │
↓                              │
Both vote                      │
↓                              │
LANDED? ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─┘
│                              (Setter keeps control)
NO
↓
Assign letter to Attempter
↓
Check if game over
↓
If not over: Return to Setting Phase
(Setter keeps control)
```

## Timeout Logic Summary

| **Phase** | **Who Timed Out** | **Letter?** | **Next Action** |
|-----------|------------------|-------------|-----------------|
| Setting   | Setter           | ❌ No       | Swap roles      |
| Attempt   | Attempter        | ✅ Yes      | Setter keeps control |

## Battle Service Methods

### `createBattle`
- Creates new battle with random Setter/Attempter assignment
- Handles wager/wager deductions
- Sets initial deadline

### `uploadSetTrick`
- Stores trick video and optional name
- **Passes turn to Attempter**
- Resets deadline

### `uploadAttempt`
- Stores attempt video
- Enters voting phase
- Clears previous votes

### `submitVote`
- Records vote from player
- Automatically calls `resolveVotes` when both voted

### `resolveVotes`
- **LANDED**: Setter keeps control, return to Setting
- **MISSED**: Assign letter, Setter keeps control
- **Disagree**: Enter Community Verification

### `checkExpiredTurns`
- Called on app load/refresh
- Skips battles in voting phase
- Handles Setter timeout: swap roles, no letter
- Handles Attempter timeout: assign letter, Setter keeps

### `assignLetter`
- Adds next letter to player's letter string
- Checks if game complete
- Auto-completes battle if winner determined

### `completeBattle`
- Sets winner
- Awards wager to winner
- Updates player scores

## Key Differences from Traditional S.K.A.T.E.

1. **Asynchronous Play**: Timer-based instead of real-time
2. **Voting System**: Both players vote on attempts (prevents disputes)
3. **Random Initial Setter**: Fair start for both players
4. **Timeout = Auto-action**: Keeps games from stalling indefinitely
