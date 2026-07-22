import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/trip_provider.dart';
import '../theme.dart';
import 'home_tab.dart';
import 'profile_tab.dart';
import 'receipts_tab.dart';
import 'trips_tab.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  final _navigatorKeys = List.generate(4, (_) => GlobalKey<NavigatorState>());

  late final List<Widget> _screens = [
    const HomeTab(),
    const TripsTab(),
    const ReceiptsTab(),
    const ProfileTab(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TripProvider>().load(refresh: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasOngoingTrip = context.watch<TripProvider>().hasOngoingTrip;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        final navigator = _navigatorKeys[_currentIndex].currentState;
        if (navigator != null && navigator.canPop()) {
          navigator.pop();
          return;
        }
        SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: IndexedStack(
          index: _currentIndex,
          children: List.generate(
            _screens.length,
            (index) => Navigator(
              key: _navigatorKeys[index],
              onGenerateRoute: (_) =>
                  MaterialPageRoute(builder: (_) => _screens[index]),
            ),
          ),
        ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF070B12),
            border: Border(
              top: BorderSide(color: Color(0xFF333336), width: 1.2),
            ),
          ),
          child: NavigationBar(
            height: 74,
            selectedIndex: _currentIndex,
            backgroundColor: const Color(0xFF070B12),
            indicatorColor: AppTheme.primaryBlue.withValues(alpha: 0.22),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            onDestinationSelected: (index) {
              if (index == _currentIndex) {
                _navigatorKeys[index].currentState?.popUntil(
                  (route) => route.isFirst,
                );
                return;
              }
              setState(() {
                _currentIndex = index;
              });
            },
            destinations: [
              const NavigationDestination(
                selectedIcon: Icon(Icons.home_rounded, size: 28),
                icon: Icon(Icons.home_outlined, size: 26),
                label: 'Home',
              ),
              NavigationDestination(
                selectedIcon: _TripNavigationIcon(
                  icon: Icons.directions_car_rounded,
                  size: 28,
                  showOngoing: hasOngoingTrip,
                ),
                icon: _TripNavigationIcon(
                  icon: Icons.directions_car_outlined,
                  size: 26,
                  showOngoing: hasOngoingTrip,
                ),
                label: 'Trips',
              ),
              const NavigationDestination(
                selectedIcon: Icon(Icons.receipt_long_rounded, size: 28),
                icon: Icon(Icons.receipt_long_outlined, size: 26),
                label: 'Receipts',
              ),
              const NavigationDestination(
                selectedIcon: Icon(Icons.person_rounded, size: 28),
                icon: Icon(Icons.person_outline_rounded, size: 26),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TripNavigationIcon extends StatefulWidget {
  const _TripNavigationIcon({
    required this.icon,
    required this.size,
    required this.showOngoing,
  });

  final IconData icon;
  final double size;
  final bool showOngoing;

  @override
  State<_TripNavigationIcon> createState() => _TripNavigationIconState();
}

class _TripNavigationIconState extends State<_TripNavigationIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _opacity = Tween<double>(
      begin: 0.25,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant _TripNavigationIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showOngoing != widget.showOngoing) _syncAnimation();
  }

  void _syncAnimation() {
    if (widget.showOngoing) {
      _controller.repeat(reverse: true);
    } else {
      _controller
        ..stop()
        ..value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(widget.icon, size: widget.size),
        if (widget.showOngoing)
          Positioned(
            top: -5,
            right: -7,
            child: FadeTransition(
              opacity: _opacity,
              child: Semantics(
                label: 'Ongoing trip',
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: const Color(0xFF24D17E),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF070B12),
                      width: 2,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x9924D17E),
                        blurRadius: 7,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
