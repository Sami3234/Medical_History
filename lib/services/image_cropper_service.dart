import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/image_crop_dialog.dart';

class ImageCropperService {
  /// Crop avatar image using the modern in-app interactive crop dialog
  static Future<Uint8List?> cropAvatar({
    required XFile file,
    required BuildContext context,
  }) async {
    try {
      final rawBytes = await file.readAsBytes();
      if (!context.mounted) return null;
      return await ImageCropDialog.show(
        context: context,
        imageBytes: rawBytes,
        title: 'Crop Profile Photo',
      );
    } catch (e) {
      debugPrint('Cropping note: $e');
      return null;
    }
  }
}
