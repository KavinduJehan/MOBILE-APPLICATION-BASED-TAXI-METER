import 'package:flutter/material.dart';

class Profile extends StatelessWidget {
  const Profile({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Profile")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: const [
            CircleAvatar(
              radius: 40,
              child: Icon(Icons.person, size: 45),
            ),
            SizedBox(height: 10),
            Text(
              "User Name",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text("user@example.com"),
            SizedBox(height: 30),
            Card(child: ListTile(leading: Icon(Icons.edit), title: Text("Edit Profile"))),
            Card(child: ListTile(leading: Icon(Icons.help), title: Text("Help & Support"))),
            Card(child: ListTile(leading: Icon(Icons.info), title: Text("About Us"))),
          ],
        ),
      ),
    );
  }
}