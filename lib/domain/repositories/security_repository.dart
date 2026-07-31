class SecuritySnapshot {
  const SecuritySnapshot({
    required this.hasPin,
    required this.enabled,
    required this.salt,
    required this.hash,
    this.pinLength,
    this.hashVersion = '1',
  });

  final bool hasPin;
  final bool enabled;
  final String? salt;
  final String? hash;
  final int? pinLength;
  final String? hashVersion;
}

abstract class SecurityRepository {
  Future<SecuritySnapshot> load();
  Future<void> setPin(String pin);
  Future<bool> verifyPin(String pin);
  Future<void> changePin({
    required String currentPin,
    required String newPin,
  });
  Future<void> disablePin();
  Future<void> enablePin();
  Future<void> clearAllSecurity();
}

