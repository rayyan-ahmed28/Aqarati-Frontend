import 'package:flutter/material.dart';
import '../help/help.dart';
import '../../core/aq/aq_primitives.dart';
import '../../core/aq/aq_scene.dart';
import '../../core/aq/aq_tokens.dart';
import '../../core/aq/aq_typography.dart';
import '../../core/localization/flow_strings.dart';
import '../../data/models/enums.dart';
import '../../data/models/money.dart';
import '../../data/models/property.dart';
import '../viewing/widgets/viewing_format.dart';
import 'aq_filters.dart';

/// Rounded choice chip used for categories, types, areas and amenities.
class AQChoicePill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const AQChoicePill({super.key, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: AQPressable(
        onTap: () {
          AQHaptics.selection();
          onTap();
        },
        child: AnimatedContainer(
          duration: AQMotion.scaled(context, AQMotion.fast),
          constraints: const BoxConstraints(minHeight: AQControl.tap - 4),
          padding: const EdgeInsets.symmetric(horizontal: AQSpacing.x4),
          decoration: BoxDecoration(color: selected ? c.accent : c.surface, borderRadius: BorderRadius.circular(AQControl.tap), border: Border.all(color: selected ? c.accent : c.hairline)),
          child: Center(widthFactor: 1, child: Text(label, style: AQTypography.of(context, AQText.labelMedium, color: selected ? c.onAccent : c.inkSoft))),
        ),
      ),
    );
  }
}

/// "N properties" with the Filters and Sort buttons beside it.
class AQResultsBar extends StatelessWidget {
  final int count;
  final int activeFilters;
  final VoidCallback onFilters, onSort;
  const AQResultsBar({super.key, required this.count, required this.activeFilters, required this.onFilters, required this.onSort});

  Widget _button(BuildContext context, {required String icon, required String label, int badge = 0, required VoidCallback onTap}) {
    final c = AQColors.of(context);
    return Semantics(
      button: true,
      label: badge > 0 ? '$label, $badge' : label,
      excludeSemantics: true,
      child: AQPressable(
        onTap: () {
          AQHaptics.selection();
          onTap();
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: AQControl.tap - 4),
          padding: const EdgeInsets.symmetric(horizontal: AQSpacing.x3),
          decoration: BoxDecoration(color: badge > 0 ? c.surfaceSelected : c.surface, borderRadius: BorderRadius.circular(AQControl.tap), border: Border.all(color: badge > 0 ? c.accent : c.hairline)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            AQIcon(icon, size: 18, color: c.accentDeep),
            const SizedBox(width: 6),
            Text(label, style: AQTypography.of(context, AQText.labelMedium)),
            if (badge > 0) ...[
              const SizedBox(width: 6),
              Container(constraints: const BoxConstraints(minWidth: 20), height: 20, padding: const EdgeInsets.symmetric(horizontal: 5), decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(10)), child: Center(child: Text(VFmt.n(context, badge), style: AQTypography.of(context, AQText.labelSmall, color: c.onAccent)))),
            ],
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final text = Semantics(liveRegion: true, child: Text(f.t('props.count', {'n': VFmt.n(context, count)}), style: AQTypography.of(context, AQText.titleMedium)));
    final filters = _button(context, icon: 'search', label: f.t('flt.button'), badge: activeFilters, onTap: onFilters);
    final sort = _button(context, icon: 'chevron-down', label: f.t('sort.button'), onTap: onSort);
    // Stack the count above the two buttons on narrow screens as well as at large text.
    if (aqLargeText(context) || MediaQuery.sizeOf(context).width < 360) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [text, const SizedBox(height: AQSpacing.x2), Wrap(spacing: AQSpacing.x2, runSpacing: AQSpacing.x2, children: [filters, sort])]);
    }
    return Row(children: [Expanded(child: text), filters, const SizedBox(width: AQSpacing.x2), sort]);
  }
}

