import 'package:anysend/model/device.dart';
import 'package:anysend/notifier/receivers_notifier.dart';
import 'package:anysend/discovery/presence.dart';
import 'package:anysend/screen/widgets/picker_buttons.dart';
import 'package:anysend/transfer/client.dart';
import 'package:anysend/utils/data.dart';
import 'package:anysend/utils/network.dart';
import 'package:anysend/widgets/file_view.dart';
import 'package:anysend/widgets/transfer_progress.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

class SendScreen extends StatefulWidget {
  const SendScreen({super.key});

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  final presenceListener = PresenceListener();
  final notifier = ReceiversNotifier();
  final files = <PlatformFile>[];
  late final Client client;

  bool transfering = false;
  String ip = '';

  @override
  void initState() {
    super.initState();
    getLocalIp().then((ip) {
      setState(() {
        this.ip = ip;
      });
    });
    _initListener();
    client = Client(
      onStart: () {
        // setState(() {
        //   transfering = true;
        // });
      },
      onComplete: (speedMbps) async {
        await showFDialog(
          context: context,
          builder: (context, _, __) {
            return FDialog.adaptive(
              title: Text('Completed!'),
              body: Text(formatTransferRate(speedMbps)),
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
        setState(() {
          transfering = false;
        });
      },
    );
  }

  Future<void> _initListener() async {
    await presenceListener.listenMessage((message, ipAddress, port) {
      notifier.add(
        Device(ipAddress: ipAddress, port: port, name: message.name),
        message.available,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return FScaffold(
      child: Column(
        children: [
          if (files.isEmpty)
            Expanded(
              child: Center(
                child: PickerButtons(
                  onPick: (files) {
                    setState(() {
                      this.files.addAll(files);
                    });
                  },
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: files.length,
                itemBuilder: (context, index) {
                  final file = files[index];
                  return Padding(
                    padding: index == 0
                        ? EdgeInsetsGeometry.fromLTRB(0, 8, 0, 8)
                        : EdgeInsetsGeometry.only(bottom: 8),
                    child: FileInfoTile(
                      filePath: file.path!,
                      fileSize: file.size,
                      onRemoveTap: () {
                        setState(() {
                          files.remove(file);
                        });
                      },
                    ),
                  );
                },
              ),
            ),
          if (transfering)
            SizedBox(
              height: 100,
              child: StreamBuilder(
                stream: client.transferMetadata,
                builder: (context, asyncSnapshot) {
                  final data = asyncSnapshot.data;
                  if (data != null) {
                    final progress = data.transferredBytes / data.totalSize;
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        TransferProgressIndicator(progress: progress),
                        if (data.speedBps != null)
                          Center(
                            child: Text(
                              formatTransferRate(data.speedBps!),
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      Text('Waiting for receiver to accept...'),
                      Text('Your IP: $ip'),
                    ],
                  );
                },
              ),
            )
          else
            SizedBox(
              height: 100,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: ListenableBuilder(
                  listenable: notifier,
                  builder: (context, child) {
                    if (notifier.isEmpty) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        spacing: 8,
                        children: [
                          FProgress.circularIcon(),
                          Text('Searching for devices...'),
                        ],
                      );
                    }
                    return Row(
                      spacing: 8,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: notifier.devices
                          .map(
                            (device) => FButton(
                              prefix: Icon(FIcons.send),
                              onPress: () => _handleOnPress(device),
                              child: Text(device.name),
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _handleOnPress(Device device) async {
    if (files.isEmpty) {
      await showFDialog(
        context: context,
        builder: (context, _, __) {
          return FDialog.adaptive(
            title: Text('No files selected'),
            body: Text('Please select files to send.'),
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
      return;
    }
    setState(() {
      transfering = true;
    });
    try {
      final request = await client.requestTransfer(device.ipAddress);
      if (request) {
        await client.upload(files, device.ipAddress);
      }
    } finally {
      setState(() {
        transfering = false;
      });
    }
  }

  @override
  void dispose() {
    presenceListener.close();
    notifier.dispose();
    super.dispose();
  }
}
