import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/aq/aq_kit.dart';
import '../../core/aq/aq_primitives.dart';
import '../../core/aq/aq_tokens.dart';
import '../../core/aq/aq_typography.dart';
import '../../core/localization/flow_strings.dart';
import '../devbuild/db_widgets.dart' show dbGovLabel;
import '../flow/state/document_state.dart' show hasAllowedSignature;
import 'listing_models.dart';

const kListingMaxFileBytes = 10 * 1024 * 1024;

/// Chooses photos and ownership documents. Replaceable in tests.
abstract class ListingFilePicker {
  Future<ListingFile?> pickPhoto();
  Future<ListingFile?> pickDocument();
}

class FilePickerListingAdapter implements ListingFilePicker {
  Future<ListingFile?> _pick(List<String> ext) async {
    final f = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ext);
    if (f == null) return null;
    final size = await f.length() ?? 0;
    if (size > kListingMaxFileBytes) return ListingFile(name: f.name, sizeBytes: size);
    final bytes = await f.readAsBytes();
    return ListingFile(name: f.name, sizeBytes: size > 0 ? size : bytes.length, bytes: bytes);
  }

  @override
  Future<ListingFile?> pickPhoto() => _pick(const ['jpg', 'jpeg', 'png']);
  @override
  Future<ListingFile?> pickDocument() => _pick(const ['pdf', 'jpg', 'jpeg', 'png']);
}

final listingFilePickerProvider = Provider<ListingFilePicker>((ref) => FilePickerListingAdapter());

/// File checks before anything is sent: signature (not extension) and the 10 MB limit (section 19.1).
bool listingFileAcceptable(ListingFile f, {required bool photo}) {
  if (f.asset != null) return true;
  final b = f.bytes;
  if (b == null || f.sizeBytes > kListingMaxFileBytes || b.isEmpty) return false;
  if (!hasAllowedSignature(b)) return false;
  // Photos must be images, not PDFs.
  if (photo && b.length >= 4 && b[0] == 0x25 && b[1] == 0x50) return false;
  return true;
}

/// Bundled photographs used only by the QA "sample photos" shortcut (never real listing media).
const kSampleListingPhotos = [
  'assets/properties/p4/01_Contemporary_family_villa_comple.jpg',
  'assets/properties/p4/02_Contemporary_villa_at_sunset.jpg',
  'assets/properties/p4/06_Courtyard_villa_architecture_design.jpg',
];

String omr(BuildContext context, double v) {
  final f = FlowStrings.of(context);
  final n = NumberFormat('#,##0.###', f.ar ? 'ar' : 'en').format(v);
  return f.ar ? '$n ر.ع.' : 'OMR $n';
}

String listingDate(BuildContext context, DateTime d) => DateFormat.yMMMd(FlowStrings.of(context).ar ? 'ar' : 'en').format(d);

String listingKind(FlowStrings f, ListingSubType s, ListingAction a, {ListingChannel? channel}) =>
    '${f.t('lst.sub.${s.name}')} · ${channel == ListingChannel.eBroker ? f.t('lst.act.buy') : f.t('lst.act.${a.name}')}';

String listingPlace(FlowStrings f, String gov, String wilayat, [String area = '']) => [if (area.trim().isNotEmpty) area.trim(), if (wilayat.isNotEmpty) wilayat, if (gov.isNotEmpty) dbGovLabel(f, gov)].join(', ');

AQPillTone listingTone(ListingState s) => switch (s) {
      ListingState.approvedActive => AQPillTone.success,
      ListingState.pending => AQPillTone.pending,
      ListingState.draft => AQPillTone.neutral,
      ListingState.resubmissionRequired || ListingState.expired => AQPillTone.warning,
      ListingState.rejected => AQPillTone.danger,
      ListingState.hidden || ListingState.sold || ListingState.rented || ListingState.withdrawn => AQPillTone.neutral,
    };

String listingIcon(ListingState s) => switch (s) {
      ListingState.approvedActive => 'verified',
      ListingState.pending => 'clock',
      ListingState.draft => 'edit',
      ListingState.resubmissionRequired => 'alert',
      ListingState.expired => 'calendar-x',
      ListingState.rejected => 'close',
      ListingState.hidden => 'eye-off',
      ListingState.sold || ListingState.rented || ListingState.withdrawn => 'check',
    };

class ListingStatePill extends StatelessWidget {
  final ListingState state;
  const ListingStatePill(this.state, {super.key});
  @override
  Widget build(BuildContext context) => AQStatusPill(FlowStrings.of(context).t('lst.st.${state.name}'), tone: listingTone(state), icon: listingIcon(state));
}

