import 'dart:async';

import 'package:anysend/discovery/presence.dart';
import 'package:anysend/screen/widgets/speedometer_widget.dart';
import 'package:anysend/transfer/server.dart';
import 'package:anysend/utils/data.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

class ReceiveScreen extends StatefulWidget {
  const ReceiveScreen({super.key});

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> {
  final receiver = PresenceBroadcaster();
  late final Server server;

  bool isReceiving = false;

  @override
  void initState() {
    super.initState();

    server = Server(
      onRequest: _onRequestHandler,
      onDownloadStart: _onDownloadStartHandler,
      onDownloadFinish: _onDownloadFinishHandler,
    );
    _initReceiver();
  }

  void _onDownloadFinishHandler() async {
    setState(() {
      isReceiving = false;
    });
    await showFDialog(
      context: context,
      builder: (context, _, __) {
        return FDialog.adaptive(
          title: Text('Files Received!'),
          body: Text(
            formatTransferRate(server.speedometerReading?.avgSpeedBps ?? 0),
          ),
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
    receiver.startPresenceAnnounce();
  }

  void _onDownloadStartHandler() {
    setState(() {
      isReceiving = true;
    });
    receiver.stopPresenceAnnounce();
  }

  Future<bool> _onRequestHandler(clientAddress) async {
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
  }

  Future<void> _initReceiver() async {
    await receiver.init();
    await server.start();
    await receiver.startPresenceAnnounce();
  }

  @override
  Widget build(BuildContext context) {
    return FScaffold(
      child: Center(
        child: Column(
          spacing: 8,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isReceiving)
              SpeedometerWidget(
                speedometerReadingsStream: server.speedometerReadingStream,
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
    receiver.close();
    server.close();
    super.dispose();
  }
}
