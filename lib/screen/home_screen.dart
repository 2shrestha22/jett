import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:jett/discovery/konst.dart';
import 'package:jett/discovery/presence.dart';
import 'package:jett/model/device.dart';
import 'package:jett/model/message.dart';
import 'package:jett/model/resource.dart';
import 'package:jett/model/transfer_status.dart';
import 'package:jett/screen/send/online_devices.dart';
import 'package:jett/screen/send/presence_notifier.dart';
import 'package:jett/transfer/client.dart';
import 'package:jett/transfer/server.dart';
import 'package:jett/utils/io.dart';
import 'package:jett/utils/network.dart';
import 'package:jett/widgets/drop_region.dart';
import 'package:jett/widgets/file_view.dart';
import 'package:jett/widgets/picker_buttons.dart';
import 'package:jett/widgets/presence_view.dart';
import 'package:jett/widgets/safe_area.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../platform/platform_api.dart';

class HomeScreen extends StatefulHookWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final presenceBroadcaster = PresenceBroadcaster();

  final presenceListener = PresenceListener();
  final presenceNotifier = PresenceNotifier();

  final List<Resource> resources = [];

  final platformApi = PlatformApi.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _initBroadcaster();
    _initListener();

    _initServer();

    _initShareIntenet();
  }

  void _onFilesReceived(List<ContentResource> files) {
    setState(() {
      // don't replace, just add so that uses can easily add files multiple times
      // resources.clear();
      resources.addAll(files);
    });
  }

  void _initShareIntenet() {
    if (isDesktop) return;

    platformApi.getInitialFiles().then(_onFilesReceived);
    platformApi.files().listen(_onFilesReceived);
  }

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
    server.transferState.listen((event) {
      switch (event) {
        case TransferState.waiting:
          _onRequestHandler();
          break;
        case TransferState.inProgress:
          _onDownloadStartHandler();
          break;
        default:
          break;
      }
    });

    await server.start();
  }

  Future<void> _onRequestHandler() async {
    final accept = await showFDialog(
      context: context,
      builder: (context, _, _) {
        final theme = context.theme;
        final address = splitAddress(server.senderIp);
        return FDialog.adaptive(
          title: Text('Incoming File Transfer'),
          body: Column(
            mainAxisSize: .min,
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

    if (accept) {
      server.acceptRequest();
    } else {
      server.rejectRequest();
    }
  }

  Future<void> _onDownloadStartHandler() async {
    presenceBroadcaster.stopPresenceAnnounce();
    await context.push('/receive');
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
          IconButton(
            onPressed: () {
              context.push('/about');
            },
            icon: Icon(LucideIcons.info),
          ),
        ],
      ),
      child: FSafeArea(
        child: (resources.isEmpty) ? _fileEmptyView() : _fileSelectedView(),
      ),
    );
  }

  Column _fileEmptyView() {
    return Column(
      children: [
        Expanded(
          child: Center(child: PickerButton(onResourceAdd: _onFilePick)),
        ),
        PresenceView(),
        SizedBox(height: 8),
      ],
    );
  }

  Column _fileSelectedView() {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: PickerButtonBar(
            onResourceAdd: _onFilePick,
            onClear: () {
              setState(() {
                resources.clear();
              });
            },
          ),
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
            client.requestUpload(resources, device.ipAddress);
            await context.push('/send');
            client.reset();
          },
        ),
      ],
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // TODO: handle app resume and paused states and idle timeouts
    switch (state) {
      case AppLifecycleState.resumed:
        log('Resumed');
        break;
      case AppLifecycleState.paused:
        log('Paused');
        break;
      default:
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    presenceBroadcaster.close();
    presenceListener.close();
    presenceNotifier.dispose();

    server.close();

    super.dispose();
  }
}
