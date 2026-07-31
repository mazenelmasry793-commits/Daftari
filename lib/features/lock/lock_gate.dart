import 'package:debt_tracker/core/constants/app_constants.dart';
import 'package:debt_tracker/features/lock/lock_screen.dart';
import 'package:debt_tracker/features/lock/pin_setup_screen.dart';
import 'package:debt_tracker/presentation/providers/app_providers.dart';
import 'package:debt_tracker/presentation/providers/security_controller.dart';
import 'package:debt_tracker/presentation/shell/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LockGate extends ConsumerStatefulWidget {
  const LockGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<LockGate> createState() => _LockGateState();
}

class _LockGateState extends ConsumerState<LockGate> {
  bool _isLockScreenShown = false;
  bool _isSetupScreenShown = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _handleSecurityState(ref.read(securityControllerProvider).valueOrNull);
  }

  void _handleSecurityState(SecurityState? state) {
    if (state == null) return;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final navigator = Navigator.of(context, rootNavigator: true);
      
      if (state.requiresSetup && !_isSetupScreenShown) {
        _isSetupScreenShown = true;
        navigator.push(
          PageRouteBuilder(
            opaque: false,
            pageBuilder: (_, __, ___) => const PinSetupScreen(),
          ),
        ).then((_) => _isSetupScreenShown = false);
      } else if (!state.requiresSetup && _isSetupScreenShown) {
        navigator.pop();
        _isSetupScreenShown = false;
      }

      if (state.requiresLock && !_isLockScreenShown) {
        _isLockScreenShown = true;
        navigator.push(
          PageRouteBuilder(
            opaque: false,
            pageBuilder: (_, __, ___) => const LockScreen(),
          ),
        ).then((_) => _isLockScreenShown = false);
      } else if (!state.requiresLock && _isLockScreenShown) {
        navigator.pop();
        _isLockScreenShown = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bootstrap = ref.watch(appBootstrapProvider);
    final security = ref.watch(securityControllerProvider);

    ref.listen<AsyncValue<SecurityState>>(securityControllerProvider, (previous, next) {
      _handleSecurityState(next.valueOrNull);
    });

    if (bootstrap.isLoading || security.isLoading) {
      return const _SplashScreen();
    }

    if (bootstrap.hasError || security.hasError) {
      return _ErrorScreen(
        message: bootstrap.error?.toString() ?? security.error?.toString() ?? 'Something went wrong.',
        onRetry: () {
          ref.invalidate(appBootstrapProvider);
          ref.invalidate(securityControllerProvider);
        },
      );
    }

    return widget.child;
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.primary.withValues(alpha: 0.12),
              scheme.surface,
              scheme.secondary.withValues(alpha: 0.08),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                height: 100,
                width: 100,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Icon(Icons.lock_outline_rounded, size: 48, color: scheme.primary),
              ),
              const SizedBox(height: 24),
              Text(
                AppConstants.appName,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48),
              const SizedBox(height: 16),
              Text(
                'Startup failed',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              FilledButton(onPressed: onRetry, child: const Text('Try Again')),
            ],
          ),
        ),
      ),
    );
  }
}

