import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme.dart';
import '../authentication/auth_screen.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final name = auth.customer?.name ?? 'Guest';
    final phone = auth.customer?.phone ?? '—';

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                // Profile Header
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF1A1A1C),
                          border: Border.all(
                            color: AppTheme.primaryBlue,
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.person,
                          size: 45,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        phone,
                        style: const TextStyle(
                          color: Color(0xFF8A8A8A),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Menu Items
                _profileMenuItem(
                  icon: Icons.edit,
                  title: 'Edit Profile',
                  subtitle: 'Update your information',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Edit profile feature coming soon')),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _profileMenuItem(
                  icon: Icons.favorite,
                  title: 'Saved Places',
                  subtitle: 'Manage your favorite locations',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Saved places feature coming soon')),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _profileMenuItem(
                  icon: Icons.payment,
                  title: 'Payment Methods',
                  subtitle: 'Manage your payment options',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Payment methods feature coming soon')),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _profileMenuItem(
                  icon: Icons.help,
                  title: 'Help & Support',
                  subtitle: 'Get help with your account',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Help & Support feature coming soon')),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _profileMenuItem(
                  icon: Icons.info,
                  title: 'About RideX',
                  subtitle: 'Learn about our app',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('About RideX feature coming soon')),
                    );
                  },
                ),
                const SizedBox(height: 32),

                // Logout Button
                if (auth.isLoggedIn)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign Out'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent.withOpacity(0.2),
                      foregroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: const Color(0xFF0A0A0A),
                          title: const Text(
                            'Sign Out?',
                            style: TextStyle(color: Colors.white),
                          ),
                          content: const Text(
                            'Are you sure you want to sign out?',
                            style: TextStyle(color: Color(0xFF8A8A8A)),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {
                                auth.logout();
                                Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const AuthScreen(),
                                  ),
                                  (_) => false,
                                );
                              },
                              child: const Text(
                                'Sign Out',
                                style: TextStyle(color: Colors.redAccent),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _profileMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1C),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF333336)),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.primaryBlue, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF8A8A8A),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: Color(0xFF666666),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
