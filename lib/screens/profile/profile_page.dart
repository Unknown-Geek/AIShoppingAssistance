import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'widgets/profile_header_pill.dart';
import 'widgets/profile_info_card.dart';
import 'widgets/order_card.dart';
import 'widgets/profile_skeleton_list.dart';

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
  List<Map<String, dynamic>> orders = [];
  bool loading = true;
  String? _profilePicBase64;
  final Set<String> _expandedOrderIds = {};
  late String _displayName;

  @override
  void initState() {
    super.initState();
    _displayName = widget.name;
    _loadOrders();
    _loadProfilePic();
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

  Future<void> _loadOrders() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        setState(() => loading = false);
        return;
      }

      final response = await Supabase.instance.client
          .from('user_carts')
          .select()
          .eq('user_id', user.id)
          .ilike('status', 'processed')
          .order('created_at', ascending: false);

      setState(() {
        orders = List<Map<String, dynamic>>.from(response);
        loading = false;
      });
    } catch (e) {
      debugPrint('Error loading orders: $e');
      setState(() => loading = false);
    }
  }

  void _toggleExpand(String orderId) {
    setState(() {
      if (_expandedOrderIds.contains(orderId)) {
        _expandedOrderIds.remove(orderId);
      } else {
        _expandedOrderIds.add(orderId);
      }
    });
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
                        // Past Orders Header Section
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                          child: Text(
                            'Past Orders',
                            style: TextStyle(
                              fontFamily: theme.textTheme.titleLarge?.fontFamily,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                        // Past Orders List
                        loading
                            ? const ProfileSkeletonList()
                            : orders.isEmpty
                                ? Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 64),
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.shopping_bag_outlined,
                                            size: 48,
                                            color: theme.colorScheme.primary.withValues(alpha: 0.3),
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            'No past orders found',
                                            style: TextStyle(
                                              fontFamily: theme.textTheme.bodyMedium?.fontFamily,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w500,
                                              color: theme.colorScheme.primary.withValues(alpha: 0.5),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                    itemCount: orders.length,
                                    itemBuilder: (context, index) {
                                      final order = orders[index];
                                      final orderId = order['id']?.toString() ?? index.toString();
                                      final isExpanded = _expandedOrderIds.contains(orderId);
                                      return OrderCard(
                                        order: order,
                                        isExpanded: isExpanded,
                                        onTap: () => _toggleExpand(orderId),
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
