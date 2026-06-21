import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'widgets/profile_header_pill.dart';

class InviteFriendsPage extends StatelessWidget {
  const InviteFriendsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const referralLink = 'qless.app.link/invite/shravan_pandala';
    const shareMessage = 'I found an awesome shopping app that lets you scan barcodes, pay in-app, and skip checkout queues entirely! Join me on QLess and let\'s skip lines together: $referralLink';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Background decorations matching theme
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
            bottom: 100,
            left: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    theme.colorScheme.secondary.withValues(alpha: 0.12),
                    theme.colorScheme.secondary.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // Custom Header Pill
                ProfileHeaderPill(
                  onBackTap: () {
                    Navigator.of(context).pop();
                  },
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 20),
                        // Title
                        Center(
                          child: Text(
                            'Invite Friends',
                            style: TextStyle(
                              fontFamily: theme.textTheme.titleLarge?.fontFamily,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF001A23),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Cute Illustration of Friends Characters in Code
                        const Center(
                          child: InviteIllustration(),
                        ),
                        const SizedBox(height: 32),

                        // Invitation Header Text
                        Center(
                          child: Text(
                            'Let\'s shop together!',
                            style: TextStyle(
                              fontFamily: theme.textTheme.titleLarge?.fontFamily,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF001A23),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: TextStyle(
                                fontFamily: theme.textTheme.bodyMedium?.fontFamily,
                                fontSize: 14,
                                color: Colors.grey.shade600,
                                height: 1.5,
                              ),
                              children: const [
                                TextSpan(text: 'Share the experience, and get '),
                                TextSpan(
                                  text: '15% cashback ',
                                  style: TextStyle(
                                    color: Color(0xFFFF5A79),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                TextSpan(text: 'on your next express checkout!'),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Link copy field
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  referralLink,
                                  style: TextStyle(
                                    fontFamily: theme.textTheme.bodyMedium?.fontFamily,
                                    fontSize: 14,
                                    color: const Color(0xFF001A23),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.copy_rounded,
                                  color: theme.colorScheme.primary.withValues(alpha: 0.6),
                                  size: 20,
                                ),
                                onPressed: () {
                                  Clipboard.setData(const ClipboardData(text: referralLink));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text('Referral link copied to clipboard!'),
                                      backgroundColor: theme.colorScheme.primary,
                                      behavior: SnackBarBehavior.fixed,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Card with Share Message
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Text(
                            shareMessage,
                            style: TextStyle(
                              fontFamily: theme.textTheme.bodyMedium?.fontFamily,
                              fontSize: 14,
                              color: Colors.grey.shade700,
                              height: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 48),

                        // Primary Action Button
                        ElevatedButton(
                          onPressed: () {
                            Clipboard.setData(const ClipboardData(text: shareMessage));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Share message copied! Go ahead and share it with friends.'),
                                backgroundColor: theme.colorScheme.primary,
                                behavior: SnackBarBehavior.fixed,
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF001A23),
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(56),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            'Share Invite Link',
                            style: TextStyle(
                              fontFamily: theme.textTheme.labelLarge?.fontFamily,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
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

class InviteIllustration extends StatelessWidget {
  const InviteIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      width: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Left decorative shape (orange blob)
          Positioned(
            left: 25,
            bottom: 15,
            child: Container(
              width: 54,
              height: 54,
              decoration: const BoxDecoration(
                color: Color(0xFFFFB085),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('😊', style: TextStyle(fontSize: 26)),
              ),
            ),
          ),
          // Right decorative shape (purple blob)
          Positioned(
            right: 25,
            bottom: 25,
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Color(0xFFC084FC),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('😉', style: TextStyle(fontSize: 22)),
              ),
            ),
          ),
          // Center cute main character (pink blob with border)
          Positioned(
            top: 5,
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: const Color(0xFFF472B6),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF472B6).withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Center(
                child: Text('🥰', style: TextStyle(fontSize: 38)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
