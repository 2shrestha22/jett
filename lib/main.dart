import 'dart:io';

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:jett/discovery/konst.dart';
import 'package:jett/platform/platform_api.dart';
import 'package:jett/screen/about_screen.dart';
import 'package:jett/screen/apk_picker_screen.dart';
import 'package:jett/screen/home_screen.dart';
import 'package:jett/screen/transfer_screen.dart';
import 'package:jett/utils/device_info.dart';
import 'package:jett/utils/package_info.dart';

import 'package:sentry_flutter/sentry_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Future.wait([PackageInfoHelper.init(), DeviceInfoHelper.init()]);

  if (Platform.isAndroid || Platform.isIOS) {
    PlatformApi.instance.init();
    PlatformApi.instance.getPlatformVersion().then((value) {
      debugPrint('Running on: ${value.string}');
    });
  }

  await SentryFlutter.init(
    (options) {
      options.dsn = 'https://da32f214874c3089e296dc6c2b95578d@o4507385753567232.ingest.de.sentry.io/4510406156615760';
      options.enableAutoSessionTracking = false; // Disable analytics
      options.tracesSampleRate = 0.0; // Disable performance tracing
    },
    appRunner: () => runApp(const MyApp()),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: _router,
      title: appName,
      debugShowCheckedModeBanner: false,
      builder: (context, child) =>
          FTheme(data: FThemes.zinc.light, child: child!),
    );
  }
}

final _router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => HomeScreen()),
    GoRoute(
      path: '/send',
      builder: (_, _) => TransferScreen(transferType: TransferType.send),
    ),
    GoRoute(
      path: '/receive',
      builder: (_, _) => TransferScreen(transferType: TransferType.receive),
    ),
    GoRoute(path: '/pick_apk', builder: (_, _) => ApkPickerScreen()),
    GoRoute(path: '/about', builder: (_, _) => AboutScreen()),
  ],
);
