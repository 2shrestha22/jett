import 'package:anysend/model/device.dart';
import 'package:anysend/model/file_info.dart';
import 'package:anysend/notifier/receivers_notifier.dart';
import 'package:anysend/discovery/presence.dart';
import 'package:anysend/screen/widgets/picker_buttons.dart';
import 'package:anysend/screen/widgets/speedometer_widget.dart';
import 'package:anysend/transfer/client.dart';
import 'package:anysend/utils/data.dart';
import 'package:anysend/utils/network.dart';
import 'package:anysend/widgets/file_view.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

enum UploadState { idle, waitingForReceiver, uploading }

class SendScreen extends StatefulWidget {
  const SendScreen({super.key});

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  final presenceListener = PresenceListener();
  final receivers = Receivers();
  final files = <FileInfo>[];
  late final Client client;

  UploadState uploadState = UploadState.idle;
  String ipAddr = '';

  @override
  void initState() {
    super.initState();
    getLocalIp().then((ip) {
      setState(() {
        ipAddr = ip;
      });
    });
    _initPresenceListener();
    client = Client(
      onUploadStart: _onUploadStartHandler,
      onUploadFinish: _onUploadFinishHandler,
    );
  }

  void _onUploadStartHandler() {
    setState(() {
      uploadState = UploadState.uploading;
    });
  }

  void _onUploadFinishHandler() async {
    await showFDialog(
      context: context,
      builder: (context, _, __) {
        return FDialog.adaptive(
          title: Text('Files Sent!'),
          body: Text(
            formatTransferRate(client.speedometerReadings?.avgSpeedBps ?? 0),
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
    setState(() {
      files.clear();
      uploadState = UploadState.idle;
    });
  }

  Future<void> _initPresenceListener() async {
    await presenceListener.init();
    await presenceListener.listenMessage((message, ipAddress, port) {
      receivers.add(
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
                      fileName: file.name,
                      // fileSize: file.size,
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
          if (uploadState == UploadState.uploading)
            SpeedometerWidget(
              speedometerReadingsStream: client.speedometerReadingsStream,
            ),
          if (uploadState == UploadState.waitingForReceiver)
            SizedBox(
              height: 100,
              child: Center(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      spacing: 8,
                      children: [
                        FProgress.circularIcon(),
                        Text('Waiting for receiver to accept.'),
                      ],
                    ),
                    Text('Your IP: $ipAddr'),
                  ],
                ),
              ),
            ),
          if (uploadState == UploadState.idle)
            SizedBox(
              height: 100,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: ListenableBuilder(
                  listenable: receivers,
                  builder: (context, child) {
                    if (receivers.isEmpty) {
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
                      children: receivers.devices
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
      uploadState = UploadState.waitingForReceiver;
    });
    try {
      final request = await client.requestUpload(device.ipAddress);
      if (request) {
        await client.upload(files, device.ipAddress);
      }
    } finally {
      setState(() {
        uploadState = UploadState.idle;
      });
    }
  }

  @override
  void dispose() {
    presenceListener.close();
    receivers.dispose();
    super.dispose();
  }
}
