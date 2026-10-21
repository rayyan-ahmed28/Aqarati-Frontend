import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'screens/auth_screens.dart';
import 'screens/operations_screens.dart';
import 'screens/queue_screens.dart';
import 'state/admin_state.dart';
import 'theme/admin_theme.dart';
import 'ui/admin_shell.dart';

void main() => runApp(const ProviderScope(child: AdminApp()));

/// Pages that do not need a session.
const _public = {'/login', '/totp', '/session-expired'};

GoRouter buildAdminRouter(AdminAuth auth) => GoRouter(
      initialLocation: '/dashboard',
      refreshListenable: auth,
      // Admin guard (section 12): an admin session with completed TOTP, otherwise the login page.
      redirect: (context, state) {
        final path = state.uri.path;
        if (path == '/totp' && !auth.awaitingTotp && !auth.signedIn) return '/login';
        if (!auth.signedIn && !_public.contains(path)) return '/login';
        if (auth.signedIn && (path == '/login' || path == '/totp' || path == '/')) return '/dashboard';
        return null;
      },
      errorBuilder: (context, state) => Scaffold(body: NotFoundScreen(path: state.uri.path)),
      routes: [
        GoRoute(path: '/login', pageBuilder: (c, s) => _fade(s, const LoginScreen())),
        GoRoute(path: '/totp', pageBuilder: (c, s) => _fade(s, const TotpScreen())),
        GoRoute(path: '/session-expired', pageBuilder: (c, s) => _fade(s, const SessionExpiredScreen())),
        ShellRoute(
          builder: (c, s, child) => AdminShell(child: child),
          routes: [
            GoRoute(path: '/dashboard', pageBuilder: (c, s) => _fade(s, const DashboardScreen())),
            GoRoute(path: '/queue', pageBuilder: (c, s) => _fade(s, const QueueScreen())),
            GoRoute(path: '/queue/:id', pageBuilder: (c, s) => _fade(s, QueueItemScreen(key: ValueKey(s.pathParameters['id']), id: s.pathParameters['id']!))),
            GoRoute(path: '/moderation', pageBuilder: (c, s) => _fade(s, const ModerationScreen())),
            GoRoute(path: '/accounts', pageBuilder: (c, s) => _fade(s, const AccountsScreen())),
            GoRoute(path: '/invitations', pageBuilder: (c, s) => _fade(s, const InvitationsScreen())),
            GoRoute(path: '/ads', pageBuilder: (c, s) => _fade(s, const AdsScreen())),
            GoRoute(path: '/audit', pageBuilder: (c, s) => _fade(s, const AuditScreen())),
            GoRoute(path: '/admins', pageBuilder: (c, s) => _fade(s, const AdminUsersScreen())),
            GoRoute(path: '/roles', pageBuilder: (c, s) => _fade(s, const RolesScreen())),
          ],
        ),
      ],
    );

/// Calm cross-fade between console pages (no travel on a desktop console). Reduced motion: instant.
Page<void> _fade(GoRouterState s, Widget child) => CustomTransitionPage<void>(
      key: s.pageKey,
      child: child,
      transitionDuration: AdminMotion.standard,
      reverseTransitionDuration: AdminMotion.fast,
      transitionsBuilder: (context, animation, _, child) => AdminMotion.reduced(context) ? child : FadeTransition(opacity: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic), child: child),
    );

class AdminApp extends ConsumerStatefulWidget {
  const AdminApp({super.key});
  @override
  ConsumerState<AdminApp> createState() => _AdminAppState();
}

class _AdminAppState extends ConsumerState<AdminApp> {
  late final GoRouter _router = buildAdminRouter(ref.read(adminAuthProvider));

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
        title: 'AQARATI Admin',
        debugShowCheckedModeBanner: false,
        theme: adminTheme(Brightness.light),
        darkTheme: adminTheme(Brightness.dark),
        themeMode: ThemeMode.system,
        routerConfig: _router,
        supportedLocales: const [Locale('en'), Locale('ar')],
        localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      );
}
