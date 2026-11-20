import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

class TemporaryShareCrypto {
  static const _magic = [0x4d, 0x48, 0x53, 0x31];
  static const _saltLength = 16;
  static const _nonceLength = 12;
  static const _macLength = 16;
  static const _iterations = 210000;

  static final _random = Random.secure();
  static final _cipher = AesGcm.with256bits();
  static final _keyDeriver = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: _iterations,
    bits: 256,
  );

  static String generateTemporaryId() {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final raw = List.generate(
      12,
      (_) => alphabet[_random.nextInt(alphabet.length)],
    ).join();
    return '${raw.substring(0, 4)}-${raw.substring(4, 8)}-${raw.substring(8)}';
  }

  static String generateOtp() =>
      _random.nextInt(1000000).toString().padLeft(6, '0');

  static String generateSecretToken({int bytes = 32}) =>
      base64Url.encode(_randomBytes(bytes)).replaceAll('=', '');

  static Future<Uint8List> encrypt({
    required Uint8List clearBytes,
    required String temporaryId,
    required String otp,
    Uint8List? salt,
  }) async {
    final resolvedSalt = salt ?? _randomBytes(_saltLength);
    final nonce = _randomBytes(_nonceLength);
    final secretKey = await _deriveKey(temporaryId, otp, resolvedSalt);
    final box = await _cipher.encrypt(
      clearBytes,
      secretKey: secretKey,
      nonce: nonce,
    );
    return Uint8List.fromList([
      ..._magic,
      ...resolvedSalt,
      ...box.nonce,
      ...box.mac.bytes,
      ...box.cipherText,
    ]);
  }

  static Future<Uint8List> decrypt({
    required Uint8List encryptedBytes,
    required String temporaryId,
    required String otp,
  }) async {
    final minimumLength =
        _magic.length + _saltLength + _nonceLength + _macLength;
    if (encryptedBytes.length <= minimumLength ||
        !_hasExpectedMagic(encryptedBytes)) {
      throw const FormatException('Invalid temporary medical record.');
    }
    var offset = _magic.length;
    final salt = encryptedBytes.sublist(offset, offset += _saltLength);
    final nonce = encryptedBytes.sublist(offset, offset += _nonceLength);
    final mac = encryptedBytes.sublist(offset, offset += _macLength);
    final cipherText = encryptedBytes.sublist(offset);
    final secretKey = await _deriveKey(temporaryId, otp, salt);
    final clearBytes = await _cipher.decrypt(
      SecretBox(cipherText, nonce: nonce, mac: Mac(mac)),
      secretKey: secretKey,
    );
    return Uint8List.fromList(clearBytes);
  }

  static Future<SecretKey> _deriveKey(
    String temporaryId,
    String otp,
    List<int> salt,
  ) {
    final normalizedId = temporaryId.trim().toUpperCase();
    return _keyDeriver.deriveKey(
      secretKey: SecretKey(utf8.encode('$normalizedId:$otp')),
      nonce: salt,
    );
  }

  static bool _hasExpectedMagic(Uint8List bytes) {
    for (var index = 0; index < _magic.length; index++) {
      if (bytes[index] != _magic[index]) return false;
    }
    return true;
  }

  static Uint8List _randomBytes(int length) =>
      Uint8List.fromList(List.generate(length, (_) => _random.nextInt(256)));
}
