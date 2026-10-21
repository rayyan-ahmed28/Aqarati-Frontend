import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/admin_api.dart';
import '../data/admin_models.dart';
import '../theme/admin_theme.dart';

/// DEMO switch: the console runs on [DemoAdminApi] until the admin API is wired. While true, every
/// screen shows a DEMO marker and the login page lists the demo accounts.
const kAdminDemo = true;

final adminApiProvider = Provider<AdminApi>((ref) => DemoAdminApi());

/// Holds the signed-in admin session and notifies the router.
class AdminAuth extends ChangeNotifier {
  AdminAuth(this.api);
  final AdminApi api;
  bool awaitingTotp = false;
  AdminSession? get session => api.session;
  bool get signedIn => api.session != null;
  AdminUser? get user => api.session?.user;
  bool can(Permission p) => user != null && rolePermissions[user!.role]!.contains(p);

  Future<void> signIn(String email, String password) async {
    await api.signIn(email, password);
    awaitingTotp = true;
    notifyListeners();
  }

  Future<void> verify(String code) async {
    await api.verifyTotp(code);
    awaitingTotp = false;
    notifyListeners();
  }

  Future<void> signOut() async {
    await api.signOut();
    awaitingTotp = false;
    notifyListeners();
  }

  void expired() {
    notifyListeners();
  }
}

final adminAuthProvider = ChangeNotifierProvider<AdminAuth>((ref) => AdminAuth(ref.watch(adminApiProvider)));

/// Bumped after every successful write so lists reload from the API (no optimistic success).
final adminRefreshProvider = StateProvider<int>((ref) => 0);

final dashboardProvider = FutureProvider.autoDispose<DashboardStats>((ref) {
  ref.watch(adminRefreshProvider);
  return ref.read(adminApiProvider).dashboard();
});
final queueProvider = FutureProvider.autoDispose<List<QueueItem>>((ref) {
  ref.watch(adminRefreshProvider);
  return ref.read(adminApiProvider).queue();
});
final queueItemProvider = FutureProvider.autoDispose.family<QueueItem?, String>((ref, id) {
  ref.watch(adminRefreshProvider);
  return ref.read(adminApiProvider).item(id);
});
final accountsProvider = FutureProvider.autoDispose<List<CustomerAccount>>((ref) {
  ref.watch(adminRefreshProvider);
  return ref.read(adminApiProvider).accounts();
});
final invitationsProvider = FutureProvider.autoDispose<List<ProviderInvite>>((ref) {
  ref.watch(adminRefreshProvider);
  return ref.read(adminApiProvider).invitations();
});
final moderationProvider = FutureProvider.autoDispose<List<ModerationItem>>((ref) {
  ref.watch(adminRefreshProvider);
  return ref.read(adminApiProvider).moderation();
});
final adsProvider = FutureProvider.autoDispose<List<AdBanner>>((ref) {
  ref.watch(adminRefreshProvider);
  return ref.read(adminApiProvider).ads();
});
final auditProvider = FutureProvider.autoDispose<List<AuditEvent>>((ref) {
  ref.watch(adminRefreshProvider);
  return ref.read(adminApiProvider).audit();
});
final adminsProvider = FutureProvider.autoDispose<List<AdminUser>>((ref) {
  ref.watch(adminRefreshProvider);
  return ref.read(adminApiProvider).admins();
});

String conflictMessage(String code) => switch (code) {
      'ITEM_CLAIMED' => 'Another reviewer holds this item. Claim it first, or wait for their claim to end.',
      'VERSION_MISMATCH' => 'This item changed since you opened it. It has been reloaded; check it again.',
      'SELF_REVIEW' => 'You cannot act on your own or a related account.',
      'SAME_APPROVER' => 'Four-eyes rule: the second approval must come from a different senior reviewer.',
      'ILLEGAL_TRANSITION' => 'That action is not allowed from the current state. The page has been reloaded.',
      'CHECKLIST_INCOMPLETE' => 'Give every checklist item a result before approving.',
      'CHECKLIST_FAILED' => 'An item failed the checklist. Request resubmission or reject with a reason code instead.',
      'REASON_REQUIRED' => 'Choose a reason code. "Other" also needs a note.',
      'NOTE_REJECTED' => 'Notes are shown to the applicant and must not contain ID or document numbers.',
      'DUPLICATE_INVITE' => 'An open invitation already exists for this email.',
      'DUPLICATE_ADMIN' => 'An admin with this email already exists.',
      'VALIDATION_FAILED' => 'Some details are missing or invalid.',
      'NOT_FOUND' => 'This record no longer exists.',
      _ => 'The action could not be completed.',
    };

