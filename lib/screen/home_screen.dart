import 'package:anysend/screen/receive_screen.dart';
import 'package:anysend/screen/send_screen.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FScaffold(
      header: FHeader(title: Text('AnySend')),
      child: Center(
        child: Row(
          spacing: 16,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SendScreen()),
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
  }
}
