import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/config/backend_mode.dart';
import 'core/localization/entry_strings.dart';
import 'data/demo/demo_providers.dart';
import 'core/startup/intro_host.dart';
import 'features/system/version_gate.dart';
import 'core/theme/app_theme.dart';
import 'core/aq/aq_tokens.dart';
import 'data/repositories/local_persistence.dart';

void main() {
  runApp(ProviderScope(overrides: kUseDemoBackend ? demoOverrides() : const [], child: const AqaratiApp()));
}

class AqaratiApp extends ConsumerWidget {
  const AqaratiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'AQARATI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: ThemeData(brightness: Brightness.dark, useMaterial3: true, scaffoldBackgroundColor: const Color(0xFF1A1613), colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF825C3F), brightness: Brightness.dark)),
      themeMode: ref.watch(themeModeProvider),
      // Material widgets interpolate with the same duration as the AQ palette (AQThemeTransition).
      themeAnimationDuration: WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations ? AQMotion.themeReduced : AQMotion.theme,
      themeAnimationCurve: Curves.easeInOutCubic,
      routerConfig: appRouter,
      // English at launch; Arabic (RTL) is architected in from day one —
      // add ar to supportedLocales + arb strings when Arabic ships.
      locale: ref.watch(localeProvider),
      builder: (context, child) {
        Widget app = AQLocalPersistence(child: AQThemeTransition(mode: ref.watch(themeModeProvider), child: IntroHost(child: AQVersionGate(child: child ?? const SizedBox.shrink()))));
        // QA only: `--dart-define=AQ_TEXT_SCALE=2.0` previews large-text layouts. Default 1.0 changes nothing.
        final scale = double.tryParse(const String.fromEnvironment('AQ_TEXT_SCALE')) ?? 1;
        if (scale != 1) app = MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)), child: app);
        return app;
      },
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
