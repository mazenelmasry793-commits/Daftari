import 'package:debt_tracker/core/constants/app_constants.dart';
import 'package:debt_tracker/core/utils/pin_hash.dart';
import 'package:debt_tracker/domain/repositories/security_repository.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PinStorage implements SecurityRepository {
  PinStorage({FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<SecuritySnapshot> load() async {
    final enabled = (await _storage.read(key: AppConstants.secureStoragePinEnabledKey)) == 'true';
    final salt = await _storage.read(key: AppConstants.secureStoragePinSaltKey);
    final hash = await _storage.read(key: AppConstants.secureStoragePinHashKey);
    final hashVersion = await _storage.read(key: AppConstants.secureStoragePinHashVersionKey);
    final lengthStr = await _storage.read(key: AppConstants.secureStoragePinLengthKey);
    return SecuritySnapshot(
      hasPin: salt != null && hash != null,
      enabled: enabled,
      salt: salt,
      hash: hash,
      pinLength: lengthStr != null ? int.tryParse(lengthStr) : null,
      hashVersion: hashVersion ?? '1',
    );
  }

  @override
  Future<void> setPin(String pin) async {
    final salt = PinHash.generateSalt();
    final hash = PinHash.hashPinPbkdf2(pin: pin, salt: salt);
    await _storage.write(key: AppConstants.secureStoragePinSaltKey, value: salt);
    await _storage.write(key: AppConstants.secureStoragePinHashKey, value: hash);
    await _storage.write(key: AppConstants.secureStoragePinLengthKey, value: pin.length.toString());
    await _storage.write(key: AppConstants.secureStoragePinHashVersionKey, value: '3');
    await _storage.write(key: AppConstants.secureStoragePinEnabledKey, value: 'true');
  }

  @override
  Future<bool> verifyPin(String pin) async {
    final snapshot = await load();
    if (!snapshot.hasPin || snapshot.salt == null || snapshot.hash == null) {
      return false;
    }
    
    if (snapshot.hashVersion == '3') {
      return PinHash.hashPinPbkdf2(pin: pin, salt: snapshot.salt!) == snapshot.hash;
    } else if (snapshot.hashVersion == '2') {
      final v2Match = PinHash.hashPinPbkdf2(pin: pin, salt: snapshot.salt!, iterations: 10000) == snapshot.hash;
      if (v2Match) {
        final newHash = PinHash.hashPinPbkdf2(pin: pin, salt: snapshot.salt!);
        await _storage.write(key: AppConstants.secureStoragePinHashKey, value: newHash);
        await _storage.write(key: AppConstants.secureStoragePinHashVersionKey, value: '3');
      }
      return v2Match;
    } else {
      final legacyMatch = PinHash.hashPin(pin: pin, salt: snapshot.salt!) == snapshot.hash;
      if (legacyMatch) {
        final newHash = PinHash.hashPinPbkdf2(pin: pin, salt: snapshot.salt!);
        await _storage.write(key: AppConstants.secureStoragePinHashKey, value: newHash);
        await _storage.write(key: AppConstants.secureStoragePinHashVersionKey, value: '3');
      }
      return legacyMatch;
    }
  }

  @override
  Future<void> changePin({
    required String currentPin,
    required String newPin,
  }) async {
    if (!await verifyPin(currentPin)) {
      throw StateError('Current PIN is incorrect.');
    }
    await setPin(newPin);
  }

  @override
  Future<void> disablePin() async {
    await _storage.write(key: AppConstants.secureStoragePinEnabledKey, value: 'false');
  }

  @override
  Future<void> enablePin() async {
    final snapshot = await load();
    if (!snapshot.hasPin) {
      throw StateError('No PIN exists yet.');
    }
    await _storage.write(key: AppConstants.secureStoragePinEnabledKey, value: 'true');
  }

  @override
  Future<void> clearAllSecurity() async {
    await _storage.delete(key: AppConstants.secureStoragePinEnabledKey);
    await _storage.delete(key: AppConstants.secureStoragePinSaltKey);
    await _storage.delete(key: AppConstants.secureStoragePinHashKey);
    await _storage.delete(key: AppConstants.secureStoragePinLengthKey);
    await _storage.delete(key: AppConstants.secureStoragePinHashVersionKey);
  }
}
