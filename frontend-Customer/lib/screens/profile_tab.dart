import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/trip_model.dart';
import '../providers/auth_provider.dart';
import '../providers/trip_provider.dart';
import '../screens/welcome_screen.dart';
import '../services/api_service.dart';
import '../theme.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  List<SavedAddress> _savedAddresses = const [];
  ProfileDetails _profileDetails = const ProfileDetails();
  bool _loadingProfileData = true;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final auth = context.read<AuthProvider>();
    final prefs = await SharedPreferences.getInstance();
    final keyPrefix = _profileKeyPrefix(auth.customer?.id);
    final savedAddressJson = prefs.getString('${keyPrefix}_saved_addresses');
    final profileJson = prefs.getString('${keyPrefix}_profile_details');
    var savedAddresses = _decodeSavedAddresses(savedAddressJson);

    try {
      final response = await ApiService.getSavedPlaces();
      savedAddresses = _decodeSavedAddressesFromResponse(response.data);
      await prefs.setString(
        '${keyPrefix}_saved_addresses',
        jsonEncode(savedAddresses.map((address) => address.toJson()).toList()),
      );
    } catch (_) {
      // Keep using the local cache when offline or unauthenticated.
    }

    if (!mounted) return;
    final customerDetails = ProfileDetails(
      nameOverride: auth.customer?.name ?? '',
      phoneOverride: auth.customer?.phone ?? '',
      emailOverride: auth.customer?.email ?? '',
      birthday: auth.customer?.birthday ?? '',
      gender: auth.customer?.gender ?? '',
      hasProfilePicture: (auth.customer?.profileImage ?? '').isNotEmpty,
      profileImage: auth.customer?.profileImage ?? '',
    );
    final storedDetails = ProfileDetails.fromJsonString(profileJson);
    setState(() {
      _savedAddresses = savedAddresses;
      _profileDetails = storedDetails.mergeFallback(customerDetails);
      _loadingProfileData = false;
    });
  }

  Future<void> _saveAddresses(List<SavedAddress> addresses) async {
    final customerId = context.read<AuthProvider>().customer?.id;
    final prefs = await SharedPreferences.getInstance();
    final keyPrefix = _profileKeyPrefix(customerId);
    await prefs.setString(
      '${keyPrefix}_saved_addresses',
      jsonEncode(addresses.map((address) => address.toJson()).toList()),
    );

    try {
      final response = await ApiService.updateSavedPlaces(
        addresses.map((address) => address.toJson()).toList(),
      );
      addresses = _decodeSavedAddressesFromResponse(response.data);
      await prefs.setString(
        '${keyPrefix}_saved_addresses',
        jsonEncode(addresses.map((address) => address.toJson()).toList()),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saved locally. Sync failed, try again online.'),
          ),
        );
      }
    }

    if (!mounted) return;
    setState(() => _savedAddresses = addresses);
  }

  Future<void> _saveProfileDetails(ProfileDetails details) async {
    final auth = context.read<AuthProvider>();
    final ok = await auth.updateProfile(
      name: details.nameOverride,
      email: details.emailOverride,
      phone: details.phoneOverride,
      birthday: details.birthday,
      gender: details.gender,
      profileImage: details.profileImage,
    );
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error ?? 'Profile update failed')),
      );
      auth.clearError();
      return;
    }

    final customerId = context.read<AuthProvider>().customer?.id;
    final prefs = await SharedPreferences.getInstance();
    final keyPrefix = _profileKeyPrefix(customerId);
    await prefs.setString(
      '${keyPrefix}_profile_details',
      jsonEncode(details.toJson()),
    );
    if (!mounted) return;
    setState(() => _profileDetails = details);
  }

  String _profileKeyPrefix(String? customerId) =>
      'customer_${customerId ?? 'guest'}';

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final customer = auth.customer;
    final name = _profileDetails.nameOverride.isNotEmpty
        ? _profileDetails.nameOverride
        : customer?.name ?? 'Guest';
    final phone = _profileDetails.phoneOverride.isNotEmpty
        ? _profileDetails.phoneOverride
        : customer?.phone ?? '-';
    final email = _profileDetails.emailOverride.isNotEmpty
        ? _profileDetails.emailOverride
        : customer?.email ?? 'No email added';

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 42,
                      backgroundColor: AppTheme.surface,
                      child: _profileDetails.profileImagePath.isNotEmpty
                          ? ClipOval(
                              child: Image.file(
                                File(_profileDetails.profileImagePath),
                                width: 84,
                                height: 84,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const Icon(
                                  Icons.person,
                                  size: 45,
                                  color: AppTheme.primaryBlue,
                                ),
                              ),
                            )
                          : _profileDetails.profileImage.isNotEmpty
                          ? ClipOval(
                              child: Image.memory(
                                base64Decode(
                                  _profileDetails.profileImage.split(',').last,
                                ),
                                width: 84,
                                height: 84,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const Icon(
                                  Icons.person,
                                  size: 45,
                                  color: AppTheme.primaryBlue,
                                ),
                              ),
                            )
                          : _profileDetails.hasProfilePicture
                          ? Text(
                              _initials(name),
                              style: const TextStyle(
                                color: AppTheme.primaryBlue,
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                              ),
                            )
                          : const Icon(
                              Icons.person,
                              size: 45,
                              color: AppTheme.primaryBlue,
                            ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      name,
                      textAlign: TextAlign.center,
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
              _profileMenuItem(
                icon: Icons.edit,
                title: 'Edit Profile',
                subtitle: 'Photo, name, mobile, email, birthday and gender',
                onTap: () async {
                  final updated = await Navigator.push<ProfileDetails>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditProfileScreen(
                        initialDetails: _profileDetails,
                        initialName: name,
                        initialPhone: phone,
                        initialEmail: email,
                      ),
                    ),
                  );
                  if (updated != null) {
                    await _saveProfileDetails(updated);
                  }
                },
              ),
              const SizedBox(height: 12),
              _profileMenuItem(
                icon: Icons.favorite,
                title: 'Saved Places',
                subtitle: _loadingProfileData
                    ? 'Loading saved addresses'
                    : '${_savedAddresses.length} saved address${_savedAddresses.length == 1 ? '' : 'es'}',
                onTap: () async {
                  final updated = await Navigator.push<List<SavedAddress>>(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          SavedPlacesScreen(addresses: _savedAddresses),
                    ),
                  );
                  if (updated != null) {
                    await _saveAddresses(updated);
                  }
                },
              ),
              const SizedBox(height: 12),
              _profileMenuItem(
                icon: Icons.payment,
                title: 'Payment Methods',
                subtitle: 'Manage your payment options',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Payment methods feature coming soon'),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              _profileMenuItem(
                icon: Icons.help,
                title: 'Help & Support',
                subtitle: 'Recent activities and support topics',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const HelpSupportScreen(),
                    ),
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
                    const SnackBar(
                      content: Text('RideX taxi meter customer app'),
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),
              if (auth.isLoggedIn)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(
                      255,
                      126,
                      122,
                      161,
                    ).withValues(alpha: 0.2),
                    foregroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => _confirmSignOut(context, auth),
                  child: const Text('Sign Out'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmSignOut(BuildContext context, AuthProvider auth) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0A0A0A),
        title: const Text('Sign Out?', style: TextStyle(color: Colors.white)),
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
              Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const WelcomeScreen()),
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
  }

  Widget _profileMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
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

