import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'local_document_service.dart';

class NativeDocumentFile {
  final String path;
  final String name;
  final String mimeType;

  const NativeDocumentFile({
    required this.path,
    required this.name,
    required this.mimeType,
  });
}

class NativeDocumentService {
  static const _channel = MethodChannel('medical_history/native_documents');

  static Future<List<NativeDocumentFile>> scanDocuments() async {
    if (kIsWeb || !Platform.isAndroid) return [];
    final raw = await _channel.invokeMethod<List<dynamic>>('scanDocuments');
    return _parse(raw);
  }

  static Future<String> recognizeText(String path) async {
    if (kIsWeb || !Platform.isAndroid) return '';
    return await _channel.invokeMethod<String>('recognizeText', {
          'path': path,
        }) ??
        '';
  }

  static Future<List<NativeDocumentFile>> consumeSharedFiles() async {
    if (kIsWeb || !Platform.isAndroid) return [];
    final raw = await _channel.invokeMethod<List<dynamic>>(
      'consumeSharedFiles',
    );
    return _parse(raw);
  }

  static List<NativeDocumentFile> _parse(List<dynamic>? raw) {
    return (raw ?? const [])
        .whereType<Map>()
        .map(
          (item) => NativeDocumentFile(
            path: item['path']?.toString() ?? '',
            name: item['name']?.toString() ?? 'shared_document',
            mimeType: item['mime']?.toString() ?? 'application/octet-stream',
          ),
        )
        .where((item) => item.path.isNotEmpty)
        .toList();
  }

  static Future<int> importSharedFilesToDrafts() async {
    final files = await consumeSharedFiles();
    final local = LocalDocumentService();
    var imported = 0;
    for (final file in files) {
      final bytes = await File(file.path).readAsBytes();
      await local.saveDraft(
        bytes: bytes,
        fileName: file.name,
        mimeType: file.mimeType,
      );
      imported++;
    }
    if (files.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('last_shared_import_count', imported);
    }
    return imported;
  }
}
