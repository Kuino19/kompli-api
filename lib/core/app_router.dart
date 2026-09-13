import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

import '../features/auth/providers/auth_provider.dart';
import '../features/dashboard/screens/dashboard_screen.dart';
import '../features/ai_assistant/screens/ai_chat_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/signup_screen.dart';
import '../features/documents/screens/document_generator_screen.dart';
import '../features/documents/screens/document_preview_screen.dart';
import '../features/profile/screens/business_profile_screen.dart';
import '../features/dashboard/screens/compliance_screen.dart';
import '../features/onboarding/screens/onboarding_screen.dart';
import '../features/compliance/screens/verification_screen.dart';
import '../features/auth/screens/passcode_screen.dart';
import '../features/profile/screens/app_policies_screen.dart';

// Provider to check if onboarding is done
final onboardingDoneProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('onboarding_done') ?? false;
});

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final onboardingDone = ref.watch(onboardingDoneProvider);

  return GoRouter(
    initialLocation: '/',
    observers: [
      FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
    ],
    redirect: (context, state) {
      // Wait until onboarding state is loaded
      if (onboardingDone.isLoading) return null;

      final isDone = onboardingDone.value ?? false;
      final isOnboarding = state.matchedLocation == '/onboarding';

      // Show onboarding for first-time users
      if (!isDone && !isOnboarding) {
        return '/onboarding';
      }

      final isAuth = authState.value != null;
      final isLoggingIn = state.matchedLocation == '/login' || state.matchedLocation == '/signup';

      if (!isAuth && !isLoggingIn && isDone && !isOnboarding) {
        return '/login';
      }

      if (isAuth && isLoggingIn) {
        return '/';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/chat',
        builder: (context, state) => const AiChatScreen(),
      ),
      GoRoute(
        path: '/generate_nda',
        builder: (context, state) => const DocumentGeneratorScreen(),
      ),
      GoRoute(
        path: '/document_preview',
        builder: (context, state) {
          final data = state.extra as Map<String, dynamic>? ?? {};
          return DocumentPreviewScreen(data: data);
        },
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const BusinessProfileScreen(),
      ),
      GoRoute(
        path: '/policies',
        builder: (context, state) => const AppPoliciesScreen(),
      ),
      GoRoute(
        path: '/compliance',
        builder: (context, state) => const ComplianceScreen(),
      ),
      GoRoute(
        path: '/verify',
        builder: (context, state) => const VerificationScreen(),
      ),
      GoRoute(
        path: '/passcode',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final isSetupMode = extra['isSetupMode'] as bool? ?? false;
          final onSuccess = extra['onSuccess'] as VoidCallback? ?? () {};
          return PasscodeScreen(
            isSetupMode: isSetupMode,
            onSuccess: onSuccess,
          );
        },
      ),
    ],
  );
});