class EditProfileScreen extends StatefulWidget {
  final ProfileDetails initialDetails;
  final String initialName;
  final String initialPhone;
  final String initialEmail;

  const EditProfileScreen({
    super.key,
    required this.initialDetails,
    required this.initialName,
    required this.initialPhone,
    required this.initialEmail,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late ProfileDetails _details;

  @override
  void initState() {
    super.initState();
    _details = widget.initialDetails.copyWith(
      nameOverride: widget.initialDetails.nameOverride.isEmpty
          ? widget.initialName
          : widget.initialDetails.nameOverride,
      phoneOverride: widget.initialDetails.phoneOverride.isEmpty
          ? widget.initialPhone
          : widget.initialDetails.phoneOverride,
      emailOverride: widget.initialDetails.emailOverride.isEmpty
          ? widget.initialEmail
          : widget.initialDetails.emailOverride,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Your information'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _details),
            child: const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Center(
            child: InkWell(
              borderRadius: BorderRadius.circular(56),
              onTap: _showProfilePictureOptions,
              child: _profileImagePreview(56),
            ),
          ),
          const SizedBox(height: 18),
          _infoTile(
            icon: Icons.person_add_alt_1,
            title: 'Add profile picture',
            value: _details.profileImagePath.isNotEmpty
                ? 'Profile picture added'
                : 'Tap to add',
            trailing: _details.profileImagePath.isNotEmpty
                ? Icons.check_circle
                : Icons.add_a_photo,
            onTap: _showProfilePictureOptions,
          ),
          _infoTile(
            icon: Icons.badge_outlined,
            title: 'Name',
            value: _details.nameOverride,
            onTap: () => _editText('Name', _details.nameOverride, (value) {
              _details = _details.copyWith(nameOverride: value);
            }),
          ),
          _infoTile(
            icon: Icons.phone_iphone,
            title: 'Mobile',
            value: _details.phoneOverride,
            onTap: () => _editText('Mobile', _details.phoneOverride, (value) {
              _details = _details.copyWith(phoneOverride: value);
            }, keyboardType: TextInputType.phone),
          ),
          _infoTile(
            icon: Icons.mail_outline,
            title: 'E-mail',
            value: _details.emailOverride,
            badge: _details.emailVerified ? 'Verified' : 'Unverified',
            onTap: () => _editText(
              'E-mail',
              _details.emailOverride,
              (value) {
                _details = _details.copyWith(
                  emailOverride: value,
                  emailVerified: false,
                );
              },
              keyboardType: TextInputType.emailAddress,
            ),
          ),
          _infoTile(
            icon: Icons.cake_outlined,
            title: 'Birthday',
            value: _details.birthday.isEmpty
                ? 'Add your birthday'
                : _details.birthday,
            onTap: _pickBirthday,
          ),
          _infoTile(
            icon: Icons.wc,
            title: 'Gender',
            value: _details.gender.isEmpty
                ? 'Add your gender'
                : _details.gender,
            onTap: _pickGender,
          ),
        ],
      ),
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
    IconData? trailing,
    String? badge,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFF2B3342))),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white70, size: 28),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: Color(0xFF9A9A9A),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (badge != null)
                        Text(
                          badge,
                          style: TextStyle(
                            color: badge == 'Verified'
                                ? AppTheme.successGreen
                                : Colors.redAccent,
                            fontSize: 14,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(trailing ?? Icons.chevron_right, color: Colors.white38),
          ],
        ),
      ),
    );
  }

  Widget _profileImagePreview(double radius) {
    final size = radius * 2;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.primaryBlue, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: _details.profileImagePath.isEmpty
          ? _details.profileImage.isEmpty
                ? const Icon(
                    Icons.person,
                    color: AppTheme.primaryBlue,
                    size: 54,
                  )
                : Image.memory(
                    base64Decode(_details.profileImage.split(',').last),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.person,
                      color: AppTheme.primaryBlue,
                      size: 54,
                    ),
                  )
          : Image.file(
              File(_details.profileImagePath),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Icon(
                Icons.person,
                color: AppTheme.primaryBlue,
                size: 54,
              ),
            ),
    );
  }

  Future<void> _showProfilePictureOptions() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.photo_camera,
                color: AppTheme.primaryBlue,
              ),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library,
                color: AppTheme.primaryBlue,
              ),
              title: const Text('Select from photos'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.close, color: Colors.white70),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    await _pickProfileImage(source);
  }

  Future<void> _pickProfileImage(ImageSource source) async {
    try {
      final image = await ImagePicker().pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1200,
      );
      if (image == null || !mounted) return;
      final bytes = await File(image.path).readAsBytes();
      final encodedImage = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      setState(() {
        _details = _details.copyWith(
          profileImagePath: image.path,
          profileImage: encodedImage,
          hasProfilePicture: true,
        );
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open photos or camera')),
      );
    }
  }

  Future<void> _editText(
    String label,
    String initialValue,
    ValueChanged<String> onSaved, {
    TextInputType keyboardType = TextInputType.text,
  }) async {
    final controller = TextEditingController(text: initialValue);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('Edit $label'),
        content: TextField(
          controller: controller,
          keyboardType: keyboardType,
          autofocus: true,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.isEmpty) return;
    setState(() => onSaved(value));
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 20, now.month, now.day),
      firstDate: DateTime(1920),
      lastDate: now,
    );
    if (picked == null) return;
    setState(() {
      _details = _details.copyWith(
        birthday:
            '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}',
      );
    });
  }

  Future<void> _pickGender() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.surface,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _genderOption('Female'),
            _genderOption('Male'),
            _genderOption('Prefer not to say'),
          ],
        ),
      ),
    );
    if (selected == null) return;
    setState(() => _details = _details.copyWith(gender: selected));
  }

  Widget _genderOption(String label) {
    return ListTile(
      title: Text(label),
      onTap: () => Navigator.pop(context, label),
    );
  }
}

