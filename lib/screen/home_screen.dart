import 'dart:async';
import 'dart:developer';

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
import 'package:anysend/utils/io.dart';
import 'package:anysend/utils/network.dart';
import 'package:anysend/widgets/desktop_picker_button.dart';
import 'package:anysend/widgets/drop_region.dart';
import 'package:anysend/widgets/file_view.dart';
import 'package:anysend/widgets/mobile_picker_button.dart';
import 'package:anysend/widgets/presence_icon.dart';
import 'package:anysend/widgets/presence_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:forui/forui.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

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

  List<FileInfo> files = [];

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

  Future<bool> _onRequestHandler(String clientAddress) async {
    final accept = await showFDialog(
      context: context,
      builder: (context, _, __) {
        final theme = context.theme;
        final address = splitAddress(clientAddress);
        return FDialog.adaptive(
          title: Text('Incoming File Transfer'),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  text: address.$1,
                  children: [
                    TextSpan(
                      text: address.$2,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: ' wants to send you files.'),
                  ],
                  style: theme.typography.sm.copyWith(
                    color: theme.colors.mutedForeground,
                  ),
                ),
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

  void _onFilePick(List<FileInfo> pickedFiles) {
    setState(() {
      files = [...files, ...pickedFiles];
    });
  }

  @override
  Widget build(BuildContext context) {
    return FScaffold(
      header: FHeader(
        title: Text(appName),
        suffixes: [
          if (files.isNotEmpty)
            FButton.icon(
              onPress: () {
                setState(() {
                  files = [];
                });
              },
              child: Icon(FIcons.x),
            ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: (files.isEmpty) ? _fileEmptyView() : _fileSelectedView(),
        ),
      ),
    );
  }

  _fileEmptyView() {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: isDesktop
                ? DesktopPickerButton(onFileAdd: _onFilePick)
                : MobilePickerButton(onPick: _onFilePick),
          ),
        ),
        PresenceView(),
      ],
    );
  }

  _fileSelectedView() {
    return Column(
      children: [
        PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            setState(() {
              files = [];
            });
          },
          child: Expanded(
            child: FileDropRegion(
              onFileAdd: (fileInfo) {
                setState(() {
                  files = [...files, fileInfo];
                });
              },
              child: ListView.builder(
                itemCount: files.length,
                itemBuilder: (context, index) {
                  final file = files[index];
                  return Padding(
                    padding: index == 0
                        ? EdgeInsetsGeometry.fromLTRB(0, 8, 0, 8)
                        : EdgeInsetsGeometry.only(bottom: 8),
                    child: FileInfoTile(
                      fileInfo: file,
                      // fileSize: file.size,
                      onRemoveTap: () {
                        setState(() {
                          files = [...files]..remove(file);
                        });
                      },
                    ),
                  );
                },
              ),
            ),
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
                  speedometerReadingStream: client.speedometerReadingsStream,
                  fileNameStream: client.fileNameStream,
                  transferNotifier: sendStateNotifier,
                ),
              ),
            ).then((value) {
              client.reset();
              sendStateNotifier.value = TransferState.idle;
            });

            try {
              final accpeted = await client.requestUpload(device.ipAddress);
              if (!accpeted) {
                sendStateNotifier.value = TransferState.failed;
                return;
              }
              sendStateNotifier.value = TransferState.inProgress;
              await client.upload(files, device.ipAddress);
              sendStateNotifier.value = TransferState.completed;
            } catch (e) {
              sendStateNotifier.value = TransferState.failed;
            }
          },
        ),
      ],
    );
  }
}
