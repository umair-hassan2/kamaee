import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import 'item_photo_widget.dart';

class ItemPhotoPicker extends StatelessWidget {
  final String? currentPhotoPath;
  final File? pendingPhoto;
  final bool photoRemoved;
  final ValueChanged<File?> onPhotoChanged;
  final VoidCallback onPhotoRemoved;

  const ItemPhotoPicker({
    super.key,
    required this.currentPhotoPath,
    required this.pendingPhoto,
    required this.photoRemoved,
    required this.onPhotoChanged,
    required this.onPhotoRemoved,
  });

  String? get _displayPath {
    if (photoRemoved) return null;
    if (pendingPhoto != null) return pendingPhoto!.path;
    return currentPhotoPath;
  }

  Future<void> _pickPhoto(BuildContext context, ImageSource source) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (image != null) {
      onPhotoChanged(File(image.path));
    }
  }

  void _showSourcePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickPhoto(context, ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickPhoto(context, ImageSource.gallery);
                },
              ),
              if (_displayPath != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: AppColors.danger),
                  title: const Text('Remove Photo',
                      style: TextStyle(color: AppColors.danger)),
                  onTap: () {
                    Navigator.pop(ctx);
                    onPhotoRemoved();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = _displayPath != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Product Photo',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            ItemPhotoWidget(
              photoPath: _displayPath,
              size: 80,
              borderRadius: 14,
              fallbackIcon: Icons.add_a_photo_outlined,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _showSourcePicker(context),
                    icon: Icon(hasPhoto ? Icons.edit_outlined : Icons.add_a_photo),
                    label: Text(hasPhoto ? 'Change Photo' : 'Add Photo'),
                  ),
                  if (hasPhoto) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Helps you recognize products at a glance',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
