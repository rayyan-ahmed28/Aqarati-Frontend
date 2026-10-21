import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/aq/aq_demo.dart';
import '../../core/aq/aq_forms.dart';
import '../../core/aq/aq_kit.dart';
import '../../core/aq/aq_primitives.dart';
import '../../core/aq/aq_scene.dart';
import '../../core/aq/aq_tokens.dart';
import '../../core/aq/aq_typography.dart';
import '../../core/config/backend_mode.dart';
import '../../core/domain/account_models.dart';
import '../../core/localization/flow_strings.dart';
import '../../data/api/account_api.dart' show ApiException, ApiErrorCode, meProvider;
import '../devbuild/db_models.dart' show omanGovernorates;
import '../devbuild/db_widgets.dart' show DbPillRow, DbSelectField, dbGovLabel, showDbChoiceSheet;
import '../help/help.dart';
import '../listings/listing_models.dart' show ListingFile;
import '../listings/listing_widgets.dart' show ListingDocSlot, listingDate, listingFilePickerProvider, listingFileAcceptable;
import '../maintenance/maintenance_models.dart';
import '../viewing/widgets/viewing_format.dart';
import '../viewing/widgets/viewing_scaffold.dart';
import 'provider_data.dart';

bool _passwordOk(String p) => p.length >= 8 && p.contains(RegExp(r'[A-Z]')) && p.contains(RegExp(r'[0-9]'));

AQPillTone requestTone(MaintenanceStatus s) => switch (s) {
      MaintenanceStatus.requested => AQPillTone.pending,
      MaintenanceStatus.confirmed => AQPillTone.success,
      MaintenanceStatus.completed => AQPillTone.neutral,
      MaintenanceStatus.declined || MaintenanceStatus.cancelled => AQPillTone.danger,
    };

/// Invitation link: validate the token, then account, company, services and area, review, accept.
class ProviderInvitationScreen extends ConsumerStatefulWidget {
  final String token;
  const ProviderInvitationScreen({super.key, required this.token});
  @override
  ConsumerState<ProviderInvitationScreen> createState() => _ProviderInvitationScreenState();
}

class _ProviderInvitationScreenState extends ConsumerState<ProviderInvitationScreen> {
  int _step = -1; // -1 = invitation overview
  bool _forward = true, _tried = false, _busy = false;
  String? _error;
  ProviderApplication _app = const ProviderApplication();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _company = TextEditingController();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  bool _prefilled = false;

  static const _steps = ['account', 'company', 'services', 'review'];

