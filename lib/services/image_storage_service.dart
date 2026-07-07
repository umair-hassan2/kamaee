import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ImageStorageService {
  static final ImageStorageService _instance = ImageStorageService._internal();
  factory ImageStorageService() => _instance;
  ImageStorageService._internal();

  Future<Directory> get _photosDir async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, 'item_photos'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<String> saveItemPhoto(File source, int itemId) async {
    final dir = await _photosDir;
    final filename = 'item_${itemId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final destPath = p.join(dir.path, filename);
    await source.copy(destPath);
    return destPath;
  }

  Future<void> deletePhoto(String? photoPath) async {
    if (photoPath == null || photoPath.isEmpty) return;
    final file = File(photoPath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> deletePhotosForItem(int itemId) async {
    final dir = await _photosDir;
    if (!await dir.exists()) return;
    await for (final entity in dir.list()) {
      if (entity is File && p.basename(entity.path).startsWith('item_${itemId}_')) {
        await entity.delete();
      }
    }
  }
}
