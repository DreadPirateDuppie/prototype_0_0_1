import 'package:flutter/material.dart';
import '../widgets/cyber/cyber_scaffold.dart';
import '../widgets/cyber/cyber_button.dart';
import 'profile_setup_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _slides = [
    {
      "title": "LOCATE OBJECTIVES",
      "desc": "Scan your sector for elite skate spots. Decrypt hidden locations.",
      "icon": Icons.radar,
    },
    {
      "title": "INITIATE COMBAT",
      "desc": "Challenge other operators in global S-K-A-T-E battles. Rank up.",
      "icon": Icons.sports_esports,
    },
    {
      "title": "AMPLIFY LEGACY",
      "desc": "Upload data clips. Build your reputation in the network.",
      "icon": Icons.history_edu,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return CyberScaffold(
      showGrid: true,
      child: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemCount: _slides.length,
              itemBuilder: (context, index) {
                return _buildSlide(_slides[index]);
              },
            ),
          ),
          
          // Indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_slides.length, (index) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _currentPage == index ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _currentPage == index 
                      ? const Color(0xFF00FF41) 
                      : const Color(0xFF003300),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: _currentPage == index
                      ? [
                          BoxShadow(
                            color: const Color(0xFF00FF41).withOpacity(0.5), // Fixed: withOpacity
                            blurRadius: 10,
                          )
                        ]
                      : [],
                ),
              );
            }),
          ),
          
          const SizedBox(height: 32),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: CyberButton(
              text: _currentPage == _slides.length - 1 ? "INITIALIZE SYSTEM" : "NEXT MODULE",
              onPressed: () {
                if (_currentPage < _slides.length - 1) {
                  _pageController.nextPage(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeInOut,
                  );
                } else {
                  // Navigate to Profile Setup
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => const ProfileSetupScreen()),
                  );
                }
              },
              isPrimary: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlide(Map<String, dynamic> slide) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF00FF41), width: 2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00FF41).withOpacity(0.2), // Fixed: withOpacity
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Icon(
              slide['icon'],
              size: 80,
              color: const Color(0xFF00FF41),
            ),
          ),
          const SizedBox(height: 48),
          Text(
            slide['title'],
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF00FF41),
              letterSpacing: 2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            slide['desc'],
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 14,
              color: Colors.grey,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
