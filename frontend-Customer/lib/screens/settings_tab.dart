import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme.dart';
import 'profile_tab.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  List<SavedAddress> _savedAddresses = const [];
  bool _loadingSavedPlaces = true;

  @override
  void initState() {
    super.initState();
    _loadSavedPlaces();
  }

  String get _savedPlacesCacheKey {
    final customerId = context.read<AuthProvider>().customer?.id ?? 'guest';
    return 'customer_${customerId}_saved_addresses';
  }

  Future<void> _loadSavedPlaces() async {
    final cacheKey = _savedPlacesCacheKey;
    final prefs = await SharedPreferences.getInstance();
    final cached = _decodeSavedAddresses(prefs.getString(cacheKey));
    if (mounted && cached.isNotEmpty) {
      setState(() => _savedAddresses = cached);
    }

    try {
      final response = await ApiService.getSavedPlaces();
      final addresses = _decodeSavedAddressesFromResponse(response.data);
      await prefs.setString(
        cacheKey,
        jsonEncode(addresses.map((address) => address.toJson()).toList()),
      );
      if (mounted) setState(() => _savedAddresses = addresses);
    } catch (_) {
      // Keep the customer's local saved places when offline.
    } finally {
      if (mounted) setState(() => _loadingSavedPlaces = false);
    }
  }

  Future<void> _openSavedPlaces() async {
    final result = await Navigator.push<SavedPlacesResult>(
      context,
      MaterialPageRoute(
        builder: (_) => SavedPlacesScreen(addresses: _savedAddresses),
      ),
    );
    if (result == null || !mounted) return;
    await _saveSavedPlaces(result.addresses);
  }

  Future<void> _saveSavedPlaces(List<SavedAddress> addresses) async {
    final cacheKey = _savedPlacesCacheKey;
    final prefs = await SharedPreferences.getInstance();
    setState(() => _savedAddresses = addresses);
    await prefs.setString(
      cacheKey,
      jsonEncode(addresses.map((address) => address.toJson()).toList()),
    );

    try {
      final response = await ApiService.updateSavedPlaces(
        addresses.map((address) => address.toJson()).toList(),
      );
      final synced = _decodeSavedAddressesFromResponse(response.data);
      await prefs.setString(
        cacheKey,
        jsonEncode(synced.map((address) => address.toJson()).toList()),
      );
      if (mounted) setState(() => _savedAddresses = synced);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saved locally. Sync failed, try again online.'),
        ),
      );
    }
  }

  Future<void> _showFeedbackDialog() async {
    final feedback = await showDialog<String>(
      context: context,
      builder: (_) => const _FeedbackDialog(),
    );
    if (!mounted || feedback == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Thank you for your feedback!')),
    );
  }

  void _openAboutUs() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FollowUsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final savedPlacesSubtitle = _loadingSavedPlaces
        ? 'Loading saved places...'
        : '${_savedAddresses.length} saved place${_savedAddresses.length == 1 ? '' : 's'}';

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 64,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppTheme.border)),
              ),
              child: const Text(
                'Settings',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _SettingsTile(
                    icon: Icons.favorite_outline_rounded,
                    title: 'Saved Places',
                    subtitle: savedPlacesSubtitle,
                    onTap: _loadingSavedPlaces ? null : _openSavedPlaces,
                  ),
                  const SizedBox(height: 12),
                  _SettingsTile(
                    icon: Icons.feedback_outlined,
                    title: 'Send Feedback',
                    subtitle: 'Tell us about your RideX experience',
                    onTap: _showFeedbackDialog,
                  ),
                  const SizedBox(height: 12),
                  _SettingsTile(
                    icon: Icons.groups_outlined,
                    title: 'About Us',
                    subtitle: 'Meet Team RideX on LinkedIn',
                    onTap: _openAboutUs,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedbackDialog extends StatefulWidget {
  const _FeedbackDialog();

  @override
  State<_FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<_FeedbackDialog> {
  final _controller = TextEditingController();
  bool _showError = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final feedback = _controller.text.trim();
    if (feedback.isEmpty) {
      setState(() => _showError = true);
      return;
    }
    Navigator.pop(context, feedback);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      title: const Text('Send Feedback'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        minLines: 4,
        maxLines: 6,
        maxLength: 500,
        onChanged: (_) {
          if (_showError) setState(() => _showError = false);
        },
        decoration: InputDecoration(
          hintText: 'Tell us about your RideX experience...',
          errorText: _showError ? 'Please enter your feedback.' : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(minimumSize: const Size(96, 44)),
          child: const Text('SEND'),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppTheme.accent, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppTheme.mutedText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.mutedText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

List<SavedAddress> _decodeSavedAddresses(String? source) {
  if (source == null || source.isEmpty) return const [];
  try {
    final decoded = jsonDecode(source);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((item) => SavedAddress.fromJson(Map<String, dynamic>.from(item)))
        .where((address) => address.address.isNotEmpty)
        .toList();
  } catch (_) {
    return const [];
  }
}

List<SavedAddress> _decodeSavedAddressesFromResponse(Object? data) {
  final source = data is Map ? data['savedPlaces'] ?? data['data'] : data;
  if (source is! List) return const [];
  return source
      .whereType<Map>()
      .map((item) => SavedAddress.fromJson(Map<String, dynamic>.from(item)))
      .where((address) => address.address.isNotEmpty)
      .toList();
}
