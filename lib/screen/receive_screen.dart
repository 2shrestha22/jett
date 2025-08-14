import 'dart:async';

import 'package:anysend/discovery/presence.dart';
import 'package:anysend/transfer/server.dart';
import 'package:anysend/widgets/transfer_progress.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

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
      onRequest: (clientAddress) async {
        final accept = await showFDialog(
          context: context,
          builder: (context, _, __) {
            return FDialog.adaptive(
              title: Text('Accept Files?'),
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Files are being sent from $clientAddress.'),
                  Text(
                    'Make sure to match the IP address with the sender\'s screen.',
                  ),
                ],
              ),
              actions: [
                FButton(
                  style: FButtonStyle.secondary(),
                  onPress: () {
                    Navigator.pop(context, false);
                  },
                  child: Text('Cancel'),
                ),
                FButton(
                  style: FButtonStyle.primary(),
                  onPress: () {
                    Navigator.pop(context, true);
                  },
                  child: Text('Accept'),
                ),
              ],
            );
          },
        );

        return accept;
      },
      onStart: () {
        setState(() {
          transfering = true;
        });
        _receiver.stopPresenceAnnounce();
      },
      onComplete: () async {
        setState(() {
          transfering = false;
        });
        await showFDialog(
          context: context,
          builder: (context, _, __) {
            return FDialog.adaptive(
              title: Text('Completed!'),
              actions: [
                FButton(
                  style: FButtonStyle.primary(),
                  onPress: () {
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
    return FScaffold(
      child: Center(
        child: Column(
          spacing: 8,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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
                      spacing: 8,
                      children: [
                        TransferProgressIndicator(progress: progress),
                        Text('Receiving: $fileName'),
                      ],
                    );
                  }
                  return SizedBox.shrink();
                },
              )
            else ...[
              Icon(FIcons.download),
              const Text('Waiting for files...'),
            ],
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