/// Photo from a picked file, a bundled sample, or a calm placeholder.
class ListingPhoto extends StatelessWidget {
  final ListingFile? file;
  final double? width, height;
  final double radius;
  const ListingPhoto(this.file, {super.key, this.width, this.height, this.radius = AQRadius.small});

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    final placeholder = Container(width: width, height: height, color: c.surfaceSelected, child: Center(child: AQIcon('home', size: 22, color: c.inkFaint)));
    final f = file;
    Widget img = placeholder;
    if (f?.asset != null) img = Image.asset(f!.asset!, width: width, height: height, fit: BoxFit.cover, cacheWidth: 600, errorBuilder: (_, _, _) => placeholder);
    if (f?.bytes != null) img = Image.memory(f!.bytes!, width: width, height: height, fit: BoxFit.cover, cacheWidth: 600, errorBuilder: (_, _, _) => placeholder);
    return ClipRRect(borderRadius: BorderRadius.circular(radius), child: SizedBox(width: width, height: height, child: img));
  }
}

/// One row on My Listings.
class ListingRow extends StatelessWidget {
  final String title, subtitle;
  final String? price;
  final ListingFile? photo;
  final Widget status;
  final String? note;
  final VoidCallback onTap;
  const ListingRow({super.key, required this.title, required this.subtitle, this.price, this.photo, required this.status, this.note, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AQSpacing.x3),
      child: Semantics(
        button: true,
        label: [title, subtitle, ?price, ?note].join('. '),
        child: AQPressable(
          onTap: onTap,
          pressedScale: 0.99,
          child: Container(
            padding: const EdgeInsets.all(AQSpacing.x3),
            decoration: BoxDecoration(color: c.surfaceRaised, borderRadius: BorderRadius.circular(AQRadius.medium), border: Border.all(color: c.hairline)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ListingPhoto(photo, width: 76, height: 76),
              const SizedBox(width: AQSpacing.x3),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: AQTypography.of(context, AQText.titleSmall)),
                  const SizedBox(height: 2),
                  Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: AQTypography.of(context, AQText.bodySmall, soft: true)),
                  if (price != null) ...[const SizedBox(height: 2), Text(price!, style: AQTypography.of(context, AQText.labelMedium, color: c.accentDeep))],
                  const SizedBox(height: AQSpacing.x2),
                  Wrap(spacing: AQSpacing.x2, runSpacing: AQSpacing.x1, children: [status, if (note != null) AQStatusPill(note!, tone: AQPillTone.pending, icon: 'edit')]),
                ]),
              ),
              Padding(padding: const EdgeInsets.only(top: 4), child: AQIcon('chevron-right', size: AQIconSize.small, color: c.inkFaint, directional: true)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// A file slot for an ownership document: name and size once chosen, never the content.
class ListingDocSlot extends StatelessWidget {
  final String label;
  final ListingFile? file;
  final String? error;
  final bool busy;
  final VoidCallback onPick;
  final VoidCallback? onSample;
  const ListingDocSlot({super.key, required this.label, required this.file, this.error, this.busy = false, required this.onPick, this.onSample});

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: AQSpacing.x3),
      padding: const EdgeInsets.all(AQSpacing.x4),
      decoration: BoxDecoration(color: c.surfaceRaised, borderRadius: BorderRadius.circular(AQRadius.medium), border: Border.all(color: error != null ? c.danger : c.hairline)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          AQIcon(file == null ? 'plus' : 'check', size: AQIconSize.medium, color: file == null ? c.accentDeep : c.success),
          const SizedBox(width: AQSpacing.x3),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: AQTypography.of(context, AQText.titleSmall)),
              if (file != null) Text(file!.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AQTypography.of(context, AQText.bodySmall, soft: true)),
            ]),
          ),
          if (busy)
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          else
            AQTextButton(label: file == null ? f.t('lst.w.docs.choose') : f.t('lst.w.docs.replace'), color: c.accentDeep, onPressed: onPick),
        ]),
        if (onSample != null && file == null) Align(alignment: AlignmentDirectional.centerEnd, child: AQTextButton(label: f.t('lst.w.docs.sample'), onPressed: onSample)),
        if (error != null) Semantics(liveRegion: true, child: Text(f.t(error!), style: AQTypography.of(context, AQText.bodySmall, color: c.danger))),
      ]),
    );
  }
}
