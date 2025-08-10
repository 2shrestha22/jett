import 'package:anysend/model/device.dart';
import 'package:anysend/notifier/receivers_notifier.dart';
import 'package:anysend/discovery/presence.dart';
import 'package:anysend/screen/widgets/online_receivers.dart';
import 'package:anysend/screen/widgets/picker_buttons.dart';
import 'package:anysend/transfer/client.dart';
import 'package:anysend/utils/data.dart';
import 'package:anysend/widgets/custom_button.dart';
import 'package:anysend/widgets/file_view.dart';
import 'package:anysend/widgets/transfer_progress.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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

  @override
  void initState() {
    super.initState();
    _initListener();
    client = Client(
      onStart: () {
        setState(() {
          transfering = true;
        });
      },
      onComplete: (speedMbps) {
        setState(() {
          transfering = false;
        });
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text('Completed!'),
              content: Text(formatTransferRate(speedMbps)),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text('Ok'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _initListener() async {
    await presenceListener.listenMessage((message, ipAddress, port) {
      notifier.add(
        Device(
          ipAddress: ipAddress,
          port: port,
          name: message.name,
          lastSeen: DateTime.now(),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return FScaffold(
      header: FHeader.nested(
        title: const Text('Send Screen'),
        prefixes: [FHeaderAction.back(onPress: () {})],
      ),
      child: SafeArea(
        child: Column(
          children: [
            if (!transfering)
              PickerButtons(
                onPick: (files) {
                  setState(() {
                    this.files.addAll(files);
                  });
                },
              ),
            Expanded(
              child: ListView.builder(
                itemCount: files.length,
                itemBuilder: (context, index) {
                  final file = files[index];
                  return FileInfoTile(
                    filePath: file.path!,
                    fileSize: file.size,
                    onRemoveTap: () {
                      setState(() {
                        files.remove(file);
                      });
                    },
                  );
                },
              ),
            ),
            if (transfering)
              StreamBuilder(
                stream: client.transferMetadata,
                builder: (context, asyncSnapshot) {
                  final data = asyncSnapshot.data;
                  if (data != null) {
                    final progress = data.transferredBytes / data.totalSize;
                    return Column(
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
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: TextButton.icon(
                            label: Text('Cancel'),
                            icon: Icon(LucideIcons.x),
                            onPressed: () {},
                          ),
                        ),
                      ],
                    );
                  }
                  return SizedBox.shrink();
                },
              )
            else
              SizedBox(
                width: double.infinity,
                child: CustomButton(
                  onPressed: () async {
                    if (files.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Pick files to send!")),
                      );
                      return;
                    }
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      clipBehavior: Clip.hardEdge,
                      builder: (context) {
                        return ListenableBuilder(
                          listenable: notifier,
                          builder: (context, child) => OnlineRecivers(
                            devices: notifier.devices,
                            onTap: (device) {
                              Navigator.pop(context);
                              client.upload(files, device.ipAddress);
                            },
                          ),
                        );
                      },
                    );
                  },
                  icon: const Icon(LucideIcons.send),
                  label: Text('Send'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    presenceListener.close();
    notifier.dispose();
    super.dispose();
  }

  // showTransferDialog() {
  //   showAdaptiveDialog(
  //     context: context,
  //     barrierDismissible: false,
  //     builder: (context) {
  //       return AlertDialog(
  //         title: Text('Sending'),
  //         actions: [
  //           TextButton(
  //             onPressed: () {
  //               Navigator.pop(context);
  //             },
  //             child: Text('Cancel'),
  //           ),
  //         ],
  //       );
  //     },
  //   );
  // }
}
