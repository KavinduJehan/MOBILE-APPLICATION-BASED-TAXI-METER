import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'qr_scan.dart';
import 'profile.dart';
import '../providers/auth_provider.dart';
import '../theme.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => QRScan()),
        );
        break;

      case 2:
        // Navigate to Trips page
        break;

      case 3:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const Profile()),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final displayName = auth.customer?.name ?? 'there';

    return Scaffold(
      backgroundColor: AppTheme.background,

      appBar: AppBar(
        title: const Text("RideX"),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(Icons.notifications),
          ),
        ],
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Greeting Card (UNCHANGED)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF001A4D),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.primaryBlue,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hello, $displayName!',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Scan a driver QR or find nearby drivers to start with a verified trip.',
                    style: TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Search Section
            const Text(
              "Where do you want to go?",
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Enter destination",
                hintStyle: const TextStyle(
                  color: Color(0xFF9CA3AF),
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  color: AppTheme.primaryBlue,
                ),
                filled: true,
                fillColor: const Color(0xFF111111),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF242A36),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF242A36),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            Expanded(
              child: Center(
                child: Icon(
                  Icons.location_city,
                  size: 120,
                  color: Colors.grey.shade800,
                ),
              ),
            ),
          ],
        ),
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        backgroundColor: const Color(0xFF111111),
        selectedItemColor: AppTheme.primaryBlue,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: "Home",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.qr_code_scanner),
            label: "QR",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: "Trips",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: "Profile",
          ),
        ],
      ),
    );
  }
}
