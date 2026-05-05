import 'package:flutter/material.dart';

class NegotiateScreen extends StatelessWidget {
  const NegotiateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final offerController = TextEditingController();

    return Scaffold(
      appBar: AppBar(title: const Text("Negotiate Rate")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text("Driver Rate: Rs. 150 / km"),
            const SizedBox(height: 20),
            TextField(
              controller: offerController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Your Offer",
                prefixText: "Rs. ",
                suffixText: "/ km",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              child: const Text("Send Offer"),
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }
}