import 'package:anysend/model/device.dart';
import 'package:anysend/notifier/receivers_notifier.dart';
import 'package:anysend/discovery/presence.dart';
import 'package:anysend/transfer/client.dart';
import 'package:anysend/widgets/custom_button.dart';
import 'package:anysend/widgets/file_view.dart';
import 'package:anysend/widgets/loader.dart';
import 'package:anysend/widgets/transfer_progress.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
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

  bool pickingFiles = false;
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
              content: Text(
                'Speed: ${(speedMbps / 8).toStringAsFixed(2)} MB/s',
              ),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Send Screen')),
      floatingActionButton: transfering
          ? null
          : FloatingActionButton(
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
                      builder: (context, child) {
                        return DraggableScrollableSheet(
                          expand: false,
                          builder: (context, scrollController) {
                            final deviecs = notifier.devices;
                            if (deviecs.isEmpty) {
                              return const Center(
                                child: Column(
                                  spacing: 8,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('Searching for devices...'),
                                    Loader(),
                                  ],
                                ),
                              );
                            }
                            return ListenableBuilder(
                              listenable: notifier,
                              builder: (context, child) {
                                return Column(
                                  children: deviecs.map((device) {
                                    return ListTile(
                                      leading: Icon(
                                        LucideIcons.monitorSmartphone,
                                      ),
                                      title: Text(device.name),
                                      subtitle: Text(device.ipAddress),
                                      onTap: () {
                                        // Handle tap on device
                                        Navigator.pop(context);
                                        client.upload(files, device.ipAddress);
                                      },
                                    );
                                  }).toList(),
                                );
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
              child: const Icon(LucideIcons.send),
            ),
      body: SafeArea(
        child: Column(
          children: [
            if (!transfering)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(8.0),
                child: CustomButton(
                  onPressed: () async {
                    final result = await FilePicker.platform.pickFiles(
                      allowMultiple: true,
                      type: FileType.any,
                      onFileLoading: _onFileLoadHandler,
                    );
                    if (result != null && result.files.isNotEmpty) {
                      setState(() {
                        files.addAll(result.files);
                      });
                    }
                  },
                  label: const Text('Pick Files'),
                  icon: const Icon(LucideIcons.filePlus),
                  isLoading: pickingFiles,
                ),
              ),
            Expanded(
              child: ListView.builder(
                itemCount: files.length,
                itemBuilder: (context, index) {
                  final file = files[index];
                  return FileInfoTile(
                    filePath: file.path!,
                    fileSize: file.size,
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
                        if (data.speedMbps != null)
                          Center(
                            child: Text(
                              '${(data.speedMbps! / 8).toStringAsFixed(0)} MB/s',
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
              ),
          ],
        ),
      ),
    );
  }

  _onFileLoadHandler(status) {
    switch (status) {
      case FilePickerStatus.picking:
        setState(() {
          pickingFiles = true;
        });
        break;
      case FilePickerStatus.done:
        setState(() {
          pickingFiles = false;
        });
        break;
    }
  }

  @override
  void dispose() {
    presenceListener.close();
    notifier.dispose();
    super.dispose();
  }
}