  @override
  void dispose() {
    for (final c in [_password, _confirm, _company, _first, _last, _phone, _address]) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, String> _errors() {
    final all = _app.validate();
    return switch (_steps[_step]) {
      'account' => {if (!_passwordOk(_password.text)) 'password': 'err.passwordRules', if (_confirm.text != _password.text) 'confirm': 'err.passwordMismatch'},
      'company' => {for (final k in ['company', 'first', 'last', 'phone', 'address']) if (all[k] != null) k: all[k]!},
      'services' => {for (final k in ['services', 'governorate', 'wilayats']) if (all[k] != null) k: all[k]!},
      _ => const {},
    };
  }

  String? _e(String k) => _tried ? (_errors()[k] == null ? null : FlowStrings.of(context).t(_errors()[k]!)) : null;

  void _go(int s) => setState(() {
        _forward = s > _step;
        _step = s;
        _tried = false;
        _error = null;
      });

  void _next() {
    if (_errors().isNotEmpty) {
      setState(() => _tried = true);
      return;
    }
    _go(_step + 1);
  }

  Future<void> _accept() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(providerRepositoryProvider).accept(widget.token, _app, _password.text);
      ref.invalidate(meProvider);
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(FlowStrings.of(context).t('prv.created'))));
      context.go('/provider/documents');
    } on ApiException catch (e) {
      setState(() => _error = e.code == ApiErrorCode.conflict ? 'prv.inv.used.t' : (e.code == ApiErrorCode.network ? 'common.networkError' : 'common.genericError'));
    } catch (_) {
      setState(() => _error = 'common.genericError');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _blocked(FlowStrings f, String t, String b, {Widget? action}) => AQPlainPage(eyebrow: f.t('prv.eyebrow'), title: t, subtitle: b, onBack: () => context.go('/entry'), children: [
        ?action,
        const SizedBox(height: AQSpacing.x4),
        Text(f.t('prv.inv.notPublic'), style: AQTypography.of(context, AQText.bodySmall, soft: true)),
      ]);

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final inv = ref.watch(providerInvitationProvider(widget.token));
    if (inv.isLoading && !inv.hasValue) return AQPlainPage(title: ' ', onBack: () => context.go('/entry'), children: const [AQSkeletonRows(count: 3)]);
    if (inv.hasError) return AQPlainPage(title: f.t('prv.inv.title'), onBack: () => context.go('/entry'), children: [AQRetryPanel(onRetry: () => ref.invalidate(providerInvitationProvider(widget.token)))]);
    final i = inv.value!;
    switch (i.state) {
      case InvitationState.expired:
        return _blocked(f, f.t('prv.inv.expired.t'), f.t('prv.inv.expired.b'));
      case InvitationState.used:
        if (_step < 0) return _blocked(f, f.t('prv.inv.used.t'), f.t('prv.inv.used.b'), action: AQPrimaryButton(label: f.t('guest.login'), onPressed: () => context.go('/login')));
      case InvitationState.notFound:
        return _blocked(f, f.t('prv.inv.notFound.t'), f.t('prv.inv.notFound.b'));
      case InvitationState.valid:
        break;
    }
    if (!_prefilled) {
      _prefilled = true;
      _app = _app.copyWith(companyName: i.companyName, email: i.email);
      _company.text = i.companyName;
    }
    if (_step < 0) {
      return AQViewingScaffold(
        washImage: 'assets/businesses/b4/02_Home_maintenance_servicing_resid.jpg',
        onBack: () => context.go('/entry'),
        backLabel: f.t('common.back'),
        trailing: const AQHelpButton('maintenance'),
        title: f.t('prv.inv.title'),
        subtitle: f.t('prv.inv.sub'),
        bottom: AQBottomActionBar(primary: AQPrimaryButton(label: f.t('prv.inv.start'), onPressed: () => _go(0))),
        children: [
          if (kUseDemoBackend) ...[const AQDemoNotice(), const SizedBox(height: AQSpacing.x4)],
          AQInfoCard(icon: 'construction', title: f.t('prv.inv.company'), body: VFmt.iso(i.companyName), children: [if (i.expiresAt != null) Text(f.t('prv.inv.expires', {'date': listingDate(context, i.expiresAt!)}), style: AQTypography.of(context, AQText.bodySmall, soft: true))]),
          AQInfoCard(title: f.t('prv.inv.need'), children: [AQStateTimeline(current: -1, steps: [for (var k = 1; k <= 4; k++) (f.t('prv.inv.n$k'), null)])]),
        ],
      );
    }
    final name = f.t('prv.s.${_steps[_step]}');
    final wilayats = omanGovernorates[_app.governorate] ?? const <String>[];
    final body = switch (_steps[_step]) {
      'account' => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          AQTextField(label: f.t('prv.acc.email'), controller: TextEditingController(text: i.email), enabled: false),
          AQPasswordField(label: f.t('field.password'), controller: _password, showLabel: f.t('field.show'), hideLabel: f.t('field.hide'), newPassword: true, error: _e('password'), onChanged: (_) => setState(() {})),
          AQRequirementList(items: [
            (label: f.t('pw.req.length'), met: _password.text.length >= 8),
            (label: f.t('pw.req.upper'), met: _password.text.contains(RegExp(r'[A-Z]'))),
            (label: f.t('pw.req.number'), met: _password.text.contains(RegExp(r'[0-9]'))),
          ]),
          AQPasswordField(label: f.t('field.confirmPassword'), controller: _confirm, showLabel: f.t('field.show'), hideLabel: f.t('field.hide'), newPassword: true, error: _e('confirm'), onChanged: (_) => setState(() {})),
        ]),
      'company' => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          AQTextField(label: f.t('prv.company'), controller: _company, error: _e('company'), onChanged: (v) => setState(() => _app = _app.copyWith(companyName: v))),
          AQTextField(label: f.t('prv.contactFirst'), controller: _first, error: _e('first'), onChanged: (v) => setState(() => _app = _app.copyWith(contactFirst: v))),
          AQTextField(label: f.t('prv.contactLast'), controller: _last, error: _e('last'), onChanged: (v) => setState(() => _app = _app.copyWith(contactLast: v))),
          AQPhoneField(label: f.t('field.phone'), hint: f.t('field.phoneHint'), controller: _phone, error: _e('phone'), onChanged: (v) => setState(() => _app = _app.copyWith(phone: v))),
          AQTextField(label: f.t('prv.address'), controller: _address, error: _e('address'), onChanged: (v) => setState(() => _app = _app.copyWith(address: v))),
        ]),
      'services' => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [Flexible(child: Text(f.t('prv.services'), style: AQTypography.of(context, AQText.titleMedium))), const AQHelpButton('maintenance')]),
          DbPillRow(pills: [
            for (final s in MaintenanceService.values)
              (f.t('mnt.svc.${s.name}'), _app.services.contains(s), () => setState(() => _app = _app.copyWith(services: _app.services.contains(s) ? ({..._app.services}..remove(s)) : {..._app.services, s}))),
          ]),
          if (_e('services') != null) Text(_e('services')!, style: AQTypography.of(context, AQText.bodySmall, color: c.danger)),
          const SizedBox(height: AQSpacing.x5),
          DbSelectField<String>(
            label: f.t('lst.w.gov'),
            required: true,
            valueLabel: _app.governorate.isEmpty ? null : dbGovLabel(f, _app.governorate),
            hint: f.t('lst.w.pick'),
            error: _tried ? _errors()['governorate'] : null,
            onTap: () async {
              final g = await showDbChoiceSheet<String>(context, title: f.t('lst.w.gov'), selected: _app.governorate, options: [for (final g in omanGovernorates.keys) (g, dbGovLabel(f, g))]);
              if (g != null && g != _app.governorate) setState(() => _app = _app.copyWith(governorate: g, wilayats: {}));
            },
          ),
          const SizedBox(height: AQSpacing.x4),
          if (_app.governorate.isNotEmpty) ...[
            Text(f.t('prv.area'), style: AQTypography.of(context, AQText.titleMedium)),
            const SizedBox(height: AQSpacing.x2),
            DbPillRow(pills: [
              for (final w in wilayats) (w, _app.wilayats.contains(w), () => setState(() => _app = _app.copyWith(wilayats: _app.wilayats.contains(w) ? ({..._app.wilayats}..remove(w)) : {..._app.wilayats, w}))),
            ]),
          ],
          if (_e('wilayats') != null) Text(_e('wilayats')!, style: AQTypography.of(context, AQText.bodySmall, color: c.danger)),
        ]),
      _ => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          AQInfoCard(title: f.t('prv.s.company'), children: [
            for (final l in [VFmt.iso(_app.companyName), '${_app.contactFirst} ${_app.contactLast}', '+968 ${_app.phone}', _app.address]) Text(l, style: AQTypography.of(context, AQText.bodyMedium)),
            Align(alignment: AlignmentDirectional.centerEnd, child: AQTextButton(label: f.t('common.edit'), onPressed: () => _go(1))),
          ]),
          AQInfoCard(title: f.t('prv.s.services'), children: [
            Text(_app.services.map((s) => f.t('mnt.svc.${s.name}')).join(', '), style: AQTypography.of(context, AQText.bodyMedium)),
            Text('${dbGovLabel(f, _app.governorate)}: ${_app.wilayats.join(', ')}', style: AQTypography.of(context, AQText.bodySmall, soft: true)),
            Align(alignment: AlignmentDirectional.centerEnd, child: AQTextButton(label: f.t('common.edit'), onPressed: () => _go(2))),
          ]),
        ]),
    };
    final last = _step == _steps.length - 1;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _go(_step - 1);
      },
      child: AQPlainPage(
        eyebrow: f.t('prv.eyebrow'),
        title: name,
        onBack: () => _go(_step - 1),
        bottom: AQBottomActionBar(
          secondary: AQBarSecondaryButton(label: f.t('common.back'), onPressed: _busy ? null : () => _go(_step - 1)),
          primary: AQPrimaryButton(label: last ? f.t('prv.create') : f.t('common.continue'), loading: _busy, onPressed: last ? _accept : _next),
        ),
        children: [
          AQProgressStepper(step: _step + 1, total: _steps.length, label: f.t('prv.step', {'n': '${_step + 1}', 'total': '${_steps.length}', 'name': name})),
          const SizedBox(height: AQSpacing.x5),
          if (_error != null) AQErrorBanner(text: f.t(_error!)),
          AQStepSwitcher(stepKey: _step, forward: _forward, child: body),
        ],
      ),
    );
  }
}

