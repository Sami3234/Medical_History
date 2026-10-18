import 'dart:io';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/med_file_model.dart';
import 'mock_data_service.dart';
import 'cloudinary_service.dart';

class StorageService {
  final _mock = MockDataService();

  Future<String> uploadFile({
    required String bucket,
    required String path,
    required File file,
  }) async {
    // If it's an image, upload to Cloudinary
    final ext = file.path.split('.').last.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'webp'].contains(ext)) {
      final res = await CloudinaryService.uploadImage(
        file: file,
        folder: bucket,
      );
      if (res.success && res.secureUrl != null) {
        return res.secureUrl!;
      }
    }

    // Fallback to Supabase storage if initialized
    if (SupabaseConfig.isInitialized && SupabaseConfig.storage != null) {
      return uploadBytes(
        bucket: bucket,
        path: path,
        bytes: await file.readAsBytes(),
      );
    }
    return 'assets/docs/${file.path.split(Platform.pathSeparator).last}';
  }

  Future<String> uploadBytes({
    required String bucket,
    required String path,
    required List<int> bytes,
  }) async {
    final userId = SupabaseConfig.currentUserId;
    if (!SupabaseConfig.isInitialized ||
        SupabaseConfig.storage == null ||
        userId == null) {
      throw StateError(
        'Sign in is required before uploading medical documents.',
      );
    }

    final normalizedPath = path
        .replaceAll('\\', '/')
        .replaceFirst(RegExp(r'^/+'), '');
    final securePath = normalizedPath.startsWith('$userId/')
        ? normalizedPath
        : '$userId/$normalizedPath';
    await SupabaseConfig.storage!
        .from(bucket)
        .uploadBinary(
          securePath,
          Uint8List.fromList(bytes),
          fileOptions: const FileOptions(upsert: false),
        );

    if (bucket == 'avatars') {
      return SupabaseConfig.storage!.from(bucket).getPublicUrl(securePath);
    }
    return SupabaseConfig.storage!
        .from(bucket)
        .createSignedUrl(securePath, 60 * 60 * 24 * 365);
  }

  Future<String?> pickAndUpload({
    required String bucket,
    required String folder,
  }) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return null;

    final bytes = await picked.readAsBytes();
    final res = await CloudinaryService.uploadImage(
      bytes: bytes,
      filename: picked.name,
      folder: bucket,
    );
    if (res.success && res.secureUrl != null) {
      return res.secureUrl!;
    }
    return null;
  }

  Future<void> deleteFile(String bucket, String path) async {
    if (SupabaseConfig.isInitialized && SupabaseConfig.storage != null) {
      final userId = SupabaseConfig.currentUserId;
      if (userId == null) return;
      final securePath = path.startsWith('$userId/') ? path : '$userId/$path';
      await SupabaseConfig.storage!.from(bucket).remove([securePath]);
    }
  }

  // Medical files
  Future<List<MedFileModel>> getFiles(String memberId) async {
    if (SupabaseConfig.isInitialized && SupabaseConfig.db != null) {
      final data = await SupabaseConfig.db!
          .from('med_files')
          .select()
          .eq('member_id', memberId)
          .order('created_at', ascending: false);
      return data.map((e) => MedFileModel.fromMap(e)).toList();
    }
    return _mock.files.where((f) => f.memberId == memberId).toList();
  }

  Future<void> saveMedFile(Map<String, dynamic> medFile) async {
    if (SupabaseConfig.isInitialized && SupabaseConfig.db != null) {
      await SupabaseConfig.db!.from('med_files').insert(medFile);
    } else {
      final newFile = MedFileModel(
        id: 'file-${DateTime.now().millisecondsSinceEpoch}',
        visitId: medFile['visit_id'],
        memberId: medFile['member_id'] ?? 'mem-3',
        fileUrl: medFile['file_url'] ?? 'assets/docs/file.pdf',
        fileType: medFile['file_type'] ?? 'prescription',
        description: medFile['description'] ?? 'Medical Document',
        createdAt: DateTime.now(),
      );
      _mock.files.insert(0, newFile);
    }
  }

  Future<void> deleteMedFile(String id) async {
    if (SupabaseConfig.isInitialized && SupabaseConfig.db != null) {
      await SupabaseConfig.db!.from('med_files').delete().eq('id', id);
    } else {
      _mock.files.removeWhere((f) => f.id == id);
    }
  }
}
