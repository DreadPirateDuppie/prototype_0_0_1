# Fix Stuck Game Timer

The user reports that the game timer is stuck at "23H 59M" for days. This suggests that the `turn_deadline` is either not being updated correctly or is being reset to 24 hours every time the battle is loaded/updated.

## Proposed Changes

### Battle Service
- [x] Fix `isFilter` typo in `checkExpiredTurns`.
- [ ] Fix `'null'` string bug in `getActiveBattles`.
- [ ] Add `turn_deadline` update to `uploadAttempt` to ensure voting phase has a timer.
- [ ] Investigate why `checkExpiredTurns` might be resetting the deadline to 24 hours repeatedly (likely due to the game state not advancing correctly on timeout).
- [ ] Ensure `checkExpiredTurns` handles voting phase timeouts as well.

### UI Improvements
- [ ] Add a timer to `VsTab` to periodically refresh the UI so the countdown is visible.

### Quickfire Fix
- [x] Fix `createBattle` in `BattleService` to use calculated `timerDuration` instead of hardcoded 24h for `turnDeadline`.

### Timeout Logic Fix
- [x] Modify `checkExpiredTurns` to handle RPS timeouts where neither player moves (randomly assign winner instead of forfeit).
- [x] Ensure active battle timeouts correctly assign letters/swap turns without ending the game prematurely.

### Auto-Refresh Fix
- [x] Modify `VsTab` to check if any battle timer has reached zero and trigger `_loadBattles`.
- [x] Modify `BattleDetailScreen` to handle timer expiration and refresh battle state.

#### [MODIFY] [battle_service.dart](file:///Users/chiiefbaka/prototype_0_0_1/lib/services/battle_service.dart)
- Update `checkExpiredTurns` to assign a letter to the Setter if they time out.

#### [MODIFY] [notification_service.dart](file:///Users/chiiefbaka/prototype_0_0_1/lib/services/notification_service.dart)
- Add `scheduleBattleTurnExpiryNotification`.
- Add `cancelBattleNotification`.

#### [MODIFY] [home_screen.dart](file:///Users/chiiefbaka/prototype_0_0_1/lib/screens/home_screen.dart)
- Add `WidgetsBindingObserver` to listen for app resume.
- Call `BattleProvider.refresh()` on resume to ensure timer logic runs.

#### [MODIFY] [battle_detail_screen.dart](file:///Users/chiiefbaka/prototype_0_0_1/lib/screens/battle_detail_screen.dart)
- Add `_showWinnerDialog` method to display winner info and avatar.
- Add `_showForfeitTurnDialog` method.
- Update `_forfeitBattle` to clarify if it's forfeiting the match or turn (or add a separate option).
- Listen for `winner_id` changes in `didUpdateWidget` or `build` to trigger the winner dialog.

#### [MODIFY] [battle_detail_screen.dart](file:///Users/chiiefbaka/prototype_0_0_1/lib/screens/battle_detail_screen.dart)
- Update `_submitRpsMove` to locally update `_battle` with the move and set `_isLoading = false` immediately.

#### [MODIFY] [vs_tab.dart](file:///Users/chiiefbaka/prototype_0_0_1/lib/tabs/vs_tab.dart)
- Update `_buildActionBar` to check if `battle.setterId == null`.
- If true, display "RPS BATTLE" (or specific status like "RPS: YOUR TURN" if they haven't moved).

## Verification Plan

### Forfeit Turn Feature
- [x] Add `forfeitTurn` method to `BattleService` (calls `assignLetter` directly).
- [x] Add "Give Up / Skip Trick" button to `BattleDetailScreen` for Attempters.

### Match Page Timer Fix
- [x] Update `_startRefreshTimer` in `BattleDetailScreen` to call `setState` every second.

### Timer Reset Loop Fix (Re-investigation)
- [ ] Add extensive logging to `checkExpiredTurns` to debug why it's not catching the expired battle.
- [ ] Verify `current_turn_player_id` logic matches the actual state of the battle.
- [ ] Ensure `assignLetter` is robust against nulls.

### In-Game Chat
- [ ] Create migration `add_battle_id_to_conversations.sql` to add `battle_id` column.
- [ ] Update `MessagingService` to support creating/fetching battle conversations.
- [ ] Create `BattleChatScreen` widget.
- [ ] Add chat button to `BattleDetailScreen`.

### Game Start Notification
- [ ] Update `BattleService.createBattle` to send a system message (or direct message) to the opponent with a link/deep-link to the battle.

### Leaderboard Redesign
- [ ] Create `LeaderboardCard` widget with "Matrix" theme (glassmorphism, neon accents).
- [ ] Update `VsTab` to use the new card.