/// CR certificate and Municipal Licence, then submit to the verification queue.
class ProviderDocumentsScreen extends ConsumerStatefulWidget {
  const ProviderDocumentsScreen({super.key});
  @override
  ConsumerState<ProviderDocumentsScreen> createState() => _ProviderDocumentsScreenState();
}

class _ProviderDocumentsScreenState extends ConsumerState<ProviderDocumentsScreen> {
  final Map<ProviderDocument, String> _names = {};
  ProviderDocument? _busyDoc;
  bool _submitting = false, _tried = false;
  String? _error;

  Future<void> _pick(ProviderDocument d, {bool sample = false}) async {
    setState(() {
      _busyDoc = d;
      _error = null;
    });
    try {
      ListingFile? file;
      if (sample) {
        file = ListingFile(name: '${d.name}-sample.pdf', sizeBytes: 150000, asset: 'sample');
      } else {
        file = await ref.read(listingFilePickerProvider).pickDocument();
        if (file == null) return;
        if (!listingFileAcceptable(file, photo: false)) {
          setState(() => _error = 'lst.w.docs.bad');
          return;
        }
      }
      await ref.read(providerRepositoryProvider).upload(d, file.name);
      _names[d] = file.name;
      ref.invalidate(providerDocsProvider);
    } catch (_) {
      if (mounted) setState(() => _error = 'common.networkError');
    } finally {
      if (mounted) setState(() => _busyDoc = null);
    }
  }

