import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:msu_wellbeing/core/router/app_routes.dart';
import 'package:msu_wellbeing/core/router/app_shell.dart';
import 'package:msu_wellbeing/core/router/route_guard.dart';
import 'package:msu_wellbeing/features/assessment/presentation/screens/report_detail_screen.dart';
import 'package:msu_wellbeing/features/assessment/presentation/screens/report_list_screen.dart';
import 'package:msu_wellbeing/features/auth/presentation/controllers/startup_controller.dart';
import 'package:msu_wellbeing/features/auth/presentation/screens/lock_screen.dart';
import 'package:msu_wellbeing/features/auth/presentation/screens/login_screen.dart';
import 'package:msu_wellbeing/features/auth/presentation/screens/splash_screen.dart';
import 'package:msu_wellbeing/features/chat/presentation/screens/chat_screen.dart';
import 'package:msu_wellbeing/features/crisis/presentation/screens/crisis_screen.dart';
import 'package:msu_wellbeing/features/home/presentation/screens/home_screen.dart';
import 'package:msu_wellbeing/features/learn/presentation/screens/article_screen.dart';
import 'package:msu_wellbeing/features/learn/presentation/screens/breathing_screen.dart';
import 'package:msu_wellbeing/features/learn/presentation/screens/learn_screen.dart';
import 'package:msu_wellbeing/features/learn/presentation/screens/release_screen.dart';
import 'package:msu_wellbeing/features/learn/presentation/screens/sounds_screen.dart';
import 'package:msu_wellbeing/features/onboarding/presentation/screens/consent_screen.dart';
import 'package:msu_wellbeing/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:msu_wellbeing/features/profile/presentation/screens/consent_history_screen.dart';
import 'package:msu_wellbeing/features/profile/presentation/screens/privacy_screen.dart';
import 'package:msu_wellbeing/features/profile/presentation/screens/profile_screen.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_router.g.dart';

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

GoRoute _route(String path, Widget Function(GoRouterState state) build) =>
    GoRoute(path: path, builder: (context, state) => build(state));

@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  final refresh = ValueNotifier<GateState>(ref.read(gateStateProvider));
  ref.listen(gateStateProvider, (_, next) => refresh.value = next);

  final router = GoRouter(
    navigatorKey: _rootKey,
    initialLocation: AppRoutes.splash,
    refreshListenable: refresh,
    redirect: (context, state) =>
        guardRedirect(refresh.value, state.matchedLocation),
    routes: [
      _route(AppRoutes.splash, (_) => const SplashScreen()),
      _route(AppRoutes.onboarding, (_) => const OnboardingScreen()),
      _route(AppRoutes.consent, (_) => const ConsentScreen()),
      _route(AppRoutes.login, (_) => const LoginScreen()),
      _route(AppRoutes.lock, (_) => const LockScreen()),
      GoRoute(
        path: AppRoutes.crisis,
        parentNavigatorKey: _rootKey,
        pageBuilder: (context, state) =>
            const MaterialPage(fullscreenDialog: true, child: CrisisScreen()),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomeScreen(),
                routes: [
                  GoRoute(
                    path: 'reports',
                    builder: (context, state) => const ReportListScreen(),
                    routes: [
                      GoRoute(
                        path: ':id',
                        builder: (context, state) => ReportDetailScreen(
                          reportId: state.pathParameters['id']!,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              _route(
                AppRoutes.chat,
                (state) => ChatScreen(
                  initialTab: ChatTab.parse(state.uri.queryParameters['tab']),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.learn,
                builder: (context, state) => const LearnScreen(),
                routes: [
                  GoRoute(
                    path: 'article/:id',
                    builder: (context, state) =>
                        ArticleScreen(articleId: state.pathParameters['id']!),
                  ),
                  GoRoute(
                    path: 'breathing',
                    builder: (context, state) => const BreathingScreen(),
                  ),
                  GoRoute(
                    path: 'release',
                    builder: (context, state) => const ReleaseScreen(),
                  ),
                  GoRoute(
                    path: 'sounds',
                    builder: (context, state) => const SoundsScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (context, state) => const ProfileScreen(),
                routes: [
                  GoRoute(
                    path: 'privacy',
                    builder: (context, state) => const PrivacyScreen(),
                  ),
                  GoRoute(
                    path: 'consent-history',
                    builder: (context, state) => const ConsentHistoryScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
}
