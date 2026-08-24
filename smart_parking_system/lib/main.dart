import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'core/theme.dart';
import 'providers/parking_provider.dart';
import 'providers/user_provider.dart';
import 'providers/notification_provider.dart';
import 'widgets/notification_toast_layer.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/verify_email_screen.dart';
import 'screens/home_screen.dart';
import 'screens/parking_details_screen.dart';
import 'screens/reservation_screen.dart';
import 'screens/statistics_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/report_issue_screen.dart';
import 'screens/parking_chat_screen.dart';
import 'screens/favorites_screen.dart';
import 'screens/notifications_settings_screen.dart';
import 'screens/security_screen.dart';
import 'screens/help_screen.dart';
import 'models/parking_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const SmartParkingApp());
}

class SmartParkingApp extends StatelessWidget {
  const SmartParkingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ParkingProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: MaterialApp(
        title: 'Smart Parking Sarajevo',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        scrollBehavior: AppScrollBehavior(),
        locale: const Locale('bs', 'BA'),
        supportedLocales: const [
          Locale('bs', 'BA'),
          Locale('en', 'US'),
        ],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        
        
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
            child: NotificationToastLayer(child: child!),
          );
        },
        initialRoute: '/',
        onGenerateRoute: (settings) {
          switch (settings.name) {
            case '/':
              return _fadeRoute(const SplashScreen());
            case '/login':
              return _slideRoute(const LoginScreen());
            case '/verify-email':
              return _slideRoute(const VerifyEmailScreen());
            case '/home':
              return _fadeRoute(const HomeScreen());
            case '/parking-details':
              final parking = settings.arguments as ParkingModel;
              return _slideRoute(ParkingDetailsScreen(parking: parking));
            case '/reservation':
              final parking = settings.arguments as ParkingModel;
              return _slideRoute(ReservationScreen(parking: parking));
            case '/statistics':
              return _slideRoute(const StatisticsScreen());
            case '/profile':
              return _slideRoute(const ProfileScreen());
            case '/report-issue':
              final parking = settings.arguments as ParkingModel;
              return _slideRoute(ReportIssueScreen(parking: parking));
            case '/parking-chat':
              final parking = settings.arguments as ParkingModel;
              return _slideRoute(ParkingChatScreen(parking: parking));
            case '/favorites':
              return _slideRoute(const FavoritesScreen());
            case '/notifications-settings':
              return _slideRoute(const NotificationsSettingsScreen());
            case '/security':
              return _slideRoute(const SecurityScreen());
            case '/help':
              return _slideRoute(const HelpScreen());
            default:
              return _fadeRoute(const SplashScreen());
          }
        },
      ),
    );
  }

  PageRoute _fadeRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
      transitionDuration: const Duration(milliseconds: 400),
    );
  }

  PageRoute _slideRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) {
        final tween = Tween(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic));
        return SlideTransition(
          position: animation.drive(tween),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      transitionDuration: const Duration(milliseconds: 350),
    );
  }
}
