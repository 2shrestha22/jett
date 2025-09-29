import 'package:go_router/go_router.dart';
import 'package:jett/discovery/konst.dart';
import 'package:jett/platform/platform_api.dart';
import 'package:jett/screen/apk_picker_screen.dart';
import 'package:jett/screen/home_screen.dart';
import 'package:jett/screen/transfer_screen.dart';
import 'package:jett/utils/device_info.dart';
import 'package:jett/utils/package_info.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  PlatformApi.instance.init();
  await Future.wait([PackageInfoHelper.init(), DeviceInfoHelper.init()]);

  PlatformApi.instance.getPlatformVersion().then((value) {
    debugPrint('Running on: ${value.string}');
  });

  runApp(const MyApp());
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
      builder: (context, state) =>
          TransferScreen(transferType: TransferType.send),
    ),
    GoRoute(
      path: '/receive',
      builder: (context, state) =>
          TransferScreen(transferType: TransferType.receive),
    ),
    GoRoute(path: '/pick_apk', builder: (context, state) => ApkPickerScreen()),
  ],
);