  Future<void> _submit(Set<ProviderDocument> have) async {
    setState(() => _tried = true);
    if (have.length < ProviderDocument.values.length || _submitting) return;
    setState(() => _submitting = true);
    try {
      await ref.read(providerRepositoryProvider).submit();
      ref.invalidate(meProvider);
      if (mounted) context.go('/provider/status');
    } catch (_) {
      if (mounted) setState(() => _error = 'common.networkError');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final have = ref.watch(providerDocsProvider).valueOrNull ?? const <ProviderDocument>{};
    return AQPlainPage(
      eyebrow: f.t('prv.eyebrow'),
      title: f.t('prv.docs.title'),
      subtitle: f.t('prv.docs.sub'),
      onBack: () => aqBack(context, '/provider/status'),
      bottom: AQBottomActionBar(primary: AQPrimaryButton(label: f.t('prv.docs.submit'), loading: _submitting, trailingChevron: false, onPressed: () => _submit(have))),
      children: [
        if (kUseDemoBackend) ...[const AQDemoNotice(), const SizedBox(height: AQSpacing.x4)],
        if (_error != null) AQErrorBanner(text: f.t(_error!)),
        for (final d in ProviderDocument.values)
          ListingDocSlot(
            label: f.t('prv.doc.${d.name}'),
            file: have.contains(d) ? ListingFile(name: _names[d] ?? f.t('lst.d.docs'), sizeBytes: 0) : null,
            busy: _busyDoc == d,
            error: _tried && !have.contains(d) ? 'prv.docs.missing' : null,
            onPick: () => _pick(d),
            onSample: kShowReviewTools ? () => _pick(d, sample: true) : null,
          ),
        Text(f.t('lst.w.docs.rules'), style: AQTypography.of(context, AQText.bodySmall, soft: true)),
      ],
    );
  }
}

/// Where the provider application stands; the workspace opens only when approved.
class ProviderStatusScreen extends ConsumerWidget {
  const ProviderStatusScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final me = ref.watch(meProvider);
    final g = me.valueOrNull?.providerGrant;
    void back() => aqBack(context, '/app/account');
    if (me.isLoading && !me.hasValue) return AQPlainPage(title: f.t('prv.status.title'), onBack: back, children: const [AQSkeletonRows(count: 2)]);
    if (g == null) return AQPlainPage(title: f.t('prv.status.title'), onBack: back, children: [AQEmptyState(icon: 'info', title: f.t('prv.gate.none'), body: f.t('prv.inv.notPublic'))]);
    final repo = ref.read(providerRepositoryProvider);
    final tone = switch (g) {
      GrantState.approved => AQPillTone.success,
      GrantState.pendingVerification => AQPillTone.pending,
      GrantState.draft => AQPillTone.neutral,
      GrantState.resubmissionRequired => AQPillTone.warning,
      GrantState.rejected || GrantState.suspended => AQPillTone.danger,
    };
    return AQPlainPage(
      eyebrow: f.t('prv.eyebrow'),
      title: f.t('prv.status.title'),
      onBack: back,
      children: [
        if (kUseDemoBackend) ...[const AQDemoNotice(), const SizedBox(height: AQSpacing.x4)],
        AQInfoCard(title: f.t('prv.st.${g.name}'), body: f.t('prv.st.${g.name}.b'), children: [Align(alignment: AlignmentDirectional.centerStart, child: AQStatusPill(f.t('prv.st.${g.name}'), tone: tone))]),
        if (g == GrantState.draft || g == GrantState.resubmissionRequired) AQPrimaryButton(label: f.t('prv.docs.title'), onPressed: () => context.push('/provider/documents')),
        if (g == GrantState.approved) AQPrimaryButton(label: f.t('prv.openWorkspace'), onPressed: () => context.go('/provider')),
        if (kShowReviewTools && repo is DemoProviderRepository)
          Padding(
            padding: const EdgeInsets.only(top: AQSpacing.x4),
            child: AQInfoCard(icon: 'shield', title: f.t('prv.qa.title'), children: [
              Wrap(spacing: AQSpacing.x2, children: [
                for (final s in [GrantState.approved, GrantState.resubmissionRequired, GrantState.rejected, GrantState.suspended])
                  AQTextButton(
                    label: f.t('prv.st.${s.name}'),
                    color: c.accentDeep,
                    onPressed: () {
                      repo.debugDecide(s);
                      ref.invalidate(meProvider);
                    },
                  ),
              ]),
            ]),
          ),
      ],
    );
  }
}

