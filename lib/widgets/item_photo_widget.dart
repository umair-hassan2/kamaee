import 'dart:io';

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ItemPhotoWidget extends StatelessWidget {
  final String? photoPath;
  final double size;
  final double borderRadius;
  final IconData fallbackIcon;

  const ItemPhotoWidget({
    super.key,
    required this.photoPath,
    this.size = 48,
    this.borderRadius = 12,
    this.fallbackIcon = Icons.shopping_bag_outlined,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto =
        photoPath != null && photoPath!.isNotEmpty && File(photoPath!).existsSync();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(borderRadius),
        image: hasPhoto
            ? DecorationImage(
                image: FileImage(File(photoPath!)),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: hasPhoto
          ? null
          : Icon(fallbackIcon, color: AppColors.primary, size: size * 0.5),
    );
  }
}
