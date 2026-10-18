import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/constants.dart';
import '../config/supabase_config.dart';

class CloudinaryUploadResult {
  final bool success;
  final String? secureUrl;
  final String? publicId;
  final String? error;

  CloudinaryUploadResult({
    required this.success,
    this.secureUrl,
    this.publicId,
    this.error,
  });
}

class CloudinaryService {
  static const String cloudName = AppStrings.cloudinaryCloudName;
  static const String apiKey = AppStrings.cloudinaryApiKey;
  static const String uploadPreset = AppStrings.cloudinaryUploadPreset;

  /// Upload an image using raw bytes or a File (fully cross-platform: Web, Android, iOS, Desktop)
  static Future<CloudinaryUploadResult> uploadImage({
    Uint8List? bytes,
    File? file,
    String? filename,
    String folder = 'medical_history/avatars',
  }) async {
    try {
      Uint8List? imageBytes = bytes;
      if (imageBytes == null && file != null) {
        imageBytes = await file.readAsBytes();
      }

      if (imageBytes == null || imageBytes.isEmpty) {
        return CloudinaryUploadResult(
          success: false,
          error: 'Please select a valid image file.',
        );
      }

      if (cloudName.isEmpty || uploadPreset.isEmpty) {
        final fallbackName =
            filename ?? 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final fallback = await _uploadToStorageFallback(
          imageBytes,
          fallbackName,
          folder,
        );
        return fallback ??
            CloudinaryUploadResult(
              success: false,
              error: 'Image storage is not configured.',
            );
      }

      final resolvedName =
          filename ??
          (file != null
              ? file.path.split(RegExp(r'[\\/]')).last
              : 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg');

      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
      );
      final request = http.MultipartRequest('POST', uri);

      // Always use MultipartFile.fromBytes - works universally on Web, Mobile, Desktop
      final multipartFile = http.MultipartFile.fromBytes(
        'file',
        imageBytes,
        filename: resolvedName,
      );
      request.files.add(multipartFile);

      // Preset & destination folder
      request.fields['upload_preset'] = uploadPreset;
      request.fields['folder'] = folder;

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final secureUrl = data['secure_url'] as String?;
        final publicId = data['public_id'] as String?;

        return CloudinaryUploadResult(
          success: true,
          secureUrl: secureUrl,
          publicId: publicId,
        );
      } else {
        debugPrint('Image upload status: ${response.statusCode}');

        // Cloud storage high-availability fallback
        final fallback = await _uploadToStorageFallback(
          imageBytes,
          resolvedName,
          folder,
        );
        if (fallback != null) return fallback;

        return CloudinaryUploadResult(
          success: false,
          error: 'Failed to upload image. Please try again.',
        );
      }
    } catch (e) {
      debugPrint('Image upload caught error: $e');
      return CloudinaryUploadResult(
        success: false,
        error: 'Unable to upload photo. Please check your internet connection.',
      );
    }
  }

  static Future<CloudinaryUploadResult> uploadDocument({
    required Uint8List bytes,
    required String filename,
    String folder = 'medical_history/documents',
  }) async {
    if (cloudName.isEmpty || uploadPreset.isEmpty) {
      return CloudinaryUploadResult(
        success: false,
        error: 'Cloudinary backup is not configured.',
      );
    }
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/auto/upload'),
      );
      request.files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: filename),
      );
      request.fields['upload_preset'] = uploadPreset;
      request.fields['folder'] = folder;
      final response = await http.Response.fromStream(await request.send());
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return CloudinaryUploadResult(
          success: true,
          secureUrl: data['secure_url'] as String?,
          publicId: data['public_id'] as String?,
        );
      }
      return CloudinaryUploadResult(
        success: false,
        error: 'Cloud backup failed with HTTP ${response.statusCode}.',
      );
    } catch (error) {
      debugPrint('Document cloud backup error: $error');
      return CloudinaryUploadResult(
        success: false,
        error: 'Cloud backup could not be completed.',
      );
    }
  }

  static Future<CloudinaryUploadResult?> _uploadToStorageFallback(
    Uint8List bytes,
    String filename,
    String folder,
  ) async {
    try {
      if (SupabaseConfig.isInitialized && SupabaseConfig.storage != null) {
        final userId = SupabaseConfig.currentUserId;
        if (userId == null) return null;
        final bucket = folder.contains('document') ? 'reports' : 'avatars';
        final storagePath =
            '$userId/photos/${DateTime.now().millisecondsSinceEpoch}_$filename';
        await SupabaseConfig.storage!
            .from(bucket)
            .uploadBinary(storagePath, bytes);
        final publicUrl = SupabaseConfig.storage!
            .from(bucket)
            .getPublicUrl(storagePath);
        return CloudinaryUploadResult(success: true, secureUrl: publicUrl);
      }
    } catch (e) {
      debugPrint('Storage fallback note: $e');
    }
    return null;
  }
}
