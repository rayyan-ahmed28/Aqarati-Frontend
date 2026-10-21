import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
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
import '../../core/localization/flow_strings.dart';
import '../../data/api/account_api.dart' show ApiException, ApiErrorCode;
import '../devbuild/db_models.dart' show omanGovernorates;
import '../devbuild/db_widgets.dart' show DbPillRow, DbSelectField, dbGovLabel, showDbChoiceSheet;
import '../help/help.dart';
import '../viewing/widgets/viewing_scaffold.dart' show AQBottomActionBar, AQBarSecondaryButton;
import 'listing_models.dart';
import 'listing_repository.dart';
import 'listing_widgets.dart';

enum ListingWizardMode { create, resubmit, edit }

/// One form for every listing: an approved agent's listing or an owner's Aqary e-Broker sale.
/// Values live in [ListingDraft] outside the step widgets, so Back, validation errors and theme or
/// language changes never lose input.
class ListingWizardScreen extends ConsumerStatefulWidget {
  final ListingChannel channel;
  final ListingWizardMode mode;
  /// Listing id (resubmit / edit) or saved draft id (create).
  final String? id;
  const ListingWizardScreen({super.key, required this.channel, this.mode = ListingWizardMode.create, this.id});

  @override
  ConsumerState<ListingWizardScreen> createState() => _ListingWizardScreenState();
}

class _ListingWizardScreenState extends ConsumerState<ListingWizardScreen> {
  late ListingDraft _d = ListingDraft(channel: widget.channel, market: widget.channel == ListingChannel.eBroker ? ListingMarket.residential : null, action: widget.channel == ListingChannel.eBroker ? ListingAction.buy : null);
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _price = TextEditingController();
  final _land = TextEditingController();
  final _build = TextEditingController();
  final _area = TextEditingController();
  final _deed = TextEditingController();
  final _unit = TextEditingController();
  final _scroll = ScrollController();
  late final String _idemKey = 'idem-${DateTime.now().microsecondsSinceEpoch}';
  int _step = 0;
  bool _forward = true;
  bool _showErrors = false;
  bool _busy = false;
  bool _loading = false;
  bool _dirty = false;
  bool _notFound = false;
  String? _bannerKey;
  String? _bannerTitleKey;
  String? _pickingKey;
  Listing? _source;

  List<ListingStep> get _steps => switch (widget.mode) {
        ListingWizardMode.edit => const [ListingStep.location, ListingStep.facts, ListingStep.photos, ListingStep.review],
        _ => ListingStep.values,
      };
  ListingStep get _current => _steps[_step];
  bool get _deedOnFile => widget.mode == ListingWizardMode.resubmit;

  @override
  void initState() {
    super.initState();
    if (widget.id != null) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final repo = ref.read(listingRepositoryProvider);
    try {
      if (widget.mode == ListingWizardMode.create) {
        final d = await repo.draft(widget.id!);
        if (d != null) _apply(d);
      } else {
        final l = await repo.get(widget.id!);
        if (l == null) {
          _notFound = true;
        } else {
          _source = l;
          _apply(l.toDraft());
        }
      }
    } catch (_) {
      _bannerKey = 'common.networkError';
    }
    if (mounted) setState(() => _loading = false);
  }

  void _apply(ListingDraft d) {
    _d = d;
    _title.text = d.title;
    _desc.text = d.description;
    _price.text = d.price;
    _land.text = d.landSqm;
    _build.text = d.buildSqm;
    _area.text = d.areaName;
    _unit.text = d.unitRef;
  }

  @override
  void dispose() {
    for (final c in [_title, _desc, _price, _land, _build, _area, _deed, _unit]) {
      c.dispose();
    }
    _scroll.dispose();
    super.dispose();
  }

  void _set(ListingDraft d) => setState(() {
        _d = d;
        _dirty = true;
      });

