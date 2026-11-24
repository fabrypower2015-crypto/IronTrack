import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'providers/app_provider.dart';
import 'screens/lock_screen.dart';
import 'screens/main_shell.dart';
import 'screens/onboarding_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Inizializza la formattazione date in lingua italiana
  await initializeDateFormatting('it_IT', null);

  final appProvider = AppProvider();
  await appProvider.initialize();

  runApp(
    ChangeNotifierProvider<AppProvider>.value(
      value: appProvider,
      child: const IronTrackApp(),
    ),
  );
}

class IronTrackApp extends StatelessWidget {
  const IronTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, app, _) {
        final seedColor = AppTheme.accentColorById(app.profile.accentColor);

        return MaterialApp(
          title: 'IronTrack',
          debugShowCheckedModeBanner: false,
          themeMode: app.themeMode,
          theme: AppTheme.buildTheme(
            brightness: Brightness.light,
            seedColor: seedColor,
          ),
          darkTheme: AppTheme.buildTheme(
            brightness: Brightness.dark,
            seedColor: seedColor,
          ),
          home: _resolveHome(app),
        );
      },
    );
  }

  Widget _resolveHome(AppProvider app) {
    if (app.isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Caricamento IronTrack...'),
            ],
          ),
        ),
      );
    }

    if (!app.profile.onboardingCompleted) {
      return const OnboardingScreen();
    }

    if (app.profile.lockEnabled && !app.isUnlocked) {
      return const LockScreen();
    }

    return const MainShell();
  }
}