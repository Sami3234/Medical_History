import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/constants.dart';
import '../../config/supabase_config.dart';
import '../../models/med_file_model.dart';
import '../../models/member_model.dart';
import '../../models/visit_model.dart';
import '../local_document_service.dart';
import 'temporary_share_crypto.dart';
import 'temporary_share_models.dart';

class TemporaryShareException implements Exception {
  final String message;

  const TemporaryShareException(this.message);

  @override
  String toString() => message;
}

class TemporaryShareService {
  static const int maximumShareBytes = 100 * 1024 * 1024;
  static const int maximumDocumentBytes = 25 * 1024 * 1024;
  static const Duration defaultLifetime = Duration(minutes: 15);
  static const Duration _requestTimeout = Duration(seconds: 90);
  static const _savedSharesKey = 'temporary_medical_shares_v1';

  final http.Client _httpClient;
  final LocalDocumentService _documents;

  TemporaryShareService({
    http.Client? httpClient,
    LocalDocumentService? documents,
  }) : _httpClient = httpClient ?? http.Client(),
       _documents = documents ?? LocalDocumentService();

  bool get isConfigured => AppStrings.temporaryShareApiUrl.trim().isNotEmpty;

  Future<TemporaryShareCredentials> createShare({
    required MemberModel member,
    required List<VisitModel> visits,
    required List<MedFileModel> documents,
    required Map<String, bool> scope,
    Duration lifetime = defaultLifetime,
    void Function(double progress)? onProgress,
  }) async {
    final session = SupabaseConfig.auth?.currentSession;
    if (session == null) {
      throw const TemporaryShareException(
        'Please sign in before sharing a medical record.',
      );
    }
    _requireConfigured();

    final temporaryId = TemporaryShareCrypto.generateTemporaryId();
    final otp = TemporaryShareCrypto.generateOtp();
    final revokeToken = TemporaryShareCrypto.generateSecretToken();
    final expiresAt = DateTime.now().toUtc().add(lifetime);
    final selectedDocuments = scope['documents'] == true
        ? documents.where((item) => item.memberId == member.id).toList()
        : <MedFileModel>[];

    final documentEntries = <TemporarySharedDocument>[];
    var totalBytes = 0;
    for (final document in selectedDocuments) {
      final size = await _documentSize(document);
      if (size > maximumDocumentBytes) {
        throw TemporaryShareException(
          '${document.fileName ?? 'A document'} is larger than the 25 MB per-file limit.',
        );
      }
      totalBytes += size;
      documentEntries.add(
        TemporarySharedDocument(
          token: TemporaryShareCrypto.generateSecretToken(bytes: 18),
          title:
              document.description ?? document.fileName ?? 'Medical document',
          fileName: document.fileName ?? 'medical-document',
          fileType: document.fileType,
          mimeType: document.mimeType,
          size: size,
        ),
      );
    }
    if (totalBytes > maximumShareBytes) {
      throw const TemporaryShareException(
        'Selected documents exceed the 100 MB temporary-share limit.',
      );
    }

    final manifest = <String, dynamic>{
      'version': 1,
      'expires_at': expiresAt.toIso8601String(),
      'member': scope['profile'] == true
          ? {
              'name': member.name,
              'relation': member.relation,
              'dob': member.dob?.toIso8601String(),
              'gender': member.gender,
              'blood_group': member.bloodGroup,
              'allergies': member.allergies,
              'notes': member.notes,
              'emergency_contact': member.emergencyContact,
            }
          : {'name': member.name},
      'visits': scope['visits'] == true
          ? visits
                .where((visit) => visit.memberId == member.id)
                .map(
                  (visit) => {
                    'visit_date': visit.visitDate.toIso8601String(),
                    'doctor_name': visit.doctorName,
                    'hospital': visit.hospital,
                    'symptoms': visit.symptoms,
                    'diagnosis': visit.diagnosis,
                    'treatment': visit.treatment,
                    'notes': visit.notes,
                    'follow_up_date': visit.followUpDate?.toIso8601String(),
                  },
                )
                .toList()
          : <Map<String, dynamic>>[],
      'documents': documentEntries.map((item) => item.toMap()).toList(),
    };
    final encryptedManifest = await TemporaryShareCrypto.encrypt(
      clearBytes: Uint8List.fromList(utf8.encode(jsonEncode(manifest))),
      temporaryId: temporaryId,
      otp: otp,
    );

    final baseHeaders = {
      'authorization': 'Bearer ${session.accessToken}',
      'content-type': 'application/octet-stream',
      'x-share-revoke-token': revokeToken,
    };
    try {
      final manifestResponse = await _send(
        _httpClient.put(
          _uri('/v1/shares/$temporaryId/manifest'),
          headers: {
            ...baseHeaders,
            'x-share-otp': otp,
            'x-share-expires-in': lifetime.inSeconds.toString(),
          },
          body: encryptedManifest,
        ),
      );
      _requireSuccess(manifestResponse, fallback: 'Unable to prepare sharing.');

      onProgress?.call(documentEntries.isEmpty ? 1 : 0.1);
      for (var index = 0; index < selectedDocuments.length; index++) {
        final clearBytes = await _documents.readBytes(selectedDocuments[index]);
        final encryptedBytes = await TemporaryShareCrypto.encrypt(
          clearBytes: clearBytes,
          temporaryId: temporaryId,
          otp: otp,
        );
        final response = await _send(
          _httpClient.put(
            _uri(
              '/v1/shares/$temporaryId/files/${documentEntries[index].token}',
            ),
            headers: baseHeaders,
            body: encryptedBytes,
          ),
        );
        _requireSuccess(
          response,
          fallback: 'A selected file could not be shared.',
        );
        onProgress?.call(0.1 + (0.9 * (index + 1) / selectedDocuments.length));
      }
    } catch (_) {
      await _bestEffortRevoke(
        temporaryId: temporaryId,
        revokeToken: revokeToken,
        accessToken: session.accessToken,
      );
      rethrow;
    }

    final credentials = TemporaryShareCredentials(
      temporaryId: temporaryId,
      otp: otp,
      expiresAt: expiresAt,
      memberId: member.id,
    );
    await _rememberShare(credentials, revokeToken);
    return credentials;
  }

