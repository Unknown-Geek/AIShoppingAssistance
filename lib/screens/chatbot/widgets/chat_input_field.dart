import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

class ChatInputField extends StatelessWidget {
  final TextEditingController controller;
  final bool loading;
  final VoidCallback onSend;
  final XFile? selectedImage;
  final String? selectedFileName;
  final ValueChanged<XFile?> onImageSelected;
  final Function(PlatformFile?, String?) onFileSelected;
  final VoidCallback onClearImage;
  final VoidCallback onClearFile;

  const ChatInputField({
    super.key,
    required this.controller,
    required this.loading,
    required this.onSend,
    required this.selectedImage,
    required this.selectedFileName,
    required this.onImageSelected,
    required this.onFileSelected,
    required this.onClearImage,
    required this.onClearFile,
  });

  @override
  Widget build(BuildContext context) {
    final imagePicker = ImagePicker();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Floating File/Image Chips above the text input pill
            if (selectedImage != null || selectedFileName != null)
              Padding(
                padding: const EdgeInsets.only(left: 28.0, right: 28.0, bottom: 8.0),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (selectedImage != null)
                      InputChip(
                        labelStyle: const TextStyle(fontFamily: 'ClashGrotesk', fontWeight: FontWeight.w600),
                        avatar: const Icon(Icons.image, size: 16, color: Color(0xFF001A23)),
                        label: Text(selectedImage!.name.split('/').last),
                        onDeleted: onClearImage,
                        deleteIconColor: const Color(0xFFEF4444),
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    if (selectedFileName != null)
                      InputChip(
                        labelStyle: const TextStyle(fontFamily: 'ClashGrotesk', fontWeight: FontWeight.w600),
                        avatar: const Icon(Icons.attach_file, size: 16, color: Color(0xFF001A23)),
                        label: Text(selectedFileName!),
                        onDeleted: onClearFile,
                        deleteIconColor: const Color(0xFFEF4444),
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                  ],
                ),
              ),
            // Floating 84px input area
            Container(
              height: 84,
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(42),
                border: Border.all(color: const Color(0xFFD2E4E6), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF001A23).withOpacity(0.06),
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
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFB3EFB2),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.add_rounded,
                          color: Color(0xFF001A23),
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
                      style: const TextStyle(
                        fontFamily: 'ClashGrotesk',
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF001A23),
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Ask for a recipe...',
                        hintStyle: TextStyle(
                          fontFamily: 'ClashGrotesk',
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF4A5568),
                        ),
                        border: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        enabledBorder: InputBorder.none,
                      ),
                    ),
                  ),
                  // Mic / Voice Button
                  IconButton(
                    icon: const Icon(
                      Icons.mic_none_rounded,
                      color: Color(0xFF001A23),
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
      ),
    );
  }

  void _showAttachmentBottomSheet(BuildContext context, ImagePicker imagePicker) {
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
                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE8F1F2),
                  child: Icon(Icons.photo_library_rounded, color: Color(0xFF001A23)),
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
                  final image = await imagePicker.pickImage(source: ImageSource.gallery);
                  if (image != null) {
                    onImageSelected(image);
                  }
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE8F1F2),
                  child: Icon(Icons.camera_alt_rounded, color: Color(0xFF001A23)),
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
                  final image = await imagePicker.pickImage(source: ImageSource.camera);
                  if (image != null) {
                    onImageSelected(image);
                  }
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE8F1F2),
                  child: Icon(Icons.attach_file_rounded, color: Color(0xFF001A23)),
                ),
                title: const Text(
                  'Choose Document / File',
                  style: TextStyle(
                    fontFamily: 'ClashGrotesk',
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF001A23),
                  ),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final result = await FilePicker.platform.pickFiles();
                  if (result != null && result.files.isNotEmpty) {
                    onFileSelected(result.files.first, result.files.first.name);
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
            color: enabled ? const Color(0xFF001A23) : const Color(0xFF001A23).withOpacity(0.3),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: const Color(0xFF001A23).withOpacity(0.2),
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