Future<void> showAQSortSheet(BuildContext context, AQFilters filters, VoidCallback onChanged) {
  final f = FlowStrings.of(context);
  return showAQSheet<void>(
    context,
    builder: (sheet) => Column(mainAxisSize: MainAxisSize.min, children: [
      Padding(padding: const EdgeInsets.fromLTRB(AQSpacing.gutter, AQSpacing.x2, AQSpacing.gutter, AQSpacing.x2), child: Align(alignment: AlignmentDirectional.centerStart, child: Text(f.t('sort.title'), style: AQTypography.of(sheet, AQText.headlineSmall)))),
      for (final s in AQSort.values)
        AQSheetRow(
          title: f.t('sort.${s.name}'),
          selected: filters.sort == s,
          onTap: () {
            filters.sort = s;
            onChanged();
            Navigator.of(sheet).pop();
          },
        ),
    ]),
  );
}

/// Opens the filters sheet over [all] (the full listing, used for live counts and for the
/// areas and amenities on offer). Returns the confirmed filters, or null if dismissed.
Future<AQFilters?> showAQFilterSheet(BuildContext context, {required List<Property> all, required AQFilters initial, String query = ''}) {
  final c = AQColors.of(context);
  return showModalBottomSheet<AQFilters>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x66000000),
    constraints: const BoxConstraints(maxWidth: AQSpacing.maxContent + AQSpacing.gutter * 2),
    sheetAnimationStyle: AnimationStyle(duration: AQMotion.sheet, reverseDuration: AQMotion.sheetReverse, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic),
    builder: (sheet) => SizedBox(
      height: MediaQuery.sizeOf(sheet).height * 0.92,
      child: DecoratedBox(
        decoration: BoxDecoration(color: c.surfaceRaised, borderRadius: const BorderRadius.vertical(top: Radius.circular(AQRadius.large)), boxShadow: AQElevation.modal),
        child: _FilterBody(all: all, initial: initial.copy(), query: query),
      ),
    ),
  );
}

class _FilterBody extends StatefulWidget {
  final List<Property> all;
  final AQFilters initial;
  final String query;
  const _FilterBody({required this.all, required this.initial, required this.query});
  @override
  State<_FilterBody> createState() => _FilterBodyState();
}

class _FilterBodyState extends State<_FilterBody> {
  late final AQFilters _d = widget.initial;
  bool _moreAreas = false, _moreAmenities = false;
  static const _fold = 6;

  late final List<String> _areas = ({for (final p in widget.all) p.area}.toList()..sort());
  late final List<String> _amenities = ({for (final p in widget.all) ...p.amenities}.toList()..sort());

  int get _count => _d.apply(widget.all, query: widget.query).length;

  double _snap(double v, double hi) {
    final step = hi > 100000 ? 5000.0 : (hi > 10000 ? 1000.0 : (hi > 2000 ? 100.0 : 10.0));
    return (v / step).round() * step;
  }

  Widget _title(BuildContext context, String text, {Widget? trailing}) => Padding(
        padding: const EdgeInsets.only(top: AQSpacing.x5, bottom: AQSpacing.x3),
        child: Row(children: [Expanded(child: Semantics(header: true, child: Text(text, style: AQTypography.of(context, AQText.titleLarge)))), ?trailing]),
      );

