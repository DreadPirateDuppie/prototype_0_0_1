# TODO: Fix Deprecated withOpacity Usages in battle_detail_screen.dart

## Tasks to Complete:
- [x] Replace `Colors.deepPurple.withOpacity(0.1)` with `Colors.deepPurple.withValues(alpha: 0.1)` in Score Display container
- [x] Replace `Colors.green.withOpacity(0.1)` with `Colors.green.withValues(alpha: 0.1)` in Turn indicator container (_isMyTurn true case)
- [x] Replace `Colors.orange.withOpacity(0.1)` with `Colors.orange.withValues(alpha: 0.1)` in Turn indicator container (else case)
- [x] Verify changes compile without errors