  Map<String, String> get _errors => _showErrors ? validateListingStep(_d, _current, deedOnFile: _deedOnFile) : const {};

  String? _err(String k) => _errors[k];

  void _goTo(int i) {
    setState(() {
      _forward = i > _step;
      _step = i;
      _showErrors = false;
      _bannerKey = null;
      _bannerTitleKey = null;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _next() {
    final errs = validateListingStep(_d, _current, deedOnFile: _deedOnFile);
    if (errs.isNotEmpty) {
      setState(() {
        _showErrors = true;
        _bannerKey = 'lst.err.fixBelow';
        _bannerTitleKey = null;
      });
      SemanticsService.sendAnnouncement(View.of(context), FlowStrings.of(context).t('lst.err.fixBelow'), Directionality.of(context));
      return;
    }
    if (_step < _steps.length - 1) _goTo(_step + 1);
  }

  Future<void> _leave() async {
    final f = FlowStrings.of(context);
    if (!_dirty || widget.mode != ListingWizardMode.create) {
      aqBack(context, '/listings');
      return;
    }
    final choice = await showAQSheet<String>(
      context,
      useRootNavigator: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(AQSpacing.gutter, AQSpacing.x2, AQSpacing.gutter, AQSpacing.x2),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Semantics(header: true, child: Text(f.t('lst.w.leave.t'), style: AQTypography.of(ctx, AQText.headlineSmall))),
          const SizedBox(height: AQSpacing.x2),
          Text(f.t('lst.w.leave.b'), style: AQTypography.of(ctx, AQText.bodyMedium, soft: true)),
          const SizedBox(height: AQSpacing.x5),
          AQPrimaryButton(label: f.t('lst.w.leave.save'), trailingChevron: false, onPressed: () => Navigator.of(ctx).pop('save')),
          const SizedBox(height: AQSpacing.x2),
          AQSecondaryButton(label: f.t('lst.w.leave.discard'), trailingChevron: false, onPressed: () => Navigator.of(ctx).pop('discard')),
          const SizedBox(height: AQSpacing.x1),
          AQTextButton(label: f.t('common.cancel'), onPressed: () => Navigator.of(ctx).pop()),
        ]),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'save' && !await _saveDraft()) return;
    if (mounted) aqBack(context, '/listings');
  }

  Future<bool> _saveDraft() async {
    final f = FlowStrings.of(context);
    setState(() => _busy = true);
    try {
      final id = await ref.read(listingRepositoryProvider).saveDraft(_d);
      _d = _d.copyWith(id: id);
      _dirty = false;
      ref.invalidate(myListingDraftsProvider);
      if (mounted) ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(f.t(kUseDemoBackend ? 'lst.w.savedDemo' : 'lst.w.saved'))));
      return true;
    } catch (_) {
      if (mounted) setState(() => _bannerKey = 'common.networkError');
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    final errs = validateListingStep(_d, ListingStep.review, deedOnFile: _deedOnFile);
    if (errs.isNotEmpty) {
      setState(() => _showErrors = true);
      return;
    }
    if (_busy) return;
    setState(() {
      _busy = true;
      _bannerKey = null;
      _bannerTitleKey = null;
    });
    final repo = ref.read(listingRepositoryProvider);
    try {
      switch (widget.mode) {
        case ListingWizardMode.create:
          final l = await repo.submit(_d, idempotencyKey: _idemKey);
          ref.invalidate(myListingsProvider);
          ref.invalidate(myListingDraftsProvider);
          if (mounted) context.pushReplacement('/listings/${l.id}/submitted');
        case ListingWizardMode.resubmit:
          final l = await repo.resubmit(widget.id!, _d);
          ref.invalidate(myListingsProvider);
          ref.invalidate(listingProvider(l.id));
          if (mounted) context.pushReplacement('/listings/${l.id}/submitted?r=resubmitted');
        case ListingWizardMode.edit:
          final r = await repo.edit(widget.id!, _d);
          ref.invalidate(myListingsProvider);
          ref.invalidate(listingProvider(r.listing.id));
          if (!mounted) return;
          final f = FlowStrings.of(context);
          String names(Set<String> s) => s.map((x) => f.t('lst.field.$x')).join(', ');
          final msg = r.underReview.isNotEmpty
              ? f.t('lst.d.done.edit.review', {'fields': names(r.underReview)})
              : (r.appliedNow.isNotEmpty ? f.t('lst.d.done.edit.now', {'fields': names(r.appliedNow)}) : f.t('lst.d.done.edit.none'));
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(msg)));
          aqBack(context, '/listings/${r.listing.id}');
      }
    } on DuplicateListingException {
      _fail('lst.err.duplicate.b', title: 'lst.err.duplicate.t');
    } on ListingNotAllowedException catch (e) {
      _fail('lst.err.notAllowed.${e.reason}');
    } on ChangeSetOpenException {
      _fail('lst.err.changeOpen');
    } on ApiException catch (e) {
      _fail(e.code == ApiErrorCode.conflict ? 'lst.err.conflict' : (e.code == ApiErrorCode.network ? 'common.networkError' : 'common.genericError'));
    } catch (_) {
      _fail('common.genericError');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _fail(String key, {String? title}) {
    if (!mounted) return;
    setState(() {
      _bannerKey = key;
      _bannerTitleKey = title;
    });
    if (_scroll.hasClients) _scroll.animateTo(0, duration: AQMotion.scaled(context, AQMotion.standard), curve: AQMotion.standardCurve);
  }

  Future<void> _pickPhoto() async {
    final f = FlowStrings.of(context);
    if (_d.photos.length >= kListingMaxPhotos) return;
    setState(() => _pickingKey = 'photos');
    try {
      final file = await ref.read(listingFilePickerProvider).pickPhoto();
      if (file == null) return;
      if (!listingFileAcceptable(file, photo: true)) {
        if (mounted) setState(() => _bannerKey = 'lst.w.photos.bad');
        return;
      }
      _set(_d.copyWith(photos: [..._d.photos, file]));
      if (mounted) setState(() => _bannerKey = null);
    } catch (_) {
      if (mounted) setState(() => _bannerKey = 'common.genericError');
    } finally {
      if (mounted) {
        setState(() => _pickingKey = null);
        SemanticsService.sendAnnouncement(View.of(context), f.t('lst.w.photos.count', {'n': '${_d.photos.length}', 'max': '$kListingMaxPhotos'}), Directionality.of(context));
      }
    }
  }

  Future<void> _pickDoc(bool deed) async {
    setState(() => _pickingKey = deed ? 'deed' : 'auth');
    try {
      final file = await ref.read(listingFilePickerProvider).pickDocument();
      if (file == null) return;
      if (!listingFileAcceptable(file, photo: false)) {
        if (mounted) setState(() => _bannerKey = 'lst.w.docs.bad');
        return;
      }
      // Bytes are only needed for the upload; keep metadata only in the form.
      final meta = ListingFile(name: file.name, sizeBytes: file.sizeBytes);
      _set(deed ? _d.copyWith(deedFile: meta) : _d.copyWith(authorisationFile: meta));
      if (mounted) setState(() => _bannerKey = null);
    } catch (_) {
      if (mounted) setState(() => _bannerKey = 'common.genericError');
    } finally {
      if (mounted) setState(() => _pickingKey = null);
    }
  }

  // ---------------------------------------------------------------- steps

  Widget _classification(FlowStrings f) {
    final eb = widget.channel == ListingChannel.eBroker;
    final markets = eb ? eBrokerMarkets : ListingMarket.values;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [Flexible(child: Text(f.t('lst.w.market'), style: AQTypography.of(context, AQText.titleMedium))), const AQHelpButton('markets')]),
      DbPillRow(pills: [
        for (final m in markets) (f.t('lst.mkt.${m.name}'), _d.market == m, () => _set(_d.copyWith(market: m, action: eb ? ListingAction.buy : null, subType: null))),
      ]),
      if (_err('market') != null) _errText(f, 'market'),
      if (eb) Padding(padding: const EdgeInsets.only(top: AQSpacing.x2), child: Text(f.t('lst.w.ebrokerScope'), style: AQTypography.of(context, AQText.bodySmall, soft: true))),
      const SizedBox(height: AQSpacing.x5),
      Row(children: [Flexible(child: Text(f.t('lst.w.action'), style: AQTypography.of(context, AQText.titleMedium))), const AQHelpButton('buyRentInvest')]),
      if (eb)
        AQStatusPill(f.t('lst.w.ebrokerSale'), icon: 'check', tone: AQPillTone.success)
      else if (_d.market == null)
        Text(f.t('lst.w.pickMarketFirst'), style: AQTypography.of(context, AQText.bodySmall, soft: true))
      else
        DbPillRow(pills: [for (final a in actionsFor(_d.market!, widget.channel)) (f.t('lst.act.${a.name}'), _d.action == a, () => _set(_d.copyWith(action: a, subType: null)))]),
      if (_err('action') != null) _errText(f, 'action'),
      const SizedBox(height: AQSpacing.x5),
      Text(f.t('lst.w.subType'), style: AQTypography.of(context, AQText.titleMedium)),
      const SizedBox(height: AQSpacing.x2),
      if (_d.market != null && _d.action != null)
        DbPillRow(pills: [for (final s in subTypesFor(_d.market!, _d.action!)) (f.t('lst.sub.${s.name}'), _d.subType == s, () => _set(_d.copyWith(subType: s)))])
      else
        Text(f.t('lst.w.pickActionFirst'), style: AQTypography.of(context, AQText.bodySmall, soft: true)),
      if (_err('subType') != null) _errText(f, 'subType'),
    ]);
  }

  Widget _errText(FlowStrings f, String k) => Padding(
        padding: const EdgeInsets.only(top: AQSpacing.x2),
        child: Semantics(liveRegion: true, child: Text(f.t(_err(k)!), style: AQTypography.of(context, AQText.bodySmall, color: AQColors.of(context).danger))),
      );

  Widget _location(FlowStrings f) {
    final wilayats = omanGovernorates[_d.governorate] ?? const <String>[];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      DbSelectField<String>(
        label: f.t('lst.w.gov'),
        required: true,
        valueLabel: _d.governorate.isEmpty ? null : dbGovLabel(f, _d.governorate),
        hint: f.t('lst.w.pick'),
        error: _err('governorate'),
        onTap: () async {
          final g = await showDbChoiceSheet<String>(context, title: f.t('lst.w.gov'), selected: _d.governorate, options: [for (final g in omanGovernorates.keys) (g, dbGovLabel(f, g))]);
          if (g != null && g != _d.governorate) _set(_d.copyWith(governorate: g, wilayat: ''));
        },
      ),
      const SizedBox(height: AQSpacing.x4),
      DbSelectField<String>(
        label: f.t('lst.w.wilayat'),
        required: true,
        valueLabel: _d.wilayat.isEmpty ? null : _d.wilayat,
        hint: _d.governorate.isEmpty ? f.t('lst.w.pickGovFirst') : f.t('lst.w.pick'),
        error: _err('wilayat'),
        onTap: _d.governorate.isEmpty
            ? null
            : () async {
                final w = await showDbChoiceSheet<String>(context, title: f.t('lst.w.wilayat'), selected: _d.wilayat, options: [for (final w in wilayats) (w, w)]);
                if (w != null) _set(_d.copyWith(wilayat: w));
              },
      ),
      const SizedBox(height: AQSpacing.x4),
      AQTextField(label: f.t('lst.w.area'), controller: _area, onChanged: (v) => _set(_d.copyWith(areaName: v))),
      Text(f.t('lst.w.mapNote'), style: AQTypography.of(context, AQText.bodySmall, soft: true)),
    ]);
  }

  Widget _facts(FlowStrings f) {
    final a = _d.attributes;
    Future<void> pickCount(String label, int? current, void Function(int) set) async {
      final v = await showDbChoiceSheet<int>(context, title: label, selected: current, options: [for (var i = 1; i <= 10; i++) (i, i == 10 ? '10+' : '$i')]);
      if (v != null) set(v);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AQTextField(
        label: f.t(_d.action == ListingAction.rent ? 'lst.w.priceRent' : 'lst.w.price'),
        controller: _price,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        formatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
        error: _err('price') == null ? null : f.t(_err('price')!),
        onChanged: (v) => _set(_d.copyWith(price: v)),
      ),
      AQTextField(label: f.t('lst.w.title'), hint: f.t('lst.w.titleHint'), controller: _title, error: _err('title') == null ? null : f.t(_err('title')!), formatters: [LengthLimitingTextInputFormatter(kListingTitleMax + 10)], onChanged: (v) => _set(_d.copyWith(title: v))),
      if (a.beds || a.baths)
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (a.beds) Expanded(child: DbSelectField<int>(label: f.t('lst.w.beds'), required: true, valueLabel: _d.beds == null ? null : '${_d.beds}', hint: f.t('lst.w.pick'), error: _err('beds'), onTap: () => pickCount(f.t('lst.w.beds'), _d.beds, (v) => _set(_d.copyWith(beds: v))))),
          if (a.beds && a.baths) const SizedBox(width: AQSpacing.x3),
          if (a.baths) Expanded(child: DbSelectField<int>(label: f.t('lst.w.baths'), required: true, valueLabel: _d.baths == null ? null : '${_d.baths}', hint: f.t('lst.w.pick'), error: _err('baths'), onTap: () => pickCount(f.t('lst.w.baths'), _d.baths, (v) => _set(_d.copyWith(baths: v))))),
        ]),
      if (a.beds || a.baths) const SizedBox(height: AQSpacing.x4),
      if (a.land || a.build) Row(children: [Flexible(child: Text(f.t('help.size.t'), style: AQTypography.of(context, AQText.titleSmall))), const AQHelpButton('size')]),
      if (a.land) AQTextField(label: f.t('lst.w.land'), controller: _land, keyboardType: const TextInputType.numberWithOptions(decimal: true), formatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))], error: _err('land') == null ? null : f.t(_err('land')!), onChanged: (v) => _set(_d.copyWith(landSqm: v))),
      if (a.build) AQTextField(label: f.t('lst.w.build'), controller: _build, keyboardType: const TextInputType.numberWithOptions(decimal: true), formatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))], error: _err('build') == null ? null : f.t(_err('build')!), onChanged: (v) => _set(_d.copyWith(buildSqm: v))),
      AQTextField(label: f.t('lst.w.desc'), controller: _desc, minLines: 3, maxLines: 8, action: TextInputAction.newline, error: _err('description') == null ? null : f.t(_err('description')!), onChanged: (v) => _set(_d.copyWith(description: v))),
    ]);
  }

  Widget _photos(FlowStrings f) {
    final c = AQColors.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(f.t('lst.w.photos.b'), style: AQTypography.of(context, AQText.bodyMedium, soft: true)),
      const SizedBox(height: AQSpacing.x4),
      Wrap(spacing: AQSpacing.x2, runSpacing: AQSpacing.x2, children: [
        for (var i = 0; i < _d.photos.length; i++)
          Stack(children: [
            ListingPhoto(_d.photos[i], width: 96, height: 96, radius: AQRadius.medium),
            if (i == 0)
              PositionedDirectional(bottom: 6, start: 6, child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: c.surfaceRaised, borderRadius: BorderRadius.circular(8)), child: Text(f.t('lst.w.photos.first'), style: AQTypography.of(context, AQText.labelSmall)))),
            PositionedDirectional(
              top: 0,
              end: 0,
              child: AQIconButton(icon: 'close', directional: false, color: c.onAccent, semanticsLabel: f.t('lst.w.photos.remove', {'n': '${i + 1}'}), onPressed: () => _set(_d.copyWith(photos: [..._d.photos]..removeAt(i)))),
            ),
          ]),
      ]),
      const SizedBox(height: AQSpacing.x3),
      Text(f.t('lst.w.photos.count', {'n': '${_d.photos.length}', 'max': '$kListingMaxPhotos'}), style: AQTypography.of(context, AQText.bodySmall, soft: true)),
      if (_err('photos') != null) _errText(f, 'photos'),
      const SizedBox(height: AQSpacing.x3),
      AQSecondaryButton(label: f.t('lst.w.photos.add'), leadingIcon: 'plus', trailingChevron: false, loading: _pickingKey == 'photos', onPressed: _d.photos.length >= kListingMaxPhotos ? null : _pickPhoto),
      if (kShowReviewTools && _d.photos.isEmpty) ...[
        const SizedBox(height: AQSpacing.x2),
        AQTextButton(label: f.t('lst.w.photos.sample'), onPressed: () => _set(_d.copyWith(photos: [for (final a in kSampleListingPhotos) ListingFile(name: a.split('/').last, sizeBytes: 0, asset: a)]))),
      ],
    ]);
  }

  Widget _documents(FlowStrings f) {
    final eb = widget.channel == ListingChannel.eBroker;
    final source = _source;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(f.t(eb ? 'lst.w.docs.owner' : 'lst.w.docs.agent'), style: AQTypography.of(context, AQText.bodyMedium, soft: true)),
      const SizedBox(height: AQSpacing.x4),
      if (_deedOnFile && source != null)
        AQInfoCard(icon: 'check', title: f.t('lst.w.rv.deedEnding', {'x': source.deedHint}), body: f.t('lst.w.deed.help'))
      else
        AQTextField(label: f.t('lst.w.deed'), controller: _deed, helper: f.t('lst.w.deed.help'), error: _err('deedNumber') == null ? null : f.t(_err('deedNumber')!), onChanged: (v) => _set(_d.copyWith(deedNumber: v))),
      AQTextField(label: f.t('lst.w.unit'), controller: _unit, helper: f.t('lst.w.unit.help'), onChanged: (v) => _set(_d.copyWith(unitRef: v))),
      ListingDocSlot(
        label: f.t('lst.w.deedFile'),
        file: _d.deedFile,
        busy: _pickingKey == 'deed',
        error: _err('deedFile'),
        onPick: () => _pickDoc(true),
        onSample: kShowReviewTools ? () => _set(_d.copyWith(deedFile: const ListingFile(name: 'title-deed-sample.pdf', sizeBytes: 182000))) : null,
      ),
      if (!eb)
        ListingDocSlot(
          label: f.t('lst.w.authFile'),
          file: _d.authorisationFile,
          busy: _pickingKey == 'auth',
          onPick: () => _pickDoc(false),
          onSample: kShowReviewTools ? () => _set(_d.copyWith(authorisationFile: const ListingFile(name: 'owner-authorisation-sample.pdf', sizeBytes: 96000))) : null,
        ),
      Text(f.t('lst.w.docs.rules'), style: AQTypography.of(context, AQText.bodySmall, soft: true)),
    ]);
  }

  Widget _review(FlowStrings f) {
    final eb = widget.channel == ListingChannel.eBroker;
    final d = _d;
    final idx = {for (var i = 0; i < _steps.length; i++) _steps[i]: i};
    VoidCallback? edit(ListingStep s) => idx[s] == null ? null : () => _goTo(idx[s]!);
    Widget section(String title, ListingStep s, List<String> lines) => AQInfoCard(
          title: title,
          children: [
            for (final l in lines) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(l, style: AQTypography.of(context, AQText.bodyMedium))),
            if (edit(s) != null) Align(alignment: AlignmentDirectional.centerEnd, child: AQTextButton(label: f.t('common.edit'), trailingIcon: 'chevron-right', onPressed: edit(s))),
          ],
        );
    final price = parseOmr(d.price);
    final edit_ = widget.mode == ListingWizardMode.edit;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (edit_) AQInfoCard(icon: 'info', title: f.t('lst.w.edit'), body: f.t('lst.w.material')),
      if (!edit_) section(f.t('lst.w.rv.property'), ListingStep.classification, [if (d.market != null) f.t('lst.mkt.${d.market!.name}'), if (d.subType != null && d.action != null) listingKind(f, d.subType!, d.action!, channel: d.channel)]),
      section(f.t('lst.w.rv.location'), ListingStep.location, [listingPlace(f, d.governorate, d.wilayat, d.areaName)]),
      section(f.t('lst.w.rv.details'), ListingStep.facts, [
        if (price != null) omr(context, price),
        d.title.trim(),
        if (d.attributes.beds && d.beds != null) '${f.t('lst.w.beds')}: ${d.beds}',
        if (d.attributes.baths && d.baths != null) '${f.t('lst.w.baths')}: ${d.baths}',
        if (d.attributes.land && d.landSqm.isNotEmpty) '${f.t('lst.w.land')}: ${d.landSqm}',
        if (d.attributes.build && d.buildSqm.isNotEmpty) '${f.t('lst.w.build')}: ${d.buildSqm}',
      ]),
      section(f.t('lst.w.rv.photos'), ListingStep.photos, [f.t('lst.w.photos.count', {'n': '${d.photos.length}', 'max': '$kListingMaxPhotos'})]),
      if (!edit_)
        section(f.t('lst.w.rv.docs'), ListingStep.documents, [
          if (_deedOnFile && _source != null) f.t('lst.w.rv.deedEnding', {'x': _source!.deedHint}) else if (d.deedNumber.trim().length >= 3) f.t('lst.w.rv.deedEnding', {'x': d.deedNumber.trim().substring(d.deedNumber.trim().length - 3)}),
          '${f.t('lst.w.deedFile')}: ${d.deedFile?.name ?? f.t('lst.w.rv.notProvided')}',
          if (!eb) '${f.t('lst.w.authFile')}: ${d.authorisationFile?.name ?? f.t('lst.w.rv.notProvided')}',
        ]),
      if (!edit_ && eb) ...[
        AQInfoCard(icon: 'info', title: f.t('eb.fee.t'), body: f.t('eb.fee.pending'), children: [Text(f.t('eb.noMoney'), style: AQTypography.of(context, AQText.bodySmall, soft: true))]),
        AQCheckRow(value: d.feeAccepted, label: f.t('eb.fee.accept'), error: _err('fee') == null ? null : f.t(_err('fee')!), onChanged: (v) => _set(d.copyWith(feeAccepted: v))),
      ],
      if (!edit_) AQCheckRow(value: d.declaration, label: f.t(eb ? 'lst.w.declaration.owner' : 'lst.w.declaration'), error: _err('declaration') == null ? null : f.t(_err('declaration')!), onChanged: (v) => _set(d.copyWith(declaration: v))),
      if (!edit_) Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: Text(f.t('lst.w.afterSubmit'), style: AQTypography.of(context, AQText.bodySmall, soft: true))), const AQHelpButton('listingReview')]),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final title = f.t(switch (widget.mode) {
      ListingWizardMode.resubmit => 'lst.w.fix',
      ListingWizardMode.edit => 'lst.w.edit',
      ListingWizardMode.create => widget.channel == ListingChannel.eBroker ? 'lst.w.sell' : 'lst.w.new',
    });
    if (_notFound) {
      return AQPlainPage(title: title, onBack: () => aqBack(context, '/listings'), children: [AQEmptyState(icon: 'alert', title: f.t('lst.w.notFound'), body: '', action: AQPrimaryButton(label: f.t('lst.sub.all'), onPressed: () => context.go('/listings')))]);
    }
    final last = _step == _steps.length - 1;
    final stepName = f.t('lst.w.s.${_current.name}');
    final body = switch (_current) {
      ListingStep.classification => _classification(f),
      ListingStep.location => _location(f),
      ListingStep.facts => _facts(f),
      ListingStep.photos => _photos(f),
      ListingStep.documents => _documents(f),
      ListingStep.review => _review(f),
    };
    final c = AQColors.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _step > 0 ? _goTo(_step - 1) : _leave();
      },
      child: Scaffold(
        backgroundColor: c.background,
        body: Stack(fit: StackFit.expand, children: [
          const AQBackdrop(asset: 'assets/entry/oman_terrace_2k.jpg', quiet: true),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: AQSpacing.maxContent + AQSpacing.gutter * 2),
                child: Column(children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AQSpacing.x4),
                    child: SizedBox(
                      height: AQControl.tap,
                      child: Row(children: [
                        AQIconButton(icon: 'chevron-left', semanticsLabel: f.t('common.back'), onPressed: () => _step > 0 ? _goTo(_step - 1) : _leave()),
                        const Spacer(),
                        if (widget.mode == ListingWizardMode.create) AQTextButton(label: f.t('lst.w.saveExit'), color: c.accentDeep, onPressed: _busy ? null : _saveDraft),
                      ]),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(AQSpacing.gutter, AQSpacing.x2, AQSpacing.gutter, AQSpacing.x8),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Semantics(header: true, child: Text(title, style: AQTypography.of(context, AQText.headlineLarge))),
                        const SizedBox(height: AQSpacing.x4),
                        AQProgressStepper(step: _step + 1, total: _steps.length, label: f.t('lst.w.step', {'n': '${_step + 1}', 'total': '${_steps.length}', 'name': stepName})),
                        const SizedBox(height: AQSpacing.x5),
                        if (kUseDemoBackend && _step == 0) ...[const AQDemoNotice(), const SizedBox(height: AQSpacing.x4)],
                        if (widget.mode == ListingWizardMode.resubmit && _source?.reasonCode != null && _step == 0)
                          AQInfoCard(icon: 'alert', accent: c.warning, title: f.t('lst.w.fixList'), body: f.t(FlowStrings.keys.contains('reason.${_source!.reasonCode}') ? 'reason.${_source!.reasonCode}' : 'reason.unknown')),
                        AQAnimatedSize(
                          child: _bannerKey == null
                              ? const SizedBox(width: double.infinity)
                              : AQErrorBanner(text: _bannerTitleKey == null ? f.t(_bannerKey!) : '${f.t(_bannerTitleKey!)}\n${f.t(_bannerKey!)}'),
                        ),
                        if (_loading) const AQSkeletonRows(count: 4, height: 64) else AQStepSwitcher(stepKey: _current, forward: _forward, child: body),
                      ]),
                    ),
                  ),
                  AQBottomActionBar(
                    secondary: _step > 0 ? AQBarSecondaryButton(label: f.t('common.back'), onPressed: _busy ? null : () => _goTo(_step - 1)) : null,
                    primary: AQPrimaryButton(
                      label: last
                          ? f.t(switch (widget.mode) {
                              ListingWizardMode.create => 'lst.w.submit',
                              ListingWizardMode.resubmit => 'lst.w.resubmit',
                              ListingWizardMode.edit => 'lst.w.saveChanges',
                            })
                          : f.t('common.continue'),
                      loading: _busy && last,
                      onPressed: _loading || _busy ? null : (last ? _submit : _next),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
