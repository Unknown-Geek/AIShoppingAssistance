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
    final theme = Theme.of(context);
    final imagePicker = ImagePicker();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          top: BorderSide(color: Color(0xFFD2E4E6), width: 1.5),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (selectedImage != null || selectedFileName != null) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (selectedImage != null)
                    InputChip(
                      avatar: const Icon(Icons.image, size: 16),
                      label: Text(selectedImage!.name.split('/').last),
                      onDeleted: onClearImage,
                    ),
                  if (selectedFileName != null)
                    InputChip(
                      avatar: const Icon(Icons.attach_file, size: 16),
                      label: Text(selectedFileName!),
                      onDeleted: onClearFile,
                    ),
                ],
              ),
            ),
          ],
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  onSubmitted: loading ? null : (_) => onSend(),
                  decoration: InputDecoration(
                    hintText: 'Ask for a recipe...',
                    filled: true,
                    fillColor: const Color(0xFFF3F4F6),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Center(
                        widthFactor: 1,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.grey.shade400,
                            ),
                          ),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(
                              Icons.add,
                              size: 18,
                            ),
                            onPressed: () async {
                              showModalBottomSheet(
                                context: context,
                                builder: (context) => SafeArea(
                                  child: Wrap(
                                    children: [
                                      ListTile(
                                        leading: const Icon(Icons.image),
                                        title: const Text('Choose Image'),
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
                                      ListTile(
                                        leading: const Icon(Icons.attach_file),
                                        title: const Text('Choose File'),
                                        onTap: () async {
                                          Navigator.pop(context);

                                          final result = await FilePicker.platform.pickFiles();

                                          if (result != null && result.files.isNotEmpty) {
                                            onFileSelected(
                                              result.files.first,
                                              result.files.first.name,
                                            );
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(
                        Icons.mic_none_rounded,
                        size: 22,
                      ),
                      onPressed: () {
                        // Speech-to-text later
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              CircleAvatar(
                radius: 22,
                backgroundColor: theme.colorScheme.primary,
                child: IconButton(
                  onPressed: loading ? null : onSend,
                  icon: const Icon(
                    Icons.arrow_upward,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
