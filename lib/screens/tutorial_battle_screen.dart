import 'package:flutter/material.dart';

enum TutorialStep {
  welcome,
  yourTurnIntro,
  setTrick,
  waitingForOpponent,
  opponentMissed,
  opponentTurn,
  opponentSetTrick,
  yourAttempt,
  attemptResult,
  continueGame,
  victory,
  complete,
}

void showTutorialBattle(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const TutorialBattleModal(),
  );
}

class TutorialBattleModal extends StatefulWidget {
  const TutorialBattleModal({super.key});

  @override
  State<TutorialBattleModal> createState() => _TutorialBattleModalState();
}

class _TutorialBattleModalState extends State<TutorialBattleModal> with SingleTickerProviderStateMixin {
  TutorialStep _currentStep = TutorialStep.welcome;
  String _yourLetters = '';
  String _opponentLetters = '';
  String _currentTrick = '';
  bool _isYourTurn = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  void _nextStep() {
    _animationController.reset();
    setState(() {
      switch (_currentStep) {
        case TutorialStep.welcome:
          _currentStep = TutorialStep.yourTurnIntro;
          break;
        case TutorialStep.yourTurnIntro:
          _currentStep = TutorialStep.setTrick;
          break;
        case TutorialStep.setTrick:
          _currentTrick = 'Kickflip';
          _currentStep = TutorialStep.waitingForOpponent;
          _isYourTurn = false;
          break;
        case TutorialStep.waitingForOpponent:
          _currentStep = TutorialStep.opponentMissed;
          _opponentLetters = 'S';
          break;
        case TutorialStep.opponentMissed:
          _currentStep = TutorialStep.opponentTurn;
          break;
        case TutorialStep.opponentTurn:
          _currentStep = TutorialStep.opponentSetTrick;
          _currentTrick = '360 Flip';
          break;
        case TutorialStep.opponentSetTrick:
          _currentStep = TutorialStep.yourAttempt;
          _isYourTurn = true;
          break;
        case TutorialStep.yourAttempt:
          _currentStep = TutorialStep.attemptResult;
          break;
        case TutorialStep.attemptResult:
          _yourLetters = 'S';
          _currentStep = TutorialStep.continueGame;
          break;
        case TutorialStep.continueGame:
          _opponentLetters = 'SKATE';
          _currentStep = TutorialStep.victory;
          break;
        case TutorialStep.victory:
          _currentStep = TutorialStep.complete;
          break;
        case TutorialStep.complete:
          Navigator.of(context).pop();
          return;
      }
    });
    _animationController.forward();
  }

  String _getStepTitle() {
    switch (_currentStep) {
      case TutorialStep.welcome:
        return '🎮 WELCOME TO SKATE';
      case TutorialStep.yourTurnIntro:
        return '🎯 YOUR TURN TO SET';
      case TutorialStep.setTrick:
        return '🛹 SET A TRICK';
      case TutorialStep.waitingForOpponent:
        return '⏳ OPPONENT ATTEMPTING...';
      case TutorialStep.opponentMissed:
        return '❌ OPPONENT MISSED!';
      case TutorialStep.opponentTurn:
        return '🔄 OPPONENT\'S TURN';
      case TutorialStep.opponentSetTrick:
        return '🎯 OPPONENT SET TRICK';
      case TutorialStep.yourAttempt:
        return '🛹 YOUR ATTEMPT';
      case TutorialStep.attemptResult:
        return '📊 RESULT';
      case TutorialStep.continueGame:
        return '⚡ GAME CONTINUES';
      case TutorialStep.victory:
        return '🏆 VICTORY!';
      case TutorialStep.complete:
        return '✅ COMPLETE';
    }
  }

