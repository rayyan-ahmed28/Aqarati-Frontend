import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/aq/aq_forms.dart';
import '../../core/aq/aq_primitives.dart';
import '../../core/aq/aq_scene.dart';
import '../../core/aq/aq_tokens.dart';
import '../../core/aq/aq_typography.dart';
import '../../core/config/app_version.dart';
import '../../core/config/backend_mode.dart';
import '../../core/localization/flow_strings.dart';
import '../../data/api/account_api.dart' show ApiErrorCode, ApiException;

/// GET /app/config (section 35): minimum supported version and flags.
class AppConfig {
  final String minSupportedVersion;
  const AppConfig({required this.minSupportedVersion});
}

abstract class AppConfigRepository {
  Future<AppConfig> load();
}

class UnavailableAppConfigRepository implements AppConfigRepository {
  const UnavailableAppConfigRepository();
  @override
  Future<AppConfig> load() async => throw const ApiException(ApiErrorCode.network);
}

/// DEMO: never blocks unless a QA build asks for it with `?minVersion=9.9.9` (web, review tools on).
class DemoAppConfigRepository implements AppConfigRepository {
  const DemoAppConfigRepository();
  @override
  Future<AppConfig> load() async {
    final qa = kShowReviewTools && kIsWeb ? Uri.base.queryParameters['minVersion'] : null;
    return AppConfig(minSupportedVersion: qa ?? kAppVersion);
  }
}

final appConfigRepositoryProvider = Provider<AppConfigRepository>((ref) => kUseDemoBackend ? const DemoAppConfigRepository() : const UnavailableAppConfigRepository());
final appConfigProvider = FutureProvider<AppConfig>((ref) => ref.watch(appConfigRepositoryProvider).load());

/// Wraps the app. Only a confirmed minimum version above this build blocks it; a failed config call
/// never blocks (the compiled configuration is used, section 18.4).
class AQVersionGate extends ConsumerWidget {
  final Widget child;
  const AQVersionGate({super.key, required this.child});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cfg = ref.watch(appConfigProvider).valueOrNull;
    if (cfg != null && compareVersions(kAppVersion, cfg.minSupportedVersion) < 0) return ForcedUpdateScreen(minVersion: cfg.minSupportedVersion);
    return child;
  }
}

class ForcedUpdateScreen extends ConsumerWidget {
  final String minVersion;
  const ForcedUpdateScreen({super.key, required this.minVersion});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final loading = ref.watch(appConfigProvider).isLoading;
    return Scaffold(
      backgroundColor: c.background,
      body: Stack(fit: StackFit.expand, children: [
        const AQBackdrop(asset: 'assets/entry/oman_terrace_2k.jpg', quiet: true),
        SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AQSpacing.maxContent),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AQSpacing.gutter),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  AQIcon('refresh', size: 56, color: c.accentDeep),
                  const SizedBox(height: AQSpacing.x4),
                  Semantics(header: true, child: Text(f.t('upd.title'), textAlign: TextAlign.center, style: AQTypography.of(context, AQText.displaySmall))),
                  const SizedBox(height: AQSpacing.x3),
                  Text(f.t('upd.body'), textAlign: TextAlign.center, style: AQTypography.of(context, AQText.bodyLarge, soft: true)),
                  const SizedBox(height: AQSpacing.x3),
                  Text(f.t('upd.versions', {'have': kAppVersion, 'need': minVersion}), textAlign: TextAlign.center, style: AQTypography.of(context, AQText.bodySmall, soft: true)),
                  const SizedBox(height: AQSpacing.x6),
                  AQErrorBanner(tone: AQBannerTone.info, text: f.t('upd.store')),
                  AQPrimaryButton(label: f.t('upd.check'), loading: loading, trailingChevron: false, onPressed: () => ref.invalidate(appConfigProvider)),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
