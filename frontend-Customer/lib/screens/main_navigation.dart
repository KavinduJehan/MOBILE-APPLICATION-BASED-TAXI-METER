import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import 'home_tab.dart';
import 'trips_tab.dart';
import 'receipts_tab.dart';
import 'profile_tab.dart';

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
  Widget build(BuildContext context) {
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
              onGenerateRoute: (_) => MaterialPageRoute(
                builder: (_) => _screens[index],
              ),
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
                _navigatorKeys[index]
                    .currentState
                    ?.popUntil((route) => route.isFirst);
                return;
              }
              setState(() {
                _currentIndex = index;
              });
            },
            destinations: const [
              NavigationDestination(
                selectedIcon: Icon(Icons.home_rounded, size: 28),
                icon: Icon(Icons.home_outlined, size: 26),
                label: 'Home',
              ),
              NavigationDestination(
                selectedIcon: Icon(Icons.directions_car_rounded, size: 28),
                icon: Icon(Icons.directions_car_outlined, size: 26),
                label: 'Trips',
              ),
              NavigationDestination(
                selectedIcon: Icon(Icons.receipt_long_rounded, size: 28),
                icon: Icon(Icons.receipt_long_outlined, size: 26),
                label: 'Receipts',
              ),
              NavigationDestination(
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
