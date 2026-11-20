import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/doctor_model.dart';
import '../models/family_model.dart';
import '../models/member_model.dart';

/// Central offline cache service that guarantees instant UI loading (0ms)
/// across app restarts and during slow/offline network conditions.
class OfflineDataService {
  static SharedPreferences? _prefs;

  // In-memory cache for synchronous instant access
  static final Map<String, List<FamilyModel>> _familyCache = {};
  static final Map<String, List<MemberModel>> _memberCache = {};
  static final Map<String, List<DoctorModel>> _doctorCache = {};
  static final Map<String, MemberModel> _ownerCache = {};
  static final Map<String, Map<String, List<DoctorModel>>> _memberDoctorCache = {};

  static Future<void> init() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      _loadAllPersisted();
    } catch (e) {
      debugPrint('OfflineDataService init warning: $e');
    }
  }

  static void _loadAllPersisted() {
    if (_prefs == null) return;
    try {
      final keys = _prefs!.getKeys();
      for (final key in keys) {
        if (key.startsWith('mh_families_')) {
          final uid = key.replaceFirst('mh_families_', '');
          final raw = _prefs!.getString(key);
          if (raw != null) {
            final list = (jsonDecode(raw) as List)
                .map((e) => FamilyModel.fromMap(Map<String, dynamic>.from(e)))
                .toList();
            _familyCache[uid] = list;
          }
        } else if (key.startsWith('mh_members_')) {
          final uid = key.replaceFirst('mh_members_', '');
          final raw = _prefs!.getString(key);
          if (raw != null) {
            final list = (jsonDecode(raw) as List)
                .map((e) => MemberModel.fromMap(Map<String, dynamic>.from(e)))
                .toList();
            _memberCache[uid] = list;
          }
        } else if (key.startsWith('mh_doctors_')) {
          final uid = key.replaceFirst('mh_doctors_', '');
          final raw = _prefs!.getString(key);
          if (raw != null) {
            final list = (jsonDecode(raw) as List)
                .map((e) => DoctorModel.fromMap(Map<String, dynamic>.from(e)))
                .toList();
            _doctorCache[uid] = list;
          }
        } else if (key.startsWith('mh_owner_')) {
          final uid = key.replaceFirst('mh_owner_', '');
          final raw = _prefs!.getString(key);
          if (raw != null) {
            _ownerCache[uid] =
                MemberModel.fromMap(Map<String, dynamic>.from(jsonDecode(raw)));
          }
        }
      }
    } catch (e) {
      debugPrint('OfflineDataService load error: $e');
    }
  }

  // ────────────────── Families ──────────────────
  static List<FamilyModel> getFamilies(String userId) {
    if (_familyCache.containsKey(userId)) {
      return List.unmodifiable(_familyCache[userId]!);
    }
    if (_prefs != null) {
      final raw = _prefs!.getString('mh_families_$userId');
      if (raw != null) {
        try {
          final list = (jsonDecode(raw) as List)
              .map((e) => FamilyModel.fromMap(Map<String, dynamic>.from(e)))
              .toList();
          _familyCache[userId] = list;
          return List.unmodifiable(list);
        } catch (_) {}
      }
    }
    return const [];
  }

  static Future<void> saveFamilies(
    String userId,
    List<FamilyModel> families,
  ) async {
    _familyCache[userId] = families;
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      _prefs = prefs;
      final encoded = jsonEncode(
        families
            .map(
              (f) => {
                'id': f.id,
                'family_id': f.familyId,
                'name': f.name,
                'contact': f.contact,
                'address': f.address,
                'user_id': f.userId,
                'created_at': f.createdAt.toIso8601String(),
              },
            )
            .toList(),
      );
      await prefs.setString('mh_families_$userId', encoded);
    } catch (e) {
      debugPrint('saveFamilies error: $e');
    }
  }

  // ────────────────── Members ──────────────────
  static List<MemberModel> getMembers(String userId) {
    if (_memberCache.containsKey(userId)) {
      return List.unmodifiable(_memberCache[userId]!);
    }
    if (_prefs != null) {
      final raw = _prefs!.getString('mh_members_$userId');
      if (raw != null) {
        try {
          final list = (jsonDecode(raw) as List)
              .map((e) => MemberModel.fromMap(Map<String, dynamic>.from(e)))
              .toList();
          _memberCache[userId] = list;
          return List.unmodifiable(list);
        } catch (_) {}
      }
    }
    return const [];
  }

  static Future<void> saveMembers(
    String userId,
    List<MemberModel> members,
  ) async {
    _memberCache[userId] = members;
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      _prefs = prefs;
      final encoded = jsonEncode(
        members
            .map(
              (m) => {
                'id': m.id,
                'family_id': m.familyId,
                'name': m.name,
                'relation': m.relation,
                'dob': m.dob?.toIso8601String(),
                'gender': m.gender,
                'blood_group': m.bloodGroup,
                'allergies': m.allergies,
                'notes': m.notes,
                'avatar_url': m.avatarUrl,
                'emergency_contact': m.emergencyContact,
                'parent_id': m.parentId,
                'created_at': m.createdAt.toIso8601String(),
              },
            )
            .toList(),
      );
      await prefs.setString('mh_members_$userId', encoded);
    } catch (e) {
      debugPrint('saveMembers error: $e');
    }
  }

  // ────────────────── Doctors ──────────────────
  static List<DoctorModel> getDoctors(String userId) {
    if (_doctorCache.containsKey(userId)) {
      return List.unmodifiable(_doctorCache[userId]!);
    }
    if (_prefs != null) {
      final raw = _prefs!.getString('mh_doctors_$userId');
      if (raw != null) {
        try {
          final list = (jsonDecode(raw) as List)
              .map((e) => DoctorModel.fromMap(Map<String, dynamic>.from(e)))
              .toList();
          _doctorCache[userId] = list;
          return List.unmodifiable(list);
        } catch (_) {}
      }
    }
    return const [];
  }

  static Future<void> saveDoctors(
    String userId,
    List<DoctorModel> doctors,
  ) async {
    _doctorCache[userId] = doctors;
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      _prefs = prefs;
      final encoded = jsonEncode(
        doctors
            .map(
              (d) => {
                'id': d.id,
                'user_id': d.userId,
                'name': d.name,
                'specialization': d.specialization,
                'hospital': d.hospital,
                'phone': d.phone,
                'email': d.email,
                'address': d.address,
                'avatar_url': d.avatarUrl,
                'qualification': d.qualification,
                'license_number': d.licenseNumber,
                'experience_years': d.experienceYears,
                'availability': d.availability,
                'notes': d.notes,
                'is_favorite': d.isFavorite,
                'created_at': d.createdAt.toIso8601String(),
              },
            )
            .toList(),
      );
      await prefs.setString('mh_doctors_$userId', encoded);
    } catch (e) {
      debugPrint('saveDoctors error: $e');
    }
  }

  // ────────────────── Owner Profile ──────────────────
  static MemberModel? getOwner(String userId) {
    if (_ownerCache.containsKey(userId)) {
      return _ownerCache[userId];
    }
    if (_prefs != null) {
      final raw = _prefs!.getString('mh_owner_$userId');
      if (raw != null) {
        try {
          final owner = MemberModel.fromMap(
            Map<String, dynamic>.from(jsonDecode(raw)),
          );
          _ownerCache[userId] = owner;
          return owner;
        } catch (_) {}
      }
    }
    return null;
  }

  static Future<void> saveOwner(String userId, MemberModel owner) async {
    _ownerCache[userId] = owner;
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      _prefs = prefs;
      final encoded = jsonEncode({
        'id': owner.id,
        'family_id': owner.familyId,
        'name': owner.name,
        'relation': owner.relation,
        'dob': owner.dob?.toIso8601String(),
        'gender': owner.gender,
        'blood_group': owner.bloodGroup,
        'allergies': owner.allergies,
        'notes': owner.notes,
        'avatar_url': owner.avatarUrl,
        'emergency_contact': owner.emergencyContact,
        'parent_id': owner.parentId,
        'created_at': owner.createdAt.toIso8601String(),
      });
      await prefs.setString('mh_owner_$userId', encoded);
    } catch (e) {
      debugPrint('saveOwner error: $e');
    }
  }

  // ────────────────── Member Doctors Mapping ──────────────────
  static Map<String, List<DoctorModel>> getMemberDoctors(String userId) {
    if (_memberDoctorCache.containsKey(userId)) {
      return _memberDoctorCache[userId]!;
    }
    if (_prefs != null) {
      final raw = _prefs!.getString('mh_member_doctors_$userId');
      if (raw != null) {
        try {
          final decoded = jsonDecode(raw) as Map<String, dynamic>;
          final map = <String, List<DoctorModel>>{};
          decoded.forEach((key, value) {
            map[key] = (value as List)
                .map((e) => DoctorModel.fromMap(Map<String, dynamic>.from(e)))
                .toList();
          });
          _memberDoctorCache[userId] = map;
          return map;
        } catch (_) {}
      }
    }
    return const {};
  }

  static Future<void> saveMemberDoctors(
    String userId,
    Map<String, List<DoctorModel>> mapping,
  ) async {
    _memberDoctorCache[userId] = mapping;
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      _prefs = prefs;
      final serializable = <String, dynamic>{};
      mapping.forEach((key, list) {
        serializable[key] = list
            .map(
              (d) => {
                'id': d.id,
                'user_id': d.userId,
                'name': d.name,
                'specialization': d.specialization,
                'hospital': d.hospital,
                'phone': d.phone,
                'email': d.email,
                'address': d.address,
                'avatar_url': d.avatarUrl,
                'qualification': d.qualification,
                'license_number': d.licenseNumber,
                'experience_years': d.experienceYears,
                'availability': d.availability,
                'notes': d.notes,
                'is_favorite': d.isFavorite,
                'created_at': d.createdAt.toIso8601String(),
              },
            )
            .toList();
      });
      await prefs.setString('mh_member_doctors_$userId', jsonEncode(serializable));
    } catch (e) {
      debugPrint('saveMemberDoctors error: $e');
    }
  }
}
