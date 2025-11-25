/// Centralized app constants
class AppConstants {
  // Battle durations
  static const Duration quickfireBattleDuration = Duration(minutes: 4, seconds: 20);
  static const Duration standardBattleDuration = Duration(hours: 24);
  static const Duration extendedBattleDuration = Duration(days: 3);
  
  // Timer intervals
  static const Duration timerUpdateInterval = Duration(seconds: 1);
  static const Duration autoRefreshInterval = Duration(minutes: 5);
  
  // Pagination
  static const int postsPerPage = 20;
  static const int battlesPerPage = 10;
  static const int notificationsPerPage = 15;
  static const int commentsPerPage = 20;
  
  // Points and scoring
  static const int pointsForWin = 100;
  static const int pointsForLoss = -50;
  static const int pointsForDraw = 25;
  static const int pointsForPost = 10;
  static const int pointsForVerification = 5;
  
  // Game modes
  static const Map<String, int> gameModeLengths = {
    'SKATE': 5,
    'BIKE': 4,
    'SCOOT': 5,
  };
  
  // Media constraints
  static const int maxVideoSizeMB = 100;
  static const int maxImageSizeMB = 10;
  static const Duration maxVideoDuration = Duration(minutes: 5);
  
  // Cache durations
  static const Duration imageCacheDuration = Duration(days: 7);
  static const Duration dataCacheDuration = Duration(hours: 1);
  
  // Network timeouts
  static const Duration networkTimeout = Duration(seconds: 30);
  static const Duration uploadTimeout = Duration(minutes: 5);
  
  // UI constants
  static const double maxContentWidth = 600.0;
  static const double minTapTargetSize = 48.0;
  static const int maxUsernameLength = 20;
  static const int maxBioLength = 150;
  static const int maxPostCaptionLength = 500;
  
  // Animation durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 300);
  static const Duration longAnimation = Duration(milliseconds: 500);
  
  // Retry configuration
  static const int maxRetryAttempts = 3;
  static const Duration retryDelay = Duration(seconds: 2);
  
  // Ad configuration
  static const Duration adRefreshInterval = Duration(minutes: 1);
  static const int maxAdsPerSession = 10;
}
