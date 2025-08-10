import 'package:anysend/screen/home_screen.dart';
import 'package:anysend/screen/receive_screen.dart';
import 'package:anysend/screen/send_screen.dart';
import 'package:anysend/utils/device_info.dart';
import 'package:anysend/utils/package_info.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait([PackageInfoHelper.init(), DeviceInfoHelper.init()]);

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
    return MaterialApp(
      title: 'AnySend',
      color: Colors.black,
      builder: (context, child) =>
          FTheme(data: FThemes.zinc.light, child: child!),
      home: HomeScreen(),
    );
  }
}
