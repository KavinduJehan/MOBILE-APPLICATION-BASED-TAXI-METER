import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'qr_scan.dart';
import 'profile.dart';
import '../providers/auth_provider.dart';
import '../theme.dart';

class Home extends StatelessWidget {
  const Home({super.key});

  Widget menuCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      color: const Color(0xFF111111),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFF242A36)),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: AppTheme.primaryBlue, size: 32),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: Color(0xFF9CA3AF)),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          color: Color(0xFF64748B),
          size: 18,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final displayName = auth.customer?.name ?? 'there';

    return Scaffold(
      backgroundColor: Colors.black,
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF0B1220),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF1D4ED8)),
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
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            menuCard(
              icon: Icons.qr_code_scanner,
              title: "Scan Driver QR",
              subtitle: "Scan driver QR code",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => QRScan()),
                );
              },
            ),
            menuCard(
              icon: Icons.search,
              title: "Search Nearby Drivers",
              subtitle: "Find available drivers near you",
              onTap: () {},
            ),
            menuCard(
              icon: Icons.receipt_long,
              title: "My Trips",
              subtitle: "View your trip history",
              onTap: () {},
            ),
            menuCard(
              icon: Icons.person,
              title: "Profile",
              subtitle: "Manage your profile",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const Profile()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