  Future<TemporarySharedRecord> redeem({
    required String temporaryId,
    required String otp,
  }) async {
    _requireConfigured();
    final normalizedId = temporaryId.trim().toUpperCase();
    final normalizedOtp = otp.trim();
    _validateCredentials(normalizedId, normalizedOtp);

    final response = await _send(
      _httpClient.post(
        _uri('/v1/shares/$normalizedId/redeem'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({'otp': normalizedOtp}),
      ),
    );
    _requireSuccess(
      response,
      fallback: 'The temporary ID or OTP is invalid or expired.',
    );
    try {
      final sessionToken = response.headers['x-share-session'];
      if (sessionToken == null || sessionToken.isEmpty) {
        throw const TemporaryShareException(
          'Temporary access could not be established.',
        );
      }
      final clearBytes = await TemporaryShareCrypto.decrypt(
        encryptedBytes: response.bodyBytes,
        temporaryId: normalizedId,
        otp: normalizedOtp,
      );
      final manifest =
          jsonDecode(utf8.decode(clearBytes)) as Map<String, dynamic>;
      final expiresAt = DateTime.parse(manifest['expires_at'] as String);
      if (!expiresAt.isAfter(DateTime.now().toUtc())) {
        throw const TemporaryShareException(
          'This temporary access has expired.',
        );
      }
      return TemporarySharedRecord(
        temporaryId: normalizedId,
        otp: normalizedOtp,
        sessionToken: sessionToken,
        expiresAt: expiresAt,
        member: Map<String, dynamic>.from(manifest['member'] as Map),
        visits: (manifest['visits'] as List? ?? const [])
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList(),
        documents: (manifest['documents'] as List? ?? const [])
            .map(
              (item) => TemporarySharedDocument.fromMap(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList(),
      );
    } catch (error) {
      if (error is TemporaryShareException) rethrow;
      throw const TemporaryShareException(
        'The shared medical record could not be verified.',
      );
    }
  }

  Future<DecryptedTemporaryDocument> downloadDocument({
    required TemporarySharedRecord record,
    required TemporarySharedDocument document,
  }) async {
    if (!record.expiresAt.isAfter(DateTime.now().toUtc())) {
      throw const TemporaryShareException('This temporary access has expired.');
    }
    final response = await _send(
      _httpClient.post(
        _uri('/v1/shares/${record.temporaryId}/files/${document.token}/redeem'),
        headers: {
          'content-type': 'application/json',
          'x-share-session': record.sessionToken,
        },
      ),
    );
    _requireSuccess(
      response,
      fallback: 'This document is unavailable or access has expired.',
    );
    final bytes = await TemporaryShareCrypto.decrypt(
      encryptedBytes: response.bodyBytes,
      temporaryId: record.temporaryId,
      otp: record.otp,
    );
    return DecryptedTemporaryDocument(document: document, bytes: bytes);
  }

  Future<void> revokeAllForMember(String memberId) async {
    final session = SupabaseConfig.auth?.currentSession;
    if (session == null || !isConfigured) return;
    final shares = await _loadSavedShares();
    final matching = shares.where((item) => item['member_id'] == memberId);
    for (final share in matching) {
      final temporaryId = share['temporary_id'] as String?;
      final revokeToken = share['revoke_token'] as String?;
      if (temporaryId == null || revokeToken == null) continue;
      await _httpClient.delete(
        _uri('/v1/shares/$temporaryId'),
        headers: {
          'authorization': 'Bearer ${session.accessToken}',
          'x-share-revoke-token': revokeToken,
        },
      );
    }
    shares.removeWhere((item) => item['member_id'] == memberId);
    await _saveShares(shares);
  }

  Future<int> _documentSize(MedFileModel document) async {
    final file = File(document.fileUrl);
    if (await file.exists()) return file.length();
    return (await _documents.readBytes(document)).length;
  }

  void _requireConfigured() {
    if (!isConfigured) {
      throw const TemporaryShareException(
        'Temporary sharing is not configured in this app build.',
      );
    }
  }

  void _validateCredentials(String temporaryId, String otp) {
    final idPattern = RegExp(r'^[A-Z2-9]{4}-[A-Z2-9]{4}-[A-Z2-9]{4}$');
    if (!idPattern.hasMatch(temporaryId) || !RegExp(r'^\d{6}$').hasMatch(otp)) {
      throw const TemporaryShareException(
        'Enter a valid temporary ID and 6-digit OTP.',
      );
    }
  }

  Uri _uri(String path) {
    final base = AppStrings.temporaryShareApiUrl.trim().replaceAll(
      RegExp(r'/+$'),
      '',
    );
    return Uri.parse('$base$path');
  }

  Future<http.Response> _send(Future<http.Response> request) async {
    try {
      return await request.timeout(_requestTimeout);
    } on TimeoutException {
      throw const TemporaryShareException(
        'The secure server is taking too long to respond. Check the connection and retry.',
      );
    } on SocketException {
      throw const TemporaryShareException(
        'No internet connection is available for temporary sharing.',
      );
    } on http.ClientException {
      throw const TemporaryShareException(
        'The secure sharing service could not be reached.',
      );
    }
  }

  Future<void> _bestEffortRevoke({
    required String temporaryId,
    required String revokeToken,
    required String accessToken,
  }) async {
    try {
      await _httpClient
          .delete(
            _uri('/v1/shares/$temporaryId'),
            headers: {
              'authorization': 'Bearer $accessToken',
              'x-share-revoke-token': revokeToken,
            },
          )
          .timeout(_requestTimeout);
    } catch (_) {}
  }

  void _requireSuccess(http.Response response, {required String fallback}) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body['message'] is String) {
        throw TemporaryShareException(body['message'] as String);
      }
    } on TemporaryShareException {
      rethrow;
    } catch (_) {}
    throw TemporaryShareException(fallback);
  }

  Future<void> _rememberShare(
    TemporaryShareCredentials credentials,
    String revokeToken,
  ) async {
    final shares = await _loadSavedShares();
    shares.removeWhere(
      (item) => item['temporary_id'] == credentials.temporaryId,
    );
    shares.add({
      'temporary_id': credentials.temporaryId,
      'member_id': credentials.memberId,
      'expires_at': credentials.expiresAt.toIso8601String(),
      'revoke_token': revokeToken,
    });
    await _saveShares(shares);
  }

  Future<List<Map<String, dynamic>>> _loadSavedShares() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_savedSharesKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List;
      final now = DateTime.now().toUtc();
      return decoded
          .map((item) => Map<String, dynamic>.from(item as Map))
          .where((item) {
            final expiry = DateTime.tryParse(
              item['expires_at']?.toString() ?? '',
            );
            return expiry != null && expiry.isAfter(now);
          })
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveShares(List<Map<String, dynamic>> shares) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_savedSharesKey, jsonEncode(shares));
  }
}