String _when(BuildContext context, FlowStrings f, ProviderRequest r) => f.t('prv.req.when', {'day': VFmt.shortDate(context, r.date), 'window': f.t('mnt.win.${r.window.name}')});

class _RequestRow extends StatelessWidget {
  final ProviderRequest r;
  const _RequestRow(this.r);
  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    return AQListRow(
      icon: 'construction',
      title: '${f.t('mnt.svc.${r.service.name}')} · ${r.wilayat}',
      subtitle: '${_when(context, f, r)} · ${f.t('mnt.st.${r.status.name}')}',
      onTap: () => context.push('/provider/requests/${r.id}'),
    );
  }
}

/// Guards the provider workspace: only an approved provider grant gets in.
Widget? _providerGate(BuildContext context, WidgetRef ref) {
  final f = FlowStrings.of(context);
  final me = ref.watch(meProvider);
  if (me.isLoading && !me.hasValue) return AQPlainPage(title: ' ', onBack: () => aqBack(context, '/app/account'), children: const [AQSkeletonRows(count: 3)]);
  final g = me.valueOrNull?.providerGrant;
  if (g == GrantState.approved) return null;
  return AQPlainPage(
    eyebrow: f.t('prv.eyebrow'),
    title: f.t('prv.gate.t'),
    subtitle: g == null ? f.t('prv.gate.none') : f.t('prv.gate.b'),
    onBack: () => aqBack(context, '/app/account'),
    children: [if (g != null) AQPrimaryButton(label: f.t('prv.status.title'), onPressed: () => context.push('/provider/status'))],
  );
}

