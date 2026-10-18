import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/med_file_model.dart';

class LocalDocumentService {
  static const _metadataKey = 'local_medical_documents_v1';

  Future<List<MedFileModel>> loadDocuments() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_metadataKey);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    final documents = decoded
        .map(
          (item) =>
              MedFileModel.fromMap(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
    documents.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return documents;
  }

  Future<MedFileModel> saveDocument({
    required Uint8List bytes,
    required String fileName,
    required String memberId,
    required String fileType,
    required String description,
    String? visitId,
    String? mimeType,
  }) async {
    final id = 'local-${DateTime.now().microsecondsSinceEpoch}';
    final safeName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final localUrl = kIsWeb
        ? 'data:${mimeType ?? _mimeForName(fileName)};base64,${base64Encode(bytes)}'
        : await _writeFile(id, safeName, bytes);
    final document = MedFileModel(
      id: id,
      visitId: visitId,
      memberId: memberId,
      fileUrl: localUrl,
      fileType: fileType,
      description: description,
      fileName: fileName,
      mimeType: mimeType ?? _mimeForName(fileName),
      createdAt: DateTime.now(),
    );
    final documents = await loadDocuments()
      ..insert(0, document);
    await _persist(documents);
    return document;
  }

  Future<String> _writeFile(String id, String fileName, Uint8List bytes) async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory(
      '${root.path}${Platform.pathSeparator}medical_documents',
    );
    await directory.create(recursive: true);
    final file = File(
      '${directory.path}${Platform.pathSeparator}${id}_$fileName',
    );
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<Uint8List> readBytes(MedFileModel document) async {
    if (document.fileUrl.startsWith('data:')) {
      return base64Decode(document.fileUrl.split(',').last);
    }
    return File(document.fileUrl).readAsBytes();
  }

  Future<bool> openDocument(MedFileModel document) async {
    if (kIsWeb) return false;
    final result = await OpenFilex.open(document.fileUrl);
    return result.type == ResultType.done;
  }

  Future<void> deleteDocument(String id) async {
    final documents = await loadDocuments();
    final index = documents.indexWhere((item) => item.id == id);
    if (index < 0) return;
    final document = documents.removeAt(index);
    if (!kIsWeb && !document.fileUrl.startsWith('data:')) {
      final file = File(document.fileUrl);
      if (await file.exists()) await file.delete();
    }
    await _persist(documents);
  }

  Future<void> setBackupUrl(String id, String backupUrl) async {
    final documents = await loadDocuments();
    final index = documents.indexWhere((item) => item.id == id);
    if (index < 0) return;
    documents[index] = documents[index].copyWith(backupUrl: backupUrl);
    await _persist(documents);
  }

  Future<List<Map<String, dynamic>>> exportForBackup() async {
    final documents = await loadDocuments();
    final exported = <Map<String, dynamic>>[];
    for (final document in documents) {
      final map = document.toMap();
      map['id'] = document.id;
      map['file_bytes'] = base64Encode(await readBytes(document));
      map.remove('file_url');
      exported.add(map);
    }
    return exported;
  }

  Future<void> restoreFromBackup(List<dynamic> records) async {
    for (final record in records) {
      final map = Map<String, dynamic>.from(record as Map);
      final encoded = map['file_bytes'] as String?;
      if (encoded == null || encoded.isEmpty) continue;
      await saveDocument(
        bytes: base64Decode(encoded),
        fileName: map['file_name'] as String? ?? 'medical_document',
        memberId: map['member_id'] as String,
        fileType: map['file_type'] as String? ?? 'other',
        description: map['description'] as String? ?? 'Medical document',
        visitId: map['visit_id'] as String?,
        mimeType: map['mime_type'] as String?,
      );
    }
  }

  Future<void> _persist(List<MedFileModel> documents) async {
    final prefs = await SharedPreferences.getInstance();
    final records = documents.map((document) {
      final map = document.toMap();
      map['id'] = document.id;
      return map;
    }).toList();
    await prefs.setString(_metadataKey, jsonEncode(records));
  }

  String _mimeForName(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    return switch (extension) {
      'pdf' => 'application/pdf',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
  }
}