class SavedPlacesScreen extends StatefulWidget {
  final List<SavedAddress> addresses;

  const SavedPlacesScreen({super.key, required this.addresses});

  @override
  State<SavedPlacesScreen> createState() => _SavedPlacesScreenState();
}

class _SavedPlacesScreenState extends State<SavedPlacesScreen> {
  late List<SavedAddress> _addresses;

  @override
  void initState() {
    super.initState();
    _addresses = List.of(widget.addresses);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.pop(context, _addresses);
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: const Text('Saved Places'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context, _addresses),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, _addresses),
              child: const Text('Done'),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _addAddress,
          icon: const Icon(Icons.add_location_alt),
          label: const Text('Add address'),
        ),
        body: _addresses.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: Text(
                    'No saved addresses yet. Add home, work, or any place you visit often.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
                itemBuilder: (context, index) {
                  final address = _addresses[index];
                  return Dismissible(
                    key: ValueKey('${address.label}_${address.address}_$index'),
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      color: Colors.redAccent,
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    direction: DismissDirection.endToStart,
                    onDismissed: (_) =>
                        setState(() => _addresses.removeAt(index)),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF333336)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.place, color: AppTheme.primaryBlue),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  address.label,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  address.address,
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Delete address',
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.redAccent,
                            ),
                            onPressed: () =>
                                setState(() => _addresses.removeAt(index)),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemCount: _addresses.length,
              ),
      ),
    );
  }

  Future<void> _addAddress() async {
    final labelController = TextEditingController();
    final addressController = TextEditingController();
    final address = await showDialog<SavedAddress>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Add saved address'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelController,
              decoration: const InputDecoration(
                labelText: 'Label',
                hintText: 'Home',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: addressController,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Address',
                hintText: 'Street, city',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final label = labelController.text.trim();
              final address = addressController.text.trim();
              if (label.isEmpty || address.isEmpty) return;
              Navigator.pop(
                context,
                SavedAddress(label: label, address: address),
              );
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    labelController.dispose();
    addressController.dispose();
    if (address == null) return;
    setState(() => _addresses = [..._addresses, address]);
  }
}

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final trips = context.watch<TripProvider>().trips.take(5).toList();
    final activities = trips.isEmpty
        ? _fallbackActivities
        : trips.map(_activityFromTrip).toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Help & Support')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Last 5 activities',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ...activities.map(
            (activity) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _supportCard(
                icon: activity.icon,
                title: activity.title,
                subtitle: activity.subtitle,
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Other topics',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          _supportTopic(context, Icons.receipt_long, 'Trip and receipt help'),
          _supportTopic(context, Icons.account_circle_outlined, 'Account help'),
          _supportTopic(context, Icons.bug_report_outlined, 'App issues'),
        ],
      ),
    );
  }

  static SupportActivity _activityFromTrip(TripModel trip) {
    return SupportActivity(
      icon: Icons.local_taxi,
      title: trip.status.isEmpty ? 'Taxi trip' : 'Trip ${trip.status}',
      subtitle: '${trip.pickupLocation} to ${trip.dropLocation}',
    );
  }

  static Widget _supportTopic(
    BuildContext context,
    IconData icon,
    String title,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _supportCard(
        icon: icon,
        title: title,
        subtitle: 'Tap to contact support about $title',
        onTap: () {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('$title support selected')));
        },
      ),
    );
  }

  static Widget _supportCard({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF333336)),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.primaryBlue),
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
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(Icons.chevron_right, color: Colors.white38),
          ],
        ),
      ),
    );
  }
}

