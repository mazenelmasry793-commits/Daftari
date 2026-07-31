import 'package:debt_tracker/core/constants/app_constants.dart';
import 'package:debt_tracker/presentation/providers/security_controller.dart';
import 'package:debt_tracker/presentation/widgets/pin_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PinSetupScreen extends ConsumerStatefulWidget {
  const PinSetupScreen({super.key});

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  final List<String> _digits = <String>[];
  String? _firstPin;
  String? _error;
  int _step = 1;
  int _chosenLength = 4;

  void _append(String digit) {
    if (_digits.length >= _chosenLength) {
      return;
    }
    setState(() {
      _digits.add(digit);
      _error = null;
    });
    
    if (_digits.length == _chosenLength) {
      // Small delay for UI feedback
      Future.delayed(const Duration(milliseconds: 150), _continue);
    }
  }

  void _backspace() {
    if (_digits.isEmpty) return;
    setState(() => _digits.removeLast());
  }

  void _clear() {
    setState(() => _digits.clear());
  }

  Future<void> _continue() async {
    if (_step == 1) {
      setState(() => _step = 2);
      return;
    }
    
    final pin = _digits.join();
    if (pin.length < _chosenLength) return;
    
    if (_step == 2) {
      setState(() {
        _firstPin = pin;
        _step = 3;
        _digits.clear();
      });
      return;
    }
    
    if (pin != _firstPin) {
      setState(() {
        _error = 'PINs do not match. Start again.';
        _firstPin = null;
        _step = 2;
        _digits.clear();
      });
      return;
    }

    await ref.read(securityControllerProvider.notifier).setupPin(pin);
  }

  void _goBack() {
    if (_step == 2) {
      setState(() {
        _step = 1;
        _digits.clear();
        _error = null;
      });
    } else if (_step == 3) {
      setState(() {
        _step = 2;
        _firstPin = null;
        _digits.clear();
        _error = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: _step > 1
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: _goBack,
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
            )
          : null,
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
                      height: 96,
                      width: 96,
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Icon(Icons.lock_reset_rounded, size: 46, color: scheme.primary),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _step == 1 ? 'Choose PIN Length' : _step == 3 ? 'Confirm your PIN' : 'Create a PIN',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _step == 1
                          ? 'Select how many digits your PIN should be.'
                          : _step == 3
                              ? 'Re-enter the same $_chosenLength-digit PIN to finish setup.'
                              : 'Enter a $_chosenLength-digit PIN to protect your tracker.',
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
                      PinDots(length: _digits.length, maxLength: _chosenLength),
                      const SizedBox(height: 12),
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
