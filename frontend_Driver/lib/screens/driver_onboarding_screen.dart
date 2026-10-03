import 'package:flutter/material.dart';

import '../services/session_store.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';

class DriverOnboardingScreen extends StatefulWidget {
  final bool fromRegister;

  const DriverOnboardingScreen({
    super.key,
    this.fromRegister = false,
  });

  @override
  State<DriverOnboardingScreen> createState() => _DriverOnboardingScreenState();
}

class _DriverOnboardingScreenState extends State<DriverOnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _steps = [
    _OnboardingStep(
      icon: Icons.directions_car_rounded,
      title: 'Welcome to RideX Driver',
      label: 'Get started',
      message: 'Join the community of drivers providing fair, safe, and reliable rides.',
    ),
    _OnboardingStep(
      icon: Icons.touch_app_rounded,
      title: 'Receiving trips',
      label: 'Live requests',
      message: 'Customers nearby will send ride requests. You can view the pickup and drop-off points before accepting.',
    ),
    _OnboardingStep(
      icon: Icons.location_on_rounded,
      title: 'Location required',
      label: 'Background tracking',
      message: 'We need your background location to match you with customers in your area and track ongoing trips accurately.',
    ),
    _OnboardingStep(
      icon: Icons.payments_rounded,
      title: 'Driver earnings',
      label: 'Cash payments',
      message: 'You get paid directly by the customer in cash at the end of the trip. The fare is calculated fairly based on distance.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await SessionStore.markOnboardingSeen();
    if (!mounted) return;
    
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const DriverHomeScreen()),
      (route) => false,
    );
  }

  void _next() {
    if (_page == _steps.length - 1) {
      _finish();
      return;
    }

    _controller.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _steps.length - 1;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _finish,
                  child: const Text(
                    'Skip',
                    style: TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Welcome to RideX',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Four simple steps for a better driving experience',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _steps.length,
                  onPageChanged: (value) => setState(() => _page = value),
                  itemBuilder: (context, index) {
                    return _OnboardingPage(
                      step: _steps[index],
                      isActive: index == _page,
                    );
                  },
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _steps.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: index == _page ? 28 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: index == _page
                          ? AppTheme.primary
                          : const Color(0xFF374151),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 58,
                child: ElevatedButton(
                  onPressed: _next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    isLast ? 'Get Started' : 'Next',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final _OnboardingStep step;
  final bool isActive;

  const _OnboardingPage({required this.step, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: _OnboardingCard(step: step, isActive: isActive),
      ),
    );
  }
}

class _OnboardingCard extends StatefulWidget {
  final _OnboardingStep step;
  final bool isActive;

  const _OnboardingCard({required this.step, required this.isActive});

  @override
  State<_OnboardingCard> createState() => _OnboardingCardState();
}

class _OnboardingCardState extends State<_OnboardingCard>
    with SingleTickerProviderStateMixin {
  static const _indigo = AppTheme.primary;
  bool _isHovered = false;
  late final AnimationController _pulseController;

  bool get _isHighlighted => widget.isActive || _isHovered;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
      lowerBound: 0.72,
      upperBound: 1,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: widget.isActive,
      label: '${widget.step.title}. ${widget.step.message}',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          width: 300,
          constraints: const BoxConstraints(minHeight: 350),
          padding: const EdgeInsets.all(26),
          transform: Matrix4.translationValues(0, _isHighlighted ? -8 : 0, 0),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: _isHighlighted
                  ? [_indigo.withValues(alpha: 0.5), const Color(0xFF111827)]
                  : const [Color(0xFF1F2937), Color(0xFF111827)],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _isHighlighted ? _indigo : Colors.transparent,
              width: 2,
            ),
            boxShadow: _isHighlighted
                ? [
                    BoxShadow(
                      color: _indigo.withValues(alpha: 0.22),
                      blurRadius: 28,
                      spreadRadius: 2,
                      offset: const Offset(0, 12),
                    ),
                  ]
                : const [
                    BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.center,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 82,
                        height: 82,
                        decoration: BoxDecoration(
                          color: _indigo.withValues(
                            alpha: _isHighlighted ? 0.30 : 0.20,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _indigo.withValues(
                              alpha: _isHighlighted ? 0.95 : 0.45,
                            ),
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          widget.step.icon,
                          color: _isHighlighted ? const Color(0xFFE0E7FF) : _indigo,
                          size: 42,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _pulseController.value,
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: _isHighlighted
                                    ? const Color(0xFF818CF8)
                                    : const Color(0xFF4B5563),
                                shape: BoxShape.circle,
                                boxShadow: _isHighlighted
                                    ? [
                                        BoxShadow(
                                          color: _indigo.withValues(alpha: 0.6),
                                          blurRadius: 10,
                                          spreadRadius: 2,
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              Text(
                widget.step.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _isHighlighted
                      ? const Color(0xFFE0E7FF)
                      : Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.step.label.toUpperCase(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                widget.step.message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFD1D5DB),
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 26),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                width: _isHighlighted ? 180 : 0,
                height: 4,
                decoration: BoxDecoration(
                  color: _indigo,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingStep {
  final IconData icon;
  final String title;
  final String label;
  final String message;

  const _OnboardingStep({
    required this.icon,
    required this.title,
    required this.label,
    required this.message,
  });
}
