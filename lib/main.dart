import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'core/theme/app_theme.dart';
import 'core/app_router.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'services/billing_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Safely load .env — won't crash if file is missing
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('main: .env file not found or failed to load: $e');
  }

  // Initialize notifications
  try {
    await NotificationService().init();
    await NotificationService().scheduleComplianceReminders();
  } catch (e) {
    debugPrint('main: Notification init failed: $e');
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    await BillingService().init();

    FlutterError.onError = (errorDetails) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  } catch (e) {
    debugPrint('main: Firebase initialization failed: $e');
  }

  runApp(
    const ProviderScope(
      child: KompliApp(),
    ),
  );
}

class KompliApp extends ConsumerWidget {
  const KompliApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Kompli',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
