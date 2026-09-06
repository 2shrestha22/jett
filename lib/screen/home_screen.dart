import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:jett/adaptive_dialog.dart';
import 'package:jett/discovery/konst.dart';
import 'package:jett/discovery/presence_broadcaster.dart';
import 'package:jett/discovery/presence_listener.dart';
import 'package:jett/model/device.dart';
import 'package:jett/model/message.dart';
import 'package:jett/model/resource.dart';
import 'package:jett/model/transfer_status.dart';
import 'package:jett/screen/send/online_devices.dart';
import 'package:jett/screen/send/presence_notifier.dart';
import 'package:jett/transfer/client.dart';
import 'package:jett/transfer/server.dart';
import 'package:jett/utils/io.dart';
import 'package:jett/utils/data.dart';
import 'package:jett/widgets/drop_region.dart';
import 'package:jett/widgets/file_view.dart';
import 'package:jett/widgets/picker_buttons.dart';
import 'package:jett/widgets/presence_view.dart';
import 'package:jett/widgets/safe_area.dart';

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
    await presenceBroadcaster.startPresenceAnnounce();
  }

  Future<void> _initListener() async {
    await presenceListener.init();
    presenceListener.startListening(
      _notifierUpdateCallback,
      onDiscoveryTimeout: _restartDiscovery,
    );
  }

  int _discoveryRestartCount = 0;
  Future<void> _restartDiscovery() async {
    if (_discoveryRestartCount > 0) return;
    _discoveryRestartCount++;

    log('Self discovery failed, restarting discovery services...');
    presenceBroadcaster.close();
    await presenceListener.close();

    // Re-initialize
    await _initBroadcaster();
    await _initListener();
  }

  void _notifierUpdateCallback(Message message, String ipAddress) {
    presenceNotifier.update(
      Device(
        ipAddress: ipAddress,
        name: message.name,
        protocolVersion: message.protocolVersion,
        fingerprint: message.fingerprint,
      ),
      message.available,
    );
  }

  // TransferWaiting and TransferInProgress are re-emitted as a transfer
  // advances, so each is acted on once per session.
  String? _promptedSession;
  String? _navigatedSession;

  /// Closes the prompt currently on screen, if any, without answering it.
  VoidCallback? _closePrompt;

  /// Asks the user to compare this device's words against the ones shown on
  /// the device being sent to, before anything leaves here.
  Future<bool> _confirmTrust(
    String peerName,
    List<String> words,
    Future<void> dismissed,
  ) async {
    if (!mounted) return false;

    final navigator = Navigator.of(context, rootNavigator: true);
    var settled = false;
    // the other device answered or hung up while this was still on screen
    unawaited(
      dismissed.then((_) {
        if (settled) return;
        settled = true;
        navigator.pop();
      }),
    );

    final confirmed = await showFDialog<bool>(
      context: context,
      builder: (context, _, _) {
        final theme = context.theme;
        return AdaptiveDialog(
          title: Text('Verify device'),
          body: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: [
              // Names the device so the person knows which screen to compare
              // against; nothing else competes with the words here.
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(text: 'Does '),
                    TextSpan(
                      text: peerName,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: ' show these same words?'),
                  ],
                  style: theme.typography.body.sm.copyWith(
                    color: theme.colors.mutedForeground,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colors.border),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  words.join('   '),
                  textAlign: TextAlign.center,
                  style: theme.typography.body.md.copyWith(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
          actions: [
            FButton(
              variant: .secondary,
              onPress: () => Navigator.pop(context, false),
              child: Text('Doesn\'t match'),
            ),
            FButton(
              variant: .primary,
              onPress: () => Navigator.pop(context, true),
              child: Text('Yes, send'),
            ),
          ],
        );
      },
    );

    settled = true;
    return confirmed ?? false;
  }

  Future<void> _initServer() async {
    server.transferState.listen((state) {
      // The sender dropped its socket, was superseded, or moved on: take the
      // prompt down rather than leaving it asking about a dead request.
      final open = _promptedSession;
      if (open != null &&
          !(state is TransferWaiting && state.sessionId == open)) {
        _closePrompt?.call();
      }

      switch (state) {
        case TransferWaiting(:final sessionId):
          if (_promptedSession == sessionId) break;
          _onRequestHandler(sessionId);
        case TransferInProgress(:final sessionId):
          if (_navigatedSession == sessionId) break;
          _navigatedSession = sessionId;
          _onDownloadStartHandler();
        case _:
          break;
      }
    });

    await server.start();
  }

  Future<void> _onRequestHandler(String sessionId) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    final senderName = server.senderName;
    final files = server.offeredFiles;
    final totalSize = server.offeredTotalSize;
    // deliberately slow, and off the main isolate; the screen may be gone by
    // the time it returns
    final words = await server.verificationPrompt();
    if (!mounted) return;

    _promptedSession = sessionId;
    var settled = false;
    _closePrompt = () {
      if (settled) return;
      settled = true;
      _promptedSession = null;
      navigator.pop();
    };

    final accept = await showFDialog<bool>(
      context: context,
      builder: (context, _, _) {
        final theme = context.theme;
        final summary = files.length == 1
            ? files.single.name
            : '${files.length} files';
        return AdaptiveDialog(
          title: Text('Incoming File Transfer'),
          body: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: [
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: senderName.isEmpty ? server.senderIp : senderName,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(
                      text:
                          ' wants to send you $summary '
                          '(${formatFileSize(totalSize)}).',
                    ),
                  ],
                  style: theme.typography.body.sm.copyWith(
                    color: theme.colors.mutedForeground,
                  ),
                ),
              ),
              // Reference material, not a second question. The decision about
              // whether the words match is made on the sending device, which
              // is the only side that can refuse in time to matter. Accepting
              // here is about the files.
              if (words.isNotEmpty) ...[
                Text(
                  'This device is showing these words to '
                  '${senderName.isEmpty ? 'the sender' : senderName}.',
                  style: theme.typography.body.sm.copyWith(
                    color: theme.colors.mutedForeground,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.colors.border),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    words.join('   '),
                    textAlign: TextAlign.center,
                    style: theme.typography.body.md.copyWith(
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            FButton(
              variant: .secondary,
              onPress: () {
                Navigator.pop(context, false);
              },
              child: Text('Decline'),
            ),
            FButton(
              variant: .primary,
              onPress: () {
                Navigator.pop(context, true);
              },
              child: Text('Accept'),
            ),
          ],
        );
      },
    );

    _closePrompt = null;
    // closed from under us because the request is no longer live; the server
    // has already moved on and is not waiting for an answer
    if (settled) return;
    settled = true;
    _promptedSession = null;

    // dismissing the dialog without choosing declines the transfer
    if (accept ?? false) {
      server.acceptRequest();
    } else {
      server.rejectRequest();
    }
  }

  Future<void> _onDownloadStartHandler() async {
    if (!mounted) return;
    presenceBroadcaster.stopPresenceAnnounce();
    await context.push('/receive');
    server.reset();
    await presenceBroadcaster.startPresenceAnnounce();
  }

  void _onFilePick(List<Resource> pickedResources) {
    setState(() {
      resources.addAll(pickedResources);
    });
  }

  void _releaseResources() {
    for (final resource in resources) {
      resource.release();
    }
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
            icon: Icon(FLucideIcons.info),
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
              _releaseResources();
              setState(() {
                resources.clear();
              });
            },
          ),
        ),
        PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            _releaseResources();
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
                        resource.release();
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
            // a transfer is already running, ignore the tap instead of
            // starting a second one that would clobber its state
            if (!client.startUpload(resources, device, _confirmTrust)) return;
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

    _releaseResources();

    presenceBroadcaster.close();
    presenceListener.close();
    presenceNotifier.dispose();

    server.close();

    super.dispose();
  }
}
