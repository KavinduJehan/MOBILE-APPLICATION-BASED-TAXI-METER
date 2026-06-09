import 'package:flutter/material.dart';
import '../services/api_service.dart';

class RateComparison extends StatefulWidget {
  final String? area;
  final double? driverRate;

  const RateComparison({super.key, this.area, this.driverRate});

  @override
  State<RateComparison> createState() => _RateComparisonState();
}

class _RateComparisonState extends State<RateComparison> {
  late Future<Map<String, dynamic>> _ratesFuture;

  @override
  void initState() {
    super.initState();
    if (widget.area != null && widget.area!.isNotEmpty) {
      _ratesFuture = _fetchAreaRates();
    }
  }

  Future<Map<String, dynamic>> _fetchAreaRates() async {
    try {
      final response = await ApiService.getAreaRates(widget.area!);
      final data = response.data as Map<String, dynamic>;
      return data;
    } catch (e) {
      rethrow;
    }
  }

  String _getStatusLabel(double driverRate, double? averageRate) {
    if (averageRate == null) {
      return "No area data";
    }
    
    final difference = driverRate - averageRate;
    if (difference.abs() <= 5) {
      return "Competitive Rate";
    } else if (difference > 0) {
      return "Higher than Average";
    } else {
      return "Lower than Average";
    }
  }

  Color _getStatusColor(double driverRate, double? averageRate) {
    if (averageRate == null) {
      return Colors.grey;
    }
    
    final difference = driverRate - averageRate;
    if (difference.abs() <= 5) {
      return Colors.green;
    } else if (difference > 0) {
      return Colors.orange;
    } else {
      return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Rate Comparison")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: widget.area == null || widget.area!.isEmpty
            ? const Center(
                child: Text("No area information available"),
              )
            : FutureBuilder<Map<String, dynamic>>(
                future: _ratesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("Failed to load area rates"),
                          const SizedBox(height: 10),
                          Text(snapshot.error.toString()),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _ratesFuture = _fetchAreaRates();
                              });
                            },
                            child: const Text("Retry"),
                          ),
                        ],
                      ),
                    );
                  }

                  final data = snapshot.data ?? {};
                  final averageRate = data['averageRate'] as double?;
                  final drivers = (data['drivers'] as List?)?.cast<Map<String, dynamic>>() ?? [];
                  final driverRate = widget.driverRate ?? 0.0;
                  final status = _getStatusLabel(driverRate, averageRate);
                  final statusColor = _getStatusColor(driverRate, averageRate);

                  return SingleChildScrollView(
                    child: Column(
                      children: [
                        Card(
                          child: ListTile(
                            title: const Text("Your Rate"),
                            subtitle: Text("Rs. ${driverRate.toStringAsFixed(0)} / km"),
                            trailing: const Icon(Icons.info),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Card(
                          child: ListTile(
                            title: Text("Average Rate in ${data['area'] ?? widget.area}"),
                            subtitle: Text(
                              averageRate != null
                                  ? "Rs. ${averageRate.toStringAsFixed(2)} / km"
                                  : "No verified drivers in this area",
                            ),
                            trailing: const Icon(Icons.show_chart),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Card(
                          child: ListTile(
                            title: const Text("Status"),
                            trailing: Text(
                              status,
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        if (drivers.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "Verified Drivers in Area",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          ...drivers.map((driver) {
                            final driverName = driver['name'] as String? ?? 'Unknown';
                            final driverRate = driver['ratePerKm'] as num? ?? 0;
                            final vehicleNumber = driver['vehicleNumber'] as String? ?? '—';
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              child: ListTile(
                                title: Text(driverName),
                                subtitle: Text(vehicleNumber),
                                trailing: Text(
                                  "Rs. ${driverRate.toString()} / km",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ],
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
