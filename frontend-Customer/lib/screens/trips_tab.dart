import 'package:flutter/material.dart';
import '../theme.dart';

class TripsTab extends StatelessWidget {
  const TripsTab({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: Replace with actual trip data from API
    final trips = [
      {
        'id': '1',
        'driver': 'M.A Kumara',
        'date': 'Today at 2:30 PM',
        'from': 'Galedanda Road,Gonawala',
        'to': 'Kelaniya Raja Maha Vihara',
        'distance': '2.5 km',
        'amount': 'Rs. 450',
        'status': 'Completed',
      },
      {
        'id': '2',
        'driver': 'Anura Kumara',
        'date': 'Yesterday at 6:15 PM',
        'from': 'Colombo City Centre',
        'to': 'Home',
        'distance': '16.2 km',
        'amount': 'Rs. 2800',
        'status': 'Completed',
      },
      {
        'id': '3',
        'driver': 'Janana Perera',
        'date': '2 days ago at 10:00 AM',
        'from': 'Office',
        'to': 'Colombo fort Train Station',
        'distance': '5.8 km',
        'amount': 'Rs. 675',
        'status': 'Completed',
      },
    ];

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: trips.isEmpty
            ? const Center(
                child: Text(
                  'No trips yet',
                  style: TextStyle(color: Color(0xFF8A8A8A), fontSize: 16),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: trips.length,
                itemBuilder: (context, index) {
                  final trip = trips[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1C),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF333336)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  trip['driver']!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  trip['date']!,
                                  style: const TextStyle(
                                    color: Color(0xFF8A8A8A),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'Completed',
                                style: TextStyle(
                                  color: Color(0xFF10B981),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.location_on, color: AppTheme.primaryBlue, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${trip['from']} → ${trip['to']}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${trip['distance']}',
                              style: const TextStyle(
                                color: Color(0xFF8A8A8A),
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              trip['amount']!,
                              style: const TextStyle(
                                color: AppTheme.primaryBlue,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
