import 'dart:async';

import 'package:jett/discovery/konst.dart';
import 'package:jett/discovery/presence.dart';
import 'package:jett/messages.g.dart';
import 'package:jett/model/device.dart';
import 'package:jett/model/message.dart';
import 'package:jett/model/resource.dart';
import 'package:jett/model/transfer_status.dart';
import 'package:jett/screen/send/online_devices.dart';
import 'package:jett/screen/send/presence_notifier.dart';
import 'package:jett/screen/transfer_screen.dart';
import 'package:jett/screen/widgets/plugin_check_widget.dart';
import 'package:jett/transfer/client.dart';
import 'package:jett/transfer/server.dart';
import 'package:jett/utils/io.dart';
import 'package:jett/utils/network.dart';
import 'package:jett/widgets/desktop_picker_button.dart';
import 'package:jett/widgets/drop_region.dart';
import 'package:jett/widgets/file_view.dart';
import 'package:jett/widgets/mobile_picker_button.dart';
import 'package:jett/widgets/presence_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:forui/forui.dart';

class HomeScreen extends StatefulHookWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> implements JettFlutterApi {
  final presenceBroadcaster = PresenceBroadcaster();

  final presenceListener = PresenceListener();
  final presenceNotifier = PresenceNotifier();

  final sendStateNotifier = ValueNotifier(TransferState.idle);
  final receiveStateNotifier = ValueNotifier(TransferState.idle);

  late final Server server;
  final Client client = Client();

  final List<Resource> resources = [];

  @override
  void initState() {
    super.initState();

    _initBroadcaster();
    _initListener();

    _initServer();

    _initShareIntenet();
  }

  void _onShareIntentReceived(List<PlatformFile> files) {
    setState(() {
      resources.clear();
      resources.addAll(
        files.map((e) => ContentResource(uri: e.uri, name: e.name)),
      );
    });
  }

  void _initShareIntenet() {
    if (isDesktop) return;

    JettFlutterApi.setUp(this);
    JettApi().getInitialFiles().then(_onShareIntentReceived);
  }

  @override
  void onIntent(List<PlatformFile> files) => _onShareIntentReceived(files);

  Future<void> _initBroadcaster() async {
    await presenceBroadcaster.init();
    presenceBroadcaster.startPresenceAnnounce();
  }

  Future<void> _initListener() async {
    await presenceListener.init();
    presenceListener.startListening(_notifierUpdateCallback);
  }

  void _notifierUpdateCallback(Message message, String ipAddress, int port) {
    presenceNotifier.update(
      Device(ipAddress: ipAddress, port: port, name: message.name),
      message.available,
    );
  }

  Future<void> _initServer() async {
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
      builder: (context, _, _) {
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

  void _onFilePick(List<Resource> pickedResources) {
    setState(() {
      resources.addAll(pickedResources);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FScaffold(
      header: FHeader(
        title: Text(appName),
        suffixes: [
          if (resources.isNotEmpty)
            FButton.icon(
              onPress: () {
                setState(() {
                  resources.clear();
                });
              },
              child: Icon(FIcons.x),
            ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: (resources.isEmpty) ? _fileEmptyView() : _fileSelectedView(),
        ),
      ),
    );
  }

  Column _fileEmptyView() {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: isDesktop
                ? DesktopPickerButton(onResourceAdd: _onFilePick)
                : MobilePickerButton(onPick: _onFilePick),
          ),
        ),
        PresenceView(),
        PluginCheckWidget(),
      ],
    );
  }

  Column _fileSelectedView() {
    return Column(
      children: [
        MobilePickerButton(
          onPick: (List<Resource> resources) {
            setState(() {
              this.resources.addAll(resources);
            });
          },
        ),
        PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            setState(() {
              resources.clear();
            });
          },
          child: Expanded(
            child: FileDropRegion(
              onResourceAdd: (fileInfo) {
                setState(() {
                  resources.add(fileInfo);
                });
              },
              child: ListView.builder(
                itemCount: resources.length,
                itemBuilder: (context, index) {
                  final resource = resources[index];
                  return Padding(
                    padding: index == 0
                        ? EdgeInsetsGeometry.fromLTRB(0, 8, 0, 8)
                        : EdgeInsetsGeometry.only(bottom: 8),
                    child: FileInfoTile(
                      resource: resource,
                      // fileSize: file.size,
                      onRemoveTap: () {
                        setState(() {
                          resources.remove(resource);
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
              await client.upload(resources, device.ipAddress);
              sendStateNotifier.value = TransferState.completed;
            } catch (e) {
              sendStateNotifier.value = TransferState.failed;
            }
          },
        ),
      ],
    );
  }

  @override
  Future<void> dispose() async {
    // await _intentSub.cancel();
    super.dispose();
  }
}
