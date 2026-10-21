import '../../features/account/account_strings.dart';
import '../../features/broker/broker_strings.dart';
import '../../features/help/help_strings.dart';
import '../../features/listings/listing_strings.dart';
import '../../features/provider/provider_strings.dart';
import '../../features/reviews/review_strings.dart';

/// Aggregates copy added by later feature modules. Arabic is DRAFT copy and needs native review.
/// A const map rejects duplicate keys at compile time, so modules cannot silently override each other.
const Map<String, (String, String)> extraStrings = {
  ...kitStrings,
  ...helpStrings,
  ...listingStrings,
  ...brokerStrings,
  ...reviewStrings,
  ...accountStrings,
  ...providerStrings,
};

const Map<String, (String, String)> kitStrings = {
  'upd.title': ('Please update AQARATI', 'يرجى تحديث عقاراتي'),
  'upd.body': ('This version is no longer supported. Update the app to keep using AQARATI safely.', 'لم يعد هذا الإصدار مدعوماً. حدّث التطبيق لمتابعة استخدام عقاراتي بأمان.'),
  'upd.versions': ('Installed {have} · minimum {need}', 'المثبّت {have} · الحد الأدنى {need}'),
  'upd.store': ('Open the App Store or Google Play and update AQARATI. Store links will appear here once the app is published.', 'افتح متجر التطبيقات أو Google Play وحدّث عقاراتي. ستظهر روابط المتجر هنا عند نشر التطبيق.'),
  'upd.check': ('I have updated, check again', 'حدّثت التطبيق، تحقّق مجدداً'),
  'kit.chars.rule': ('Between {min} and {max} characters.', 'بين {min} و{max} حرفاً.'),
  // Reason codes from the closed list of 12 (architecture section 50.2). Earlier demo codes stay above.
  'reason.DOC_WRONG_TYPE': ('This is not the document that was asked for.', 'هذا ليس المستند المطلوب.'),
  'reason.NAME_MISMATCH': ('The name on the document does not match the name on the account.', 'الاسم في المستند لا يطابق الاسم في الحساب.'),
  'reason.EXPIRED': ('The document has expired.', 'انتهت صلاحية المستند.'),
  'reason.NOT_ON_REGISTRY': ('The registration or licence could not be found on the official register.', 'تعذّر العثور على السجل أو الرخصة في السجل الرسمي.'),
  'reason.LICENCE_CATEGORY_MISMATCH': ('The licence does not cover this kind of service.', 'الرخصة لا تغطي هذا النوع من الخدمات.'),
  'reason.OWNER_MISMATCH': ('The owner on the title deed does not match your photo ID, and no owner authorisation was provided.', 'المالك في سند الملكية لا يطابق هويتك، ولم يُقدَّم تفويض من المالك.'),
  'reason.DUPLICATE_LISTING': ('This property is already listed.', 'هذا العقار معروض بالفعل.'),
  'reason.PHOTOS_MISMATCH': ('The photos do not match the property described.', 'الصور لا تطابق العقار الموصوف.'),
  'reason.CALL_FAILED': ('We could not reach the business on its registered contact number.', 'تعذّر الوصول إلى الجهة على رقم التواصل المسجّل.'),
  'reason.INCOMPLETE_SUBMISSION': ('Some required information or documents were missing.', 'كانت بعض البيانات أو المستندات المطلوبة ناقصة.'),
  'reason.OTHER': ('The reviewer left a note explaining what to change.', 'ترك المراجع ملاحظة توضح ما يجب تغييره.'),
};
