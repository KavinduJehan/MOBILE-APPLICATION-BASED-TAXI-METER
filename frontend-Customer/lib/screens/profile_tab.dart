import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/auth_provider.dart';
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
                  final result = await Navigator.push<SavedPlacesResult>(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          SavedPlacesScreen(addresses: _savedAddresses),
                    ),
                  );
                  if (result != null) {
                    await _saveAddresses(result.addresses);
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
                icon: Icons.groups_outlined,
                title: 'TEAM RideX',
                subtitle: 'Meet our team on LinkedIn',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FollowUsScreen()),
                  );
                },
              ),
              const SizedBox(height: 12),
              _profileMenuItem(
                icon: Icons.feedback_outlined,
                title: 'Send Feedback',
                subtitle: 'Tell us about your RideX experience',
                onTap: _showFeedbackDialog,
              ),
              const SizedBox(height: 32),
              if (auth.isLoggedIn)
                _AnimatedSignOutButton(
                  onPressed: () => _confirmSignOut(context, auth),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showFeedbackDialog() async {
    final feedbackController = TextEditingController();
    int? selectedMood;
    bool showError = false;

    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final hasFeedback = feedbackController.text.trim().isNotEmpty;

          return Dialog(
            backgroundColor: AppTheme.surface,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
              side: const BorderSide(color: AppTheme.border),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Send Feedback',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          icon: const Icon(Icons.close_rounded),
                          color: AppTheme.mutedText,
                          tooltip: 'Close',
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: feedbackController,
                      autofocus: true,
                      minLines: 4,
                      maxLines: 5,
                      maxLength: 500,
                      onChanged: (_) {
                        setDialogState(() => showError = false);
                      },
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Your feedback...',
                        errorText: showError
                            ? 'Please enter your feedback before sending.'
                            : null,
                        filled: true,
                        fillColor: AppTheme.surfaceAlt,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'How was your experience?',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.mutedText,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _FeedbackMoodButton(
                          icon: Icons.sentiment_satisfied_alt_rounded,
                          label: 'Good',
                          selected: selectedMood == 1,
                          onPressed: () {
                            setDialogState(() => selectedMood = 1);
                          },
                        ),
                        const SizedBox(width: 8),
                        _FeedbackMoodButton(
                          icon: Icons.sentiment_dissatisfied_rounded,
                          label: 'Bad',
                          selected: selectedMood == -1,
                          onPressed: () {
                            setDialogState(() => selectedMood = -1);
                          },
                        ),
                        const Spacer(),
                        SizedBox(
                          width: 58,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: () {
                              if (!hasFeedback) {
                                setDialogState(() => showError = true);
                                return;
                              }
                              Navigator.pop(dialogContext, true);
                            },
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(58, 52),
                              padding: EdgeInsets.zero,
                            ),
                            child: const Icon(Icons.send_rounded, size: 23),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    feedbackController.dispose();
    if (!mounted || submitted != true) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Thank you for your feedback!')),
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

class SavedPlacesResult {
  const SavedPlacesResult({required this.addresses, this.selectedAddress});

  final List<SavedAddress> addresses;
  final SavedAddress? selectedAddress;
}

class SavedPlacesScreen extends StatefulWidget {
  final List<SavedAddress> addresses;
  final bool allowSelection;

  const SavedPlacesScreen({
    super.key,
    required this.addresses,
    this.allowSelection = false,
  });

  @override
  State<SavedPlacesScreen> createState() => _SavedPlacesScreenState();
}

class _SavedPlacesScreenState extends State<SavedPlacesScreen> {
  late List<SavedAddress> _addresses;
  bool _canPop = false;

  @override
  void initState() {
    super.initState();
    _addresses = List.of(widget.addresses);
  }

  void _finish([SavedAddress? selectedAddress]) {
    if (_canPop) return;
    final result = SavedPlacesResult(
      addresses: List.unmodifiable(_addresses),
      selectedAddress: selectedAddress,
    );
    setState(() => _canPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context, result);
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _canPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _finish();
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: const Text('Favourites'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _finish,
          ),
          actions: [TextButton(onPressed: _finish, child: const Text('Done'))],
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
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: widget.allowSelection
                          ? () => _finish(address)
                          : null,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF333336)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.place,
                              color: AppTheme.primaryBlue,
                            ),
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
                                    style: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Edit address',
                              icon: const Icon(
                                Icons.edit_outlined,
                                color: Colors.white70,
                              ),
                              onPressed: () => _editAddress(index),
                            ),
                            if (widget.allowSelection)
                              const Icon(
                                Icons.chevron_right,
                                color: AppTheme.primaryBlue,
                              )
                            else
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

  Future<void> _editAddress(int index) async {
    final existing = _addresses[index];
    final labelController = TextEditingController(text: existing.label);
    final addressController = TextEditingController(text: existing.address);
    final updated = await showDialog<SavedAddress>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Edit saved address'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelController,
              decoration: const InputDecoration(labelText: 'Label'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: addressController,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Address'),
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
                SavedAddress(
                  label: label,
                  address: address,
                  lat: address == existing.address ? existing.lat : null,
                  lng: address == existing.address ? existing.lng : null,
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    labelController.dispose();
    addressController.dispose();
    if (updated == null || !mounted) return;
    setState(() => _addresses[index] = updated);
  }
}

class FollowUsScreen extends StatelessWidget {
  const FollowUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Follow Us')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Connect with our team',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Follow the people behind RideX on LinkedIn.',
            style: TextStyle(color: Color(0xFF8A8A8A), fontSize: 14),
          ),
          const SizedBox(height: 24),
          ..._linkedInProfiles.map(
            (profile) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _linkedInCard(context, profile),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _linkedInCard(BuildContext context, LinkedInProfile profile) {
    return InkWell(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${profile.name} LinkedIn link will be added soon'),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF333336)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.14),
              backgroundImage: profile.imageAsset == null
                  ? null
                  : AssetImage(profile.imageAsset!),
              child: profile.imageAsset == null
                  ? const Icon(
                      Icons.person_outline,
                      color: AppTheme.primaryBlue,
                      size: 34,
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    profile.role,
                    style: const TextStyle(
                      color: Color(0xFF8A8A8A),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'View LinkedIn profile',
                    style: TextStyle(
                      color: AppTheme.primaryBlue,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF0A66C2),
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Text(
                'in',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
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
  final double? lat;
  final double? lng;

  const SavedAddress({
    required this.label,
    required this.address,
    this.lat,
    this.lng,
  });

  Map<String, dynamic> toJson() => {
    'label': label,
    'address': address,
    'lat': lat,
    'lng': lng,
  };

  factory SavedAddress.fromJson(Map<String, dynamic> json) {
    return SavedAddress(
      label: json['label'] as String? ?? 'Saved place',
      address: json['address'] as String? ?? '',
      lat: _savedAddressDouble(json['lat']),
      lng: _savedAddressDouble(json['lng']),
    );
  }
}

double? _savedAddressDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

class LinkedInProfile {
  final String name;
  final String role;
  final String? imageAsset;
  final String? url;

  const LinkedInProfile({
    required this.name,
    required this.role,
    this.imageAsset,
    this.url,
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

const _linkedInProfiles = [
  LinkedInProfile(name: 'LinkedIn Profile 1', role: 'RideX team member'),
  LinkedInProfile(name: 'LinkedIn Profile 2', role: 'RideX team member'),
  LinkedInProfile(name: 'LinkedIn Profile 3', role: 'RideX team member'),
  LinkedInProfile(name: 'LinkedIn Profile 4', role: 'RideX team member'),
];

class _FeedbackMoodButton extends StatelessWidget {
  const _FeedbackMoodButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppTheme.primary : AppTheme.mutedText;

    return Semantics(
      button: true,
      selected: selected,
      label: '$label experience',
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.primary.withValues(alpha: 0.16)
                : AppTheme.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppTheme.primary : AppTheme.border,
            ),
          ),
          child: Icon(icon, color: color, size: 25),
        ),
      ),
    );
  }
}

class _AnimatedSignOutButton extends StatefulWidget {
  const _AnimatedSignOutButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_AnimatedSignOutButton> createState() => _AnimatedSignOutButtonState();
}

class _AnimatedSignOutButtonState extends State<_AnimatedSignOutButton> {
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;
  bool _activationPending = false;

  bool get _active => _hovered || _focused || _pressed;

  void _handleTap() {
    if (_activationPending) return;
    _activationPending = true;
    setState(() => _pressed = true);
    Future<void>.delayed(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      setState(() => _pressed = false);
      _activationPending = false;
      widget.onPressed();
    });
  }

  @override
  Widget build(BuildContext context) {
    final active = _active;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: AnimatedScale(
        scale: _pressed ? 0.9 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _handleTap,
            onTapDown: (_) => setState(() => _pressed = true),
            onTapCancel: () => setState(() => _pressed = false),
            onHover: (hovered) => setState(() => _hovered = hovered),
            onFocusChange: (focused) => setState(() => _focused = focused),
            hoverColor: Colors.transparent,
            focusColor: Colors.transparent,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: AppTheme.buttonHeight,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.dangerRed, width: 2),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOut,
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: active ? AppTheme.buttonHeight : 0,
                    child: const ColoredBox(color: AppTheme.dangerRed),
                  ),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOut,
                    style: TextStyle(
                      color: active ? Colors.white : AppTheme.dangerRed,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                    child: const Text('Sign Out'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
