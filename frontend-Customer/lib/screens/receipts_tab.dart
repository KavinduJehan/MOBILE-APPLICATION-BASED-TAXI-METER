import 'package:flutter/material.dart';
import '../theme.dart';

class ReceiptsTab extends StatelessWidget {
  const ReceiptsTab({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: Replace with actual receipt data from API
    final receipts = [
      {
        'date': 'Today',
        'items': [
          {
            'trip': 'Main Street → Airport',
            'time': '2:30 PM',
            'amount': 'Rs. 450',
            'distance': '12.5 km',
          },
        ],
      },
      {
        'date': 'Yesterday',
        'items': [
          {
            'trip': 'Central Mall → Home',
            'time': '6:15 PM',
            'amount': 'Rs. 280',
            'distance': '8.2 km',
          },
        ],
      },
      {
        'date': 'This Week',
        'items': [
          {
            'trip': 'Office → Train Station',
            'time': '10:00 AM',
            'amount': 'Rs. 200',
            'distance': '5.8 km',
          },
          {
            'trip': 'Hotel → Shopping Center',
            'time': '3:45 PM',
            'amount': 'Rs. 320',
            'distance': '9.1 km',
          },
        ],
      },
    ];

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: receipts.isEmpty
            ? const Center(
                child: Text(
                  'No receipts yet',
                  style: TextStyle(color: Color(0xFF8A8A8A), fontSize: 16),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: receipts.length,
                itemBuilder: (context, dateIndex) {
                  final dateGroup = receipts[dateIndex];
                  final items = dateGroup['items'] as List<dynamic>;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          dateGroup['date']! as String,
                          style: const TextStyle(
                            color: AppTheme.primaryBlue,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      ...List.generate(items.length, (itemIndex) {
                        final item = items[itemIndex] as Map<String, dynamic>;
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
                                  Expanded(
                                    child: Text(
                                      item['trip']! as String,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    item['amount']! as String,
                                    style: const TextStyle(
                                      color: AppTheme.primaryBlue,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    item['time']! as String,
                                    style: const TextStyle(
                                      color: Color(0xFF8A8A8A),
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    item['distance']! as String,
                                    style: const TextStyle(
                                      color: Color(0xFF8A8A8A),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.download, size: 16),
                                  label: const Text('Download Receipt'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1A1A1C),
                                    foregroundColor: AppTheme.primaryBlue,
                                    side: const BorderSide(color: AppTheme.primaryBlue),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                  ),
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Receipt downloaded')),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 20),
                    ],
                  );
                },
              ),
      ),
    );
  }
}
