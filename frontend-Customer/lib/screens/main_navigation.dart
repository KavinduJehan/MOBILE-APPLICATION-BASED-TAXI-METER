import 'package:flutter/material.dart';
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

  late final List<Widget> _screens = [
    const HomeTab(),
    const TripsTab(),
    const ReceiptsTab(),
    const ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: const Color(0xFF333336), width: 1),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.black,
          selectedItemColor: AppTheme.primaryBlue,
          unselectedItemColor: const Color(0xFF666666),
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.directions_car),
              label: 'Trips',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long),
              label: 'Receipts',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