/// Provider home: new requests first, then confirmed jobs, then history.
class ProviderHomeScreen extends ConsumerWidget {
  const ProviderHomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gate = _providerGate(context, ref);
    if (gate != null) return gate;
    final f = FlowStrings.of(context);
    final async = ref.watch(providerRequestsProvider);
    final name = ref.watch(meProvider).valueOrNull?.businessName ?? '';
    return AQPlainPage(
      eyebrow: f.t('prv.eyebrow'),
      title: f.t('prv.home.title'),
      subtitle: f.t('prv.home.sub'),
      onBack: () => aqBack(context, '/app/account'),
      trailing: const AQHelpButton('maintenance'),
      children: [
        if (kUseDemoBackend) ...[const AQDemoNotice(), const SizedBox(height: AQSpacing.x4)],
        Wrap(spacing: AQSpacing.x2, runSpacing: AQSpacing.x2, crossAxisAlignment: WrapCrossAlignment.center, children: [Text(VFmt.iso(name), style: AQTypography.of(context, AQText.titleMedium)), AQStatusPill(f.t('prv.home.verified'), tone: AQPillTone.success, icon: 'verified')]),
        const SizedBox(height: AQSpacing.x4),
        ...async.when(
          loading: () => [const AQSkeletonRows(count: 3)],
          error: (_, _) => [AQRetryPanel(onRetry: () => ref.invalidate(providerRequestsProvider))],
          data: (list) {
            final incoming = list.where((r) => r.status == MaintenanceStatus.requested).toList();
            final upcoming = list.where((r) => r.status == MaintenanceStatus.confirmed).toList();
            return [
              AQRowGroup(title: '${f.t('prv.home.new')} (${incoming.length})', rows: incoming.isEmpty ? [AQListRow(icon: 'check', title: f.t('prv.home.none'))] : [for (final r in incoming) _RequestRow(r)]),
              if (upcoming.isNotEmpty) AQRowGroup(title: '${f.t('prv.home.upcoming')} (${upcoming.length})', rows: [for (final r in upcoming) _RequestRow(r)]),
              AQSecondaryButton(label: f.t('prv.home.all'), trailingChevron: false, onPressed: () => context.push('/provider/requests')),
            ];
          },
        ),
      ],
    );
  }
}

class ProviderRequestsScreen extends ConsumerStatefulWidget {
  final String? tab;
  const ProviderRequestsScreen({super.key, this.tab});
  @override
  ConsumerState<ProviderRequestsScreen> createState() => _ProviderRequestsScreenState();
}

class _ProviderRequestsScreenState extends ConsumerState<ProviderRequestsScreen> {
  late String _tab = const ['incoming', 'upcoming', 'history'].contains(widget.tab) ? widget.tab! : 'incoming';

