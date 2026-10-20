class MedFileModel {
  final String id;
  final String? visitId;
  final String memberId;
  final String fileUrl;
  final String fileType; // prescription, labReport, xray, scan, other
  final String? description;
  final String? fileName;
  final String? mimeType;
  final String? backupUrl;
  final String? fileHash;
  final String? ocrText;
  final DateTime createdAt;

  MedFileModel({
    required this.id,
    this.visitId,
    required this.memberId,
    required this.fileUrl,
    required this.fileType,
    this.description,
    this.fileName,
    this.mimeType,
    this.backupUrl,
    this.fileHash,
    this.ocrText,
    required this.createdAt,
  });

  factory MedFileModel.fromMap(Map<String, dynamic> map) {
    return MedFileModel(
      id: map['id'] as String,
      visitId: map['visit_id'] as String?,
      memberId: map['member_id'] as String,
      fileUrl: map['file_url'] as String,
      fileType: map['file_type'] as String,
      description: map['description'] as String?,
      fileName: map['file_name'] as String?,
      mimeType: map['mime_type'] as String?,
      backupUrl: map['backup_url'] as String?,
      fileHash: map['file_hash'] as String?,
      ocrText: map['ocr_text'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
    'visit_id': visitId,
    'member_id': memberId,
    'file_url': fileUrl,
    'file_type': fileType,
    'description': description,
    'file_name': fileName,
    'mime_type': mimeType,
    'backup_url': backupUrl,
    'file_hash': fileHash,
    'ocr_text': ocrText,
    'created_at': createdAt.toIso8601String(),
  };

  MedFileModel copyWith({String? backupUrl}) => MedFileModel(
    id: id,
    visitId: visitId,
    memberId: memberId,
    fileUrl: fileUrl,
    fileType: fileType,
    description: description,
    fileName: fileName,
    mimeType: mimeType,
    backupUrl: backupUrl ?? this.backupUrl,
    fileHash: fileHash,
    ocrText: ocrText,
    createdAt: createdAt,
  );
}