  String _getStepDescription() {
    switch (_currentStep) {
      case TutorialStep.welcome:
        return 'Players take turns SETTING and ATTEMPTING tricks. Miss = get a letter. First to spell SKATE loses!';
      case TutorialStep.yourTurnIntro:
        return 'You\'re first! Choose any trick. Your opponent must land it.';
      case TutorialStep.setTrick:
        return 'In real games, you\'d upload a video. For this tutorial, just tap "Set Trick"!';
      case TutorialStep.waitingForOpponent:
        return 'You set "$_currentTrick". Opponent is attempting...';
      case TutorialStep.opponentMissed:
        return 'Opponent missed the $_currentTrick! They get "S".\n\nYou: $_yourLetters\nOpponent: S';
      case TutorialStep.opponentTurn:
        return 'Since they missed, they set the next trick.';
      case TutorialStep.opponentSetTrick:
        return 'Opponent set "$_currentTrick". Your turn to attempt!';
      case TutorialStep.yourAttempt:
        return 'Try to land the $_currentTrick! (In real games, upload video)';
      case TutorialStep.attemptResult:
        return 'You missed! You get "S".\n\nYou: S\nOpponent: S\n\nGame continues...';
      case TutorialStep.continueGame:
        return 'After several rounds...\n\nYou: $_yourLetters\nOpponent: SKATE';
      case TutorialStep.victory:
        return '🎉 Opponent spelled SKATE first!\n\nYou win and now understand how to play!';
      case TutorialStep.complete:
        return 'Ready for real battles!';
    }
  }

  String _getButtonText() {
    if (_currentStep == TutorialStep.setTrick) return 'SET TRICK';
    if (_currentStep == TutorialStep.yourAttempt) return 'ATTEMPT TRICK';
    if (_currentStep == TutorialStep.complete) return 'DONE';
    return 'NEXT';
  }

  @override
  Widget build(BuildContext context) {
    const matrixGreen = Color(0xFF00FF41);
    const matrixBlack = Color(0xFF000000);
    const matrixSurface = Color(0xFF0D0D0D);
    
    final progress = (_currentStep.index + 1) / TutorialStep.values.length;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: matrixBlack,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: matrixGreen, width: 2),
        boxShadow: [
          BoxShadow(
            color: matrixGreen.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: matrixGreen.withOpacity(0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TUTORIAL BATTLE',
                        style: TextStyle(
                          color: matrixGreen,
                          fontFamily: 'monospace',
                          fontSize: 12,
                          letterSpacing: 2,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Progress bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: matrixSurface,
                          valueColor: AlwaysStoppedAnimation(matrixGreen),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: matrixSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: matrixGreen.withOpacity(0.3)),
                  ),
                  child: Text(
                    '${_currentStep.index + 1}/${TutorialStep.values.length}',
                    style: const TextStyle(
                      color: matrixGreen,
                      fontFamily: 'monospace',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: matrixGreen.withOpacity(0.7)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Score display
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: matrixSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: matrixGreen.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildCompactScore('YOU', _yourLetters.isEmpty ? '-' : _yourLetters),
                Container(
                  height: 30,
                  width: 2,
                  color: matrixGreen.withOpacity(0.3),
                ),
                _buildCompactScore('OPP', _opponentLetters.isEmpty ? '-' : _opponentLetters),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Content area
          Expanded(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Title
                    Text(
                      _getStepTitle(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: matrixGreen,
                        fontFamily: 'monospace',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Current trick display
                    if (_currentTrick.isNotEmpty && _currentStep.index >= 3 && _currentStep.index <= 8)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: matrixBlack,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: matrixGreen, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: matrixGreen.withOpacity(0.2),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Text(
                              'TRICK',
                              style: TextStyle(
                                color: matrixGreen.withOpacity(0.6),
                                fontSize: 10,
                                fontFamily: 'monospace',
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _currentTrick,
                              style: const TextStyle(
                                color: matrixGreen,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Description
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: matrixSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: matrixGreen.withOpacity(0.2)),
                      ),
                      child: Text(
                        _getStepDescription(),
                        style: TextStyle(
                          color: matrixGreen.withOpacity(0.9),
                          fontSize: 14,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Turn indicator
                    if (_currentStep.index > 1 && _currentStep != TutorialStep.complete)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: matrixSurface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: matrixGreen.withOpacity(0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isYourTurn ? Icons.person : Icons.computer,
                              color: matrixGreen,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isYourTurn ? 'YOUR TURN' : 'OPPONENT\'S TURN',
                              style: const TextStyle(
                                color: matrixGreen,
                                fontFamily: 'monospace',
                                fontSize: 11,
                                letterSpacing: 1,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Action button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: matrixGreen.withOpacity(0.4),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _nextStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: matrixBlack,
                    foregroundColor: matrixGreen,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: matrixGreen, width: 2),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    _getButtonText(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactScore(String label, String letters) {
    const matrixGreen = Color(0xFF00FF41);
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: matrixGreen.withOpacity(0.6),
            fontSize: 10,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          letters,
          style: const TextStyle(
            color: matrixGreen,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}
