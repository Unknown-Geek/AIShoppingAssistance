import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ChatInputField extends StatelessWidget {
  final TextEditingController controller;
  final bool loading;
  final VoidCallback onSend;
  final XFile? selectedImage;
  final ValueChanged<XFile?> onImageSelected;
  final VoidCallback onClearImage;

  const ChatInputField({
    super.key,
    required this.controller,
    required this.loading,
    required this.onSend,
    required this.selectedImage,
    required this.onImageSelected,
    required this.onClearImage,
  });

  @override
  Widget build(BuildContext context) {
    final imagePicker = ImagePicker();
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    // Calculate equal visual gaps above and below the floating white pill
    final double topGap = selectedImage != null
        ? 6.0
        : (isKeyboardOpen
            ? 8.0
            : (bottomPadding > 0 ? 24.0 : 16.0));
    final double bottomGap = isKeyboardOpen
        ? 8.0
        : (bottomPadding > 0 ? bottomPadding : 16.0);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Floating File/Image Chips above the text input pill
          if (selectedImage != null)
            Padding(
              padding: const EdgeInsets.only(
                top: 12.0,
                bottom: 4.0,
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Row(
                  children: [
                    InputChip(
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      labelPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      avatar: Icon(
                        Icons.image_outlined,
                        size: 14,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      label: Text(selectedImage!.name.split('/').last),
                      onDeleted: onClearImage,
                      deleteIcon: Icon(
                        Icons.close,
                        size: 14,
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                      ),
                      backgroundColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.35),
                      side: BorderSide.none,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Floating 84px input area
          Container(
            height: 84,
            margin: EdgeInsets.only(
              left: 16,
              right: 16,
              top: topGap,
              bottom: bottomGap,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(42),
              border: Border.all(color: const Color(0xFFD2E4E6), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.06),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                // Plus Menu Button
                GestureDetector(
                  onTap: () {
                    _showAttachmentBottomSheet(context, imagePicker);
                  },
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    child: Center(
                      child: Icon(
                        Icons.add_rounded,
                        color: Theme.of(context).colorScheme.onSecondary,
                        size: 24,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Text Field
                Expanded(
                  child: TextField(
                    controller: controller,
                    onSubmitted: loading ? null : (_) => onSend(),
                    style: TextStyle(
                      fontFamily: 'ClashGrotesk',
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Ask me anything...',
                      hintStyle: TextStyle(
                        fontFamily: 'ClashGrotesk',
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      border: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      enabledBorder: InputBorder.none,
                    ),
                  ),
                ),
                // Mic / Voice Button
                IconButton(
                  icon: Icon(
                    Icons.mic_none_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 24,
                  ),
                  onPressed: () {
                    // Speech to text integration placeholder
                  },
                ),
                const SizedBox(width: 8),
                // Send Button
                AnimSendButton(
                  onTap: loading ? null : onSend,
                  loading: loading,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAttachmentBottomSheet(
    BuildContext context,
    ImagePicker imagePicker,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Add Attachment',
                style: TextStyle(
                  fontFamily: 'ClashDisplay',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF001A23),
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
                    fontFamily: 'ClashGrotesk',
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF001A23),
                  ),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final image = await imagePicker.pickImage(
                    source: ImageSource.gallery,
                  );
                  if (image != null) {
                    onImageSelected(image);
                  }
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
                    fontFamily: 'ClashGrotesk',
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF001A23),
                  ),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final image = await imagePicker.pickImage(
                    source: ImageSource.camera,
                  );
                  if (image != null) {
                    onImageSelected(image);
                  }
                },
              ),

            ],
          ),
        ),
      ),
    );
  }
}

class AnimSendButton extends StatefulWidget {
  final VoidCallback? onTap;
  final bool loading;

  const AnimSendButton({super.key, required this.onTap, this.loading = false});

  @override
  State<AnimSendButton> createState() => _AnimSendButtonState();
}

class _AnimSendButtonState extends State<AnimSendButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = widget.onTap != null && !widget.loading;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _isPressed = true) : null,
      onTapUp: enabled ? (_) => setState(() => _isPressed = false) : null,
      onTapCancel: enabled ? () => setState(() => _isPressed = false) : null,
      onTap: enabled ? widget.onTap : null,
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: enabled
                ? theme.colorScheme.primary
                : theme.colorScheme.primary.withValues(alpha: 0.3),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: const Center(
            child: Icon(
              Icons.arrow_upward_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}
