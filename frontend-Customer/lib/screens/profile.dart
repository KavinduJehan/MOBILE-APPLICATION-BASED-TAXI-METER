import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/welcome_screen.dart';

class Profile extends StatelessWidget {
  const Profile({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final name = auth.customer?.name ?? 'Guest';
    final phone = auth.customer?.phone ?? '—';

    return Scaffold(
      appBar: AppBar(title: const Text("Profile")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const CircleAvatar(radius: 40, child: Icon(Icons.person, size: 45)),
            const SizedBox(height: 10),
            Text(
              name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(phone),
            const SizedBox(height: 30),
            const Card(
              child: ListTile(
                leading: Icon(Icons.edit),
                title: Text("Edit Profile"),
              ),
            ),
            const Card(
              child: ListTile(
                leading: Icon(Icons.help),
                title: Text("Help & Support"),
              ),
            ),
            const Card(
              child: ListTile(
                leading: Icon(Icons.info),
                title: Text("About Us"),
              ),
            ),
            if (auth.isLoggedIn) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () {
                  auth.logout();
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                    (_) => false,
                  );
                },
                icon: const Icon(Icons.logout, color: Colors.redAccent),
                label: const Text(
                  'Sign Out',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