class ProfileDetails {
  final String nameOverride;
  final String phoneOverride;
  final String emailOverride;
  final bool emailVerified;
  final String birthday;
  final String gender;
  final bool hasProfilePicture;
  final String profileImagePath;
  final String profileImage;

  const ProfileDetails({
    this.nameOverride = '',
    this.phoneOverride = '',
    this.emailOverride = '',
    this.emailVerified = false,
    this.birthday = '',
    this.gender = '',
    this.hasProfilePicture = false,
    this.profileImagePath = '',
    this.profileImage = '',
  });

  ProfileDetails copyWith({
    String? nameOverride,
    String? phoneOverride,
    String? emailOverride,
    bool? emailVerified,
    String? birthday,
    String? gender,
    bool? hasProfilePicture,
    String? profileImagePath,
    String? profileImage,
  }) {
    return ProfileDetails(
      nameOverride: nameOverride ?? this.nameOverride,
      phoneOverride: phoneOverride ?? this.phoneOverride,
      emailOverride: emailOverride ?? this.emailOverride,
      emailVerified: emailVerified ?? this.emailVerified,
      birthday: birthday ?? this.birthday,
      gender: gender ?? this.gender,
      hasProfilePicture: hasProfilePicture ?? this.hasProfilePicture,
      profileImagePath: profileImagePath ?? this.profileImagePath,
      profileImage: profileImage ?? this.profileImage,
    );
  }