  Widget _price(BuildContext context, FlowStrings f) {
    final c = AQColors.of(context);
    final (lo, hi) = aqPriceBounds(widget.all, _d.tx);
    final a = (_d.minPrice ?? lo).clamp(lo, hi).toDouble();
    final b = (_d.maxPrice ?? hi).clamp(lo, hi).toDouble();
    String money(double v) => Money(v).formatted;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _title(context, f.t('flt.price'), trailing: Flexible(child: Container(padding: const EdgeInsets.symmetric(horizontal: AQSpacing.x3, vertical: 6), decoration: BoxDecoration(color: c.surfaceSelected, borderRadius: BorderRadius.circular(AQRadius.small)), child: FittedBox(fit: BoxFit.scaleDown, child: Text(VFmt.iso('${VFmt.n(context, a.round())} – ${VFmt.n(context, b.round())}'), maxLines: 1, style: AQTypography.of(context, AQText.labelSmall, color: c.accentDeep)))))),
      SliderTheme(
        data: SliderTheme.of(context).copyWith(trackHeight: 4, activeTrackColor: c.accent, inactiveTrackColor: c.hairline, thumbColor: c.accent, overlayColor: c.accent.withValues(alpha: 0.14), rangeThumbShape: const RoundRangeSliderThumbShape(enabledThumbRadius: 12)),
        child: RangeSlider(
          min: lo,
          max: hi,
          values: RangeValues(a, b),
          semanticFormatterCallback: (v) => money(v),
          onChanged: (v) => setState(() {
            final s = _snap(v.start, hi).clamp(lo, hi).toDouble(), e = _snap(v.end, hi).clamp(lo, hi).toDouble();
            _d.minPrice = s <= lo ? null : s;
            _d.maxPrice = e >= hi ? null : e;
          }),
        ),
      ),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(VFmt.iso(money(lo)), style: AQTypography.of(context, AQText.bodySmall, soft: true)),
        Text(VFmt.iso(money(hi)), style: AQTypography.of(context, AQText.bodySmall, soft: true)),
      ]),
    ]);
  }

  Future<void> _pickCount(BuildContext context, FlowStrings f, String title, List<int?> options, int? current, String Function(int) fmt, ValueChanged<int?> set) async {
    await showAQSheet<void>(
      context,
      builder: (s) => Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(padding: const EdgeInsets.fromLTRB(AQSpacing.gutter, AQSpacing.x2, AQSpacing.gutter, AQSpacing.x2), child: Align(alignment: AlignmentDirectional.centerStart, child: Text(title, style: AQTypography.of(s, AQText.headlineSmall)))),
        for (final o in options)
          AQSheetRow(
            title: o == null ? f.t('flt.any') : fmt(o),
            selected: current == o,
            onTap: () {
              setState(() => set(o));
              Navigator.of(s).pop();
            },
          ),
      ]),
    );
  }

  Widget _drop(BuildContext context, {required String icon, required String label, required String value, required VoidCallback onTap}) {
    final c = AQColors.of(context);
    return Semantics(
      button: true,
      label: '$label: $value',
      excludeSemantics: true,
      child: AQPressable(
        onTap: () {
          AQHaptics.selection();
          onTap();
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(horizontal: AQSpacing.x3, vertical: AQSpacing.x2),
          decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(AQRadius.medium), border: Border.all(color: c.hairline)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [AQIcon(icon, size: 18, color: c.accent), const SizedBox(width: 6), Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: Text(label, maxLines: 1, style: AQTypography.of(context, AQText.labelSmall, soft: true))))]),
            const SizedBox(height: 2),
            Row(children: [Flexible(child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: AQTypography.of(context, AQText.titleSmall))), const SizedBox(width: 2), AQIcon('chevron-down', size: 16, color: c.inkSoft)]),
          ]),
        ),
      ),
    );
  }

  Widget _moreToggle(FlowStrings f, bool open, VoidCallback onTap) => AQChoicePill(label: open ? f.t('flt.less') : '+ ${f.t('flt.more')}', selected: false, onTap: onTap);

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final n = _count;
    final metric = f.t('flt.areaUnit');
    final tiles = [
      _drop(context, icon: 'bed', label: f.t('flt.beds'), value: _d.beds == null ? f.t('flt.any') : '${VFmt.n(context, _d.beds!)}+', onTap: () => _pickCount(context, f, f.t('flt.beds'), const [null, 1, 2, 3, 4, 5], _d.beds, (v) => '${VFmt.n(context, v)}+', (v) => _d.beds = v)),
      _drop(context, icon: 'home', label: f.t('flt.baths'), value: _d.baths == null ? f.t('flt.any') : '${VFmt.n(context, _d.baths!)}+', onTap: () => _pickCount(context, f, f.t('flt.baths'), const [null, 1, 2, 3, 4], _d.baths, (v) => '${VFmt.n(context, v)}+', (v) => _d.baths = v)),
      _drop(context, icon: 'area', label: metric, value: _d.minArea == null ? f.t('flt.any') : '${VFmt.n(context, _d.minArea!)}+', onTap: () => _pickCount(context, f, metric, const [null, 100, 200, 300, 500, 1000], _d.minArea, (v) => '${VFmt.n(context, v)}+', (v) => _d.minArea = v)),
    ];
    final areas = _moreAreas ? _areas : _areas.take(_fold).toList();
    final amenities = _moreAmenities ? _amenities : _amenities.take(_fold).toList();
    return Column(children: [
      const SizedBox(height: AQSpacing.x3),
      Container(width: 36, height: 4, decoration: BoxDecoration(color: c.hairline, borderRadius: BorderRadius.circular(2))),
      Padding(
        padding: const EdgeInsets.fromLTRB(AQSpacing.gutter, AQSpacing.x3, AQSpacing.x4, 0),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Flexible(child: Semantics(header: true, child: Text(f.t('flt.title'), style: AQTypography.of(context, AQText.displaySmall)))), const AQHelpButton('markets')]),
              Text(f.t('flt.sub'), style: AQTypography.of(context, AQText.bodySmall, soft: true)),
            ]),
          ),
          AQTextButton(label: f.t('flt.clear'), color: c.accentDeep, onPressed: () => setState(_d.reset)),
          AQIconButton(icon: 'close', semanticsLabel: f.t('flt.close'), onPressed: () => Navigator.of(context).pop()),
        ]),
      ),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(AQSpacing.gutter, 0, AQSpacing.gutter, AQSpacing.x4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _title(context, f.t('flt.type')),
            Wrap(spacing: AQSpacing.x2, runSpacing: AQSpacing.x2, children: [
              AQChoicePill(label: f.t('flt.all'), selected: _d.types.isEmpty && _d.category == null, onTap: () => setState(() {
                    _d.types.clear();
                    _d.category = null;
                  })),
              for (final t in aqFilterTypes)
                AQChoicePill(label: f.t('ptype.${t.name}'), selected: _d.types.contains(t), onTap: () => setState(() {
                      _d.category = null;
                      _d.types.contains(t) ? _d.types.remove(t) : _d.types.add(t);
                    })),
            ]),
            _title(context, f.t('flt.purpose')),
            Wrap(spacing: AQSpacing.x2, runSpacing: AQSpacing.x2, children: [
              AQChoicePill(label: f.t('flt.any'), selected: _d.tx == null, onTap: () => setState(() {
                    _d.tx = null;
                    _d.minPrice = _d.maxPrice = null;
                  })),
              AQChoicePill(label: f.t('home.buy'), selected: _d.tx == TransactionType.buy, onTap: () => setState(() {
                    _d.tx = TransactionType.buy;
                    _d.minPrice = _d.maxPrice = null;
                  })),
              AQChoicePill(label: f.t('home.rent'), selected: _d.tx == TransactionType.rent, onTap: () => setState(() {
                    _d.tx = TransactionType.rent;
                    _d.minPrice = _d.maxPrice = null;
                  })),
            ]),
            _price(context, f),
            if (_areas.isNotEmpty) ...[
              _title(context, f.t('flt.location')),
              Wrap(spacing: AQSpacing.x2, runSpacing: AQSpacing.x2, children: [
                AQChoicePill(label: f.t('flt.allAreas'), selected: _d.areas.isEmpty, onTap: () => setState(_d.areas.clear)),
                for (final a in areas) AQChoicePill(label: a, selected: _d.areas.contains(a), onTap: () => setState(() => _d.areas.contains(a) ? _d.areas.remove(a) : _d.areas.add(a))),
                if (_areas.length > _fold) _moreToggle(f, _moreAreas, () => setState(() => _moreAreas = !_moreAreas)),
              ]),
            ],
            _title(context, f.t('flt.details')),
            aqLargeText(context) || MediaQuery.sizeOf(context).width < 360
                ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (final t in tiles) Padding(padding: const EdgeInsets.only(bottom: AQSpacing.x2), child: t)])
                : Row(children: [for (var i = 0; i < tiles.length; i++) ...[if (i > 0) const SizedBox(width: AQSpacing.x2), Expanded(child: tiles[i])]]),
            if (_amenities.isNotEmpty) ...[
              _title(context, f.t('flt.features')),
              Wrap(spacing: AQSpacing.x2, runSpacing: AQSpacing.x2, children: [
                for (final a in amenities) AQChoicePill(label: a, selected: _d.amenities.contains(a), onTap: () => setState(() => _d.amenities.contains(a) ? _d.amenities.remove(a) : _d.amenities.add(a))),
                if (_amenities.length > _fold) _moreToggle(f, _moreAmenities, () => setState(() => _moreAmenities = !_moreAmenities)),
              ]),
            ],
            const SizedBox(height: AQSpacing.x5),
            AQCheckToggle(label: f.t('flt.verified'), value: _d.verifiedOnly, onChanged: (v) => setState(() => _d.verifiedOnly = v)),
          ]),
        ),
      ),
      DecoratedBox(
        decoration: BoxDecoration(color: c.surfaceRaised, border: Border(top: BorderSide(color: c.hairline))),
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.only(bottom: AQSpacing.x2),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AQSpacing.gutter, AQSpacing.x3, AQSpacing.gutter, AQSpacing.x1),
            child: aqLargeText(context)
                ? Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [_show(context, f, n), const SizedBox(height: AQSpacing.x2), _reset(f)])
                : Row(children: [Expanded(child: _reset(f)), const SizedBox(width: AQSpacing.x3), Expanded(child: _show(context, f, n))]),
          ),
        ),
      ),
    ]);
  }

  Widget _reset(FlowStrings f) => AQSecondaryButton(label: f.t('flt.reset'), leadingIcon: 'refresh', trailingChevron: false, onPressed: () => setState(_d.reset));

  Widget _show(BuildContext context, FlowStrings f, int n) => AQPrimaryButton(
        label: n == 0 ? f.t('flt.none') : f.t('flt.show', {'n': VFmt.n(context, n)}),
        trailingChevron: false,
        onPressed: n == 0 ? null : () => Navigator.of(context).pop(_d),
      );
}

