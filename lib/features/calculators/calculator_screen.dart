import 'package:flutter/material.dart';
import '../help/help.dart';
import 'package:flutter/services.dart';
import '../../core/aq/aq_forms.dart';
import '../../core/aq/aq_scene.dart';
import '../../core/aq/aq_tokens.dart';
import '../../core/aq/aq_typography.dart';
import '../../core/localization/flow_strings.dart';
import '../../data/models/money.dart';
import '../viewing/widgets/viewing_format.dart';
import '../viewing/widgets/viewing_scaffold.dart';
import 'calculator_logic.dart';
import 'calculator_models.dart';

/// One calculator: inputs on top, results update as the numbers change. Nothing is
/// shown until the inputs make sense; results are estimates, not offers.
class CalculatorScreen extends StatefulWidget {
  final CalculatorType type;
  const CalculatorScreen({super.key, required this.type});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  late final List<CalcField> _fields = calcFields(widget.type);
  late final Map<String, TextEditingController> _ctl = {for (final f in _fields) f.key: TextEditingController(text: f.initial ?? '')};

  @override
  void dispose() {
    for (final c in _ctl.values) {
      c.dispose();
    }
    super.dispose();
  }

  double? _parse(String key) => double.tryParse(_ctl[key]!.text.replaceAll(',', '').trim());

  String _fmt(BuildContext context, CalcOut o, FlowStrings f) {
    switch (o.format) {
      case CalcFormat.money:
        return VFmt.iso(Money(o.value).formatted);
      case CalcFormat.percent:
        return '${VFmt.dec(context, o.value)}%';
      case CalcFormat.years:
        return o.value == 0 ? '—' : f.t('calc.years', {'n': VFmt.dec(context, o.value, digits: 1)});
      case CalcFormat.text:
        return f.t(o.text!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final values = {for (final fl in _fields) fl.key: _parse(fl.key)};
    final out = calculate(widget.type, values);
    final hero = out?.where((o) => o.hero).firstOrNull;
    final rest = out?.where((o) => !o.hero).toList() ?? const <CalcOut>[];
    final note = switch (widget.type) {
      CalculatorType.emi || CalculatorType.affordability || CalculatorType.rentVsBuy => f.t('calc.n.${widget.type.name}', {'y': VFmt.n(context, kLoanTermYears), 's': VFmt.n(context, (kAffordabilityShare * 100).round()), 'u': VFmt.n(context, (kUpkeepShare * 100).round())}),
      _ => null,
    };
    return AQViewingScaffold(
      title: f.t('calc.t.${widget.type.name}'),
      subtitle: f.t('calc.d.${widget.type.name}'),
      backLabel: f.t('common.back'),
      onBack: () => aqBack(context, '/calculators'),
      children: [
        for (var i = 0; i < _fields.length; i++) ...[
          AQTextField(
            label: f.t('calc.f.${_fields[i].key}'),
            controller: _ctl[_fields[i].key]!,
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            action: i == _fields.length - 1 ? TextInputAction.done : TextInputAction.next,
            formatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,-]'))],
            suffix: _fields[i].unit == null ? null : Padding(padding: const EdgeInsetsDirectional.only(end: AQSpacing.x3), child: Center(widthFactor: 1, child: Text(f.t('calc.u.${_fields[i].unit}'), style: AQTypography.of(context, AQText.labelMedium, soft: true)))),
            error: _ctl[_fields[i].key]!.text.trim().isNotEmpty && _parse(_fields[i].key) == null ? f.t('calc.err.number') : null,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AQSpacing.x3),
        ],
        const SizedBox(height: AQSpacing.x2),
        AnimatedSwitcher(
          duration: AQMotion.scaled(context, AQMotion.standard),
          child: out == null
              ? Padding(key: const ValueKey('hint'), padding: const EdgeInsets.symmetric(vertical: AQSpacing.x4), child: Text(f.t('calc.hint'), style: AQTypography.of(context, AQText.bodyMedium, soft: true)))
              : Container(
                  key: const ValueKey('result'),
                  padding: const EdgeInsets.all(AQSpacing.x5),
                  decoration: BoxDecoration(color: c.surfaceRaised, borderRadius: BorderRadius.circular(AQRadius.large), border: Border.all(color: c.hairline), boxShadow: AQElevation.floating),
                  child: Semantics(
                    liveRegion: true,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      if (hero != null) ...[
                        Text(f.t(hero.labelKey), style: AQTypography.of(context, AQText.labelMedium, soft: true)),
                        const SizedBox(height: 4),
                        Text(_fmt(context, hero, f), style: AQTypography.of(context, AQText.displaySmall, color: c.accentDeep)),
                        if (rest.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: AQSpacing.x3), child: Divider(height: 1, color: c.hairline)),
                      ],
                      for (final o in rest)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Expanded(child: Text(f.t(o.labelKey), style: AQTypography.of(context, AQText.bodyMedium, soft: true))),
                            const SizedBox(width: AQSpacing.x3),
                            Flexible(child: Text(_fmt(context, o, f), textAlign: TextAlign.end, style: AQTypography.of(context, AQText.titleSmall))),
                          ]),
                        ),
                    ]),
                  ),
                ),
        ),
        if (out != null && note != null) Padding(padding: const EdgeInsets.only(top: AQSpacing.x3), child: Text(note, style: AQTypography.of(context, AQText.bodySmall, soft: true))),
        Padding(padding: const EdgeInsets.only(top: AQSpacing.x3, bottom: AQSpacing.x4), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: Text(f.t('calc.disclaimer'), style: AQTypography.of(context, AQText.bodySmall, color: c.inkFaint))), const AQHelpButton('loan')])),
      ],
    );
  }
}
