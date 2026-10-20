import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../config/supabase_config.dart';

class MemberShareService {
  static const _uuid = Uuid();

  static SupabaseClient get _client {
    final client = SupabaseConfig.db;
    if (client == null) {
      throw StateError('Secure sharing is unavailable while offline.');
    }
    return client;
  }

  static Future<String> createShareToken({
    required String memberId,
    int validForDays = 7,
    Map<String, bool> scope = const {
      'profile': true,
      'visits': true,
      'documents': true,
    },
  }) async {
    final ownerId = SupabaseConfig.currentUserId;
    if (ownerId == null) throw StateError('Please sign in before sharing.');

    final token = 'mh_${_uuid.v4()}_${_uuid.v4()}';
    final tokenHash = sha256.convert(utf8.encode(token)).toString();
    final expiresAt = DateTime.now().toUtc().add(Duration(days: validForDays));

    await _client.from('member_share_links').insert({
      'member_id': memberId,
      'owner_id': ownerId,
      'token_hash': tokenHash,
      'expires_at': expiresAt.toIso8601String(),
      'scope': scope,
    });
    return token;
  }

  static Future<List<Map<String, dynamic>>> getActiveShares(
    String memberId,
  ) async {
    final ownerId = SupabaseConfig.currentUserId;
    if (ownerId == null) return [];
    final rows = await _client
        .from('member_share_links')
        .select('id, expires_at, created_at, revoked_at')
        .eq('member_id', memberId)
        .eq('owner_id', ownerId)
        .isFilter('revoked_at', null)
        .order('created_at', ascending: false);
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  static Future<void> revokeShare(String shareId) async {
    final ownerId = SupabaseConfig.currentUserId;
    if (ownerId == null) return;
    await _client
        .from('member_share_links')
        .update({'revoked_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', shareId)
        .eq('owner_id', ownerId);
  }

  static Future<void> revokeAllShares(String memberId) async {
    final ownerId = SupabaseConfig.currentUserId;
    if (ownerId == null) return;
    await _client
        .from('member_share_links')
        .update({'revoked_at': DateTime.now().toUtc().toIso8601String()})
        .eq('member_id', memberId)
        .eq('owner_id', ownerId)
        .isFilter('revoked_at', null);
  }

  static Future<Map<String, dynamic>?> loadSharedRecord(String token) async {
    if (token.trim().isEmpty) return null;
    final result = await _client.rpc(
      'get_shared_member_record',
      params: {'p_token': token.trim()},
    );
    if (result is Map<String, dynamic>) return result;
    if (result is Map) return Map<String, dynamic>.from(result);
    return null;
  }
}
