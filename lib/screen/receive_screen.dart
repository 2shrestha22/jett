import 'dart:async';

import 'package:anysend/discovery/multicast.dart';
import 'package:flutter/material.dart';

class ReceiveScreen extends StatefulWidget {
  const ReceiveScreen({super.key});

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> {
  final receiver = Receiver();

  @override
  void initState() {
    super.initState();
    _initReceiver();
  }

  Future<void> _initReceiver() async {
    await receiver.init();
    await receiver.announcePresense();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Receive')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [Icon(Icons.download, size: 50), Text('Waiting...')],
        ),
      ),
    );
  }

  @override
  void dispose() {
    receiver.close();
    super.dispose();
  }
}