  @override
  Widget build(BuildContext context) {
    final gate = _providerGate(context, ref);
    if (gate != null) return gate;
    final f = FlowStrings.of(context);
    final async = ref.watch(providerRequestsProvider);
    bool keep(ProviderRequest r) => switch (_tab) {
          'incoming' => r.status == MaintenanceStatus.requested,
          'upcoming' => r.status == MaintenanceStatus.confirmed,
          _ => r.status == MaintenanceStatus.completed || r.status == MaintenanceStatus.declined || r.status == MaintenanceStatus.cancelled,
        };
    return AQPlainPage(
      eyebrow: f.t('prv.eyebrow'),
      title: f.t('prv.req.title'),
      onBack: () => aqBack(context, '/provider'),
      children: [
        DbPillRow(pills: [for (final t in const ['incoming', 'upcoming', 'history']) (f.t('prv.tab.$t'), _tab == t, () => setState(() => _tab = t))]),
        const SizedBox(height: AQSpacing.x4),
        ...async.when(
          loading: () => [const AQSkeletonRows(count: 3)],
          error: (_, _) => [AQRetryPanel(onRetry: () => ref.invalidate(providerRequestsProvider))],
          data: (list) {
            final shown = list.where(keep).toList();
            return shown.isEmpty ? [AQEmptyState(icon: 'calendar', title: f.t('prv.req.empty'), body: f.t('prv.req.contactNote'))] : [AQRowGroup(rows: [for (final r in shown) _RequestRow(r)])];
          },
        ),
      ],
    );
  }
}

class ProviderRequestDetailScreen extends ConsumerStatefulWidget {
  final String id;
  const ProviderRequestDetailScreen({super.key, required this.id});
  @override
  ConsumerState<ProviderRequestDetailScreen> createState() => _ProviderRequestDetailScreenState();
}

class _ProviderRequestDetailScreenState extends ConsumerState<ProviderRequestDetailScreen> {
  MaintenanceStatus? _busy;
  String? _error;

