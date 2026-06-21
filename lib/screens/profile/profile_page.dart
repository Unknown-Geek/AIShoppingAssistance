import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'widgets/profile_header_pill.dart';
import 'widgets/profile_info_card.dart';
import 'widgets/profile_settings_menu.dart';
import 'widgets/saved_cards_sheet.dart';
import 'past_orders_page.dart';
import 'invite_friends_page.dart';

class ProfilePage extends StatefulWidget {
  final String name;
  final String email;
  final VoidCallback onLogout;

  const ProfilePage({
    super.key,
    required this.name,
    required this.email,
    required this.onLogout,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String? _profilePicBase64;
  late String _displayName;

  @override
  void initState() {
    super.initState();
    _displayName = widget.name;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted) {
          _loadProfilePic();
        }
      });
    });
  }

  Future<void> _loadProfilePic() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('profile_pic_${widget.email}');
      if (saved != null && saved.isNotEmpty) {
        setState(() {
          _profilePicBase64 = saved;
        });
      }
    } catch (e) {
      debugPrint('Error loading profile pic: $e');
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: source,
        maxWidth: 200,
        maxHeight: 200,
        imageQuality: 70,
      );

      if (image == null) return;

      final bytes = await image.readAsBytes();
      final base64String = base64Encode(bytes);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profile_pic_${widget.email}', base64String);

      setState(() {
        _profilePicBase64 = base64String;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile picture updated successfully!'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            behavior: SnackBarBehavior.fixed,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to pick image.'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.fixed,
          ),
        );
      }
    }
  }

  Future<void> _removeImage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('profile_pic_${widget.email}');

      setState(() {
        _profilePicBase64 = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile picture removed.'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            behavior: SnackBarBehavior.fixed,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error removing image: $e');
    }
  }

  Future<void> _showPickImageOptions() async {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Profile Photo',
                style: TextStyle(
                  fontFamily: theme.textTheme.titleLarge?.fontFamily,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF001A23),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 8,
                ),
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE8F1F2),
                  child: Icon(
                    Icons.photo_library_rounded,
                    color: Color(0xFF001A23),
                  ),
                ),
                title: const Text(
                  'Choose Image from Gallery',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF001A23),
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 8,
                ),
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE8F1F2),
                  child: Icon(
                    Icons.camera_alt_rounded,
                    color: Color(0xFF001A23),
                  ),
                ),
                title: const Text(
                  'Take Photo with Camera',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF001A23),
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              if (_profilePicBase64 != null) ...[
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 8,
                  ),
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFFEBEE),
                    child: Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.redAccent,
                    ),
                  ),
                  title: const Text(
                    'Remove Current Photo',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.redAccent,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _removeImage();
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showSavedCardsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const SavedCardsSheet(),
    );
  }

  void _showManageProfileSheet() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Manage Profile',
                style: TextStyle(
                  fontFamily: theme.textTheme.titleLarge?.fontFamily,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF001A23),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 8,
                ),
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE8F1F2),
                  child: Icon(
                    Icons.badge_outlined,
                    color: Color(0xFF001A23),
                  ),
                ),
                title: const Text(
                  'Edit Display Name',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF001A23),
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showEditNameDialog();
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 8,
                ),
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE8F1F2),
                  child: Icon(
                    Icons.photo_camera_outlined,
                    color: Color(0xFF001A23),
                  ),
                ),
                title: const Text(
                  'Change Profile Photo',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF001A23),
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showPickImageOptions();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showChangePasswordDialog() async {
    final theme = Theme.of(context);
    final controller = TextEditingController();
    final confirmController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setModalState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: Text(
            'Change Password',
            style: TextStyle(
              fontFamily: theme.textTheme.titleLarge?.fontFamily,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
              fontSize: 20,
            ),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: controller,
                  obscureText: true,
                  enabled: !saving,
                  style: TextStyle(
                    fontFamily: theme.textTheme.bodyMedium?.fontFamily,
                    color: theme.colorScheme.primary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'New Password',
                    filled: true,
                    fillColor: const Color(0xFFF3F4F6),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  validator: (val) {
                    if (val == null || val.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: confirmController,
                  obscureText: true,
                  enabled: !saving,
                  style: TextStyle(
                    fontFamily: theme.textTheme.bodyMedium?.fontFamily,
                    color: theme.colorScheme.primary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Confirm Password',
                    filled: true,
                    fillColor: const Color(0xFFF3F4F6),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  validator: (val) {
                    if (val != controller.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: theme.colorScheme.primary.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      final newPassword = controller.text.trim();

                      setModalState(() => saving = true);

                      try {
                        await Supabase.instance.client.auth.updateUser(
                          UserAttributes(password: newPassword),
                        );

                        if (!mounted) return;

                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Password updated successfully!'),
                            backgroundColor: theme.colorScheme.primary,
                            behavior: SnackBarBehavior.fixed,
                          ),
                        );
                      } catch (e) {
                        debugPrint('Error updating password: $e');
                        setModalState(() => saving = false);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Failed to update password.'),
                            backgroundColor: Colors.redAccent,
                            behavior: SnackBarBehavior.fixed,
                          ),
                        );
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Text(
                      'Save',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditNameDialog() async {
    final theme = Theme.of(context);
    final controller = TextEditingController(text: _displayName);
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setModalState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: Text(
            'Edit Name',
            style: TextStyle(
              fontFamily: theme.textTheme.titleLarge?.fontFamily,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
              fontSize: 20,
            ),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            enabled: !saving,
            style: TextStyle(
              fontFamily: theme.textTheme.bodyMedium?.fontFamily,
              color: theme.colorScheme.primary,
            ),
            decoration: InputDecoration(
              hintText: 'Enter your name',
              filled: true,
              fillColor: const Color(0xFFF3F4F6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: theme.colorScheme.primary.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              onPressed: saving
                  ? null
                  : () async {
                      final newName = controller.text.trim();
                      if (newName.isEmpty) return;

                      setModalState(() => saving = true);

                      try {
                        await Supabase.instance.client.auth.updateUser(
                          UserAttributes(data: {'name': newName}),
                        );

                        if (!mounted) return;

                        setState(() {
                          _displayName = newName;
                        });

                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Name updated successfully!'),
                            backgroundColor: theme.colorScheme.primary,
                            behavior: SnackBarBehavior.fixed,
                          ),
                        );
                      } catch (e) {
                        debugPrint('Error updating name: $e');
                        setModalState(() => saving = false);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Failed to update name.'),
                            backgroundColor: Colors.redAccent,
                            behavior: SnackBarBehavior.fixed,
                          ),
                        );
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Text(
                      'Save',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInviteFriendsCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 80,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFFF472B6), Color(0xFFFF8F60)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF472B6).withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const InviteFriendsPage(),
                ),
              );
            },
            child: Stack(
              children: [
                // Left content
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                        child: const Icon(
                          Icons.people_outline_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Text(
                        'Invite friends',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                // Right decorative shapes matching mockup graphic
                Positioned(
                  right: -20,
                  top: -10,
                  bottom: -10,
                  child: SizedBox(
                    width: 130,
                    child: Stack(
                      alignment: Alignment.centerRight,
                      children: [
                        Positioned(
                          right: 20,
                          bottom: 12,
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFFB085),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Text('😊', style: TextStyle(fontSize: 22)),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 52,
                          top: 10,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(
                              color: Color(0xFFC084FC),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Text('😉', style: TextStyle(fontSize: 16)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Background soft visual decoration (radial gradients) matching chatbot/dashboard
          Positioned(
            top: -120,
            right: -120,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    theme.colorScheme.primary.withValues(alpha: 0.08),
                    theme.colorScheme.primary.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 200,
            left: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    theme.colorScheme.secondary.withValues(alpha: 0.15),
                    theme.colorScheme.secondary.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          // Main Body
          SafeArea(
            child: Column(
              children: [
                // Custom Floating Header Pill
                ProfileHeaderPill(
                  onBackTap: () {
                    Navigator.of(context).pop();
                  },
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Profile Card (Matches WelcomeCard styling)
                        ProfileInfoCard(
                          name: _displayName,
                          email: widget.email,
                          profilePicBase64: _profilePicBase64,
                          onPickImage: _showPickImageOptions,
                          onEditName: _showEditNameDialog,
                        ),
                        _buildInviteFriendsCard(),
                        ProfileSettingsMenu(
                          onManageProfileTap: _showManageProfileSheet,
                          onChangePasswordTap: _showChangePasswordDialog,
                          onSavedCardsTap: _showSavedCardsSheet,
                          onPastOrdersTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const PastOrdersPage(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                // Premium Redesigned Logout Button
                 Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: const Text('Logout'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                        ),
                        textStyle: TextStyle(
                          fontFamily: theme.textTheme.labelLarge?.fontFamily,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      onPressed: () {
                        widget.onLogout();
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
