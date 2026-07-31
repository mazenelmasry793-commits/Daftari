import 'dart:async';
import 'dart:ui';

import 'package:debt_tracker/core/constants/app_constants.dart';
import 'package:debt_tracker/presentation/providers/security_controller.dart';
import 'package:debt_tracker/presentation/widgets/pin_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  final List<String> _digits = <String>[];
  String? _error;
  int _failedAttempts = 0;
  DateTime? _lockedUntil;
  Timer? _lockTimer;

  @override
  void dispose() {
    _lockTimer?.cancel();
    super.dispose();
  }

  void _startLockTimer() {
    _lockTimer?.cancel();
    _lockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_lockedUntil != null && DateTime.now().isAfter(_lockedUntil!)) {
        timer.cancel();
        setState(() {
          _lockedUntil = null;
          _error = null;
        });
      } else {
        setState(() {});
      }
    });
  }

  void _handleFailure() {
    _failedAttempts++;
    int delaySeconds = 0;
    if (_failedAttempts >= 8) {
      delaySeconds = 300;
    } else if (_failedAttempts >= 6) {
      delaySeconds = 60;
    } else if (_failedAttempts >= 4) {
      delaySeconds = 15;
    }

    setState(() {
      if (delaySeconds > 0) {
        _lockedUntil = DateTime.now().add(Duration(seconds: delaySeconds));
        _error = null;
        _startLockTimer();
      } else {
        _error = 'Wrong PIN. Try again.';
      }
      _digits.clear();
    });
  }

  void _append(String digit) {
    if (_lockedUntil != null) return;
    final targetLength = ref.read(securityControllerProvider).valueOrNull?.pinLength ?? AppConstants.maxPinLength;
    if (_digits.length >= targetLength) return;
    setState(() {
      _digits.add(digit);
      _error = null;
    });
    if (_digits.length == targetLength) {
      _unlock();
    }
  }

  void _backspace() {
    if (_lockedUntil != null || _digits.isEmpty) return;
    setState(() => _digits.removeLast());
  }

  void _clear() {
    if (_lockedUntil != null) return;
    setState(() => _digits.clear());
  }

  Future<void> _unlock() async {
    if (_lockedUntil != null) return;
    final pin = _digits.join();
    if (pin.length < AppConstants.minPinLength) return;
    try {
      await ref.read(securityControllerProvider.notifier).unlock(pin);
      if (!mounted) return;
      _failedAttempts = 0;
      _clear();
    } catch (_) {
      _handleFailure();
    }
  }

  @override
  Widget build(BuildContext context) {
    final securityState = ref.watch(securityControllerProvider).valueOrNull;
    final targetLength = securityState?.pinLength ?? AppConstants.maxPinLength;
    final scheme = Theme.of(context).colorScheme;
    final isLocked = _lockedUntil != null && DateTime.now().isBefore(_lockedUntil!);
    final remainingSeconds = isLocked ? _lockedUntil!.difference(DateTime.now()).inSeconds : 0;
    final displayError = isLocked 
        ? 'Too many attempts. Try again in ${remainingSeconds}s.' 
        : (_error ?? '');

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
        child: Container(
          color: Colors.black.withValues(alpha: 0.6),
          child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      height: 64,
                      width: 64,
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(isLocked ? Icons.lock_clock_rounded : Icons.lock_outline_rounded, size: 32, color: scheme.primary),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Enter PIN',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w400),
                    ),
                    const SizedBox(height: 24),
                    PinDots(length: _digits.length, maxLength: targetLength),
                    const SizedBox(height: 8),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: Text(
                        displayError,
                        key: ValueKey(displayError.isEmpty ? 'ok' : displayError),
                        style: TextStyle(color: scheme.error, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Opacity(
                      opacity: isLocked ? 0.5 : 1.0,
                      child: IgnorePointer(
                        ignoring: isLocked,
                        child: PinPad(
                          onDigit: _append,
                          onBackspace: _backspace,
                          onClear: _clear,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ))),
    );
  }
}
