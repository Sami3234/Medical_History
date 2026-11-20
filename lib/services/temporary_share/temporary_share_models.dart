import 'dart:typed_data';

class TemporaryShareCredentials {
  final String temporaryId;
  final String otp;
  final DateTime expiresAt;
  final String memberId;

  const TemporaryShareCredentials({
    required this.temporaryId,
    required this.otp,
    required this.expiresAt,
    required this.memberId,
  });
}

class TemporarySharedDocument {
  final String token;
  final String title;
  final String fileName;
  final String fileType;
  final String? mimeType;
  final int size;

  const TemporarySharedDocument({
    required this.token,
    required this.title,
    required this.fileName,
    required this.fileType,
    required this.size,
    this.mimeType,
  });

  factory TemporarySharedDocument.fromMap(Map<String, dynamic> map) {
    return TemporarySharedDocument(
      token: map['token'] as String,
      title: map['title'] as String? ?? 'Medical document',
      fileName: map['file_name'] as String? ?? 'medical-document',
      fileType: map['file_type'] as String? ?? 'Document',
      mimeType: map['mime_type'] as String?,
      size: (map['size'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    'token': token,
    'title': title,
    'file_name': fileName,
    'file_type': fileType,
    'mime_type': mimeType,
    'size': size,
  };
}

class TemporarySharedRecord {
  final String temporaryId;
  final String otp;
  final String sessionToken;
  final DateTime expiresAt;
  final Map<String, dynamic> member;
  final List<Map<String, dynamic>> visits;
  final List<TemporarySharedDocument> documents;

  const TemporarySharedRecord({
    required this.temporaryId,
    required this.otp,
    required this.sessionToken,
    required this.expiresAt,
    required this.member,
    required this.visits,
    required this.documents,
  });
}

class DecryptedTemporaryDocument {
  final TemporarySharedDocument document;
  final Uint8List bytes;

  const DecryptedTemporaryDocument({
    required this.document,
    required this.bytes,
  });
}
