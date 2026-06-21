import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../../models/cart_item_model.dart';
import '../../../services/inventory_service.dart';
import 'payment_sheet.dart';
import 'missing_regulars_sheet.dart';

class DashboardSheets {
  static Future<void> showProfileSheet(
    BuildContext context, {
    required String email,
    required VoidCallback onSignOut,
  }) {
    final initial = email.isNotEmpty ? email[0].toUpperCase() : 'U';
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              CircleAvatar(
                radius: 36,
                backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                child: Text(
                  initial,
                  style: TextStyle(
                    fontFamily: theme.textTheme.titleLarge?.fontFamily,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Signed in as',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF4A5568),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                email,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    onSignOut();
                  },
                  icon: const Icon(
                    Icons.logout_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  label: const Text(
                    'Sign Out',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: Color(0xFF4A5568),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static Future<void> showRagSheet(
    BuildContext context, {
    required Function(String) onSubmitted,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _RagSheetContent(onSubmitted: onSubmitted);
      },
    );
  }

  static Future<void> showVoiceRagSheet(
    BuildContext context, {
    required Function(String) onSubmitted,
    required VoidCallback onTypeInsteadTap,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _VoiceRagSheetContent(
          onSubmitted: onSubmitted,
          onTypeInsteadTap: onTypeInsteadTap,
        );
      },
    );
  }

  static Future<bool?> showItemConfirmSheet(
    BuildContext context, {
    required CartItemModel item,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: const Color(0xFFF3F4F6),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: FutureBuilder<Map<String, dynamic>?>(
                      future: () async {
                        final inventoryService = InventoryService();
                        final slug = inventoryService.getSlugByName(item.name);
                        if (slug != null) {
                          return await inventoryService.getProductBySlug(slug);
                        }
                        return null;
                      }(),
                      builder: (context, snapshot) {
                        String displayUrl = item.imageUrl;
                        if (snapshot.hasData && snapshot.data != null) {
                          final thumbnail = snapshot.data!['thumbnail_url'] as String?;
                          if (thumbnail != null && thumbnail.isNotEmpty) {
                            displayUrl = thumbnail;
                          }
                        }
                        return CachedNetworkImage(
                          imageUrl: displayUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const Center(
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 1.5),
                            ),
                          ),
                          errorWidget: (context, url, error) => const Icon(Icons.image, size: 20),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Item detected',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF4A5568),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₹${item.price.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                  child: const Text(
                    'Add to Cart',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                  child: const Text(
                    'Not this item',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF4A5568),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static Future<void> showPaymentSheet(
    BuildContext context, {
    required double amount,
    required VoidCallback onPaymentSuccess,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return PaymentSheet(
          amount: amount,
          onPaymentSuccess: onPaymentSuccess,
        );
      },
    );
  }

  static Future<void> showMissingRegularsSheet(
    BuildContext context, {
    required List<dynamic> missingItems,
    required VoidCallback onContinueToCheckout,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return MissingRegularsSheet(
          missingItems: missingItems,
          onContinueToCheckout: () {
            // we already popped in the sheet
            onContinueToCheckout();
          },
        );
      },
    );
  }
}

class _RagSheetContent extends StatefulWidget {
  final Function(String) onSubmitted;

  const _RagSheetContent({required this.onSubmitted});

  @override
  State<_RagSheetContent> createState() => _RagSheetContentState();
}

class _RagSheetContentState extends State<_RagSheetContent> {
  final TextEditingController _ragController = TextEditingController();

  @override
  void dispose() {
    _ragController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Ask Chef RAG',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ragController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Ask anything about the products...',
                hintStyle: const TextStyle(color: Color(0xFF4A5568)),
                filled: true,
                fillColor: const Color(0xFFFFFFFF),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: Color(0xFFD2E4E6),
                    width: 1,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: Color(0xFFD2E4E6),
                    width: 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: theme.colorScheme.secondary,
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              onSubmitted: (val) {
                if (val.trim().isNotEmpty) {
                  Navigator.pop(context);
                  widget.onSubmitted(val);
                }
              },
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (_ragController.text.trim().isNotEmpty) {
                    final text = _ragController.text;
                    Navigator.pop(context);
                    widget.onSubmitted(text);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
                child: const Text(
                  'Ask',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoiceRagSheetContent extends StatefulWidget {
  final Function(String) onSubmitted;
  final VoidCallback onTypeInsteadTap;

  const _VoiceRagSheetContent({
    required this.onSubmitted,
    required this.onTypeInsteadTap,
  });

  @override
  State<_VoiceRagSheetContent> createState() => _VoiceRagSheetContentState();
}

class _VoiceRagSheetContentState extends State<_VoiceRagSheetContent> with SingleTickerProviderStateMixin {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _text = 'Listening...';
  bool _isAvailable = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _initSpeech();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _speech.stop();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    try {
      final available = await _speech.initialize(
        onStatus: (val) {
          debugPrint('Speech status: $val');
          if (mounted) {
            setState(() {
              _isListening = _speech.isListening;
              if (val == 'done' || val == 'notListening') {
                _isListening = false;
                if (_text != 'Listening...' && _text.trim().isNotEmpty) {
                  // Auto submit after short delay if status is done
                  Future.delayed(const Duration(milliseconds: 800), () {
                    if (mounted && !_isListening && _text.trim().isNotEmpty) {
                      Navigator.pop(context);
                      widget.onSubmitted(_text);
                    }
                  });
                }
              }
            });
          }
        },
        onError: (val) {
          debugPrint('Speech error: $val');
          if (mounted) {
            setState(() {
              _isListening = false;
              _text = 'Could not recognize speech. Tap mic to retry.';
            });
          }
        },
      );
      if (mounted) {
        setState(() {
          _isAvailable = available;
        });
        if (available) {
          _startListening();
        } else {
          setState(() {
            _text = 'Speech recognition not available on this device.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _text = 'Failed to initialize speech recognition.';
        });
      }
    }
  }

  void _startListening() async {
    if (!_isAvailable) return;
    setState(() {
      _text = 'Listening...';
      _isListening = true;
    });
    await _speech.listen(
      onResult: (val) {
        if (mounted) {
          setState(() {
            _text = val.recognizedWords;
          });
        }
      },
      listenFor: const Duration(seconds: 15),
      pauseFor: const Duration(seconds: 3),
      partialResults: true,
    );
  }

  void _stopListening() async {
    await _speech.stop();
    setState(() {
      _isListening = false;
    });
  }

  void _toggleListening() {
    if (_isListening) {
      _stopListening();
    } else {
      _startListening();
    }
  }

  Widget _buildPulsingMic(ThemeData theme) {
    return GestureDetector(
      onTap: _toggleListening,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_isListening)
            ...List.generate(3, (index) {
              final delay = index * 0.4;
              return AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final progress = (_pulseController.value + delay) % 1.0;
                  final size = 80.0 + (progress * 80.0);
                  final opacity = (1.0 - progress) * 0.3;
                  return Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.colorScheme.secondary.withValues(alpha: opacity),
                    ),
                  );
                },
              );
            }),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isListening ? theme.colorScheme.secondary : Colors.white,
              border: Border.all(
                color: const Color(0xFFD2E4E6),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: (_isListening ? theme.colorScheme.secondary : theme.colorScheme.primary)
                      .withValues(alpha: 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              _isListening ? Icons.mic : Icons.mic_none,
              color: _isListening ? Colors.white : theme.colorScheme.primary,
              size: 32,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Voice Search',
              style: TextStyle(
                fontFamily: theme.textTheme.titleLarge?.fontFamily,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 36),
            _buildPulsingMic(theme),
            const SizedBox(height: 36),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: theme.textTheme.bodyLarge?.fontFamily,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _isListening
                      ? theme.colorScheme.primary
                      : theme.colorScheme.primary.withValues(alpha: 0.6),
                ),
              ),
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: widget.onTypeInsteadTap,
                  icon: const Icon(Icons.keyboard_outlined, size: 18),
                  label: const Text(
                    'Type instead',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.primary.withValues(alpha: 0.6),
                  ),
                ),
                if (_text != 'Listening...' && _text.trim().isNotEmpty)
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onSubmitted(_text);
                    },
                    icon: const Icon(Icons.send_rounded, size: 16, color: Colors.white),
                    label: const Text(
                      'Search',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
