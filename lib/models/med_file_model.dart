class MedFileModel {
  final String id;
  final String? visitId;
  final String memberId;
  final String fileUrl;
  final String fileType; // prescription, labReport, xray, scan, other
  final String? description;
  final DateTime createdAt;

  MedFileModel({
    required this.id,
    this.visitId,
    required this.memberId,
    required this.fileUrl,
    required this.fileType,
    this.description,
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
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
    'visit_id': visitId,
    'member_id': memberId,
    'file_url': fileUrl,
    'file_type': fileType,
    'description': description,
  };
}
