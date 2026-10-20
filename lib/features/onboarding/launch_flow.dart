import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services.dart';
import '../../core/theme.dart';
import '../screens.dart';
import '../shell.dart';

/// First-launch experience: splash -> onboarding -> authentication -> app.
class LaunchFlow extends StatefulWidget {
  const LaunchFlow({
    super.key,
    required this.backendConfigured,
    this.backendInitializationPending = false,
    this.backendInitializationFailed = false,
    this.backendInitializationError,
    this.initialTab = 0,
  });
  final bool backendConfigured;
  final bool backendInitializationPending;
  final bool backendInitializationFailed;
  final String? backendInitializationError;
  final int initialTab;

  @override
  State<LaunchFlow> createState() => _LaunchFlowState();
}

class _LaunchFlowState extends State<LaunchFlow>
    with SingleTickerProviderStateMixin {
  final PageController _pages = PageController();
  int _page = -1; // -1 is the splash screen.
  bool _ready = false;
  bool _showAuthentication = false;
  bool _showStore = false;

  static const _slides = <_SlideData>[
    _SlideData(
      image: 'assets/image.png',
      title: 'Tools for every build',
      body: 'Find dependable power tools for the work ahead.',
    ),
    _SlideData(
      image: 'assets/image copy.png',
      title: 'Materials that build strong',
      body: 'Cement, lumber, steel, and more for every project.',
    ),
    _SlideData(
      image: 'assets/image copy 2.png',
      title: 'Electrical essentials',
      body: 'Get the wiring and fittings your project needs.',
    ),
    _SlideData(
      image: 'assets/image copy 3.png',
      title: 'Tools for the finishing touches',
      body: 'Stock up on the reliable hand tools you reach for daily.',
    ),
    _SlideData(
      image: 'assets/image copy 4.png',
      title: 'Make every finish count',
      body: 'Paints and supplies to bring your space together.',
    ),
    _SlideData(
      image: 'assets/image copy 5.png',
      title: 'Plumbing made practical',
      body: 'Pipes and fittings for repairs and new installations.',
    ),
    _SlideData(
      image: 'assets/image copy 6.png',
      title: 'BuildHive for every project',
      body: 'Shop trusted construction supplies in one place.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    var seen = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      seen = prefs.getBool('buildhive_onboarding_seen') ?? false;
    } catch (_) {
      // Onboarding still works if local preferences are temporarily unavailable.
    }
    if (!mounted) return;
    if (seen) {
      _continueToApp();
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    setState(() {
      _page = 0;
      _ready = true;
    });
  }

  void _openStore() {
    if (!mounted) return;
    setState(() {
      _showAuthentication = false;
      _showStore = true;
    });
  }

  void _requireAuthentication() {
    if (!mounted) return;
    setState(() {
      _showStore = false;
      _showAuthentication = true;
    });
  }

  void _continueToApp() {
    if (!mounted) return;
    final hasSession = widget.backendConfigured &&
        Backend.isConfigured &&
        Backend.db.auth.currentUser != null;
    setState(() {
      _ready = true;
      _showStore = hasSession;
      _showAuthentication = !hasSession;
    });
  }

  Future<void> _finish() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('buildhive_onboarding_seen', true);
    } catch (_) {}
    _requireAuthentication();
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showStore) {
      return BuildHiveShell(
        backendConfigured: widget.backendConfigured,
        initialTab: widget.initialTab,
        onSignedOut: _requireAuthentication,
      );
    }
    if (_showAuthentication) {
      return AuthScreen(
        requiredAuth: true,
        backendInitializationPending: widget.backendInitializationPending,
        backendInitializationFailed: widget.backendInitializationFailed,
        backendInitializationError: widget.backendInitializationError,
        onAuthenticated: _openStore,
      );
    }
    if (!_ready || _page == -1) {
      return Scaffold(
        backgroundColor: hiveBlack,
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/buildhive_logo.png',
                width: 220,
                height: 250,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 20),
            const Text('Build More. Deliver Faster.',
                style:
                    TextStyle(color: hiveYellow, fontStyle: FontStyle.italic)),
          ]),
        ),
      );
    }

    return Scaffold(
      backgroundColor: hiveBlack,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  PageView.builder(
                    controller: _pages,
                    itemCount: _slides.length,
                    onPageChanged: (index) => setState(() => _page = index),
                    itemBuilder: (context, index) {
                      final slide = _slides[index];
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.asset(slide.image, fit: BoxFit.cover),
                          const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Color(0x330B2D3B),
                                  Color(0x000B2D3B),
                                  Color(0xF20B2D3B),
                                ],
                                stops: [0, .42, 1],
                              ),
                            ),
                          ),
                          Positioned(
                            top: 50,
                            left: 16,
                            child: Text(
                              slide.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                height: 1.12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 32,
                            left: 16,
                            right: 16,
                            child: Text(
                              slide.body,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  Positioned(
                    top: 10,
                    right: 16,
                    child: TextButton(
                      onPressed: _finish,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: hiveBlack.withValues(alpha: .72),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Skip'),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _slides.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _page == index ? 22 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: _page == index ? hiveYellow : Colors.white38,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _finish,
                    child: const Text('Get Started'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlideData {
  const _SlideData(
      {required this.image, required this.title, required this.body});
  final String image;
  final String title;
  final String body;
}
