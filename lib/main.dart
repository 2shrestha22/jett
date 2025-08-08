import 'package:anysend/receive.dart';
import 'package:anysend/send.dart';
import 'package:flutter/material.dart';

void main() {
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
      title: 'Flutter Demo',
      home: Builder(
        builder: (context) {
          return Scaffold(
            appBar: AppBar(title: const Text('Flutter Demo Home Page')),
            body: Center(
              child: Row(
                spacing: 16,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SendScreen(),
                        ),
                      );
                    },
                    child: const Text('Send'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ReceiveScreen(),
                        ),
                      );
                    },
                    child: const Text('Receive'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
