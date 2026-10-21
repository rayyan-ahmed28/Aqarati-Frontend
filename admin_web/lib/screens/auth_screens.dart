import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../data/admin_api.dart';
import '../data/admin_models.dart';
import '../state/admin_state.dart';
import '../theme/admin_theme.dart';

class _AuthFrame extends StatelessWidget {
  final String title, subtitle;
  final List<Widget> children;
  const _AuthFrame({required this.title, required this.subtitle, required this.children});
  @override
  Widget build(BuildContext context) {
    final c = AdminColors.of(context);
    return Scaffold(
      backgroundColor: c.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AdminSpace.x6),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Container(
              padding: const EdgeInsets.all(AdminSpace.x8),
              decoration: BoxDecoration(color: c.surfaceRaised, borderRadius: BorderRadius.circular(22), border: Border.all(color: c.hairline), boxShadow: const [BoxShadow(color: Color(0x1A2D2823), blurRadius: 28, offset: Offset(0, 10))]),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Center(child: SvgPicture.asset('assets/logo/aqarati_master.svg', height: 84)),
                const SizedBox(height: AdminSpace.x5),
                Text('ADMIN WEB CONSOLE', textAlign: TextAlign.center, style: adminText(context, size: 11, weight: FontWeight.w700, color: c.accentDeep).copyWith(letterSpacing: 1.6)),
                const SizedBox(height: AdminSpace.x2),
                Semantics(header: true, child: Text(title, textAlign: TextAlign.center, style: adminDisplay(context, size: 28))),
                const SizedBox(height: AdminSpace.x2),
                Text(subtitle, textAlign: TextAlign.center, style: adminText(context, soft: true)),
                const SizedBox(height: AdminSpace.x6),
                ...children,
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Separate staff credentials (never customer sign-in) followed by TOTP.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false, _hide = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Enter your admin email and password.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(adminAuthProvider).signIn(_email.text, _password.text);
      if (mounted) context.go('/totp');
    } on InvalidCredentials {
      setState(() => _error = 'Those details are not valid for an admin account.');
    } catch (_) {
      setState(() => _error = 'Could not reach the admin service. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AdminColors.of(context);
    return _AuthFrame(
      title: 'Staff sign in',
      subtitle: 'For AQARATI reviewers and administrators only. Customer accounts cannot sign in here.',
      children: [
        AutofillGroup(
          child: Column(children: [
            TextField(controller: _email, autofillHints: const [AutofillHints.username], keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Admin email'), onSubmitted: (_) => _submit()),
            const SizedBox(height: AdminSpace.x3),
            TextField(
              controller: _password,
              obscureText: _hide,
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(labelText: 'Password', suffixIcon: IconButton(tooltip: _hide ? 'Show password' : 'Hide password', icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined), onPressed: () => setState(() => _hide = !_hide))),
              onSubmitted: (_) => _submit(),
            ),
          ]),
        ),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: AdminSpace.x3), child: Semantics(liveRegion: true, child: Text(_error!, style: adminText(context, color: c.danger)))),
        const SizedBox(height: AdminSpace.x5),
        FilledButton(onPressed: _busy ? null : _submit, child: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Continue')),
        if (kAdminDemo) ...[
          const SizedBox(height: AdminSpace.x5),
          Container(
            padding: const EdgeInsets.all(AdminSpace.x4),
            decoration: BoxDecoration(color: c.surfaceSelected, borderRadius: BorderRadius.circular(AdminSpace.radiusSmall)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('DEMO ACCOUNTS', style: adminText(context, size: 11, weight: FontWeight.w700, color: c.accentDeep)),
              const SizedBox(height: AdminSpace.x2),
              Text('Password ${DemoAdminApi.demoPassword} · authenticator code ${DemoAdminApi.demoTotp}', style: adminText(context, size: 12, soft: true)),
              const SizedBox(height: AdminSpace.x2),
              Wrap(spacing: AdminSpace.x2, runSpacing: AdminSpace.x2, children: [
                for (final e in const ['reviewer@aqarati.test', 'senior@aqarati.test', 'senior2@aqarati.test', 'super@aqarati.test', 'auditor@aqarati.test'])
                  ActionChip(label: Text(e, style: adminText(context, size: 12)), onPressed: () => setState(() {
                        _email.text = e;
                        _password.text = DemoAdminApi.demoPassword;
                      })),
              ]),
            ]),
          ),
        ],
      ],
    );
  }
}

class TotpScreen extends ConsumerStatefulWidget {
  const TotpScreen({super.key});
  @override
  ConsumerState<TotpScreen> createState() => _TotpScreenState();
}

class _TotpScreenState extends ConsumerState<TotpScreen> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(adminAuthProvider).verify(_code.text.trim());
      if (mounted) context.go('/dashboard');
    } on SessionExpired {
      if (mounted) context.go('/login');
    } catch (_) {
      setState(() => _error = 'That code is not valid. Enter the current 6-digit code from your authenticator app.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AdminColors.of(context);
    return _AuthFrame(
      title: 'Two-step verification',
      subtitle: 'Enter the 6-digit code from your authenticator app. Admin access always needs it.',
      children: [
        TextField(controller: _code, autofocus: true, keyboardType: TextInputType.number, maxLength: 6, textAlign: TextAlign.center, style: adminDisplay(context, size: 26), decoration: const InputDecoration(labelText: 'Authenticator code', counterText: ''), onSubmitted: (_) => _verify()),
        if (_error != null) Semantics(liveRegion: true, child: Text(_error!, style: adminText(context, color: c.danger))),
        const SizedBox(height: AdminSpace.x5),
        FilledButton(onPressed: _busy ? null : _verify, child: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Verify and sign in')),
        TextButton(onPressed: () => context.go('/login'), child: const Text('Use a different account')),
      ],
    );
  }
}

class SessionExpiredScreen extends ConsumerWidget {
  const SessionExpiredScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => _AuthFrame(
        title: 'Session ended',
        subtitle: 'Admin sessions are short and end after inactivity. Sign in again with your password and authenticator code. Unsaved decisions were not submitted.',
        children: [FilledButton(onPressed: () => context.go('/login'), child: const Text('Sign in again'))],
      );
}

class ForbiddenScreen extends StatelessWidget {
  const ForbiddenScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(body: Center(child: Text('This page is not available for your role.', style: adminText(context))));
}

/// Shown for an unknown console address.
class NotFoundScreen extends StatelessWidget {
  final String path;
  const NotFoundScreen({super.key, required this.path});
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Page not found', style: adminDisplay(context)),
          const SizedBox(height: AdminSpace.x2),
          Text('There is no console page at $path.', style: adminText(context, soft: true)),
          const SizedBox(height: AdminSpace.x4),
          FilledButton(onPressed: () => context.go('/dashboard'), child: const Text('Go to dashboard')),
        ]),
      );
}

bool allowedFor(AdminAuth auth, Permission? p) => p == null || auth.can(p);
