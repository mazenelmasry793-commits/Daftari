import 'package:debt_tracker/core/constants/app_constants.dart';
import 'package:debt_tracker/core/platform/ios_navigation_channel.dart';
import 'package:debt_tracker/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:debt_tracker/presentation/shell/app_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: DebtTrackerApp()));
}

class DebtTrackerApp extends StatelessWidget {
  const DebtTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      navigatorObservers: [iosNavigationRouteObserver],
      builder: (context, child) {
        return child!;
      },
      home: const AppShell(),
    );
  }
}
