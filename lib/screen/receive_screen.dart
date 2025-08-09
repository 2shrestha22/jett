import 'dart:async';

import 'package:anysend/discovery/presence.dart';
import 'package:anysend/transfer/server.dart';
import 'package:anysend/widgets/transfer_progress.dart';
import 'package:flutter/material.dart';

class ReceiveScreen extends StatefulWidget {
  const ReceiveScreen({super.key});

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> {
  final _receiver = PresenceBroadcaster();
  late final Server _server;

  bool transfering = false;

  @override
  void initState() {
    super.initState();
    _server = Server(
      onStart: () async {
        setState(() {
          transfering = true;
        });
        await _receiver.stopPresenceAnnounce();
      },
      onComplete: () async {
        setState(() {
          transfering = false;
        });
        await showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              content: Text('Completed!'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text('Ok'),
                ),
              ],
            );
          },
        );
        _receiver.startPresenceAnnounce();
      },
    );

    _initReceiver();
  }

  Future<void> _initReceiver() async {
    await _receiver.init();
    await _server.start();
    await _receiver.startPresenceAnnounce();
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
            if (transfering)
              StreamBuilder(
                stream: _server.transferMetadata,
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    final progress =
                        snapshot.data!.transferredBytes /
                        snapshot.data!.totalSize;
                    final fileName = snapshot.data!.fileName;
                    return Column(
                      children: [
                        TransferProgressIndicator(progress: progress),
                        Text('Receiving: $fileName'),
                      ],
                    );
                  }
                  return SizedBox.shrink();
                },
              )
            else
              const Text('Waiting for files...'),
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
