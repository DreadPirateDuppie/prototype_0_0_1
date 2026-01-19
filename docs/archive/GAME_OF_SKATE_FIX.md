# Game of Skate Fix - Battle Workflow Issue

## Problem Identified
When you upload a set trick in a game of skate battle, the button correctly shows "waiting" but the rest of the UI doesn't respond properly because the system isn't automatically switching turns after uploading a set trick.

## Root Cause
The `uploadSetTrick` method in `lib/services/battle_service.dart` only updates the video URL but doesn't:
1. Switch the turn to the opponent
2. Reset the timer for the opponent's turn
3. Update the UI state properly

## Fix Required
Replace the current `uploadSetTrick` method with this improved version:

```dart
// Upload set trick - FIXED VERSION
static Future<Battle?> uploadSetTrick({
  required String battleId,
  required String videoUrl,
}) async {
  try {
    final battle = await getBattle(battleId);
    if (battle == null) return null;

    // Update set trick video URL
    await _client
        .from('battles')
        .update({'set_trick_video_url': videoUrl})
        .eq('id', battleId);

    // Switch turn to opponent automatically after setting trick
    final nextPlayer = battle.currentTurnPlayerId == battle.player1Id
        ? battle.player2Id
        : battle.player1Id;

    // Calculate new deadline
    final Duration timerDuration = battle.isQuickfire
        ? const Duration(minutes: 4, seconds: 20)
        : const Duration(hours: 24);
    final newDeadline = DateTime.now().add(timerDuration);

    final response = await _client
        .from('battles')
        .update({
          'current_turn_player_id': nextPlayer,
          'turn_deadline': newDeadline.toIso8601String(),
        })
        .eq('id', battleId)
        .select()
        .single();

    return Battle.fromMap(response);
  } catch (e) {
    throw Exception('Failed to upload set trick: $e');
  }
}
```

## What This Fixes

1. **Turn Switching**: After you upload a set trick, the system automatically switches the turn to your opponent
2. **Timer Reset**: A new deadline is calculated and set for your opponent's turn
3. **UI Updates**: The battle detail screen will receive the updated battle object with the new turn state
4. **Game Flow**: Your opponent will now see the "Upload Clip" button active for attempting the trick

## Expected Behavior After Fix

1. You upload a set trick
2. System automatically switches turn to opponent
3. Your UI shows "Waiting on opponent"
4. Opponent receives notification/prompt to attempt the trick
5. Game proceeds normally

## Manual Fix Steps

1. Open `lib/services/battle_service.dart`
2. Find the `uploadSetTrick` method (around line 240)
3. Replace the entire method with the fixed version above
4. Save the file
5. Hot reload your Flutter app
6. Test the battle workflow

## Additional Considerations

If this doesn't immediately fix the issue, you may also need to:
1. Ensure the BattleDetailScreen is properly listening to state changes
2. Check that the `_isMyTurn` calculation is working correctly after the turn switch
3. Verify that the UI is refreshing when the battle state changes

The core issue is that the backend wasn't properly managing the turn state after setting tricks, which should now be resolved with this fix.