/// Runs an admin write. Handles session expiry (to the expiry page), step-up re-authentication (asks
/// for the TOTP code and retries once), permission denial and conflicts. Returns the result, or null
/// when the action did not succeed. Success is only reported after the API returns.
Future<T?> runAdmin<T>(BuildContext context, WidgetRef ref, Future<T> Function() op, {String? success}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  void say(String m) => messenger?.showSnackBar(SnackBar(content: Text(m)));
  Future<T?> attempt({bool retried = false}) async {
    try {
      final r = await op();
      ref.read(adminRefreshProvider.notifier).state++;
      if (success != null) say(success);
      return r;
    } on SessionExpired {
      ref.read(adminAuthProvider).expired();
      if (context.mounted) context.go('/session-expired');
    } on StepUpRequired {
      if (retried || !context.mounted) return null;
      final ok = await stepUpDialog(context, ref);
      if (ok) return attempt(retried: true);
    } on AdminForbidden {
      say('Your role does not allow this action. Nothing was changed.');
    } on AdminConflict catch (e) {
      ref.read(adminRefreshProvider.notifier).state++;
      say(conflictMessage(e.code));
    } catch (_) {
      say('Could not reach the admin service. Nothing was changed. Try again.');
    }
    return null;
  }

  return attempt();
}

/// Re-enter the TOTP code before approve, reject or suspend (15-minute step-up).
Future<bool> stepUpDialog(BuildContext context, WidgetRef ref) async {
  final ctrl = TextEditingController();
  String? error;
  var busy = false;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) {
        final c = AdminColors.of(ctx);
        Future<void> submit() async {
          set(() => busy = true);
          try {
            await ref.read(adminApiProvider).stepUp(ctrl.text.trim());
            if (ctx.mounted) Navigator.of(ctx).pop(true);
          } catch (_) {
            set(() {
              error = 'That code is not valid. Enter the current code from your authenticator.';
              busy = false;
            });
          }
        }

        return AlertDialog(
          backgroundColor: c.surfaceRaised,
          title: Text('Confirm it is you', style: adminDisplay(ctx, size: 22)),
          content: SizedBox(
            width: 380,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Decisions and suspensions need a fresh authenticator code. It stays valid for 15 minutes.', style: adminText(ctx, soft: true)),
              const SizedBox(height: AdminSpace.x4),
              TextField(controller: ctrl, autofocus: true, keyboardType: TextInputType.number, maxLength: 6, decoration: InputDecoration(labelText: 'Authenticator code', errorText: error), onSubmitted: (_) => submit()),
              if (kAdminDemo) Text('Demo code: ${DemoAdminApi.demoTotp}', style: adminText(ctx, size: 12, soft: true)),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
            FilledButton(onPressed: busy ? null : submit, child: busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Confirm')),
          ],
        );
      },
    ),
  );
  ctrl.dispose();
  return ok ?? false;
}

/// Confirmation for a consequential action. Resolves true only on the confirm button.
Future<bool> confirmAdmin(BuildContext context, {required String title, required String body, required String confirm, bool destructive = false}) async {
  final c = AdminColors.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: c.surfaceRaised,
      title: Text(title, style: adminDisplay(ctx, size: 22)),
      content: SizedBox(width: 420, child: Text(body, style: adminText(ctx, soft: true))),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
        FilledButton(style: destructive ? FilledButton.styleFrom(backgroundColor: c.danger) : null, onPressed: () => Navigator.of(ctx).pop(true), child: Text(confirm)),
      ],
    ),
  );
  return ok ?? false;
}