  Future<void> _decide(MaintenanceStatus to, String key) async {
    final f = FlowStrings.of(context);
    final ok = await aqConfirm(context, title: f.t('prv.req.$key.t'), body: f.t('prv.req.$key.b'), confirmLabel: f.t('prv.req.$key'), destructive: to == MaintenanceStatus.declined || to == MaintenanceStatus.cancelled);
    if (!ok || !mounted) return;
    setState(() {
      _busy = to;
      _error = null;
    });
    try {
      await ref.read(providerRepositoryProvider).decide(widget.id, to);
      if (mounted) ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(f.t('prv.req.done.${to.name}'))));
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.code == ApiErrorCode.conflict ? 'prv.req.conflict' : 'common.networkError');
    } catch (_) {
      if (mounted) setState(() => _error = 'common.genericError');
    } finally {
      ref.invalidate(providerRequestProvider(widget.id));
      ref.invalidate(providerRequestsProvider);
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gate = _providerGate(context, ref);
    if (gate != null) return gate;
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final async = ref.watch(providerRequestProvider(widget.id));
    void back() => aqBack(context, '/provider/requests');
    return async.when(
      loading: () => AQPlainPage(title: f.t('mnt.det.title'), onBack: back, children: const [AQSkeletonRows(count: 3)]),
      error: (_, _) => AQPlainPage(title: f.t('mnt.det.title'), onBack: back, children: [AQRetryPanel(onRetry: () => ref.invalidate(providerRequestProvider(widget.id)))]),
      data: (r) {
        if (r == null) return AQPlainPage(title: f.t('mnt.det.title'), onBack: back, children: [AQEmptyState(icon: 'alert', title: f.t('prv.req.notFound'), body: '')]);
        final now = DateTime.now();
        return AQPlainPage(
          eyebrow: f.t('prv.eyebrow'),
          title: f.t('mnt.svc.${r.service.name}'),
          subtitle: _when(context, f, r),
          onBack: back,
          children: [
            Align(alignment: AlignmentDirectional.centerStart, child: AQStatusPill(f.t('mnt.st.${r.status.name}'), tone: requestTone(r.status))),
            const SizedBox(height: AQSpacing.x4),
            if (_error != null) AQErrorBanner(text: f.t(_error!)),
            AQInfoCard(title: f.t('mnt.det.title'), children: [
              for (final kv in [(f.t('prv.req.service'), f.t('mnt.svc.${r.service.name}')), (f.t('prv.req.preferred'), _when(context, f, r)), (f.t('prv.req.area'), r.wilayat), (f.t('prv.req.customer'), r.requesterLabel)])
                Padding(padding: const EdgeInsets.only(bottom: AQSpacing.x2), child: Row(children: [Expanded(child: Text(kv.$1, style: AQTypography.of(context, AQText.bodySmall, soft: true))), Flexible(child: Text(kv.$2, textAlign: TextAlign.end, style: AQTypography.of(context, AQText.titleSmall)))])),
              if (r.notes.isNotEmpty) ...[Text(f.t('prv.req.notes'), style: AQTypography.of(context, AQText.bodySmall, soft: true)), Text(r.notes, style: AQTypography.of(context, AQText.bodyMedium))],
            ]),
            if (r.status == MaintenanceStatus.requested || r.status == MaintenanceStatus.confirmed)
              AQInfoCard(icon: 'phone', title: f.t('prv.req.contact'), body: f.t('prv.req.contactNote'), children: [
                AQListRow(
                  icon: 'phone',
                  title: VFmt.iso(r.requesterPhone),
                  trailing: f.t('db.contact.copy'),
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: r.requesterPhone));
                    if (context.mounted) ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(f.t('abk.p.copied'))));
                  },
                ),
              ]),
            if (r.status == MaintenanceStatus.requested) ...[
              AQPrimaryButton(label: f.t('prv.req.confirm'), loading: _busy == MaintenanceStatus.confirmed, trailingChevron: false, onPressed: _busy != null ? null : () => _decide(MaintenanceStatus.confirmed, 'confirm')),
              const SizedBox(height: AQSpacing.x2),
              AQSecondaryButton(label: f.t('prv.req.decline'), loading: _busy == MaintenanceStatus.declined, trailingChevron: false, foreground: c.danger, onPressed: _busy != null ? null : () => _decide(MaintenanceStatus.declined, 'decline')),
            ],
            if (r.status == MaintenanceStatus.confirmed) ...[
              AQPrimaryButton(label: f.t('prv.req.complete'), loading: _busy == MaintenanceStatus.completed, trailingChevron: false, onPressed: _busy != null || !r.canComplete(now) ? null : () => _decide(MaintenanceStatus.completed, 'complete')),
              if (!r.canComplete(now)) Padding(padding: const EdgeInsets.only(top: AQSpacing.x2), child: Text(f.t('prv.req.completeLater'), style: AQTypography.of(context, AQText.bodySmall, soft: true))),
              const SizedBox(height: AQSpacing.x2),
              AQSecondaryButton(label: f.t('prv.req.cancel'), loading: _busy == MaintenanceStatus.cancelled, trailingChevron: false, foreground: c.danger, onPressed: _busy != null ? null : () => _decide(MaintenanceStatus.cancelled, 'cancel')),
            ],
          ],
        );
      },
    );
  }
}

/// On the Home tab of an account that holds a provider grant: the way into the workspace, or the
/// honest status of the application.
class ProviderHomeBanner extends StatelessWidget {
  final GrantState grant;
  const ProviderHomeBanner({super.key, required this.grant});
  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final approved = grant == GrantState.approved;
    return AQInfoCard(
      icon: 'construction',
      title: approved ? f.t('prv.home.title') : f.t('prv.st.${grant.name}'),
      body: approved ? f.t('prv.home.sub') : f.t('prv.st.${grant.name}.b'),
      children: [AQPrimaryButton(label: approved ? f.t('prv.openWorkspace') : f.t('prv.status.title'), onPressed: () => context.push(approved ? '/provider' : '/provider/status'))],
    );
  }
}
