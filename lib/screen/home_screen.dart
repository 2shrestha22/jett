import 'dart:async';

import 'package:anysend/core/hooks.dart';
import 'package:anysend/discovery/konst.dart';
import 'package:anysend/discovery/presence.dart';
import 'package:anysend/model/device.dart';
import 'package:anysend/model/file_info.dart';
import 'package:anysend/model/transfer_status.dart';
import 'package:anysend/screen/send/online_devices.dart';
import 'package:anysend/screen/send/picker_buttons.dart';
import 'package:anysend/screen/send/presence_notifier.dart';
import 'package:anysend/screen/transfer_screen.dart';
import 'package:anysend/transfer/client.dart';
import 'package:anysend/transfer/server.dart';
import 'package:anysend/widgets/file_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:forui/forui.dart';

class HomeScreen extends StatefulHookWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final presenceBroadcaster = PresenceBroadcaster();

  final presenceListener = PresenceListener();
  final presenceNotifier = PresenceNotifier();

  final sendStateNotifier = ValueNotifier(TransferState.idle);
  final receiveStateNotifier = ValueNotifier(TransferState.idle);

  late final Server server;
  final Client client = Client();

  @override
  void initState() {
    super.initState();

    _initBroadcaster();
    _initListener();

    _initServer();
  }

  Future<void> _initBroadcaster() async {
    await presenceBroadcaster.init();
    presenceBroadcaster.startPresenceAnnounce();
  }

  _initListener() async {
    await presenceListener.init();
    presenceListener.startListening(_notifierUpdateCallback);
  }

  void _notifierUpdateCallback(message, ipAddress, port) {
    presenceNotifier.update(
      Device(ipAddress: ipAddress, port: port, name: message.name),
      message.available,
    );
  }

  _initServer() async {
    server = Server(
      onRequest: _onRequestHandler,
      onDownloadStart: _onDownloadStartHandler,
      onDownloadFinish: () {
        receiveStateNotifier.value = TransferState.completed;
      },
      onError: () {
        receiveStateNotifier.value = TransferState.failed;
      },
    );
    await server.start();
  }

  Future<bool> _onRequestHandler(clientAddress) async {
    final accept = await showFDialog(
      context: context,
      builder: (context, _, __) {
        return FDialog.adaptive(
          title: Text('Incoming File Transfer'),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$clientAddress wants to send you files.'),
              Text(
                "Please confirm the sender's IP address matches your screen.",
              ),
            ],
          ),
          actions: [
            FButton(
              style: FButtonStyle.secondary(),
              onPress: () {
                Navigator.pop(context, false);
              },
              child: Text('Decline'),
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

  Future<void> _onDownloadStartHandler() async {
    presenceBroadcaster.stopPresenceAnnounce();
    receiveStateNotifier.value = TransferState.inProgress;
    await Navigator.push<TransferState>(
      context,
      MaterialPageRoute(
        builder: (context) => TransferScreen(
          transferType: TransferType.receive,
          speedometerReadingStream: server.speedometerReadingStream,
          fileNameStream: server.fileNameStream,
          transferNotifier: receiveStateNotifier,
        ),
      ),
    );
    // user cancelled the tranfer while in progress
    // server.requestCancel();
    server.reset();
    presenceBroadcaster.startPresenceAnnounce();
  }

  @override
  Widget build(BuildContext context) {
    final localAddress = useLocalAddress();
    final files = useState<List<FileInfo>>([]);

    return FScaffold(
      header: FHeader(title: Text(appName)),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            if (files.value.isEmpty) ...[
              Spacer(),
              Center(
                child: PickerButtons(
                  onPick: (data) {
                    files.value = data;
                  },
                ),
              ),
              Spacer(),
              FAvatar.raw(size: 40, child: Icon(FIcons.radio, size: 30)),
              Text('Online', style: context.theme.typography.xs),
              Text(
                'Your Address: ${localAddress.value}',
                style: context.theme.typography.sm,
              ),
            ] else ...[
              Expanded(
                child: ListView.builder(
                  itemCount: files.value.length,
                  itemBuilder: (context, index) {
                    final file = files.value[index];
                    return Padding(
                      padding: index == 0
                          ? EdgeInsetsGeometry.fromLTRB(0, 8, 0, 8)
                          : EdgeInsetsGeometry.only(bottom: 8),
                      child: FileInfoTile(
                        fileName: file.name,
                        // fileSize: file.size,
                        onRemoveTap: () {
                          files.value = [...files.value]..remove(file);
                        },
                      ),
                    );
                  },
                ),
              ),

              OnlineDevices(
                notifier: presenceNotifier,
                onTap: (device) async {
                  sendStateNotifier.value = TransferState.waiting;
                  Navigator.push<TransferState>(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TransferScreen(
                        transferType: TransferType.send,
                        speedometerReadingStream:
                            client.speedometerReadingsStream,
                        fileNameStream: client.fileNameStream,
                        transferNotifier: sendStateNotifier,
                      ),
                    ),
                  ).then((value) {
                    client.reset();
                    sendStateNotifier.value = TransferState.idle;
                  });

                  try {
                    final accpeted = await client.requestUpload(
                      device.ipAddress,
                    );
                    if (!accpeted) {
                      sendStateNotifier.value = TransferState.failed;
                      return;
                    }
                    sendStateNotifier.value = TransferState.inProgress;
                    await client.upload(files.value, device.ipAddress);
                    sendStateNotifier.value = TransferState.completed;
                  } catch (e) {
                    sendStateNotifier.value = TransferState.failed;
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
