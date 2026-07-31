import 'package:debt_tracker/domain/repositories/security_repository.dart';
import 'package:debt_tracker/presentation/providers/app_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SecurityState {
  const SecurityState({
    required this.hasPin,
    required this.enabled,
    required this.unlocked,
    this.pinLength,
  });

  const SecurityState.initial()
      : hasPin = false,
        enabled = false,
        pinLength = null,
        unlocked = false;

  final bool hasPin;
  final bool enabled;
  final bool unlocked;
  final int? pinLength;

  bool get requiresSetup => !hasPin;
  bool get requiresLock => hasPin && enabled && !unlocked;
  bool get canUseApp => !requiresSetup && (!enabled || unlocked);

  SecurityState copyWith({
    bool? hasPin,
    bool? enabled,
    bool? unlocked,
    int? pinLength,
  }) {
    return SecurityState(
      hasPin: hasPin ?? this.hasPin,
      enabled: enabled ?? this.enabled,
      unlocked: unlocked ?? this.unlocked,
      pinLength: pinLength ?? this.pinLength,
    );
  }
}

final securityControllerProvider =
    AsyncNotifierProvider<SecurityController, SecurityState>(SecurityController.new);

class SecurityController extends AsyncNotifier<SecurityState> {
  SecurityRepository get _repo => ref.read(securityRepositoryProvider);

  @override
  Future<SecurityState> build() async {
    await ref.watch(appBootstrapProvider.future);
    final snapshot = await _repo.load();
    return SecurityState(
      hasPin: snapshot.hasPin,
      enabled: snapshot.enabled,
      unlocked: !snapshot.hasPin || !snapshot.enabled,
      pinLength: snapshot.pinLength,
    );
  }

  Future<void> setupPin(String pin) async {
    state = const AsyncLoading();
    await _repo.setPin(pin);
    state = AsyncData(SecurityState(hasPin: true, enabled: true, unlocked: true, pinLength: pin.length));
  }

  Future<bool> verifyPin(String pin) async {
    return await _repo.verifyPin(pin);
  }

  Future<void> unlock(String pin) async {
    final current = state.value ?? const SecurityState.initial();
    if (!await _repo.verifyPin(pin)) {
      throw StateError('Invalid PIN.');
    }
    state = AsyncData(current.copyWith(hasPin: true, enabled: true, unlocked: true));
  }

  Future<void> changePin({
    required String currentPin,
    required String newPin,
  }) async {
    await _repo.changePin(currentPin: currentPin, newPin: newPin);
    state = AsyncData((state.value ?? const SecurityState.initial()).copyWith(
      hasPin: true,
      enabled: true,
      unlocked: true,
      pinLength: newPin.length,
    ));
  }

  Future<void> disablePin() async {
    await _repo.disablePin();
    final current = state.value ?? const SecurityState.initial();
    state = AsyncData(current.copyWith(enabled: false, unlocked: true, hasPin: true));
  }

  Future<void> enablePin() async {
    await _repo.enablePin();
    final current = state.value ?? const SecurityState.initial();
    state = AsyncData(current.copyWith(enabled: true, unlocked: true, hasPin: true));
  }

  Future<void> lockSession() async {
    final current = state.value ?? const SecurityState.initial();
    if (current.hasPin && current.enabled) {
      state = AsyncData(current.copyWith(unlocked: false));
    }
  }

  Future<void> resetSecurity() async {
    await _repo.clearAllSecurity();
    state = const AsyncData(SecurityState.initial());
  }
}
