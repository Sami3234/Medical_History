import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:medical_history/services/temporary_share/temporary_share_crypto.dart';

void main() {
  test('temporary IDs and passcodes use the expected safe format', () {
    final temporaryId = TemporaryShareCrypto.generateTemporaryId();
    final otp = TemporaryShareCrypto.generateOtp();

    expect(
      temporaryId,
      matches(RegExp(r'^[A-Z2-9]{4}-[A-Z2-9]{4}-[A-Z2-9]{4}$')),
    );
    expect(otp, matches(RegExp(r'^\d{6}$')));
  });

  test(
    'temporary payload encrypts and decrypts with ID and passcode',
    () async {
      final clearBytes = Uint8List.fromList(
        utf8.encode('private medical record'),
      );
      const temporaryId = 'ABCD-EFGH-2345';
      const otp = '123456';

      final encrypted = await TemporaryShareCrypto.encrypt(
        clearBytes: clearBytes,
        temporaryId: temporaryId,
        otp: otp,
      );
      final decrypted = await TemporaryShareCrypto.decrypt(
        encryptedBytes: encrypted,
        temporaryId: temporaryId,
        otp: otp,
      );

      expect(encrypted, isNot(equals(clearBytes)));
      expect(decrypted, clearBytes);
    },
  );

  test('wrong passcode cannot decrypt a temporary payload', () async {
    final encrypted = await TemporaryShareCrypto.encrypt(
      clearBytes: Uint8List.fromList([1, 2, 3, 4]),
      temporaryId: 'ABCD-EFGH-2345',
      otp: '123456',
    );

    expect(
      () => TemporaryShareCrypto.decrypt(
        encryptedBytes: encrypted,
        temporaryId: 'ABCD-EFGH-2345',
        otp: '654321',
      ),
      throwsA(anything),
    );
  });

  test('tampered encrypted payload is rejected', () async {
    final encrypted = await TemporaryShareCrypto.encrypt(
      clearBytes: Uint8List.fromList([10, 20, 30, 40]),
      temporaryId: 'ABCD-EFGH-2345',
      otp: '123456',
    );
    encrypted[encrypted.length - 1] ^= 0xff;

    expect(
      () => TemporaryShareCrypto.decrypt(
        encryptedBytes: encrypted,
        temporaryId: 'ABCD-EFGH-2345',
        otp: '123456',
      ),
      throwsA(anything),
    );
  });
}