/// Labelled switch row.
class AQCheckToggle extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const AQCheckToggle({super.key, required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    return Semantics(
      toggled: value,
      label: label,
      excludeSemantics: true,
      onTap: () => onChanged(!value),
      child: AQPressable(
        onTap: () {
          AQHaptics.selection();
          onChanged(!value);
        },
        pressedScale: 0.99,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: AQSpacing.x4),
          decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(AQRadius.medium), border: Border.all(color: c.hairline)),
          child: Row(children: [
            AQIcon('verified', size: 22, color: c.accent),
            const SizedBox(width: AQSpacing.x3),
            Expanded(child: Text(label, style: AQTypography.of(context, AQText.bodyMedium))),
            ExcludeSemantics(
              child: AnimatedContainer(
                duration: AQMotion.scaled(context, AQMotion.fast),
                curve: AQMotion.standardCurve,
                width: 48,
                height: 28,
                padding: const EdgeInsets.all(3),
                alignment: value ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
                decoration: BoxDecoration(color: value ? c.accent : c.surfaceSelected, borderRadius: BorderRadius.circular(14), border: Border.all(color: value ? c.accent : c.hairline)),
                child: Container(width: 22, height: 22, decoration: BoxDecoration(color: value ? c.onAccent : c.inkFaint, shape: BoxShape.circle)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