  ProfileDetails mergeFallback(ProfileDetails fallback) {
    return ProfileDetails(
      nameOverride: nameOverride.isNotEmpty
          ? nameOverride
          : fallback.nameOverride,
      phoneOverride: phoneOverride.isNotEmpty
          ? phoneOverride
          : fallback.phoneOverride,
      emailOverride: emailOverride.isNotEmpty
          ? emailOverride
          : fallback.emailOverride,
      emailVerified: emailVerified,
      birthday: birthday.isNotEmpty ? birthday : fallback.birthday,
      gender: gender.isNotEmpty ? gender : fallback.gender,
      hasProfilePicture: hasProfilePicture || fallback.hasProfilePicture,
      profileImagePath: profileImagePath,
      profileImage: profileImage.isNotEmpty
          ? profileImage
          : fallback.profileImage,
    );
  }

  Map<String, dynamic> toJson() => {
    'nameOverride': nameOverride,
    'phoneOverride': phoneOverride,
    'emailOverride': emailOverride,
    'emailVerified': emailVerified,
    'birthday': birthday,
    'gender': gender,
    'hasProfilePicture': hasProfilePicture,
    'profileImagePath': profileImagePath,
    'profileImage': profileImage,
  };

  factory ProfileDetails.fromJsonString(String? source) {
    if (source == null || source.isEmpty) return const ProfileDetails();
    try {
      final json = jsonDecode(source) as Map<String, dynamic>;
      return ProfileDetails(
        nameOverride: json['nameOverride'] as String? ?? '',
        phoneOverride: json['phoneOverride'] as String? ?? '',
        emailOverride: json['emailOverride'] as String? ?? '',
        emailVerified: json['emailVerified'] as bool? ?? false,
        birthday: json['birthday'] as String? ?? '',
        gender: json['gender'] as String? ?? '',
        hasProfilePicture: json['hasProfilePicture'] as bool? ?? false,
        profileImagePath: json['profileImagePath'] as String? ?? '',
        profileImage: json['profileImage'] as String? ?? '',
      );
    } catch (_) {
      return const ProfileDetails();
    }
  }
}

class SavedAddress {
  final String label;
  final String address;

  const SavedAddress({required this.label, required this.address});

  Map<String, dynamic> toJson() => {'label': label, 'address': address};

  factory SavedAddress.fromJson(Map<String, dynamic> json) {
    return SavedAddress(
      label: json['label'] as String? ?? 'Saved place',
      address: json['address'] as String? ?? '',
    );
  }
}

class SupportActivity {
  final IconData icon;
  final String title;
  final String subtitle;

  const SupportActivity({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}

List<SavedAddress> _decodeSavedAddresses(String? source) {
  if (source == null || source.isEmpty) return const [];
  try {
    final list = jsonDecode(source) as List<dynamic>;
    return list
        .whereType<Map>()
        .map((json) => SavedAddress.fromJson(Map<String, dynamic>.from(json)))
        .where((address) => address.address.isNotEmpty)
        .toList();
  } catch (_) {
    return const [];
  }
}

List<SavedAddress> _decodeSavedAddressesFromResponse(Object? data) {
  Object? listSource;
  if (data is Map) {
    listSource = data['savedPlaces'] ?? data['data'];
  } else {
    listSource = data;
  }
  if (listSource is! List) return const [];
  return listSource
      .whereType<Map>()
      .map((json) => SavedAddress.fromJson(Map<String, dynamic>.from(json)))
      .where((address) => address.address.isNotEmpty)
      .toList();
}

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty);
  if (parts.isEmpty) return 'U';
  return parts.take(2).map((part) => part[0].toUpperCase()).join();
}

const _fallbackActivities = [
  SupportActivity(
    icon: Icons.login,
    title: 'Signed in to RideX',
    subtitle: 'Your customer account is active on this device',
  ),
  SupportActivity(
    icon: Icons.search,
    title: 'Browsed nearby drivers',
    subtitle: 'Checked drivers around your current area',
  ),
  SupportActivity(
    icon: Icons.compare_arrows,
    title: 'Viewed rate comparison',
    subtitle: 'Compared available taxi meter rates',
  ),
  SupportActivity(
    icon: Icons.qr_code_scanner,
    title: 'Opened QR scanner',
    subtitle: 'Ready to scan a taxi meter QR code',
  ),
  SupportActivity(
    icon: Icons.person,
    title: 'Opened profile',
    subtitle: 'Managed customer information and saved places',
  ),
];
