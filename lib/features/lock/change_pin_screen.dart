import 'package:debt_tracker/core/constants/app_constants.dart';
import 'package:debt_tracker/presentation/providers/security_controller.dart';
import 'package:debt_tracker/presentation/widgets/pin_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChangePinScreen extends ConsumerStatefulWidget {
  const ChangePinScreen({super.key});

  @override
  ConsumerState<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends ConsumerState<ChangePinScreen> {
  final List<String> _digits = <String>[];
  String? _currentPin;
  String? _firstNewPin;
  String? _error;
  int _step = 0; // 0: Enter current, 1: Choose length, 2: Enter new, 3: Confirm new
  int _chosenLength = 4;
  bool _verifying = false;

  void _append(String digit) {
    if (_verifying) return;
    
    int targetLength = _step == 0 
        ? (ref.read(securityControllerProvider).valueOrNull?.pinLength ?? AppConstants.maxPinLength)
        : _chosenLength;
        
    if (_digits.length >= targetLength) return;
    
    setState(() {
      _digits.add(digit);
      _error = null;
    });
    
    if (_digits.length == targetLength) {
      _continue();
    }
  }

  void _backspace() {
    if (_verifying || _digits.isEmpty) return;
    setState(() => _digits.removeLast());
  }

  void _clear() {
    if (_verifying) return;
    setState(() => _digits.clear());
  }

  Future<void> _continue() async {
    if (_step == 1) {
      setState(() => _step = 2);
      return;
    }
    
    final pin = _digits.join();
    
    if (_step == 0) {
      final targetLength = ref.read(securityControllerProvider).valueOrNull?.pinLength ?? AppConstants.maxPinLength;
      if (pin.length < targetLength) return;
      
      setState(() => _verifying = true);
      final isValid = await ref.read(securityControllerProvider.notifier).verifyPin(pin);
      
      if (!mounted) return;
      if (!isValid) {
        setState(() {
          _error = 'Incorrect current PIN.';
          _digits.clear();
          _verifying = false;
        });
        return;
      }
      
      setState(() {
        _currentPin = pin;
        _step = 1;
        _digits.clear();
        _verifying = false;
      });
      return;
    }
    
    if (pin.length < _chosenLength) return;
    
    if (_step == 2) {
      setState(() {
        _firstNewPin = pin;
        _step = 3;
        _digits.clear();
      });
      return;
    }
    
    if (_step == 3) {
      if (pin != _firstNewPin) {
        setState(() {
          _error = 'PINs do not match. Start again.';
          _firstNewPin = null;
          _step = 2;
          _digits.clear();
        });
        return;
      }

      await ref.read(securityControllerProvider.notifier).changePin(
        currentPin: _currentPin!,
        newPin: pin,
      );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN changed successfully.')),
        );
      }
    }
  }

  void _goBack() {
    if (_step == 1) {
      setState(() {
        _step = 0;
        _digits.clear();
        _error = null;
        _currentPin = null;
      });
    } else if (_step == 2) {
      setState(() {
        _step = 1;
        _digits.clear();
        _error = null;
      });
    } else if (_step == 3) {
      setState(() {
        _step = 2;
        _firstNewPin = null;
        _digits.clear();
        _error = null;
      });
    } else if (_step == 0) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final securityState = ref.watch(securityControllerProvider).valueOrNull;
    final currentPinLength = securityState?.pinLength ?? AppConstants.maxPinLength;
    
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _goBack,
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
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
                      child: Icon(Icons.lock_reset_rounded, size: 32, color: scheme.primary),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _step == 0 ? 'Current PIN' : _step == 1 ? 'Choose PIN Length' : _step == 3 ? 'Confirm New PIN' : 'Enter New PIN',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _step == 0 
                          ? 'Enter your current PIN to continue.'
                          : _step == 1
                          ? 'Select how many digits your new PIN should be.'
                          : _step == 3
                              ? 'Re-enter the same $_chosenLength-digit PIN to finish.'
                              : 'Enter a new $_chosenLength-digit PIN to protect your tracker.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 24),
                    if (_step == 1) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          children: [
                            Text(
                              '$_chosenLength digits',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: scheme.primary),
                            ),
                            Slider(
                              value: _chosenLength.toDouble(),
                              min: AppConstants.minPinLength.toDouble(),
                              max: AppConstants.maxPinLength.toDouble(),
                              divisions: AppConstants.maxPinLength - AppConstants.minPinLength,
                              onChanged: (value) {
                                setState(() => _chosenLength = value.toInt());
                              },
                            ),
                            const SizedBox(height: 32),
                            FilledButton(
                              onPressed: _continue,
                              style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 56)),
                              child: const Text('Continue'),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      PinDots(length: _digits.length, maxLength: _step == 0 ? currentPinLength : _chosenLength),
                      const SizedBox(height: 8),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: Text(
                          _error ?? '',
                          key: ValueKey(_error ?? 'ok'),
                          style: TextStyle(color: scheme.error, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(height: 20),
                      PinPad(
                        onDigit: _append,
                        onBackspace: _backspace,
                        onClear: _clear,
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
