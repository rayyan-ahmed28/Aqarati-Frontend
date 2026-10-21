import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/aq/aq_demo.dart';
import '../../core/aq/aq_forms.dart';
import '../../core/aq/aq_primitives.dart';
import '../../core/aq/aq_scene.dart';
import '../../core/aq/aq_tokens.dart';
import '../../core/aq/aq_typography.dart';
import '../../core/auth/auth_repository.dart';
import '../../core/config/backend_mode.dart';
import '../../core/localization/flow_strings.dart';
import '../../data/api/account_api.dart';
import '../../data/repositories/app_state_providers.dart';
import '../notifications/notifications.dart';
import '../viewing/domain/viewing_presentation.dart' show AQTone;
import '../viewing/widgets/viewing_components.dart';
import '../viewing/widgets/viewing_scaffold.dart';

enum _Stage { info, confirm, working, done }

/// Delete account: what changes, an explicit confirmation, a real attempt, and an honest result.
/// If the request cannot be processed, nothing is deleted and the person stays signed in. Only after
/// a successful result is the person signed out and the local data cleared.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});
  @override
  ConsumerState<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  _Stage _stage = _Stage.info;
  bool _forward = true;
  bool _ack = false, _tried = false, _busy = false;
  String? _errorKey;
  final _word = TextEditingController();

  @override
  void dispose() {
    _word.dispose();
    super.dispose();
  }

  void _go(_Stage s) => setState(() {
        _forward = s.index > _stage.index;
        _stage = s;
      });

  Future<void> _delete(FlowStrings f) async {
    setState(() => _tried = true);
    if (_word.text.trim() != f.t('del.word') || !_ack || _busy) return;
    setState(() {
      _busy = true;
      _errorKey = null;
      _forward = true;
      _stage = _Stage.working;
    });
    try {
      await ref.read(accountApiProvider).deleteAccount();
    } catch (_) {
      // Nothing was deleted: stay signed in and let the person retry.
      if (mounted) {
        setState(() {
          _busy = false;
          _errorKey = 'del.error';
          _forward = false;
          _stage = _Stage.confirm;
        });
      }
      return;
    }
    // Success: sign out and clear what this device kept.
    try {
      await ref.read(authRepositoryProvider).signOut();
    } catch (_) {}
    ref.read(savedPropertyIdsProvider.notifier).state = {};
    ref.read(recentSearchesProvider.notifier).state = [];
    ref.read(readNotificationsProvider.notifier).state = {};
    ref.invalidate(meProvider);
    ref.invalidate(verificationProvider);
    AQHaptics.success();
    if (mounted) {
      setState(() {
        _busy = false;
        _forward = true;
        _stage = _Stage.done;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final me = ref.watch(meProvider);
    final signedIn = me.valueOrNull != null;
    final done = _stage == _Stage.done;

    Widget body;
    Widget? bottom;
    switch (_stage) {
      case _Stage.info:
        if (!signedIn && !me.isLoading) {
          body = AQNoticeCard(icon: 'info', title: f.t('del.signedOut.t'), body: f.t('del.signedOut.b'));
          bottom = AQBottomActionBar(primary: AQPrimaryButton(label: f.t('guest.login'), trailingChevron: false, onPressed: () => context.push('/login')));
        } else {
          body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            AQSurface(
              padding: const EdgeInsets.all(AQSpacing.x4),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (final k in ['del.c1', 'del.c2', 'del.c3', 'del.c4', 'del.c5', 'del.c6'])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AQSpacing.x1),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Padding(padding: const EdgeInsets.only(top: 3), child: AQIcon(k == 'del.c6' ? 'alert' : 'info', size: AQIconSize.small, color: k == 'del.c6' ? c.danger : c.accent)),
                      const SizedBox(width: AQSpacing.x3),
                      Expanded(child: Text(f.t(k), style: AQTypography.of(context, AQText.bodyMedium, color: k == 'del.c6' ? c.danger : null))),
                    ]),
                  ),
              ]),
            ),
            const SizedBox(height: AQSpacing.x3),
            const AQDemoNotice(),
          ]);
          bottom = AQBottomActionBar(
            primary: AQPrimaryButton(label: f.t('del.keep'), trailingChevron: false, onPressed: () => aqBack(context, '/app/account')),
            secondary: AQBarSecondaryButton(label: f.t('del.continue'), onPressed: signedIn ? () => _go(_Stage.confirm) : null, foreground: c.danger),
          );
        }
      case _Stage.confirm:
        final wordBad = _tried && _word.text.trim() != f.t('del.word');
        body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          AQTextField(label: f.t('del.field'), hint: f.t('del.word'), controller: _word, error: wordBad ? f.t('del.err.word') : null, onChanged: (_) => setState(() {})),
          AQCheckRow(value: _ack, label: f.t('del.ack'), error: _tried && !_ack ? f.t('del.err.ack') : null, onChanged: (v) => setState(() => _ack = v)),
          if (_errorKey != null) Padding(padding: const EdgeInsets.only(top: AQSpacing.x3), child: AQErrorBanner(text: f.t(_errorKey!))),
        ]);
        bottom = AQBottomActionBar(
          primary: AQPrimaryButton(label: f.t('del.keep'), trailingChevron: false, onPressed: () => aqBack(context, '/app/account')),
          secondary: AQBarSecondaryButton(label: f.t('del.submit'), onPressed: () => _delete(f), foreground: c.danger),
        );
      case _Stage.working:
        body = Column(children: [
          const SizedBox(height: AQSpacing.x8),
          Center(child: Semantics(label: f.t('del.working'), liveRegion: true, child: SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 2.5, color: c.accent)))),
          const SizedBox(height: AQSpacing.x4),
          Text(f.t('del.working'), textAlign: TextAlign.center, style: AQTypography.of(context, AQText.titleMedium)),
        ]);
      case _Stage.done:
        body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          AQNoticeCard(icon: 'check', title: f.t('del.done.t'), body: f.t('del.done.b'), tone: AQTone.success),
          // Demo builds only removed the simulated session account: say so instead of implying a server deletion.
          if (kUseDemoBackend) ...[const SizedBox(height: AQSpacing.x3), AQErrorBanner(tone: AQBannerTone.info, text: f.t('del.done.demo'))],
        ]);
        bottom = AQBottomActionBar(primary: AQPrimaryButton(label: f.t('del.done.cta'), trailingChevron: false, onPressed: () => context.go('/entry')));
    }

    return AQViewingScaffold(
      title: done ? null : (_stage == _Stage.confirm ? f.t('del.confirm.title') : f.t('del.title')),
      subtitle: done ? null : (_stage == _Stage.confirm ? f.t('del.confirm.sub') : f.t('del.sub')),
      backLabel: f.t('common.back'),
      showBack: !done && _stage != _Stage.working,
      onBack: () => _stage == _Stage.confirm ? _go(_Stage.info) : aqBack(context, '/app/account'),
      bottom: bottom,
      children: [AQStepSwitcher(stepKey: _stage, forward: _forward, child: body)],
    );
  }
}
