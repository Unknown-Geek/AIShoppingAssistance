import 'package:flutter/material.dart';

class ProfileSettingsMenu extends StatelessWidget {
  final VoidCallback onManageProfileTap;
  final VoidCallback onChangePasswordTap;
  final VoidCallback onSavedCardsTap;
  final VoidCallback onPastOrdersTap;

  const ProfileSettingsMenu({
    super.key,
    required this.onManageProfileTap,
    required this.onChangePasswordTap,
    required this.onSavedCardsTap,
    required this.onPastOrdersTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.15),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Column(
          children: [
            _buildMenuItem(
              context: context,
              icon: Icons.manage_accounts_outlined,
              title: 'Manage Profile',
              onTap: onManageProfileTap,
            ),
            _buildDivider(theme),
            _buildMenuItem(
              context: context,
              icon: Icons.lock_outline_rounded,
              title: 'Change Password',
              onTap: onChangePasswordTap,
            ),
            _buildDivider(theme),
            _buildMenuItem(
              context: context,
              icon: Icons.credit_card_outlined,
              title: 'Saved Cards',
              onTap: onSavedCardsTap,
            ),
            _buildDivider(theme),
            _buildMenuItem(
              context: context,
              icon: Icons.shopping_bag_outlined,
              title: 'View Past Orders',
              onTap: onPastOrdersTap,
              isLast: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isLast = false,
  }) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Centered Icon block (no circle background, reduced size)
              SizedBox(
                width: 20,
                height: 20,
                child: Center(
                  child: Icon(icon, color: theme.colorScheme.primary, size: 18),
                ),
              ),
              const SizedBox(width: 16),
              // Title text
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: theme.textTheme.bodyMedium?.fontFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.primary,
                    height: 1.2,
                  ),
                ),
              ),
              // Centered Arrow trailing icon
              SizedBox(
                width: 14,
                height: 14,
                child: Center(
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 13,
                    color: theme.colorScheme.primary.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider(ThemeData theme) {
    return Divider(
      height: 1,
      thickness: 1,
      indent:
          20, // starts right under the icon at the left margin, covering the icon area
      endIndent: 20,
      color: theme.colorScheme.primary.withValues(alpha: 0.08),
    );
  }
}
