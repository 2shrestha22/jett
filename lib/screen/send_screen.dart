import 'package:anysend/model/device.dart';
import 'package:anysend/model/file_info.dart';
import 'package:anysend/notifier/presence_notifier.dart';
import 'package:anysend/discovery/presence.dart';
import 'package:anysend/screen/widgets/picker_buttons.dart';
import 'package:anysend/screen/widgets/send_dialog.dart';
import 'package:anysend/utils/network.dart';
import 'package:anysend/widgets/file_view.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

class SendScreen extends StatefulWidget {
  const SendScreen({super.key});

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  final presenceListener = PresenceListener();
  final presenceNotifier = PresenceNotifier();
  final files = <FileInfo>[];

  String ipAddr = '';

  @override
  void initState() {
    super.initState();
    _initLocalIp();
    _setupPresenceListener();
  }

  void _initLocalIp() {
    getLocalIp().then((ip) {
      setState(() {
        ipAddr = ip;
      });
    });
  }

  Future<void> _setupPresenceListener() async {
    await presenceListener.init();
    presenceListener.startListening(_notifierUpdateCallback);
  }

  void _notifierUpdateCallback(message, ipAddress, port) {
    presenceNotifier.update(
      Device(ipAddress: ipAddress, port: port, name: message.name),
      message.available,
    );
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
          SizedBox(
            height: 100,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: ListenableBuilder(
                listenable: presenceNotifier,
                builder: (context, child) {
                  if (presenceNotifier.devices.isEmpty) {
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
                    children: presenceNotifier.devices
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
                onPress: () => Navigator.pop(context),
                child: Text('Ok'),
              ),
            ],
          );
        },
      );
      return;
    }

    showFDialog<int>(
      useSafeArea: true,
      barrierDismissible: false,
      context: context,
      builder: (context, _, __) => SendDialog(device: device, files: files),
    );
  }

  @override
  void dispose() {
    presenceListener.close();
    presenceNotifier.dispose();
    super.dispose();
  }
}
