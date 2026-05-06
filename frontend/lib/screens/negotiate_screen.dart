import 'package:flutter/material.dart';

class NegotiateScreen extends StatefulWidget {
  final Map<String, dynamic> driver;

  const NegotiateScreen({super.key, required this.driver});

  @override
  State<NegotiateScreen> createState() => _NegotiateScreenState();
}

class _NegotiateScreenState extends State<NegotiateScreen> {
  final _offerController = TextEditingController();
  String? _validationError;

  double get _driverRate =>
      (widget.driver['ratePerKm'] as num?)?.toDouble() ?? 0.0;

  @override
  void dispose() {
    _offerController.dispose();
    super.dispose();
  }

  void _sendOffer() {
    final text = _offerController.text.trim();
    final value = double.tryParse(text);

    if (value == null || value <= 0) {
      setState(() => _validationError = 'Enter a valid rate greater than 0.');
      return;
    }
    if (value >= _driverRate) {
      setState(
        () => _validationError =
            'Your offer must be less than the driver rate (Rs. ${_driverRate.toStringAsFixed(0)}).',
      );
      return;
    }

    // Return the negotiated rate to DriverVerificationScreen
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Negotiate Rate')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Driver's Rate", style: TextStyle(fontSize: 16)),
                    Text(
                      'Rs. ${_driverRate.toStringAsFixed(0)} / km',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _offerController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => setState(() => _validationError = null),
              decoration: InputDecoration(
                labelText: 'Your Offer (Rs. / km)',
                prefixText: 'Rs. ',
                suffixText: '/ km',
                border: const OutlineInputBorder(),
                errorText: _validationError,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Enter a rate lower than the driver\'s rate to negotiate.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _sendOffer,
              child: const Text('Send Offer'),
            ),
          ],
        ),
      ),
    );
  }
}
