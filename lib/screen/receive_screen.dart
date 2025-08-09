import 'dart:async';

import 'package:anysend/discovery/multicast.dart';
import 'package:anysend/transfer/server.dart';
import 'package:flutter/material.dart';

class ReceiveScreen extends StatefulWidget {
  const ReceiveScreen({super.key});

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> {
  final _receiver = Receiver();
  final _server = Server();

  @override
  void initState() {
    super.initState();
    _initReceiver();
  }

  Future<void> _initReceiver() async {
    await _receiver.init();
    await _server.start();
    await _receiver.announcePresense();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Receive')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.download, size: 50),

            StreamBuilder(
              stream: _server.progressStream,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return Text(
                    'Progress: ${snapshot.data!.toStringAsFixed(2)}%',
                  );
                } else {
                  return const Text('Waiting for files...');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _receiver.close();
    _server.close();
    super.dispose();
  }
}
